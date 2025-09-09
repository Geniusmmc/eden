#!/bin/sh -e

# SPDX-FileCopyrightText: 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

# Check dependencies
for cmd in png2icns magick svgo; do
    if ! which "$cmd" >/dev/null 2>&1; then
        pkg="$cmd"
        case "$cmd" in
            png2icns) pkg="icnsutils" ;;
            magick) pkg="imagemagick" ;;
        esac
        echo "Error: command '$cmd' not found. Install the package '$pkg'."
        exit 1
    fi
done

export EDEN_SVG_ICO="dist/dev.eden_emu.eden.svg"
TMP_PNG="$(mktemp /tmp/eden-tmp-XXXXXX.png)"

svgo --multipass "$EDEN_SVG_ICO"

magick \
    -density 256x256 -background transparent "$EDEN_SVG_ICO" \
    -define icon:auto-resize -colors 256 "dist/eden.ico"

magick "$EDEN_SVG_ICO" -resize 256x256 -background transparent "dist/yuzu.bmp"

magick -size 1024x1024 -background transparent "$EDEN_SVG_ICO" "$TMP_PNG"

png2icns "dist/eden.icns" "$TMP_PNG"

cp "dist/eden.icns" "dist/yuzu.icns"
rm -f "$TMP_PNG"
