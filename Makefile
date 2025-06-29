# FFmpeg Build System Makefile
# Provides convenient targets for building and packaging FFmpeg

.PHONY: help setup build package install clean docker-build docker-package docker-clean test

# Default target
help:
	@echo "FFmpeg 5.1.2 Build System"
	@echo "========================="
	@echo ""
	@echo "Available targets:"
	@echo "  setup          - Install build dependencies"
	@echo "  build          - Build FFmpeg with shared libraries"
	@echo "  package        - Create distribution packages"
	@echo "  install        - Install FFmpeg locally (requires sudo)"
	@echo "  docker-build   - Build using Docker"
	@echo "  docker-package - Create packages using Docker"
	@echo "  test           - Test the built FFmpeg"
	@echo "  clean          - Clean build artifacts"
	@echo "  docker-clean   - Clean Docker artifacts"
	@echo ""
	@echo "Example usage:"
	@echo "  make setup build package"
	@echo "  make docker-build docker-package"

# Setup build dependencies
setup:
	@echo "Setting up build dependencies..."
	sudo ./scripts/setup-dependencies.sh
	@echo "Setup completed. Run 'source build-env.sh' to configure environment."

# Build FFmpeg
build: check-env
	@echo "Building FFmpeg..."
	./scripts/build-ffmpeg.sh

# Create distribution packages
package: check-build
	@echo "Creating distribution packages..."
	./scripts/create-deb-package.sh

# Install FFmpeg locally
install: check-build
	@echo "Installing FFmpeg locally..."
	sudo make -C build/ffmpeg-5.1.2 install
	sudo ldconfig

# Test the built FFmpeg
test: check-build
	@echo "Testing FFmpeg installation..."
	@if [ -f "build/staging/usr/local/bin/ffmpeg" ]; then \
		echo "Testing FFmpeg binary..."; \
		LD_LIBRARY_PATH=build/staging/usr/local/lib build/staging/usr/local/bin/ffmpeg -version | head -5; \
		echo "Basic functionality test..."; \
		LD_LIBRARY_PATH=build/staging/usr/local/lib build/staging/usr/local/bin/ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=30 -t 1 -c:v libx264 -f null - 2>/dev/null && echo "✓ Basic encoding test passed" || echo "✗ Basic encoding test failed"; \
	else \
		echo "FFmpeg binary not found. Run 'make build' first."; \
		exit 1; \
	fi

# Docker-based build
docker-build:
	@echo "Building FFmpeg using Docker..."
	./scripts/docker-build.sh build

# Docker-based packaging
docker-package:
	@echo "Creating packages using Docker..."
	./scripts/docker-build.sh package

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/ dist/
	@echo "Build artifacts cleaned."

# Clean Docker artifacts
docker-clean:
	@echo "Cleaning Docker artifacts..."
	./scripts/docker-build.sh clean

# Development targets
dev-setup: setup
	@echo "Setting up development environment..."
	@if [ ! -f "build-env.sh" ]; then \
		echo "build-env.sh not found. Run setup first."; \
		exit 1; \
	fi

# Full build pipeline
all: setup build package test
	@echo "Full build pipeline completed!"

# Docker full build pipeline
docker-all: docker-build docker-package
	@echo "Docker build pipeline completed!"

# Check if environment is configured
check-env:
	@if [ ! -f "build-env.sh" ]; then \
		echo "Environment not configured. Run 'make setup' first."; \
		exit 1; \
	fi

# Check if build exists
check-build:
	@if [ ! -d "build/ffmpeg-5.1.2" ]; then \
		echo "Build not found. Run 'make build' first."; \
		exit 1; \
	fi

# Show build information
info:
	@echo "FFmpeg Build System Information"
	@echo "=============================="
	@echo "FFmpeg Version: 5.1.2"
	@echo "Target Platform: Ubuntu x64"
	@echo "Library Type: Shared"
	@echo ""
	@if [ -d "build" ]; then \
		echo "Build Status: Available"; \
		echo "Build Size: $$(du -sh build 2>/dev/null | cut -f1)"; \
	else \
		echo "Build Status: Not built"; \
	fi
	@if [ -d "dist" ]; then \
		echo "Packages: Available"; \
		echo "Package Files:"; \
		find dist -name "*.tar.gz" -o -name "*.deb" 2>/dev/null | sed 's/^/  - /' || echo "  None"; \
	else \
		echo "Packages: Not created"; \
	fi
	@echo ""
	@echo "System Information:"
	@echo "OS: $$(lsb_release -d 2>/dev/null | cut -f2 || echo 'Unknown')"
	@echo "Architecture: $$(uname -m)"
	@echo "CPU Cores: $$(nproc)"
	@echo "Available Memory: $$(free -h | awk '/^Mem:/ {print $$2}')"
	@echo "Available Disk: $$(df -h . | tail -1 | awk '{print $$4}')"

# Backup build artifacts
backup:
	@echo "Creating backup of build artifacts..."
	@timestamp=$$(date +%Y%m%d-%H%M%S); \
	tar -czf "ffmpeg-build-backup-$$timestamp.tar.gz" \
		--exclude='build/ffmpeg-5.1.2/*.o' \
		--exclude='build/ffmpeg-5.1.2/.deps' \
		build/ dist/ 2>/dev/null || true; \
	echo "Backup created: ffmpeg-build-backup-$$timestamp.tar.gz"

# Show logs
logs:
	@if [ -f "build/build.log" ]; then \
		echo "Showing build logs (last 50 lines):"; \
		tail -50 build/build.log; \
	else \
		echo "No build logs found."; \
	fi
