#!/bin/bash
set -e

# FFmpeg Debian Package Creator
# Creates a .deb package for easy installation on Ubuntu systems

FFMPEG_VERSION="5.1.2"
PACKAGE_VERSION="1"
ARCH="amd64"
BUILD_DIR="$(pwd)/build"
PACKAGE_DIR="$(pwd)/packaging"
DIST_DIR="$(pwd)/dist"
STAGING_DIR="$BUILD_DIR/staging"

# Package information
PACKAGE_NAME="ffmpeg"
PACKAGE_FULLNAME="${PACKAGE_NAME}_${FFMPEG_VERSION}-${PACKAGE_VERSION}_${ARCH}"
MAINTAINER="FFmpeg Build System <build@example.com>"
DESCRIPTION="FFmpeg multimedia framework with shared libraries"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if dpkg-deb is available
    if ! command -v dpkg-deb &> /dev/null; then
        error "dpkg-deb not found. Please install dpkg-dev package."
    fi
    
    # Check if staging directory exists
    if [ ! -d "$STAGING_DIR" ]; then
        error "Staging directory not found. Please run build-ffmpeg.sh first."
    fi
    
    log "Prerequisites check passed"
}

# Create package directory structure
create_package_structure() {
    log "Creating package directory structure..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    
    # Remove existing package directory
    rm -rf "$pkg_dir"
    
    # Create directory structure
    mkdir -p "$pkg_dir/DEBIAN"
    mkdir -p "$pkg_dir/usr/local"
    mkdir -p "$pkg_dir/etc/ld.so.conf.d"
    mkdir -p "$pkg_dir/usr/share/doc/$PACKAGE_NAME"
    
    log "Package structure created"
}

# Copy files from staging
copy_package_files() {
    log "Copying package files..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    
    # Copy FFmpeg installation
    cp -r "$STAGING_DIR/usr/local"/* "$pkg_dir/usr/local/"
    
    # Create library configuration
    echo "/usr/local/lib" > "$pkg_dir/etc/ld.so.conf.d/ffmpeg.conf"
    
    log "Package files copied"
}

# Calculate package size
calculate_package_size() {
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    local size_kb
    
    size_kb=$(du -sk "$pkg_dir" | cut -f1)
    echo "$size_kb"
}

# Generate dependency list
generate_dependencies() {
    local deps=""
    
    # Core dependencies
    deps+="libc6 (>= 2.17), "
    deps+="libass9, "
    deps+="libfreetype6, "
    deps+="libgnutls30, "
    deps+="libmp3lame0, "
    deps+="libopus0, "
    deps+="libtheora0, "
    deps+="libvorbis0a, "
    deps+="libvorbisenc2, "
    deps+="libvpx6, "
    deps+="libwebp6, "
    deps+="libx264-155, "
    deps+="libx265-179, "
    deps+="libxvidcore4, "
    deps+="libfdk-aac2, "
    deps+="libopenjp2-7, "
    deps+="librtmp1, "
    deps+="libspeex1, "
    deps+="libtwolame0, "
    deps+="libwavpack1, "
    deps+="libxml2, "
    deps+="libzmq5, "
    deps+="libzvbi0, "
    deps+="libbz2-1.0, "
    deps+="liblzma5, "
    deps+="zlib1g, "
    deps+="libssl1.1, "
    deps+="libdrm2, "
    deps+="libva2, "
    deps+="libvdpau1"
    
    echo "$deps"
}

# Create control file
create_control_file() {
    log "Creating control file..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    local package_size
    local dependencies
    
    package_size=$(calculate_package_size)
    dependencies=$(generate_dependencies)
    
    cat > "$pkg_dir/DEBIAN/control" << EOF
Package: $PACKAGE_NAME
Version: $FFMPEG_VERSION-$PACKAGE_VERSION
Section: multimedia
Priority: optional
Architecture: $ARCH
Depends: $dependencies
Installed-Size: $package_size
Maintainer: $MAINTAINER
Description: $DESCRIPTION
 FFmpeg is a complete, cross-platform solution to record, convert and
 stream audio and video. It includes libavcodec - the leading audio/video
 codec library.
 .
 This package contains FFmpeg binaries and shared libraries built with
 support for many popular codecs and formats.
Homepage: https://ffmpeg.org/
EOF

    log "Control file created"
}

# Create postinst script
create_postinst_script() {
    log "Creating postinst script..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    
    cat > "$pkg_dir/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    configure)
        # Update library cache
        ldconfig
        
        # Update man database
        if command -v mandb > /dev/null 2>&1; then
            mandb -q /usr/local/share/man || true
        fi
        ;;
esac

exit 0
EOF

    chmod 755 "$pkg_dir/DEBIAN/postinst"
    log "Postinst script created"
}

# Create prerm script
create_prerm_script() {
    log "Creating prerm script..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    
    cat > "$pkg_dir/DEBIAN/prerm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove|upgrade|deconfigure)
        # Nothing special needed
        ;;
esac

exit 0
EOF

    chmod 755 "$pkg_dir/DEBIAN/prerm"
    log "Prerm script created"
}

# Create postrm script
create_postrm_script() {
    log "Creating postrm script..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    
    cat > "$pkg_dir/DEBIAN/postrm" << 'EOF'
#!/bin/bash
set -e

case "$1" in
    remove|purge)
        # Update library cache
        ldconfig
        
        # Update man database
        if command -v mandb > /dev/null 2>&1; then
            mandb -q /usr/local/share/man || true
        fi
        ;;
esac

exit 0
EOF

    chmod 755 "$pkg_dir/DEBIAN/postrm"
    log "Postrm script created"
}

# Create documentation
create_documentation() {
    log "Creating documentation..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    local doc_dir="$pkg_dir/usr/share/doc/$PACKAGE_NAME"
    
    # Create copyright file
    cat > "$doc_dir/copyright" << 'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: FFmpeg
Upstream-Contact: FFmpeg development team
Source: https://ffmpeg.org/

Files: *
Copyright: 2000-2022 FFmpeg developers
License: GPL-2+ with additional permissions
 This package is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 .
 This package is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU General Public License for more details.
 .
 You should have received a copy of the GNU General Public License
 along with this program. If not, see <https://www.gnu.org/licenses/>
 .
 On Debian systems, the complete text of the GNU General
 Public License version 2 can be found in "/usr/share/common-licenses/GPL-2".
EOF

    # Create changelog
    cat > "$doc_dir/changelog.Debian" << EOF
$PACKAGE_NAME ($FFMPEG_VERSION-$PACKAGE_VERSION) unstable; urgency=medium

  * Custom build of FFmpeg $FFMPEG_VERSION with shared libraries
  * Optimized for Ubuntu x64 distribution
  * Includes common codecs and hardware acceleration support

 -- $MAINTAINER  $(date -R)
EOF

    # Compress changelog
    gzip -9 "$doc_dir/changelog.Debian"
    
    log "Documentation created"
}

# Build package
build_package() {
    log "Building .deb package..."
    
    local pkg_dir="$PACKAGE_DIR/$PACKAGE_FULLNAME"
    
    mkdir -p "$DIST_DIR"
    
    # Build the package
    dpkg-deb --build "$pkg_dir" "$DIST_DIR/${PACKAGE_FULLNAME}.deb"
    
    log "Package built successfully"
}

# Verify package
verify_package() {
    log "Verifying package..."
    
    local deb_file="$DIST_DIR/${PACKAGE_FULLNAME}.deb"
    
    # Check package info
    dpkg-deb --info "$deb_file"
    
    # Check package contents
    echo
    info "Package contents:"
    dpkg-deb --contents "$deb_file" | head -20
    
    # Verify package
    if ! dpkg-deb --verify "$deb_file"; then
        error "Package verification failed"
    fi
    
    log "Package verification successful"
}

# Create installation instructions
create_install_instructions() {
    log "Creating installation instructions..."
    
    cat > "$DIST_DIR/INSTALL.md" << EOF
# FFmpeg ${FFMPEG_VERSION} Installation Instructions

## Package Information
- Package: ${PACKAGE_FULLNAME}.deb
- Version: FFmpeg ${FFMPEG_VERSION}
- Architecture: ${ARCH} (x86_64)
- Type: Shared libraries

## Installation

### Method 1: Using dpkg
\`\`\`bash
sudo dpkg -i ${PACKAGE_FULLNAME}.deb
sudo apt-get install -f  # Install missing dependencies
\`\`\`

### Method 2: Using apt (if in repository)
\`\`\`bash
sudo apt update
sudo apt install ./${PACKAGE_FULLNAME}.deb
\`\`\`

## Verification
After installation, verify FFmpeg is working:
\`\`\`bash
ffmpeg -version
ffprobe -version
\`\`\`

## Uninstallation
To remove the package:
\`\`\`bash
sudo apt remove ffmpeg
\`\`\`

## Troubleshooting
If you encounter dependency issues:
\`\`\`bash
sudo apt update
sudo apt install -f
\`\`\`

## Support
This is a custom build of FFmpeg ${FFMPEG_VERSION} with shared libraries.
For FFmpeg support, visit: https://ffmpeg.org/
EOF

    log "Installation instructions created"
}

# Display summary
show_summary() {
    echo
    log "=== Package Creation Summary ==="
    info "Package: $DIST_DIR/${PACKAGE_FULLNAME}.deb"
    info "Version: FFmpeg $FFMPEG_VERSION-$PACKAGE_VERSION"
    info "Architecture: $ARCH"
    info "Type: Shared libraries"
    
    local file_size
    file_size=$(du -h "$DIST_DIR/${PACKAGE_FULLNAME}.deb" | cut -f1)
    info "Size: $file_size"
    
    echo
    log "Installation:"
    info "sudo dpkg -i $DIST_DIR/${PACKAGE_FULLNAME}.deb"
    info "sudo apt-get install -f"
    echo
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help       Show this help message"
    echo "  -v, --version    Package version (default: $PACKAGE_VERSION)"
    echo "  -m, --maintainer Maintainer information"
    echo
    echo "This script creates a .deb package from the built FFmpeg installation."
}

# Parse command line options
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--version)
            PACKAGE_VERSION="$2"
            shift 2
            ;;
        -m|--maintainer)
            MAINTAINER="$2"
            shift 2
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
main() {
    log "Starting .deb package creation for FFmpeg $FFMPEG_VERSION..."
    
    check_prerequisites
    create_package_structure
    copy_package_files
    create_control_file
    create_postinst_script
    create_prerm_script
    create_postrm_script
    create_documentation
    build_package
    verify_package
    create_install_instructions
    show_summary
}

# Run main function
main "$@"
