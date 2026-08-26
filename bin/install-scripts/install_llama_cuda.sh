#!/bin/bash
#
# Installation script for ik_llama.cpp CUDA build
# Run as root: sudo bash /tmp/install_llama_cuda.sh
#

set -e  # Exit on any error

echo "========================================"
echo "Installing ik_llama.cpp CUDA binaries"
echo "========================================"

SOURCE_DIR="/data/source/ik_llama.cpp/build/bin"
INSTALL_DIR="/usr/local/bin"

# Check if source binaries exist
if [ ! -f "$SOURCE_DIR/llama-server" ]; then
    echo "ERROR: Source binary not found at $SOURCE_DIR/llama-server"
    exit 1
fi

echo "Source directory: $SOURCE_DIR"
echo "Install directory: $INSTALL_DIR"
echo ""

# Install llama-server with CUDA
echo "[1/3] Installing llama-server-cuda..."
cp "$SOURCE_DIR/llama-server" "$INSTALL_DIR/llama-server-cuda"
chmod 755 "$INSTALL_DIR/llama-server-cuda"
echo "✓ Installed: $INSTALL_DIR/llama-server-cuda"

# Install llama-cli with CUDA
echo "[2/3] Installing llama-cli-cuda..."
cp "$SOURCE_DIR/llama-cli" "$INSTALL_DIR/llama-cli-cuda"
chmod 755 "$INSTALL_DIR/llama-cli-cuda"
echo "✓ Installed: $INSTALL_DIR/llama-cli-cuda"

# Create symlink so llama-server points to CUDA version
echo "[3/3] Creating symlink llama-server -> llama-server-cuda..."
rm -f "$INSTALL_DIR/llama-server"
ln -s "$INSTALL_DIR/llama-server-cuda" "$INSTALL_DIR/llama-server"
echo "✓ Symlink created"

echo ""
echo "========================================"
echo "Installation complete!"
echo "========================================"
echo ""
echo "Binary locations:"
ls -lh "$INSTALL_DIR/llama-server"* 2>/dev/null | sed 's/^/  /'
echo ""
echo "Version check (should show CUDA-compiled version):"
"$INSTALL_DIR/llama-server" --version
echo ""
echo "Which llama-server is in PATH:"
which llama-server
echo ""
echo "PATH priority:"
echo "  • /usr/local/bin (CUDA build, ik_llama.cpp optimized)"
echo "  • /usr/bin (Debian package, no CUDA)"
echo ""
echo "To restore the Debian version: rm $INSTALL_DIR/llama-server"
echo "To remove CUDA build: rm $INSTALL_DIR/llama-server-cuda"

#,,.,,.,.,,..,,.,,.,,,,,,,,.,,,,,,.,,,..,,,,,,..,,...,...,..,,..,,,,,,.,.,.,.,
#S2RX3UM3OTXCFFLHH2QBZPRHEH4IZ5K3QKYTV7JFI5W7A4NYPAVB6CHZBH4E3CW7RAEASHTTNTH4I
#\\\|MYBNUVPQLXTE67GWWC7TIYLAYECGHVHCD4L3N545X6XNBWNTZQN \ / AMOS7 \ YOURUM ::
#\[7]6W7EWVDWCOKNBXUZGH5JTTP2MHAUAUCTRU6TH3WKX353PPXX32DA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
