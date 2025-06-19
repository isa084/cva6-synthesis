# Use Ubuntu 24.04 as the base image
FROM ubuntu:24.04

# Set non-interactive mode for package installation to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install all prerequisites from the readme
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    cmake \
    git \
    build-essential \
    lld \
    bison \
    flex \
    libreadline-dev \
    gawk \
    tcl-dev \
    libffi-dev \
    graphviz \
    xdot \
    pkg-config \
    python3 \
    libboost-system-dev \
    libboost-python-dev \
    libboost-filesystem-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Create and set the main working directory
WORKDIR /install

# --- 1. Setup Yosys ---
RUN git clone --recurse-submodules https://github.com/YosysHQ/yosys.git && \
    cd yosys && \
    make config-gcc && \
    make -j$(($(nproc) * 2 / 3)) && \
    make install

# --- 2. Setup Yosys-slang ---
# This builds and installs the slang plugin for the Yosys installation above
RUN git clone --recursive https://github.com/povik/yosys-slang.git && \
    cd yosys-slang && \
    make -j$(($(nproc) * 2 / 3)) && \
    make install

# --- 3. Setup lib files (OpenROAD flow scripts) ---
RUN git clone https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts.git

# --- 4. Setup CVA6 ---
RUN git clone https://github.com/openhwgroup/cva6.git && \
    cd cva6 && \
    git submodule update --init --recursive

# --- 5. Setup cva6-synthesis ---
RUN git clone https://github.com/isa084/cva6-synthesis.git

# Set the final working directory and start a shell by default
WORKDIR /install/cva6-synthesis
CMD ["bash"]
