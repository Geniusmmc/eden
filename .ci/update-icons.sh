#!/bin/sh -e

# SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

# Check dependencies
for cmd in png2icns magick svgo; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        pkg="$cmd"
        case "$cmd" in
            png2icns) pkg="icnsutils" ;;
            magick) pkg="imagemagick" ;;
        esac
        echo "Error: command '$cmd' not found. Install the package '$pkg'."
        exit 1
    fi
done

EDEN_SVG_ICO="dist/dev.eden_emu.eden.svg"

# Create temporary PNG file safely (and POSIX-compliant)
TMP_PNG=$(mktemp /tmp/eden-tmp-XXXXXX)
TMP_PNG="${TMP_PNG}.png"

# Optimize SVG
svgo --multipass "$EDEN_SVG_ICO"

# Generate ICO
magick \
    -density 256x256 -background transparent "$EDEN_SVG_ICO" \
    -define icon:auto-resize -colors 256 "dist/eden.ico"

# Generate BMP
magick "$EDEN_SVG_ICO" -resize 256x256 -background transparent "dist/yuzu.bmp"

# Generate PNG for ICNS
magick -size 1024x1024 -background transparent "$EDEN_SVG_ICO" "$TMP_PNG"

# Generate ICNS
png2icns "dist/eden.icns" "$TMP_PNG"

# Copy ICNS to Yuzu file
cp "dist/eden.icns" "dist/yuzu.icns"

# Remove temporary PNG
rm -f "$TMP_PNG"

