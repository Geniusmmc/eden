#!/bin/sh -e

# SPDX-FileCopyrightText: 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo
    echo "license-header.sh: Eden License Headers Accreditation Script"
    echo
    echo "This script checks and optionally fixes license headers in source and CMake files."
    echo
    echo "Environment Variables:"
    echo "  FIX=true      Automatically add the correct license headers to offending files."
    echo "  COMMIT=true   If FIX=true, commit the changes automatically."
    echo
    echo "Usage Examples:"
    echo "  # Just check headers (will fail if headers are missing)"
    echo "  .ci/license-header.sh"
    echo
    echo "  # Fix headers only"
    echo "  FIX=true .ci/license-header.sh"
    echo
    echo "  # Fix headers and commit changes"
    echo "  FIX=true COMMIT=true .ci/license-header.sh"
    exit 0
fi

HEADER="$(cat "$PWD/.ci/license/header.txt")"
HEADER_HASH="$(cat "$PWD/.ci/license/header-hash.txt")"

echo
echo "license-header.sh: Getting branch changes"

BASE=$(git merge-base master HEAD)
if git diff --quiet "$BASE"..HEAD; then
    echo
    echo "license-header.sh: No commits on this branch different from master."
    exit 0
fi
FILES=$(git diff --name-only "$BASE")

check_header() {
    CONTENT=$(head -n3 < "$1")
    case "$CONTENT" in
        "$HEADER"*) ;;
        *) BAD_FILES="$BAD_FILES $1" ;;
    esac
}

check_cmake_header() {
    CONTENT=$(head -n3 < "$1")
    case "$CONTENT" in
        "$HEADER_HASH"*) ;;
        *) BAD_CMAKE="$BAD_CMAKE $1" ;;
    esac
}

for file in $FILES; do
    [ -f "$file" ] || continue

    if [ "$(basename -- "$file")" = "CMakeLists.txt" ]; then
        check_cmake_header "$file"
        continue
    fi

    EXTENSION="${file##*.}"
    case "$EXTENSION" in
        kts|kt|cpp|h)
            check_header "$file"
            ;;
        cmake)
            check_cmake_header "$file"
            ;;
    esac
done

if [ -z "$BAD_FILES" ] && [ -z "$BAD_CMAKE" ]; then
    echo
    echo "license-header.sh: All good!"
    exit 0
fi

if [ -n "$BAD_FILES" ]; then
    echo
    echo "license-header.sh: The following source files have incorrect license headers:"

    echo
    for file in $BAD_FILES; do
        echo " - $file"
    done

    cat << EOF

The following license header should be added to the start of all offending SOURCE files:

=== BEGIN ===
$HEADER
===  END  ===

EOF

fi

if [ -n "$BAD_CMAKE" ]; then
    echo
    echo "license-header.sh: The following CMake files have incorrect license headers:"

    echo
    for file in $BAD_CMAKE; do
        echo " - $file"
    done

    cat << EOF

The following license header should be added to the start of all offending CMake files:

=== BEGIN ===
$HEADER_HASH
===  END  ===

EOF

fi

cat << EOF
If some of the code in this PR is not being contributed by the original author,
the files which have been exclusively changed by that code can be ignored.
If this happens, this PR requirement can be bypassed once all other files are addressed.
EOF

if [ "$FIX" = "true" ]; then
    echo
    echo "license-header.sh: FIX set to true, fixing headers..."

    for file in $BAD_FILES; do
        cp -- "$file" "$file.bak"

        cat .ci/license/header.txt > "$file"
        echo >> "$file"
        cat "$file.bak" >> "$file"

        rm -- "$file.bak"
        git add "$file"
    done

    for file in $BAD_CMAKE; do
        cp -- "$file" "$file.bak"

        cat .ci/license/header-hash.txt > "$file"
        echo >> "$file"
        cat "$file.bak" >> "$file"

        rm -- "$file.bak"
        git add "$file"
    done

    echo
    echo "license-header.sh: License headers fixed!"

    if [ "$COMMIT" = "true" ]; then
        echo
        echo "license-header.sh: COMMIT set to true, committing changes..."

        git commit -m "[license] Fix license headers"

        echo
        echo  "license-header.sh: Changes committed. You may now push."
    fi
else
    exit 1
fi
