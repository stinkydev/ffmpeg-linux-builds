#!/bin/bash
set -e

# Docker-based FFmpeg Build Script
# Builds FFmpeg in a controlled Docker environment for consistency

IMAGE_NAME="ffmpeg-builder-ubuntu"
CONTAINER_NAME="ffmpeg-build-container"
BUILD_DIR="$(pwd)/build"
DIST_DIR="$(pwd)/dist"

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

# Check Docker availability
check_docker() {
    log "Checking Docker availability..."
    
    if ! command -v docker &> /dev/null; then
        error "Docker not found. Please install Docker to use this build method."
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon not running. Please start Docker."
    fi
    
    log "Docker check passed"
}

# Build Docker image
build_image() {
    log "Building Docker image..."
    
    # Check for forced Ubuntu version
    if [ "$FORCE_UBUNTU" = "20" ]; then
        log "Force using Ubuntu 20.04 base image..."
        if docker build -t "$IMAGE_NAME" . $NO_CACHE $PULL; then
            log "Docker image built successfully with Ubuntu 20.04"
            return 0
        else
            error "Docker image build failed with Ubuntu 20.04"
        fi
    elif [ "$FORCE_UBUNTU" = "22" ]; then
        log "Force using Ubuntu 22.04 base image..."
        if docker build -f Dockerfile.ubuntu22 -t "$IMAGE_NAME" . $NO_CACHE $PULL; then
            log "Docker image built successfully with Ubuntu 22.04"
            return 0
        else
            error "Docker image build failed with Ubuntu 22.04"
        fi
    fi
    
    # Auto-detect: Try Ubuntu 22.04 first (more reliable)
    if [ -f "Dockerfile.ubuntu22" ]; then
        log "Using Ubuntu 22.04 base image..."
        if docker build -f Dockerfile.ubuntu22 -t "$IMAGE_NAME" . $NO_CACHE $PULL; then
            log "Docker image built successfully with Ubuntu 22.04"
            return 0
        else
            warn "Ubuntu 22.04 build failed, trying Ubuntu 20.04..."
        fi
    fi
    
    # Fallback to original Dockerfile
    log "Using Ubuntu 20.04 base image..."
    if docker build -t "$IMAGE_NAME" . $NO_CACHE $PULL; then
        log "Docker image built successfully with Ubuntu 20.04"
    else
        error "Docker image build failed with both Ubuntu versions"
    fi
}

# Run build in container
run_build() {
    log "Running FFmpeg build in Docker container..."
    
    # Create directories if they don't exist
    mkdir -p "$BUILD_DIR"
    mkdir -p "$DIST_DIR"
    
    # Remove existing container if it exists
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    # Run the build with retry mechanism
    local max_retries=2
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        log "Build attempt $((retry + 1)) of $max_retries..."
        
        if docker run \
            --name "$CONTAINER_NAME" \
            -v "$BUILD_DIR:/build/build" \
            -v "$DIST_DIR:/build/dist" \
            -e "THREADS=$(nproc)" \
            "$IMAGE_NAME"; then
            log "Build completed in Docker container"
            return 0
        else
            warn "Build attempt $((retry + 1)) failed"
            docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
            retry=$((retry + 1))
            
            if [ $retry -lt $max_retries ]; then
                log "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    error "All build attempts failed"
}

# Extract artifacts
extract_artifacts() {
    log "Extracting build artifacts..."
    
    # Copy any additional files from container if needed
    docker cp "$CONTAINER_NAME:/build/build" ./build-tmp 2>/dev/null || true
    docker cp "$CONTAINER_NAME:/build/dist" ./dist-tmp 2>/dev/null || true
    
    # Merge with existing directories
    if [ -d "./build-tmp" ]; then
        cp -r ./build-tmp/* "$BUILD_DIR/" 2>/dev/null || true
        rm -rf ./build-tmp
    fi
    
    if [ -d "./dist-tmp" ]; then
        cp -r ./dist-tmp/* "$DIST_DIR/" 2>/dev/null || true
        rm -rf ./dist-tmp
    fi
    
    log "Artifacts extracted"
}

# Create package in container
create_package() {
    log "Creating distribution package in Docker..."
    
    docker exec "$CONTAINER_NAME" /build/scripts/create-deb-package.sh
    
    log "Package created"
}

# Cleanup container
cleanup() {
    log "Cleaning up Docker container..."
    
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    
    log "Cleanup completed"
}

# Interactive shell for debugging
debug_shell() {
    log "Starting debug shell in container..."
    
    docker run -it \
        --name "${CONTAINER_NAME}-debug" \
        -v "$BUILD_DIR:/build/build" \
        -v "$DIST_DIR:/build/dist" \
        --entrypoint /bin/bash \
        "$IMAGE_NAME"
    
    docker rm -f "${CONTAINER_NAME}-debug" 2>/dev/null || true
}

# Clean Docker artifacts
clean_docker() {
    log "Cleaning Docker artifacts..."
    
    # Remove containers
    docker rm -f "$CONTAINER_NAME" 2>/dev/null || true
    docker rm -f "${CONTAINER_NAME}-debug" 2>/dev/null || true
    
    # Remove image
    docker rmi "$IMAGE_NAME" 2>/dev/null || true
    
    log "Docker artifacts cleaned"
}

# Show build logs
show_logs() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        docker logs "$CONTAINER_NAME"
    else
        warn "Container $CONTAINER_NAME not found"
    fi
}

# Display summary
show_summary() {
    echo
    log "=== Docker Build Summary ==="
    info "Build completed in Docker environment"
    info "Image: $IMAGE_NAME"
    info "Container: $CONTAINER_NAME"
    
    if [ -d "$DIST_DIR" ]; then
        info "Distribution files:"
        find "$DIST_DIR" -type f -name "*.tar.gz" -o -name "*.deb" | while read -r file; do
            info "  - $(basename "$file")"
        done
    fi
    
    echo
    log "Docker build completed successfully!"
}

# Usage information
usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo
    echo "Commands:"
    echo "  build      Build FFmpeg in Docker (default)"
    echo "  package    Create distribution package"
    echo "  shell      Start interactive shell for debugging"
    echo "  clean      Clean Docker artifacts"
    echo "  logs       Show build logs"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  --no-cache     Build Docker image without cache"
    echo "  --pull         Pull latest base image"
    echo "  --ubuntu22     Force use of Ubuntu 22.04 (default: auto-detect)"
    echo "  --ubuntu20     Force use of Ubuntu 20.04"
    echo
    echo "This script builds FFmpeg using Docker for consistent, reproducible builds."
    echo "It automatically tries Ubuntu 22.04 first, then falls back to 20.04 if needed."
}

# Parse command line options
COMMAND="build"
NO_CACHE=""
PULL=""
FORCE_UBUNTU=""

while [[ $# -gt 0 ]]; do
    case $1 in
        build|package|shell|clean|logs)
            COMMAND="$1"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        --pull)
            PULL="--pull"
            shift
            ;;
        --ubuntu22)
            FORCE_UBUNTU="22"
            shift
            ;;
        --ubuntu20)
            FORCE_UBUNTU="20"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Main execution
main() {
    case $COMMAND in
        build)
            log "Starting Docker-based FFmpeg build..."
            check_docker
            build_image
            run_build
            extract_artifacts
            cleanup
            show_summary
            ;;
        package)
            log "Creating package in Docker..."
            check_docker
            if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
                error "No build container found. Run 'build' command first."
            fi
            create_package
            extract_artifacts
            ;;
        shell)
            log "Starting debug shell..."
            check_docker
            build_image
            debug_shell
            ;;
        clean)
            log "Cleaning Docker artifacts..."
            clean_docker
            ;;
        logs)
            log "Showing build logs..."
            show_logs
            ;;
        *)
            error "Unknown command: $COMMAND"
            ;;
    esac
}

# Trap cleanup on exit
trap cleanup EXIT

# Run main function
main "$@"
