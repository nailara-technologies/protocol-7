#!/bin/bash

## [:< ##
# name = setup-httpd-static-assets.sh
# descr = Populate /var/httpd/static/ from repository data/ for web serving

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ".:[ Protocol-7 Static Assets Setup ]:."
echo ""
echo "Project root: $PROJECT_ROOT"
echo ""

## Create static directory structure ##
echo "[*] Creating static asset directories..."
mkdir -p "$PROJECT_ROOT/var/httpd/static/gfx/logos"
mkdir -p "$PROJECT_ROOT/var/httpd/static/css"
mkdir -p "$PROJECT_ROOT/var/httpd/static/js"
mkdir -p "$PROJECT_ROOT/var/httpd/static/fonts"

## Copy logos from data/gfx/logos/ to var/httpd/static/gfx/logos/ ##
echo "[*] Copying logos..."
if [ -d "$PROJECT_ROOT/data/gfx/logos" ]; then
    cp -v "$PROJECT_ROOT/data/gfx/logos/nailara_logo.trans-dark.png" \
          "$PROJECT_ROOT/var/httpd/static/gfx/logos/"
    cp -v "$PROJECT_ROOT/data/gfx/logos/nailara.png" \
          "$PROJECT_ROOT/var/httpd/static/gfx/logos/" 2>/dev/null || true
    cp -v "$PROJECT_ROOT/data/gfx/logos/nailara.jpg" \
          "$PROJECT_ROOT/var/httpd/static/gfx/logos/" 2>/dev/null || true
    echo "    Logos copied successfully"
else
    echo "    Warning: data/gfx/logos/ not found"
fi

## Set permissions ##
echo "[*] Setting permissions..."
chmod -R 755 "$PROJECT_ROOT/var/httpd/static"
find "$PROJECT_ROOT/var/httpd/static" -type f -exec chmod 644 {} \;

echo ""
echo "[✓] Manual asset copy complete!"
echo ""

## Run template validator for automatic dependency resolution ##
echo "[*] Running template asset validator..."
echo ""
if [ -x "$SCRIPT_DIR/validate-template-assets.pl" ]; then
    PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_DIR/validate-template-assets.pl"
    VALIDATOR_EXIT=$?
    echo ""
    if [ $VALIDATOR_EXIT -eq 0 ]; then
        echo "[✓] All template assets validated and resolved"
    else
        echo "[!] Template validation failed - some assets could not be resolved"
        exit $VALIDATOR_EXIT
    fi
else
    echo "[!] Warning: validate-template-assets.pl not found or not executable"
fi

echo ""
echo "Assets location: /var/httpd/static/"
echo "Web path:        /static/"
echo ""
echo "Note: httpd must be configured to serve /static/ from /var/httpd/static/"

#,,..,.,.,,,.,..,,,,.,,,,,...,...,.,,,,,,,.,.,..,,...,...,,,,,,.,,,..,.,.,.,.,
#JBUAD55UWZUEFXPPKTDLWZGTACPDDWB6B7KNNXI3CSQ5V3RDZBSNN334AV36VTBTRBONCJAODWASY
#\\\|557OGTF6G7KUTQOF5NCKCOR52TELN3NQRX2RS6KU6EHK4HNA2JF \ / AMOS7 \ YOURUM ::
#\[7]3QRWK7ERSOOPUSQIHQEIDM6T3D6QV5AZW4QAFQNJSQLAJTMR7SCA 7  DATA SIGNATURE ::
#:::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
