#!/bin/bash
# Build ik_llama.cpp with CUDA GPU support using Docker
# Avoids Debian 12 glibc incompatibility by using Ubuntu 22.04 container
# Usage: ./build-cuda-docker.sh [OPTIONS]

set -e

# Configuration
CUDA_VERSION=${CUDA_VERSION:-12.5.0}
UBUNTU_VERSION=${UBUNTU_VERSION:-jammy}
IMAGE_NAME=${IMAGE_NAME:-ik_llama_cuda_gpu}
OUTPUT_DIR=${OUTPUT_DIR:-.}
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
}

# Build Docker image
build_image() {
    log_info "Building Docker image with CUDA ${CUDA_VERSION}..."
    log_info "This may take 10-30 minutes on first build..."

    $DOCKER_CMD build \
        -f Dockerfile.cuda-build \
        -t ${IMAGE_NAME}:${CUDA_VERSION} \
        --build-arg CUDA_VERSION=${CUDA_VERSION} \
        --build-arg UBUNTU_VERSION=${UBUNTU_VERSION} \
        . || {
            log_error "Docker build failed"
            exit 1
        }

    log_info "✓ Docker image built successfully"
}

# Extract binary from container
extract_binary() {
    log_info "Extracting llama-server binary and libraries from container..."

    # Create temporary container
    CONTAINER_ID=$($DOCKER_CMD create ${IMAGE_NAME}:${CUDA_VERSION})

    # Copy binary
    $DOCKER_CMD cp ${CONTAINER_ID}:/usr/local/bin/llama-server \
        ${OUTPUT_DIR}/llama-server-cuda-${CUDA_VERSION} || {
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
    for lib in libcudart.so.12 libcuda.so.1 libcublas.so.12 libcublasLt.so.12 libcudnn.so.8 libcurand.so.10 libcusparse.so.12; do
        $DOCKER_CMD cp ${CONTAINER_ID}:/usr/local/cuda/lib64/${lib} \
            ${OUTPUT_DIR}/ 2>/dev/null || log_info "Library ${lib} not found (optional)"
    done

    # Cleanup
    $DOCKER_CMD rm ${CONTAINER_ID}

    # Make executable
    chmod +x ${OUTPUT_DIR}/llama-server-cuda-${CUDA_VERSION}

    log_info "✓ Binary extracted to: ${OUTPUT_DIR}/llama-server-cuda-${CUDA_VERSION}"
    log_info "✓ Libraries extracted to: ${OUTPUT_DIR}/"
}

# Test the binary
test_binary() {
    log_info "Testing compiled binary..."

    # Run with LD_LIBRARY_PATH pointing to extracted libraries
    if LD_LIBRARY_PATH="${OUTPUT_DIR}:${LD_LIBRARY_PATH}" ${OUTPUT_DIR}/llama-server-cuda-${CUDA_VERSION} --version > /dev/null 2>&1; then
        log_info "✓ Binary works: $(LD_LIBRARY_PATH="${OUTPUT_DIR}:${LD_LIBRARY_PATH}" $OUTPUT_DIR/llama-server-cuda-${CUDA_VERSION} --version)"
    else
        log_warn "Binary version check failed"
        log_info "  Note: Run with: export LD_LIBRARY_PATH=${OUTPUT_DIR}:\$LD_LIBRARY_PATH"
    fi
}

# Create symlink to latest
create_symlink() {
    log_info "Creating symlink to latest build..."
    ln -sf llama-server-cuda-${CUDA_VERSION} ${OUTPUT_DIR}/llama-server-cuda
    log_info "✓ Symlink created: ${OUTPUT_DIR}/llama-server-cuda"
}

# Main execution
main() {
    log_info "=== ik_llama.cpp CUDA Docker Build ==="
    log_info "CUDA Version: ${CUDA_VERSION}"
    log_info "Ubuntu Version: ${UBUNTU_VERSION}"
    log_info "Output Directory: ${OUTPUT_DIR}"
    echo ""

    check_prerequisites
    build_image
    extract_binary
    test_binary
    create_symlink

    log_info ""
    log_info "=== Build Complete ==="
    log_info "GPU-accelerated llama-server is ready:"
    log_info "  ${OUTPUT_DIR}/llama-server-cuda-${CUDA_VERSION}"
    log_info ""
    log_info "To use with a model:"
    log_info "  ${OUTPUT_DIR}/llama-server-cuda -m /path/to/model.gguf -ngl 33"
    log_info ""
    log_info "Environment variables:"
    log_info "  CUDA_VISIBLE_DEVICES=0  (if you have multiple GPUs)"
    echo ""
}

# Run main
main "$@"
