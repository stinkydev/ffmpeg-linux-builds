FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set working directory
WORKDIR /build

# Update package lists with retry and fix broken packages
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update --fix-missing && \
    apt-get install -y --fix-broken \
    ca-certificates \
    && apt-get update

# Install build dependencies in stages to handle potential issues
RUN apt-get install -y \
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
    coreutils \
    && apt-get clean

# Install codec development libraries
RUN apt-get install -y \
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
    && apt-get clean

# Install additional libraries
RUN apt-get install -y \
    librtmp-dev \
    libspeex-dev \
    libtwolame-dev \
    libwavpack-dev \
    libxml2-dev \
    libzmq3-dev \
    libzvbi-dev \
    libbz2-dev \
    liblzma-dev \
    zlib1g-dev \
    libssl-dev \
    libdrm-dev \
    libva-dev \
    libvdpau-dev \
    dpkg-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy build scripts
COPY scripts/ /build/scripts/
COPY packaging/ /build/packaging/

# Make scripts executable
RUN chmod +x /build/scripts/*.sh

# Set environment variables for build
ENV DOCKER_BUILD=1
ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig"
ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/lib/x86_64-linux-gnu"
ENV PATH="/usr/local/bin:$PATH"
ENV CFLAGS="-O3 -march=x86-64 -mtune=generic"
ENV CXXFLAGS="-O3 -march=x86-64 -mtune=generic"

# Default command
CMD ["/build/scripts/build-ffmpeg.sh"]
