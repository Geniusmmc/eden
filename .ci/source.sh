#!/bin/sh -e

# SPDX-FileCopyrightText: 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

GITDATE=$(git show -s --date=short --format='%ad' | sed 's/-//g')
GITREV=$(git show -s --format='%h')
REV_NAME="eden-unified-source-${GITDATE}-${GITREV}"

COMPAT_LIST="dist/compatibility_list/compatibility_list.json"
ARTIFACT_DIR="artifacts"
ARCHIVE_PATH="${ARTIFACT_DIR}/${REV_NAME}.tar"
XZ_PATH="${ARCHIVE_PATH}.xz"
SHA_PATH="${XZ_PATH}.sha256sum"

# Abort if archive already exists
if [ -e "$XZ_PATH" ]; then
    echo "Error: Archive '$XZ_PATH' already exists. Aborting."
    exit 1
fi

# Create output directory
mkdir -p "$ARTIFACT_DIR"

# Create temporary directory
TMPDIR=$(mktemp -d)

# Ensure compatibility list file exists
touch "$COMPAT_LIST"
cp "$COMPAT_LIST" "$TMPDIR/"

# Create base archive from git
git archive --format=tar --prefix="${REV_NAME}/" HEAD > "$ARCHIVE_PATH"

# Create commit and tag files with correct names
git describe --abbrev=0 --always HEAD > "$TMPDIR/GIT-COMMIT"
if ! git describe --tags HEAD > "$TMPDIR/GIT-TAG" 2>/dev/null; then
    echo "unknown" > "$TMPDIR/GIT-TAG"
fi

# Append extra files to archive
tar --append --file="$ARCHIVE_PATH" -C "$TMPDIR" "$(basename "$COMPAT_LIST")" GIT-COMMIT GIT-TAG

# Remove temporary directory
rm -rf "$TMPDIR"

# Compress using xz
xz -9 "$ARCHIVE_PATH"

# Generate SHA-256 checksum (GNU vs BSD/macOS)
if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$XZ_PATH" > "$SHA_PATH"
elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$XZ_PATH" > "$SHA_PATH"
else
    echo "No SHA-256 tool found (sha256sum or shasum required)" >&2
    exit 1
fi

