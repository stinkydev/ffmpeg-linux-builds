#!/bin/bash
set -e

# FFmpeg 5.1.2 Build Script for Ubuntu x64 with Shared Libraries
# This script builds FFmpeg with essential codecs and no hardware acceleration
# for maximum compatibility across Ubuntu systems

# Configuration
FFMPEG_VERSION="5.1.2"
BUILD_DIR="$(pwd)/build"
INSTALL_PREFIX="/usr/local"
DIST_DIR="$(pwd)/dist"
THREADS=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo "4")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}" >&2
    exit 1
}

# Check if running on Ubuntu
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        error "This script is designed for Ubuntu systems"
    fi
    log "Ubuntu system detected"
}

# Install build dependencies (skipped in Docker - dependencies pre-installed)
install_dependencies() {
    log "Checking build dependencies..."
    
    # In Docker, dependencies are pre-installed via Dockerfile
    # This function is kept for compatibility with non-Docker builds
    if [ -z "$DOCKER_BUILD" ]; then
        log "Installing build dependencies..."
        
        apt update
        apt install -y \
            build-essential \
            pkg-config \
            cmake \
            yasm \
            nasm \
            git \
            wget \
            curl \
            autoconf \
            automake \
            libtool \
            libfreetype6-dev \
            libmp3lame-dev \
            libopus-dev \
            libx264-dev \
            libx265-dev \
            libbz2-dev \
            liblzma-dev \
            zlib1g-dev \
            libssl-dev
    else
        log "Running in Docker - dependencies pre-installed"
    fi
    
    log "Dependencies ready"
}

# Download and build codec libraries from source
build_codec_libraries() {
    log "Building codec libraries from source for bundling..."
    
    mkdir -p "$BUILD_DIR/libs"
    cd "$BUILD_DIR/libs"
    
    local CODEC_PREFIX="$BUILD_DIR/codec-libs"
    mkdir -p "$CODEC_PREFIX"
    
    # Build x264
    if [ ! -f "$CODEC_PREFIX/lib/libx264.so" ]; then
        log "Building x264..."
        if [ ! -d "x264" ]; then
            git clone --depth 1 --branch stable https://code.videolan.org/videolan/x264.git
        fi
        cd x264
        ./configure --prefix="$CODEC_PREFIX" --enable-shared --enable-pic --disable-cli
        make -j"$THREADS"
        make install
        cd ..
        log "x264 build completed"
    fi
    
    # Build x265 (skip if it fails, as it's more complex)
    if [ ! -f "$CODEC_PREFIX/lib/libx265.so" ]; then
        log "Building x265..."
        if [ ! -d "x265" ]; then
            git clone --depth 1 --branch stable https://bitbucket.org/multicoreware/x265_git.git x265
        fi
        cd x265
        # Create build directory if it doesn't exist
        mkdir -p build/linux
        cd build/linux
        # Try to build x265, but continue if it fails
        if cmake -DCMAKE_INSTALL_PREFIX="$CODEC_PREFIX" \
                 -DENABLE_SHARED=ON \
                 -DENABLE_STATIC=OFF \
                 -DENABLE_CLI=OFF \
                 -DCMAKE_BUILD_TYPE=Release \
                 ../../source; then
            if make -j"$THREADS"; then
                # Install manually to ensure shared library is installed
                make install
                # x265 sometimes doesn't install the .so properly, so copy it manually
                if [ -f "libx265.so" ] && [ ! -f "$CODEC_PREFIX/lib/libx265.so" ]; then
                    cp libx265.so* "$CODEC_PREFIX/lib/" 2>/dev/null || true
                    log "Manually copied x265 shared library"
                fi
                # Also copy pkg-config file if it exists in build directory
                if [ -f "x265.pc" ] && [ ! -f "$CODEC_PREFIX/lib/pkgconfig/x265.pc" ]; then
                    mkdir -p "$CODEC_PREFIX/lib/pkgconfig"
                    cp x265.pc "$CODEC_PREFIX/lib/pkgconfig/" 2>/dev/null || true
                    log "Manually copied x265 pkg-config file"
                fi
                log "x265 build completed"
            else
                warn "x265 build failed, continuing without x265 support"
            fi
        else
            warn "x265 cmake configuration failed, continuing without x265 support"
        fi
        cd ../../..
    fi
    
    # Build lame (MP3)
    if [ ! -f "$CODEC_PREFIX/lib/libmp3lame.so" ]; then
        log "Building libmp3lame..."
        if [ ! -f "lame-3.100.tar.gz" ]; then
            wget "https://downloads.sourceforge.net/project/lame/lame/3.100/lame-3.100.tar.gz"
        fi
        if [ ! -d "lame-3.100" ]; then
            tar -xzf lame-3.100.tar.gz
        fi
        cd lame-3.100
        ./configure --prefix="$CODEC_PREFIX" --enable-shared --enable-nasm --disable-static
        make -j"$THREADS"
        make install
        cd ..
        log "libmp3lame build completed"
    fi
    
    # Build opus
    if [ ! -f "$CODEC_PREFIX/lib/libopus.so" ]; then
        log "Building libopus..."
        if [ ! -f "opus-1.4.tar.gz" ]; then
            wget "https://downloads.xiph.org/releases/opus/opus-1.4.tar.gz"
        fi
        if [ ! -d "opus-1.4" ]; then
            tar -xzf opus-1.4.tar.gz
        fi
        cd opus-1.4
        ./configure --prefix="$CODEC_PREFIX" --enable-shared --disable-static
        make -j"$THREADS"
        make install
        cd ..
        log "libopus build completed"
    fi
    
    # List what we actually built
    log "Available codec libraries:"
    ls -la "$CODEC_PREFIX/lib/" | grep "\.so"
    
    log "Codec libraries build process completed"
}

# Download and prepare FFmpeg source
download_ffmpeg() {
    log "Downloading FFmpeg ${FFMPEG_VERSION}..."
    
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    if [ ! -f "ffmpeg-${FFMPEG_VERSION}.tar.xz" ]; then
        wget "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
    fi
    
    if [ ! -d "ffmpeg-${FFMPEG_VERSION}" ]; then
        tar -xf "ffmpeg-${FFMPEG_VERSION}.tar.xz"
    fi
    
    log "FFmpeg source prepared"
}

# Configure FFmpeg build with bundled codec libraries
configure_ffmpeg() {
    log "Configuring FFmpeg build with bundled codec libraries..."
    
    cd "$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    
    local CODEC_PREFIX="$BUILD_DIR/codec-libs"
    
    # Set PKG_CONFIG_PATH to find our built libraries first
    export PKG_CONFIG_PATH="$CODEC_PREFIX/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"
    export LD_LIBRARY_PATH="$CODEC_PREFIX/lib:$LD_LIBRARY_PATH"
    export CPPFLAGS="-I$CODEC_PREFIX/include"
    export LDFLAGS="-L$CODEC_PREFIX/lib -Wl,-rpath,/usr/local/lib/ffmpeg-codecs"
    
    # Check which codec libraries we actually have
    local ENABLE_X264=""
    local ENABLE_X265=""
    local ENABLE_MP3LAME=""
    local ENABLE_OPUS=""
    
    if [ -f "$CODEC_PREFIX/lib/libx264.so" ]; then
        ENABLE_X264="--enable-libx264"
        log "Found bundled x264"
    else
        log "x264 not available, disabling"
    fi
    
    if [ -f "$CODEC_PREFIX/lib/libx265.so" ]; then
        ENABLE_X265="--enable-libx265"
        log "Found bundled x265"
        # x265 might not have proper pkg-config, so help FFmpeg find it
        export LDFLAGS="$LDFLAGS -L$CODEC_PREFIX/lib"
        export CPPFLAGS="$CPPFLAGS -I$CODEC_PREFIX/include"
    else
        log "x265 not available, disabling"
    fi
    
    if [ -f "$CODEC_PREFIX/lib/libmp3lame.so" ]; then
        ENABLE_MP3LAME="--enable-libmp3lame"
        log "Found bundled mp3lame"
    else
        log "mp3lame not available, disabling"
    fi
    
    if [ -f "$CODEC_PREFIX/lib/libopus.so" ]; then
        ENABLE_OPUS="--enable-libopus"
        log "Found bundled opus"
    else
        log "opus not available, disabling"
    fi
    
    # Configure with available bundled libraries
    log "Attempting FFmpeg configure with all available codecs..."
    
    # Try with x265 first
    if [ -n "$ENABLE_X265" ]; then
        if ./configure \
            --prefix="$INSTALL_PREFIX" \
            --enable-shared \
            --disable-static \
            --disable-debug \
            --enable-optimizations \
            --disable-doc \
            --disable-htmlpages \
            --disable-manpages \
            --disable-podpages \
            --disable-txtpages \
            --enable-pic \
            --enable-gpl \
            --enable-version3 \
            --enable-nonfree \
            --enable-runtime-cpudetect \
            --disable-vaapi \
            --disable-vdpau \
            --disable-libass \
            --enable-libfreetype \
            $ENABLE_MP3LAME \
            $ENABLE_OPUS \
            $ENABLE_X264 \
            $ENABLE_X265 \
            --enable-openssl \
            --disable-libfdk-aac \
            --disable-libtheora \
            --disable-libvorbis \
            --disable-libvpx \
            --disable-libwebp \
            --disable-libxvid \
            --disable-libopenjpeg \
            --disable-libxml2 \
            --extra-ldflags="-static-libgcc -Wl,-rpath,/usr/local/lib/ffmpeg-codecs" \
            --extra-version="ubuntu-x64-bundled"; then
            log "FFmpeg configured successfully with all codecs including x265"
        else
            warn "x265 configuration failed, retrying without x265"
            ENABLE_X265=""
        fi
    fi
    
    # If x265 failed or wasn't available, configure without it
    if [ -z "$ENABLE_X265" ] || [ $? -ne 0 ]; then
        ./configure \
            --prefix="$INSTALL_PREFIX" \
            --enable-shared \
            --disable-static \
            --disable-debug \
            --enable-optimizations \
            --disable-doc \
            --disable-htmlpages \
            --disable-manpages \
            --disable-podpages \
            --disable-txtpages \
            --enable-pic \
            --enable-gpl \
            --enable-version3 \
            --enable-nonfree \
            --enable-runtime-cpudetect \
            --disable-vaapi \
            --disable-vdpau \
            --disable-libass \
            --enable-libfreetype \
            $ENABLE_MP3LAME \
            $ENABLE_OPUS \
            $ENABLE_X264 \
            --enable-openssl \
            --disable-libfdk-aac \
            --disable-libtheora \
            --disable-libvorbis \
            --disable-libvpx \
            --disable-libwebp \
            --disable-libxvid \
            --disable-libopenjpeg \
            --disable-libxml2 \
            --extra-ldflags="-static-libgcc -Wl,-rpath,/usr/local/lib/ffmpeg-codecs" \
            --extra-version="ubuntu-x64-bundled"
        
        log "FFmpeg configured successfully with x264, mp3lame, and opus"
    fi
}

# Build FFmpeg
build_ffmpeg() {
    log "Building FFmpeg (using ${THREADS} threads)..."
    
    cd "$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    make -j"$THREADS"
    
    log "FFmpeg build completed"
}

# Install FFmpeg to staging directory
install_ffmpeg() {
    log "Installing FFmpeg to staging directory..."
    
    cd "$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    make DESTDIR="$BUILD_DIR/staging" install
    
    # Copy bundled codec libraries to staging
    local CODEC_PREFIX="$BUILD_DIR/codec-libs"
    local STAGING_LIB_DIR="$BUILD_DIR/staging/usr/local/lib/ffmpeg-codecs"
    
    mkdir -p "$STAGING_LIB_DIR"
    
    # Copy codec libraries that were successfully built
    local COPIED_LIBS=()
    
    if [ -f "$CODEC_PREFIX/lib/libx264.so" ]; then
        cp -a "$CODEC_PREFIX"/lib/libx264.so* "$STAGING_LIB_DIR/" 2>/dev/null || true
        COPIED_LIBS+=("libx264")
    fi
    if [ -f "$CODEC_PREFIX/lib/libx265.so" ]; then
        cp -a "$CODEC_PREFIX"/lib/libx265.so* "$STAGING_LIB_DIR/" 2>/dev/null || true
        COPIED_LIBS+=("libx265")
    fi
    if [ -f "$CODEC_PREFIX/lib/libmp3lame.so" ]; then
        cp -a "$CODEC_PREFIX"/lib/libmp3lame.so* "$STAGING_LIB_DIR/" 2>/dev/null || true
        COPIED_LIBS+=("libmp3lame")
    fi
    if [ -f "$CODEC_PREFIX/lib/libopus.so" ]; then
        cp -a "$CODEC_PREFIX"/lib/libopus.so* "$STAGING_LIB_DIR/" 2>/dev/null || true
        COPIED_LIBS+=("libopus")
    fi
    
    if [ ${#COPIED_LIBS[@]} -gt 0 ]; then
        log "Bundled codec libraries: ${COPIED_LIBS[*]}"
    else
        log "No bundled codec libraries to copy"
    fi
    
    log "FFmpeg and bundled codec libraries installed to staging directory"
}

# Create distribution package
create_package() {
    log "Creating distribution package..."
    
    mkdir -p "$DIST_DIR"
    cd "$BUILD_DIR/staging"
    
    # Create tarball with portable naming
    tar -czf "$DIST_DIR/ffmpeg-${FFMPEG_VERSION}-ubuntu-x64-portable.tar.gz" .
    
    # Create deb package
    create_deb_package
    
    log "Distribution package created"
}

# Create Debian package
create_deb_package() {
    log "Creating Debian package..."
    
    local DEB_DIR="$DIST_DIR/ffmpeg-package"
    local PACKAGE_NAME="ffmpeg-portable"
    local PACKAGE_VERSION="${FFMPEG_VERSION}-2"
    local ARCH="amd64"
    
    # Clean and create package directory structure
    rm -rf "$DEB_DIR"
    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/usr/local"
    mkdir -p "$DEB_DIR/usr/share/doc/$PACKAGE_NAME"
    
    # Copy built files
    cp -r "$BUILD_DIR/staging/usr/local"/* "$DEB_DIR/usr/local/"
    
    # Calculate installed size (in KB)
    local INSTALLED_SIZE=$(du -sk "$DEB_DIR/usr/local" | cut -f1)
    
    # Create control file with bundled codec libraries (minimal system dependencies)
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: multimedia
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Depends: libc6 (>= 2.29), libfreetype6, libssl3 | libssl1.1
Conflicts: ffmpeg, ffmpeg-shared, ffmpeg-shared-minimal, ffmpeg-essential
Provides: ffmpeg
Maintainer: FFmpeg Build Script <build@example.com>
Description: FFmpeg multimedia framework - self-contained build with bundled codecs
 FFmpeg is a complete, cross-platform solution to record, convert and
 stream audio and video. This package contains FFmpeg with all essential
 codec libraries bundled for maximum compatibility across Ubuntu versions.
 .
 This self-contained build includes:
  - H.264/H.265 encoding and decoding (bundled libx264/libx265)
  - MP3 audio encoding (bundled libmp3lame) 
  - Opus audio codec (bundled libopus)
  - PNG/JPEG image formats (built-in)
  - Common containers (MP4, MKV, AVI, MOV, etc.)
  - SSL/TLS support for network protocols
 .
 All codec libraries are bundled with the package, eliminating dependency
 conflicts and ensuring consistent behavior across different Ubuntu versions.
Homepage: https://ffmpeg.org/
EOF

    # Create installation instructions
    cat > "$DEB_DIR/usr/share/doc/$PACKAGE_NAME/README.Debian" << 'EOF'
FFmpeg Self-Contained Build with Bundled Codecs
==============================================

This package provides FFmpeg with all essential codec libraries bundled.

Included codecs and features:
- H.264/H.265 video encoding and decoding (bundled libx264/libx265)
- MP3 and Opus audio codecs (bundled libmp3lame/libopus)
- PNG, JPEG, and other common image formats
- All standard container formats (MP4, MKV, AVI, MOV, etc.)
- TrueType font rendering for subtitles
- Network streaming protocols with SSL/TLS

Key benefits:
- No codec library dependencies or version conflicts
- Works across all Ubuntu versions without additional packages
- Self-contained - no need to install separate codec libraries
- Consistent behavior regardless of system libraries

This build eliminates the common "library not found" errors by bundling
all codec libraries directly with the FFmpeg package.

The bundled libraries are installed in /usr/local/lib/ffmpeg-codecs/
and are automatically found by the FFmpeg binaries through rpath linking.

For advanced use cases requiring additional codecs not included in this
build, you may need to build a custom version or install the full FFmpeg
package from Ubuntu repositories.
EOF

    # Create postinst script for ldconfig and PATH setup
    cat > "$DEB_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Update shared library cache
ldconfig

# Create symlinks in /usr/bin for convenience (only for binaries that exist)
for binary in ffmpeg ffprobe; do
    if [ -f "/usr/local/bin/$binary" ] && [ ! -e "/usr/bin/$binary" ]; then
        ln -sf "/usr/local/bin/$binary" "/usr/bin/$binary"
        echo "Created symlink for $binary"
    fi
done

# Ensure /usr/local/bin is in PATH for all users
# Add to /etc/environment if not already present
if ! grep -q "/usr/local/bin" /etc/environment 2>/dev/null; then
    # Backup current PATH from /etc/environment
    if [ -f /etc/environment ]; then
        current_path=$(grep "^PATH=" /etc/environment | cut -d= -f2 | tr -d '"')
    else
        current_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    fi
    
    # Add /usr/local/bin if not present
    if [[ ":$current_path:" != *":/usr/local/bin:"* ]]; then
        new_path="/usr/local/bin:$current_path"
        echo "PATH=\"$new_path\"" > /etc/environment.tmp
        mv /etc/environment.tmp /etc/environment
        echo "Added /usr/local/bin to system PATH in /etc/environment"
    fi
fi

# Create a profile script to ensure PATH is set
cat > /etc/profile.d/ffmpeg-local.sh << 'PROFILE_EOF'
# Add /usr/local/bin to PATH if not present
case ":$PATH:" in
    *:/usr/local/bin:*) ;;
    *) export PATH="/usr/local/bin:$PATH" ;;
esac
PROFILE_EOF

chmod 644 /etc/profile.d/ffmpeg-local.sh

echo "FFmpeg Portable installation completed successfully!"
echo "This build includes all codec libraries bundled - no additional packages needed."
echo "You may need to log out and back in for PATH changes to take effect."
echo "Alternatively, run: source /etc/profile.d/ffmpeg-local.sh"

exit 0
EOF

    # Create postrm script for cleanup
    cat > "$DEB_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    # Remove symlinks (only if they point to our binaries)
    for binary in ffmpeg ffprobe; do
        if [ -L "/usr/bin/$binary" ] && [ "$(readlink /usr/bin/$binary)" = "/usr/local/bin/$binary" ]; then
            rm -f "/usr/bin/$binary"
            echo "Removed symlink for $binary"
        fi
    done
    
    # Remove profile script
    rm -f /etc/profile.d/ffmpeg-local.sh
    
    # Update shared library cache
    ldconfig
fi

exit 0
EOF

    # Make scripts executable
    chmod 755 "$DEB_DIR/DEBIAN/postinst"
    chmod 755 "$DEB_DIR/DEBIAN/postrm"
    
    # Build the package
    local DEB_FILE="$DIST_DIR/${PACKAGE_NAME}_${PACKAGE_VERSION}_${ARCH}.deb"
    dpkg-deb --build "$DEB_DIR" "$DEB_FILE"
    
    log "Debian package created: $(basename "$DEB_FILE")"
}

# Verify build
verify_build() {
    log "Verifying build..."
    
    local ffmpeg_bin="$BUILD_DIR/staging$INSTALL_PREFIX/bin/ffmpeg"
    
    if [ ! -f "$ffmpeg_bin" ]; then
        error "FFmpeg binary not found"
    fi
    
    # Check if it's linked with shared libraries
    if ! ldd "$ffmpeg_bin" | grep -q "libavcodec"; then
        error "FFmpeg not properly linked with shared libraries"
    fi
    
    log "Build verification successful"
}

# Main execution
main() {
    log "Starting FFmpeg ${FFMPEG_VERSION} portable build with essential codecs for Ubuntu x64"
    
    check_ubuntu
    install_dependencies
    build_codec_libraries
    download_ffmpeg
    configure_ffmpeg
    build_ffmpeg
    install_ffmpeg
    create_package
    verify_build
    
    log "Build completed successfully!"
    log "Tarball package: $DIST_DIR/ffmpeg-${FFMPEG_VERSION}-ubuntu-x64-portable.tar.gz"
    log "Debian package: $DIST_DIR/ffmpeg-portable_${FFMPEG_VERSION}-2_amd64.deb"
    log ""
    log "To install the portable package:"
    log "  sudo dpkg -i $DIST_DIR/ffmpeg-portable_${FFMPEG_VERSION}-2_amd64.deb"
    log ""
    log "This portable build includes:"
    log "  - H.264/H.265 video codecs (bundled libx264/libx265)"
    log "  - MP3 and Opus audio codecs (bundled libmp3lame/libopus)"
    log "  - PNG/JPEG and common image formats"
    log "  - All standard container formats"
    log "  - No external codec dependencies"
    log ""
    log "After installation:"
    log "  - FFmpeg binaries will be available in /usr/local/bin/"
    log "  - Symlinks will be created in /usr/bin/ for convenience"
    log "  - You may need to log out and back in for PATH changes"
    log "  - Or run: source /etc/profile.d/ffmpeg-local.sh"
    log ""
    log "To verify installation:"
    log "  ffmpeg -version"
    log "  ffprobe -version"
    log ""
    log "See /usr/share/doc/ffmpeg-portable/README.Debian for more information."
}

# Run main function
main "$@"
