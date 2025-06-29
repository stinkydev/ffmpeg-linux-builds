#!/bin/bash
set -e

# FFmpeg Installation Script for Ubuntu x64
# This script installs the pre-built FFmpeg package on target Ubuntu systems

PACKAGE_NAME="ffmpeg-5.1.2-ubuntu-x64-shared.tar.gz"
INSTALL_PREFIX="/usr/local"
BACKUP_DIR="/tmp/ffmpeg-backup-$(date +%Y%m%d-%H%M%S)"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Check if running on Ubuntu
check_ubuntu() {
    if ! grep -q "Ubuntu" /etc/os-release; then
        warn "This package was built for Ubuntu. Compatibility is not guaranteed on other distributions."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    log "System check completed"
}

# Install runtime dependencies
install_runtime_deps() {
    log "Installing runtime dependencies..."
    
    apt update
    apt install -y \
        libass9 \
        libfreetype6 \
        libgnutls30 \
        libmp3lame0 \
        libopus0 \
        libtheora0 \
        libvorbis0a \
        libvorbisenc2 \
        libvpx6 \
        libwebp6 \
        libx264-155 \
        libx265-179 \
        libxvidcore4 \
        libfdk-aac2 \
        libopenjp2-7 \
        librtmp1 \
        libspeex1 \
        libtwolame0 \
        libwavpack1 \
        libxml2 \
        libzmq5 \
        libzvbi0 \
        libbz2-1.0 \
        liblzma5 \
        zlib1g \
        libssl1.1 \
        libdrm2 \
        libva2 \
        libvdpau1
    
    log "Runtime dependencies installed"
}

# Backup existing FFmpeg installation
backup_existing() {
    log "Checking for existing FFmpeg installation..."
    
    local existing_files=()
    
    # Check for existing binaries
    for bin in ffmpeg ffprobe ffplay; do
        if command -v "$bin" &> /dev/null; then
            existing_files+=("$(which "$bin")")
        fi
    done
    
    # Check for existing libraries
    if [ -d "$INSTALL_PREFIX/lib" ]; then
        while IFS= read -r -d '' lib; do
            existing_files+=("$lib")
        done < <(find "$INSTALL_PREFIX/lib" -name "libav*" -o -name "libsw*" -o -name "libpostproc*" -print0 2>/dev/null || true)
    fi
    
    if [ ${#existing_files[@]} -gt 0 ]; then
        warn "Existing FFmpeg installation detected"
        mkdir -p "$BACKUP_DIR"
        
        for file in "${existing_files[@]}"; do
            if [ -f "$file" ] || [ -L "$file" ]; then
                local backup_path="$BACKUP_DIR$(dirname "$file")"
                mkdir -p "$backup_path"
                cp -a "$file" "$backup_path/"
                log "Backed up: $file"
            fi
        done
        
        info "Backup created at: $BACKUP_DIR"
    else
        log "No existing FFmpeg installation found"
    fi
}

# Extract and install FFmpeg
install_ffmpeg() {
    log "Installing FFmpeg package..."
    
    if [ ! -f "$PACKAGE_NAME" ]; then
        error "Package file '$PACKAGE_NAME' not found in current directory"
    fi
    
    # Extract to temporary directory
    local temp_dir="/tmp/ffmpeg-install-$$"
    mkdir -p "$temp_dir"
    
    tar -xzf "$PACKAGE_NAME" -C "$temp_dir"
    
    # Copy files to system
    if [ -d "$temp_dir$INSTALL_PREFIX" ]; then
        cp -r "$temp_dir$INSTALL_PREFIX"/* "$INSTALL_PREFIX/"
    else
        error "Invalid package structure"
    fi
    
    # Clean up
    rm -rf "$temp_dir"
    
    log "FFmpeg installed successfully"
}

# Update library cache
update_ldconfig() {
    log "Updating library cache..."
    
    # Add library path to ld.so.conf if not already present
    local lib_path="$INSTALL_PREFIX/lib"
    if [ -d "$lib_path" ] && ! grep -q "$lib_path" /etc/ld.so.conf.d/* 2>/dev/null; then
        echo "$lib_path" > /etc/ld.so.conf.d/ffmpeg.conf
    fi
    
    ldconfig
    log "Library cache updated"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check if binaries are accessible
    for bin in ffmpeg ffprobe; do
        if ! command -v "$bin" &> /dev/null; then
            error "$bin not found in PATH"
        fi
        
        local version_output
        if ! version_output=$("$bin" -version 2>&1 | head -n1); then
            error "$bin failed to run"
        fi
        
        if [[ "$version_output" == *"5.1.2"* ]]; then
            log "$bin version verified: FFmpeg 5.1.2"
        else
            warn "$bin version unexpected: $version_output"
        fi
    done
    
    # Check library linking
    local ffmpeg_bin
    if ffmpeg_bin=$(which ffmpeg); then
        if ldd "$ffmpeg_bin" | grep -q "not found"; then
            error "FFmpeg has missing library dependencies"
        fi
        log "Library dependencies verified"
    fi
    
    log "Installation verification successful"
}

# Create uninstall script
create_uninstall() {
    log "Creating uninstall script..."
    
    cat > /usr/local/bin/uninstall-ffmpeg.sh << 'EOF'
#!/bin/bash
# FFmpeg Uninstall Script

set -e

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

echo "Removing FFmpeg installation..."

# Remove binaries
rm -f /usr/local/bin/ffmpeg
rm -f /usr/local/bin/ffprobe
rm -f /usr/local/bin/ffplay

# Remove libraries
rm -f /usr/local/lib/libav*.so*
rm -f /usr/local/lib/libsw*.so*
rm -f /usr/local/lib/libpostproc*.so*
rm -f /usr/local/lib/pkgconfig/libav*.pc
rm -f /usr/local/lib/pkgconfig/libsw*.pc
rm -f /usr/local/lib/pkgconfig/libpostproc*.pc

# Remove headers
rm -rf /usr/local/include/libav*
rm -rf /usr/local/include/libsw*
rm -rf /usr/local/include/libpostproc*

# Remove documentation
rm -rf /usr/local/share/ffmpeg
rm -rf /usr/local/share/man/man1/ff*

# Remove library configuration
rm -f /etc/ld.so.conf.d/ffmpeg.conf

# Update library cache
ldconfig

echo "FFmpeg uninstalled successfully"
EOF

    chmod +x /usr/local/bin/uninstall-ffmpeg.sh
    log "Uninstall script created at /usr/local/bin/uninstall-ffmpeg.sh"
}

# Display installation summary
show_summary() {
    echo
    log "=== Installation Summary ==="
    info "FFmpeg 5.1.2 has been successfully installed"
    info "Binaries installed to: $INSTALL_PREFIX/bin"
    info "Libraries installed to: $INSTALL_PREFIX/lib"
    info "Headers installed to: $INSTALL_PREFIX/include"
    
    if [ -d "$BACKUP_DIR" ]; then
        info "Previous installation backed up to: $BACKUP_DIR"
    fi
    
    info "To uninstall: sudo /usr/local/bin/uninstall-ffmpeg.sh"
    echo
    log "Installation completed successfully!"
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --no-deps      Skip runtime dependency installation"
    echo "  --force        Force installation without confirmation"
    echo
    echo "This script installs FFmpeg 5.1.2 with shared libraries."
    echo "The package file '$PACKAGE_NAME' must be in the current directory."
}

# Parse command line options
SKIP_DEPS=false
FORCE_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --no-deps)
            SKIP_DEPS=true
            shift
            ;;
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
main() {
    log "Starting FFmpeg installation..."
    
    check_root
    check_ubuntu
    
    if [ "$SKIP_DEPS" = false ]; then
        install_runtime_deps
    fi
    
    backup_existing
    install_ffmpeg
    update_ldconfig
    verify_installation
    create_uninstall
    show_summary
}

# Run main function
main "$@"
