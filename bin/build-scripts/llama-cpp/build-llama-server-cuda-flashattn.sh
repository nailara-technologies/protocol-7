#!/bin/bash
# Build ik_llama.cpp llama-server with CUDA GPU support and Flash Attention
# Using Docker to avoid dependency issues
# Outputs: llama-server-cuda-flashattn binary + shared libraries
# Usage: ./build-llama-server-cuda-flashattn.sh

set -e

# Configuration
CUDA_VERSION=${CUDA_VERSION:-12.5.0}
UBUNTU_VERSION=${UBUNTU_VERSION:-jammy}
IMAGE_NAME=${IMAGE_NAME:-ik_llama_server_cuda_fa}
OUTPUT_DIR=${OUTPUT_DIR:-/data/source/ik_llama.cpp}
DOCKER_CMD=${DOCKER_CMD:-docker}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi
    log_info "✓ Docker found: $(docker --version)"

    if ! command -v nvidia-smi &> /dev/null; then
        log_error "NVIDIA driver not installed (nvidia-smi not found)"
        exit 1
    fi
    log_info "✓ NVIDIA driver found: $(nvidia-smi --query-gpu=name --format=csv,noheader)"

    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        exit 1
    fi
    log_info "✓ Git found"
}

# Build Docker image
build_image() {
    log_info "Building Docker image with CUDA ${CUDA_VERSION} and Flash Attention..."
    log_info "This may take 15-30 minutes on first build..."
    log_info "Building from: /data/source/ik_llama.cpp"

    # Create inline Dockerfile with llama-server instead of llama-mtmd-cli
    cat > /tmp/Dockerfile.llama-server << 'DOCKERFILE'
ARG CUDA_VERSION=12.5.0
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu22.04

# Install build dependencies
RUN apt-get update && apt-get install -y \
    git \
    build-essential \
    cmake \
    ccache \
    pkg-config \
    libgomp1 \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Upgrade CMake
RUN wget -O /tmp/cmake-keyring.gpg https://apt.kitware.com/keys/kitware-archive-latest.asc && \
    gpg --dearmor < /tmp/cmake-keyring.gpg > /usr/share/keyrings/kitware-archive-keyring.gpg && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ jammy main' > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && \
    apt-get install -y cmake && \
    rm -rf /var/lib/apt/lists/*

# Copy source
WORKDIR /build
COPY . .

# Build with CUDA and Flash Attention
ENV CUDA_HOME=/usr/local/cuda
ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
ENV PATH=/usr/local/cuda/bin:$PATH
ENV CUDA_ARCHITECTURES=86

RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_CUDA_FA=ON \
    -DCMAKE_CUDA_ARCHITECTURES=86 \
    -DBUILD_SHARED_LIBS=ON \
    && cmake --build build --config Release -j$(nproc) --target llama-server

# Verify binary
RUN test -f ./build/bin/llama-server && echo "Binary verified: llama-server exists" || (echo "ERROR: llama-server not built" && exit 1)

# Extract to runtime stage
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu22.04

RUN apt-get update && apt-get install -y --allow-change-held-packages libgomp1 libnccl2 && rm -rf /var/lib/apt/lists/*

# Copy server binary and libraries
COPY --from=0 /build/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=0 /build/build/ggml/src/libggml.so /usr/local/lib/libggml.so
COPY --from=0 /build/build/src/libllama.so /usr/local/lib/libllama.so
COPY --from=0 /build/build/examples/mtmd/libmtmd.so /usr/local/lib/libmtmd.so

RUN chmod +x /usr/local/bin/llama-server
RUN ldconfig

ENV LD_LIBRARY_PATH=/usr/local/cuda/lib64:/usr/local/lib:$LD_LIBRARY_PATH

ENTRYPOINT [ "llama-server" ]
DOCKERFILE

    $DOCKER_CMD build \
        -f /tmp/Dockerfile.llama-server \
        -t ${IMAGE_NAME}:${CUDA_VERSION} \
        --build-arg CUDA_VERSION=${CUDA_VERSION} \
        /data/source/ik_llama.cpp || {
            log_error "Docker build failed"
            rm /tmp/Dockerfile.llama-server
            exit 1
        }

    rm /tmp/Dockerfile.llama-server
    log_info "✓ Docker image built successfully"
}

# Extract binary from container
extract_binary() {
    log_info "Extracting llama-server binary and libraries from container..."

    # Create temporary container
    CONTAINER_ID=$($DOCKER_CMD create ${IMAGE_NAME}:${CUDA_VERSION})

    # Copy server binary
    $DOCKER_CMD cp ${CONTAINER_ID}:/usr/local/bin/llama-server \
        ${OUTPUT_DIR}/llama-server-cuda-fa-${CUDA_VERSION} || {
            log_error "Failed to extract binary"
            $DOCKER_CMD rm ${CONTAINER_ID}
            exit 1
        }

    # Extract required libraries
    log_info "Extracting supporting libraries..."
    for lib in libggml.so libllama.so libmtmd.so; do
        $DOCKER_CMD cp ${CONTAINER_ID}:/usr/local/lib/${lib} \
            ${OUTPUT_DIR}/ 2>/dev/null || log_warn "Library ${lib} not found in container"
    done

    # Extract CUDA runtime libraries
    log_info "Extracting CUDA runtime libraries..."
    for lib in libcudart.so.12 libcuda.so.1 libcublas.so.12 libcublasLt.so.12 libcurand.so.10 libcusparse.so.12; do
        $DOCKER_CMD cp ${CONTAINER_ID}:/usr/local/cuda/lib64/${lib} \
            ${OUTPUT_DIR}/ 2>/dev/null || log_info "Library ${lib} not found (optional)"
    done

    # Cleanup
    $DOCKER_CMD rm ${CONTAINER_ID}

    # Make executable
    chmod +x ${OUTPUT_DIR}/llama-server-cuda-fa-${CUDA_VERSION}

    log_info "✓ Server binary extracted to: ${OUTPUT_DIR}/llama-server-cuda-fa-${CUDA_VERSION}"
    log_info "✓ Libraries extracted to: ${OUTPUT_DIR}/"
}

# Test the binary
test_binary() {
    log_info "Testing compiled binary..."

    if LD_LIBRARY_PATH="${OUTPUT_DIR}:${LD_LIBRARY_PATH}" ${OUTPUT_DIR}/llama-server-cuda-fa-${CUDA_VERSION} --version > /dev/null 2>&1; then
        log_info "✓ Binary works: $(LD_LIBRARY_PATH="${OUTPUT_DIR}:${LD_LIBRARY_PATH}" ${OUTPUT_DIR}/llama-server-cuda-fa-${CUDA_VERSION} --version)"
    else
        log_warn "Binary version check failed"
        log_info "  Run with: export LD_LIBRARY_PATH=${OUTPUT_DIR}:\$LD_LIBRARY_PATH"
    fi
}

# Create symlink to latest
create_symlink() {
    log_info "Creating symlink to latest build..."
    ln -sf llama-server-cuda-fa-${CUDA_VERSION} ${OUTPUT_DIR}/llama-server-cuda-fa
    log_info "✓ Symlink created: ${OUTPUT_DIR}/llama-server-cuda-fa"
}

# Main execution
main() {
    log_info "=== ik_llama.cpp llama-server Docker Build with Flash Attention ==="
    log_info "CUDA Version: ${CUDA_VERSION}"
    log_info "Ubuntu Version: ${UBUNTU_VERSION}"
    log_info "Output Directory: ${OUTPUT_DIR}"
    log_info "Image Name: ${IMAGE_NAME}"
    echo ""

    check_prerequisites
    build_image
    extract_binary
    test_binary
    create_symlink

    log_info ""
    log_info "=== Build Complete ==="
    log_info "GPU-accelerated llama-server with Flash Attention is ready:"
    log_info "  ${OUTPUT_DIR}/llama-server-cuda-fa-${CUDA_VERSION}"
    log_info ""
    log_info "To use:"
    log_info "  LD_LIBRARY_PATH=${OUTPUT_DIR}:\$LD_LIBRARY_PATH ${OUTPUT_DIR}/llama-server-cuda-fa -m model.gguf --port 8000 -ngl 33"
    log_info ""
    log_info "Or update coding zenka configuration to point to the new binary."
    echo ""
}

# Run main
main "$@"
