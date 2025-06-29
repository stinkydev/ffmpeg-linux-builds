#!/bin/bash
set -e

# FFmpeg 5.1.2 Build Script for Ubuntu x64 with Shared Libraries
# This script builds FFmpeg with shared libraries for distribution

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
            libass-dev \
            libfreetype6-dev \
            libgnutls28-dev \
            libmp3lame-dev \
            libopus-dev \
            libtheora-dev \
            libvorbis-dev \
            libvpx-dev \
            libwebp-dev \
            libx264-dev \
            libx265-dev \
            libxvidcore-dev \
            libfdk-aac-dev \
            libopenjp2-7-dev \
            librtmp-dev \
            libspeex-dev \
            libxml2-dev \
            libzmq3-dev \
            libbz2-dev \
            liblzma-dev \
            zlib1g-dev \
            libssl-dev \
            libdrm-dev \
            libva-dev \
            libvdpau-dev
    else
        log "Running in Docker - dependencies pre-installed"
    fi
    
    log "Dependencies ready"
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

# Configure FFmpeg build
configure_ffmpeg() {
    log "Configuring FFmpeg build..."
    
    cd "$BUILD_DIR/ffmpeg-${FFMPEG_VERSION}"
    
    ./configure \
        --prefix="$INSTALL_PREFIX" \
        --enable-shared \
        --disable-static \
        --enable-gpl \
        --enable-version3 \
        --enable-nonfree \
        --enable-pic \
        --enable-libass \
        --enable-libfdk-aac \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libtheora \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libwebp \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libxvid \
        --enable-libopenjpeg \
        --enable-libxml2 \
        --enable-openssl \
        --enable-runtime-cpudetect \
        --extra-version="ubuntu-x64-shared"
    
    log "FFmpeg configured successfully"
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
    
    log "FFmpeg installed to staging directory"
}

# Create distribution package
create_package() {
    log "Creating distribution package..."
    
    mkdir -p "$DIST_DIR"
    cd "$BUILD_DIR/staging"
    
    # Create tarball
    tar -czf "$DIST_DIR/ffmpeg-${FFMPEG_VERSION}-ubuntu-x64-shared.tar.gz" .
    
    # Create deb package
    create_deb_package
    
    log "Distribution package created"
}

# Create Debian package
create_deb_package() {
    log "Creating Debian package..."
    
    local DEB_DIR="$DIST_DIR/ffmpeg-package"
    local PACKAGE_NAME="ffmpeg-shared"
    local PACKAGE_VERSION="${FFMPEG_VERSION}-1"
    local ARCH="amd64"
    
    # Clean and create package directory structure
    rm -rf "$DEB_DIR"
    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/usr/local"
    
    # Copy built files
    cp -r "$BUILD_DIR/staging/usr/local"/* "$DEB_DIR/usr/local/"
    
    # Calculate installed size (in KB)
    local INSTALLED_SIZE=$(du -sk "$DEB_DIR/usr/local" | cut -f1)
    
    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $PACKAGE_VERSION
Section: multimedia
Priority: optional
Architecture: $ARCH
Installed-Size: $INSTALLED_SIZE
Depends: libass9, libfreetype6, libmp3lame0, libopus0, libtheora0, libvorbis0a, libvorbisenc2, libvpx7, libwebp7, libx264-164, libx265-199, libxvidcore4, libfdk-aac2, libopenjp2-7, libxml2, libssl3, libdrm2, libva2, libvdpau1, libc6 (>= 2.34)
Maintainer: FFmpeg Build Script <build@example.com>
Description: FFmpeg multimedia framework - shared libraries build
 FFmpeg is a complete, cross-platform solution to record, convert and
 stream audio and video. This package contains FFmpeg built with shared
 libraries for Ubuntu x64, including support for various codecs and formats.
 .
 This build includes support for:
  - H.264/H.265 encoding and decoding
  - VP8/VP9 encoding and decoding
  - AAC, MP3, Opus, Vorbis audio codecs
  - Hardware acceleration (VAAPI, VDPAU)
  - Various container formats
Homepage: https://ffmpeg.org/
EOF

    # Create postinst script for ldconfig
    cat > "$DEB_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

# Update shared library cache
ldconfig

# Create symlinks in /usr/bin for convenience
if [ ! -e /usr/bin/ffmpeg ]; then
    ln -sf /usr/local/bin/ffmpeg /usr/bin/ffmpeg
fi
if [ ! -e /usr/bin/ffprobe ]; then
    ln -sf /usr/local/bin/ffprobe /usr/bin/ffprobe
fi
if [ ! -e /usr/bin/ffplay ]; then
    ln -sf /usr/local/bin/ffplay /usr/bin/ffplay
fi

exit 0
EOF

    # Create postrm script for cleanup
    cat > "$DEB_DIR/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
    # Remove symlinks
    rm -f /usr/bin/ffmpeg
    rm -f /usr/bin/ffprobe
    rm -f /usr/bin/ffplay
    
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
    log "Starting FFmpeg ${FFMPEG_VERSION} build for Ubuntu x64 with shared libraries"
    
    check_ubuntu
    install_dependencies
    download_ffmpeg
    configure_ffmpeg
    build_ffmpeg
    install_ffmpeg
    create_package
    verify_build
    
    log "Build completed successfully!"
    log "Tarball package: $DIST_DIR/ffmpeg-${FFMPEG_VERSION}-ubuntu-x64-shared.tar.gz"
    log "Debian package: $DIST_DIR/ffmpeg-shared_${FFMPEG_VERSION}-1_amd64.deb"
    log ""
    log "To install the Debian package:"
    log "  sudo dpkg -i $DIST_DIR/ffmpeg-shared_${FFMPEG_VERSION}-1_amd64.deb"
    log "  sudo apt-get install -f  # Fix any dependency issues"
}

# Run main function
main "$@"
