#!/bin/bash
# Utility function to robustly find Protocol-7 project root
# Works regardless of script location in nested directories
# Usage: source this file, then call: find_protocol_7_root

find_protocol_7_root() {
    # 1. Check environment variable first (fastest)
    if [ -n "$PROTOCOL_7_ROOT" ] && [ -d "$PROTOCOL_7_ROOT" ]; then
        if [ -f "$PROTOCOL_7_ROOT/bin/nshell" ] || [ -d "$PROTOCOL_7_ROOT/modules" ]; then
            echo "$PROTOCOL_7_ROOT"
            return 0
        fi
    fi

    # 2. Find script's location
    local script_path="${BASH_SOURCE[1]}"
    if [ -z "$script_path" ]; then
        script_path="${0}"
    fi

    local current_dir
    current_dir="$(cd "$(dirname "$script_path")" && pwd)"

    # 3. Walk up directory tree looking for project markers
    local marker_count=0
    local max_depth=10  # Safety limit to prevent infinite loops

    while [ $marker_count -lt $max_depth ]; do
        # Check for multiple markers that identify Protocol-7 root
        if [ -d "$current_dir/.git" ] && [ -d "$current_dir/modules" ] && [ -d "$current_dir/bin" ]; then
            echo "$current_dir"
            return 0
        fi

        # Also check for just the key directories (in case .git doesn't exist)
        if [ -d "$current_dir/modules" ] && [ -f "$current_dir/bin/nshell" ] && [ -d "$current_dir/configuration" ]; then
            echo "$current_dir"
            return 0
        fi

        # Move up one level
        if [ "$current_dir" = "/" ]; then
            break
        fi
        current_dir="$(dirname "$current_dir")"
        marker_count=$((marker_count + 1))
    done

    # 4. Fallback: If called from bin/test-*, assume parent is root
    local fallback_root="$(cd "$(dirname "$script_path")/.." && pwd)"
    if [ -f "$fallback_root/bin/nshell" ] || [ -d "$fallback_root/modules" ]; then
        echo "$fallback_root"
        return 0
    fi

    # 5. Final fallback: Two levels up (for bin/dev/tests/*)
    fallback_root="$(cd "$(dirname "$script_path")/../../.." && pwd)"
    if [ -f "$fallback_root/bin/nshell" ] || [ -d "$fallback_root/modules" ]; then
        echo "$fallback_root"
        return 0
    fi

    # Failed to find root
    echo "ERROR: Could not find Protocol-7 project root" >&2
    echo "Searched from: $(dirname "$script_path")" >&2
    echo "Set PROTOCOL_7_ROOT environment variable if script is in non-standard location" >&2
    return 1
}

# Export function so it can be used in sourced scripts
export -f find_protocol_7_root

#,,..,,.,,...,,.,,,..,.,.,.,,,.,,,,,.,...,.,,,..,,...,..,,,,,,.,,,,,,,...,.,,,
#FNFPG4MTVKFATZORHKJPQS5LMQG2IG5YOYONQ5D3K7EA2WRC6YOM7E2DNFWQRWR6JLDDXCMBQMNLI
#\\\|A25Q3LUFB7U62MBGKHL6HFUDTE4QJPAYB4KH7Y6AF4U33YSAMFO \ / AMOS7 \ YOURUM ::
#\[7]WQ2K5OVUG3DYOZQHN2IJF3UT27AIS3MNMIHJ4XA4RKYMU742GYAQ 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
