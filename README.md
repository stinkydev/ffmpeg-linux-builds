# FFmpeg 5.1.2 Ubuntu x64 Build System

This project provides a comprehensive build system for creating FFmpeg 5.1.2 with shared libraries for Ubuntu x64 systems. The resulting packages can be distributed and installed on other Ubuntu instances.

## Features

- **Shared Libraries**: Builds FFmpeg with shared libraries for smaller distribution size
- **Hardware Acceleration**: Includes VAAPI, VDPAU, and other hardware acceleration support
- **Comprehensive Codecs**: Supports popular audio and video codecs
- **Multiple Build Methods**: Native build scripts and Docker-based builds
- **Package Creation**: Generates both .tar.gz and .deb packages
- **Easy Installation**: Simple installation scripts for target systems

## Project Structure

```
ffmpeg-build-ubuntu/
├── scripts/
│   ├── setup-dependencies.sh    # Install build dependencies
│   ├── build-ffmpeg.sh         # Main build script
│   ├── install-ffmpeg.sh       # Installation script for target systems
│   ├── create-deb-package.sh   # Create .deb package
│   └── docker-build.sh         # Docker-based build
├── packaging/                  # Package files and metadata
├── build/                     # Build artifacts (created during build)
├── dist/                      # Final distribution packages
├── Dockerfile                 # Docker build environment
└── README.md                  # This file
```

## Requirements

### Build System Requirements
- Ubuntu 18.04 or later (x86_64)
- At least 5GB free disk space
- 4GB+ RAM recommended
- Internet connection for downloading dependencies

### Target System Requirements
- Ubuntu 18.04 or later (x86_64)
- Compatible with most Ubuntu-based distributions

## Quick Start

### Method 1: Native Build

1. **Setup Dependencies**
   ```bash
   chmod +x scripts/*.sh
   sudo ./scripts/setup-dependencies.sh
   ```

2. **Configure Environment**
   ```bash
   source build-env.sh
   ```

3. **Build FFmpeg**
   ```bash
   ./scripts/build-ffmpeg.sh
   ```

4. **Create Package**
   ```bash
   ./scripts/create-deb-package.sh
   ```

### Method 2: Docker Build

1. **Build with Docker**
   ```bash
   chmod +x scripts/*.sh
   ./scripts/docker-build.sh build
   ```

2. **Create Package**
   ```bash
   ./scripts/docker-build.sh package
   ```

## Installation on Target Systems

### Using .deb Package

1. **Copy the package to target system**
   ```bash
   scp dist/ffmpeg_5.1.2-1_amd64.deb user@target-system:~/
   ```

2. **Install on target system**
   ```bash
   sudo dpkg -i ffmpeg_5.1.2-1_amd64.deb
   sudo apt-get install -f  # Install missing dependencies
   ```

### Using .tar.gz Package

1. **Copy the package to target system**
   ```bash
   scp dist/ffmpeg-5.1.2-ubuntu-x64-shared.tar.gz user@target-system:~/
   scp scripts/install-ffmpeg.sh user@target-system:~/
   ```

2. **Install on target system**
   ```bash
   chmod +x install-ffmpeg.sh
   sudo ./install-ffmpeg.sh
   ```

## Build Configuration

### Enabled Features

- **Video Codecs**: H.264 (x264), H.265 (x265), VP8/VP9 (libvpx), Theora, XviD
- **Audio Codecs**: AAC (FDK), MP3 (LAME), Opus, Vorbis, Speex
- **Hardware Acceleration**: VAAPI, VDPAU
- **Network Protocols**: RTMP, HTTP, HTTPS
- **Container Formats**: MP4, MKV, WebM, AVI, and many more

### Optimization

- Optimized for x86_64 architecture
- Runtime CPU detection enabled
- Shared libraries for reduced size
- Multi-threaded compilation

## Advanced Usage

### Custom Build Options

Edit `scripts/build-ffmpeg.sh` and modify the configure options:

```bash
./configure \
    --prefix="$INSTALL_PREFIX" \
    --enable-shared \
    --disable-static \
    --enable-gpl \
    # Add your custom options here
```

### Docker Build Options

```bash
# Build without cache
./scripts/docker-build.sh build --no-cache

# Debug build issues
./scripts/docker-build.sh shell

# View build logs
./scripts/docker-build.sh logs

# Clean Docker artifacts
./scripts/docker-build.sh clean
```

### Dependencies Management

Install minimal dependencies only:
```bash
./scripts/setup-dependencies.sh --minimal
```

Skip hardware acceleration libraries:
```bash
./scripts/setup-dependencies.sh --no-hw
```

## Verification

### Test Installation

After installation, verify FFmpeg is working:

```bash
# Check version
ffmpeg -version

# Test basic functionality
ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=30 -c:v libx264 test.mp4

# Check available codecs
ffmpeg -codecs | grep -E "(h264|hevc|vp9|aac)"

# Check hardware acceleration
ffmpeg -hwaccels
```

### Library Dependencies

Check shared library dependencies:
```bash
ldd $(which ffmpeg)
```

## Troubleshooting

### Common Issues

1. **Missing Dependencies**
   ```bash
   sudo apt-get install -f
   ```

2. **Library Not Found**
   ```bash
   sudo ldconfig
   export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"
   ```

3. **Permission Denied**
   ```bash
   sudo chown -R $USER:$USER build/ dist/
   ```

### Build Failures

1. **Check dependencies**
   ```bash
   ./scripts/setup-dependencies.sh
   ```

2. **Clean and rebuild**
   ```bash
   rm -rf build/
   ./scripts/build-ffmpeg.sh
   ```

3. **Use Docker build for consistency**
   ```bash
   ./scripts/docker-build.sh build
   ```

## Package Details

### Distribution Packages

- **ffmpeg-5.1.2-ubuntu-x64-shared.tar.gz**: Complete installation archive
- **ffmpeg_5.1.2-1_amd64.deb**: Debian package with dependency management

### Package Contents

- Binaries: `ffmpeg`, `ffprobe`, `ffplay`
- Libraries: `libavcodec`, `libavformat`, `libavutil`, etc.
- Headers: Development headers for linking
- Documentation: Man pages and documentation

## Uninstallation

### .deb Package
```bash
sudo apt remove ffmpeg
```

### .tar.gz Package
```bash
sudo /usr/local/bin/uninstall-ffmpeg.sh
```

## Development

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test your changes
4. Submit a pull request

### Testing

Test builds on different Ubuntu versions:
```bash
# Ubuntu 18.04
docker run -it ubuntu:18.04 bash

# Ubuntu 20.04
docker run -it ubuntu:20.04 bash

# Ubuntu 22.04
docker run -it ubuntu:22.04 bash
```

## License

This build system is provided under the MIT License. FFmpeg itself is licensed under GPL v2+ with additional permissions.

## Support

- FFmpeg Documentation: https://ffmpeg.org/documentation.html
- FFmpeg Community: https://ffmpeg.org/contact.html
- Build Issues: Check the troubleshooting section above

## Changelog

### Version 1.0.0
- Initial release
- FFmpeg 5.1.2 support
- Ubuntu x64 optimization
- Docker build support
- .deb package creation
