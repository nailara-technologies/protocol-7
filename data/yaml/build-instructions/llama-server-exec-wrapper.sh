#!/bin/bash
#
# LLAMA-SERVER EXECUTION WRAPPER
#
# This script allows protocol-7 to select which llama-server to run
# Based on environment configuration and preference order
#
# Location: /data/projects/protocol-7/data/yaml/build-instructions/llama-server-exec-wrapper.sh
# Usage: ./llama-server-exec-wrapper.sh [args...]
#

set -e

# Configuration - reorder these to change preference order
SEARCH_PATHS=(
    "/usr/local/bin/llama-server"      # ik_llama.cpp CUDA build (installed)
    "/usr/local/bin/llama-server-cuda" # ik_llama.cpp CUDA build (original)
    "/usr/bin/llama-server"            # Debian package (system default)
)

# Environment override: LLAMA_SERVER_VARIANT
# Set to: cuda, debian, or full path
if [ -n "$LLAMA_SERVER_VARIANT" ]; then
    case "$LLAMA_SERVER_VARIANT" in
        cuda)
            SEARCH_PATHS=("/usr/local/bin/llama-server-cuda" "/usr/local/bin/llama-server" "${SEARCH_PATHS[@]}")
            ;;
        debian)
            SEARCH_PATHS=("/usr/bin/llama-server" "${SEARCH_PATHS[@]}")
            ;;
        *)
            # Treat as direct path
            if [ -x "$LLAMA_SERVER_VARIANT" ]; then
                exec "$LLAMA_SERVER_VARIANT" "$@"
            fi
            ;;
    esac
fi

# Find first available binary in preference order
LLAMA_SERVER=""
for path in "${SEARCH_PATHS[@]}"; do
    if [ -x "$path" ]; then
        LLAMA_SERVER="$path"
        break
    fi
done

if [ -z "$LLAMA_SERVER" ]; then
    echo "ERROR: llama-server not found in any search path:" >&2
    printf '%s\n' "${SEARCH_PATHS[@]}" | sed 's/^/  /' >&2
    echo "" >&2
    echo "Available binaries:" >&2
    which -a llama-server 2>/dev/null | sed 's/^/  /' || echo "  (none found)" >&2
    exit 1
fi

# Print which version is being used (for debugging)
if [ -n "$VERBOSE" ] || [ "$1" = "--version" ]; then
    echo "Using llama-server: $LLAMA_SERVER" >&2
    "$LLAMA_SERVER" --version >&2
fi

# Execute with all passed arguments
exec "$LLAMA_SERVER" "$@"
