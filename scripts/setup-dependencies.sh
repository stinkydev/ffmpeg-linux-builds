#!/bin/bash
set -e

# Dependency Setup Script for FFmpeg Build Environment
# This script prepares the build environment with all necessary dependencies

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

# Check system requirements
check_system() {
    log "Checking system requirements..."
    
    # Check Ubuntu version
    if ! grep -q "Ubuntu" /etc/os-release; then
        error "This script requires Ubuntu"
    fi
    
    local ubuntu_version
    ubuntu_version=$(grep "VERSION_ID" /etc/os-release | cut -d'"' -f2)
    log "Ubuntu version: $ubuntu_version"
    
    # Check architecture
    local arch
    arch=$(uname -m)
    if [ "$arch" != "x86_64" ]; then
        error "This script requires x86_64 architecture, found: $arch"
    fi
    log "Architecture: $arch"
    
    # Check available disk space (need at least 5GB)
    local available_space
    available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=5242880  # 5GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        error "Insufficient disk space. Required: 5GB, Available: $((available_space/1024/1024))GB"
    fi
    log "Disk space check passed"
}

# Update system packages
update_system() {
    log "Updating system packages..."
    
    sudo apt update
    sudo apt upgrade -y
    
    log "System packages updated"
}

# Install essential build tools
install_build_tools() {
    log "Installing essential build tools..."
    
    sudo apt install -y \
        build-essential \
        pkg-config \
        cmake \
        autoconf \
        automake \
        libtool \
        make \
        gcc \
        g++ \
        yasm \
        nasm \
        git \
        wget \
        curl \
        unzip \
        tar \
        gzip
    
    log "Build tools installed"
}

# Install codec libraries
install_codec_libraries() {
    log "Installing codec libraries..."
    
    # Audio codecs
    sudo apt install -y \
        libmp3lame-dev \
        libopus-dev \
        libvorbis-dev \
        libfdk-aac-dev \
        libspeex-dev \
        libtwolame-dev \
        libwavpack-dev
    
    # Video codecs
    sudo apt install -y \
        libx264-dev \
        libx265-dev \
        libxvidcore-dev \
        libvpx-dev \
        libtheora-dev \
        libopenjp2-7-dev
    
    # Image codecs
    sudo apt install -y \
        libwebp-dev
    
    log "Codec libraries installed"
}

# Install multimedia libraries
install_multimedia_libraries() {
    log "Installing multimedia libraries..."
    
    sudo apt install -y \
        libass-dev \
        libfreetype6-dev \
        libfontconfig1-dev \
        libfribidi-dev \
        libharfbuzz-dev
    
    log "Multimedia libraries installed"
}

# Install system libraries
install_system_libraries() {
    log "Installing system libraries..."
    
    # Compression libraries
    sudo apt install -y \
        libbz2-dev \
        liblzma-dev \
        zlib1g-dev
    
    # Networking libraries
    sudo apt install -y \
        libssl-dev \
        libgnutls28-dev \
        librtmp-dev
    
    # XML/Utility libraries
    sudo apt install -y \
        libxml2-dev \
        libzmq3-dev \
        libzvbi-dev
    
    log "System libraries installed"
}

# Install hardware acceleration libraries
install_hardware_acceleration() {
    log "Installing hardware acceleration libraries..."
    
    sudo apt install -y \
        libdrm-dev \
        libva-dev \
        libvdpau-dev \
        libgl1-mesa-dev
    
    # NVIDIA libraries (optional)
    if lspci | grep -i nvidia > /dev/null; then
        info "NVIDIA GPU detected, installing CUDA development libraries..."
        sudo apt install -y \
            nvidia-cuda-dev \
            libnvidia-encode-dev || warn "NVIDIA development libraries not available"
    fi
    
    # Intel libraries (optional)
    if lscpu | grep -i intel > /dev/null; then
        info "Intel CPU detected, installing Intel Media SDK..."
        sudo apt install -y \
            libmfx-dev || warn "Intel Media SDK not available"
    fi
    
    log "Hardware acceleration libraries installed"
}

# Install development headers
install_development_headers() {
    log "Installing development headers..."
    
    sudo apt install -y \
        linux-headers-$(uname -r) \
        libc6-dev
    
    log "Development headers installed"
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check essential tools
    local tools=("gcc" "g++" "make" "cmake" "pkg-config" "yasm" "nasm")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool not found"
        fi
        log "$tool: $(command -v "$tool")"
    done
    
    # Check pkg-config packages
    local packages=("libavcodec" "libavformat" "libavutil" "x264" "x265" "opus" "vorbis")
    for package in "${packages[@]}"; do
        if pkg-config --exists "$package" 2>/dev/null; then
            local version
            version=$(pkg-config --modversion "$package" 2>/dev/null)
            log "$package: $version"
        else
            warn "$package not found via pkg-config"
        fi
    done
    
    log "Installation verification completed"
}

# Create environment setup script
create_env_script() {
    log "Creating environment setup script..."
    
    cat > build-env.sh << 'EOF'
#!/bin/bash
# FFmpeg Build Environment Setup

export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"
export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
export PATH="/usr/local/bin:$PATH"

# Compiler optimizations for x64
export CFLAGS="-O3 -march=x86-64 -mtune=generic"
export CXXFLAGS="-O3 -march=x86-64 -mtune=generic"

# Build parallelism
export MAKEFLAGS="-j$(nproc)"

echo "FFmpeg build environment configured"
echo "Available CPU cores: $(nproc)"
echo "PKG_CONFIG_PATH: $PKG_CONFIG_PATH"
EOF

    chmod +x build-env.sh
    log "Environment script created: build-env.sh"
}

# Display summary
show_summary() {
    echo
    log "=== Dependency Installation Summary ==="
    info "All build dependencies have been successfully installed"
    info "System is ready for FFmpeg compilation"
    info "Available CPU cores for parallel build: $(nproc)"
    
    local mem_gb
    mem_gb=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))
    info "Available memory: ${mem_gb}GB"
    
    echo
    log "Next steps:"
    info "1. Source the environment: source build-env.sh"
    info "2. Run the build script: ./scripts/build-ffmpeg.sh"
    echo
}

# Usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --minimal      Install minimal dependencies only"
    echo "  --no-hw        Skip hardware acceleration libraries"
    echo
    echo "This script installs all dependencies required to build FFmpeg 5.1.2"
}

# Parse command line options
MINIMAL=false
NO_HW=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        --minimal)
            MINIMAL=true
            shift
            ;;
        --no-hw)
            NO_HW=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
main() {
    log "Starting dependency installation for FFmpeg build..."
    
    check_system
    update_system
    install_build_tools
    install_codec_libraries
    install_multimedia_libraries
    install_system_libraries
    
    if [ "$NO_HW" = false ]; then
        install_hardware_acceleration
    fi
    
    if [ "$MINIMAL" = false ]; then
        install_development_headers
    fi
    
    verify_installation
    create_env_script
    show_summary
}

# Run main function
main "$@"
