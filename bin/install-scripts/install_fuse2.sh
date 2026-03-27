#!/bin/sh
# Install FUSE 2.x from source for Fuse.pm compatibility
# Modern distros provide FUSE 3.x only, but Fuse.pm requires FUSE 2.x

set -e

FUSE2_VERSION="2.9.9"
FUSE2_TAG="fuse-2.9.9"
FUSE2_REPO="https://github.com/libfuse/libfuse"
BUILD_DIR="/tmp/fuse2-build-$$"
INSTALL_PREFIX="/usr/local"

echo " :"
echo " : Installing FUSE ${FUSE2_VERSION} from git.."
echo " : (Required for Perl Fuse module compatibility)"
echo " :"

# Check if already installed
if [ -f "${INSTALL_PREFIX}/lib/libfuse.so" ] || [ -f "${INSTALL_PREFIX}/lib/x86_64-linux-gnu/libfuse.so" ]; then
    echo " : libfuse.so already present, checking version.."
    if pkg-config --exists fuse 2>/dev/null; then
        FUSE_VER=$(pkg-config --modversion fuse 2>/dev/null || echo "unknown")
        echo " : FUSE version: ${FUSE_VER}"
        case "${FUSE_VER}" in
            2.*)
                echo " : FUSE 2.x already installed =)"
                echo " :"
                exit 0
                ;;
            3.*)
                echo " : FUSE 3.x detected, need 2.x for Fuse.pm"
                ;;
        esac
    fi
fi

# Install build dependencies
echo " : Installing build dependencies.."
apt-get update
apt-get install -y build-essential git pkg-config autoconf automake libtool gettext || true

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Clone FUSE 2.x
echo " : Cloning libfuse repository.."
git clone --depth 1 --branch "${FUSE2_TAG}" "${FUSE2_REPO}" "fuse-${FUSE2_VERSION}"

if [ ! -d "fuse-${FUSE2_VERSION}" ]; then
    echo " : ERROR: Git clone failed"
    rm -rf "${BUILD_DIR}"
    exit 1
fi

cd "fuse-${FUSE2_VERSION}"

# Generate configure script
echo " : Running autoreconf.."
autoreconf -fiv || {
    echo " : WARNING: autoreconf failed, trying without iconv.."
    # Disable iconv which can cause build issues
    sed -i 's/AM_ICONV/# AM_ICONV/' configure.ac 2>/dev/null || true
    autoreconf -fiv
}

# Configure
echo " : Configuring.."
./configure --prefix="${INSTALL_PREFIX}" --disable-example

# Build
echo " : Building.."
make -j$(nproc)

# Install
echo " : Installing to ${INSTALL_PREFIX}.."
make install

# Update library cache
echo " : Updating library cache.."
ldconfig

# Update pkg-config path
if [ -d "${INSTALL_PREFIX}/lib/pkgconfig" ]; then
    export PKG_CONFIG_PATH="${INSTALL_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH}"
fi

# Verify installation
echo " : Verifying installation.."
if pkg-config --exists fuse; then
    FUSE_VER=$(pkg-config --modversion fuse)
    echo " : FUSE ${FUSE_VER} installed successfully =)"
else
    echo " : WARNING: pkg-config cannot find fuse"
fi

# Cleanup
cd /
rm -rf "${BUILD_DIR}"

echo " :"
echo " : FUSE 2.x installation complete."
echo " : You can now install the Perl Fuse module:"
echo " :   cpanm Fuse"
echo " :"

#,,.,,.,,.,,.,,.,.,.,.,.,,.,.,.,,.,.,.,,.,,.,.,.,,.,.,.,,.,.,.,,.,.,.,,.,.,.,,

#,,,,,,..,,,,,,..,.,,,,,.,,,.,.,,,.,,,,.,,,,,,..,,...,...,...,,,.,...,,,,,..,,
#NRSHQCXRHXSOVX55KVVLJAK7VF4INJ7ME7IBNZMCEYY72TZ7OEZYF5XRAN7OINUIY6UXRM4NAAT4I
#\\\|33YGIXGBHICH4TPGFT6J5SE6LIWBSHZR4HRFIWYZHYGGEHQXAQS \ / AMOS7 \ YOURUM ::
#\[7]QH3OH5WNCBZLVEXWG5H3DVT4CNS3RIKHKNYDYU32GS6TFP46TUBQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
