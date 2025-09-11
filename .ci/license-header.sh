#!/bin/sh -e

# SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

COPYRIGHT_YEAR="2025"
COPYRIGHT_OWNER="Eden Emulator Project"
COPYRIGHT_LICENSE="GPL-3.0-or-later"

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo
    echo "license-header.sh: Eden License Headers Accreditation Script"
    echo
    echo "This script checks and optionally fixes license headers in source, CMake and shell script files."
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

HEADER_LINE1_TEMPLATE="{COMMENT_TEMPLATE} SPDX-FileCopyrightText: Copyright $COPYRIGHT_YEAR $COPYRIGHT_OWNER"
HEADER_LINE2_TEMPLATE="{COMMENT_TEMPLATE} SPDX-License-Identifier: $COPYRIGHT_LICENSE"

SRC_FILES=""
OTHER_FILES=""

BASE=$(git merge-base master HEAD)
if git diff --quiet "$BASE"..HEAD; then
    echo
    echo "license-header.sh: No commits on this branch different from master."
    exit 0
fi
FILES=$(git diff --name-only "$BASE")

check_header() {
    COMMENT_TYPE="$1"
    FILE="$2"

    HEADER_LINE1=$(printf '%s\n' "$HEADER_LINE1_TEMPLATE" | sed "s|{COMMENT_TEMPLATE}|$COMMENT_TYPE|g")
    HEADER_LINE2=$(printf '%s\n' "$HEADER_LINE2_TEMPLATE" | sed "s|{COMMENT_TEMPLATE}|$COMMENT_TYPE|g")

    FOUND=0
    while IFS= read -r line || [ -n "$line" ]; do
        if [ "$line" = "$HEADER_LINE1" ]; then
            IFS= read -r next_line || next_line=""
            if [ "$next_line" = "$HEADER_LINE2" ]; then
                FOUND=1
                break
            fi
        fi
    done < "$FILE"

    if [ "$FOUND" -eq 0 ]; then
        case "$COMMENT_TYPE" in
            "//") SRC_FILES="$SRC_FILES $FILE" ;;
            "#")  OTHER_FILES="$OTHER_FILES $FILE" ;;
        esac
    fi
}

for file in $FILES; do
    [ -f "$file" ] || continue

    case "$(basename "$file")" in
        CMakeLists.txt)
            COMMENT_TYPE="#" ;;
        *)
            EXT="${file##*.}"
            case "$EXT" in
                kts|kt|cpp|h) COMMENT_TYPE="//" ;;
                cmake|sh|ps1) COMMENT_TYPE="#" ;;
                *)            continue ;;
            esac ;;
    esac

    check_header "$COMMENT_TYPE" "$file"
done

if [ -z "$SRC_FILES" ] && [ -z "$OTHER_FILES" ]; then
    echo
    echo "license-header.sh: All good!"
    exit 0
fi

for TYPE in "SRC" "OTHER"; do
    if [ "$TYPE" = "SRC" ] && [ -n "$SRC_FILES" ]; then
        FILES_LIST="$SRC_FILES"
        COMMENT_TYPE="//"
        DESC="Source"
    elif [ "$TYPE" = "OTHER" ] && [ -n "$OTHER_FILES" ]; then
        FILES_LIST="$OTHER_FILES"
        COMMENT_TYPE="#"
        DESC="CMake and shell script"
    else
        continue
    fi

    echo
    echo "------------------------------------------------------------"
    echo "$DESC files"
    echo "------------------------------------------------------------"
    echo
    echo "  The following files contain incorrect license headers:"
    for file in $FILES_LIST; do
        echo "  - $file"
    done

    echo
    echo "  The correct license header to be added to all affected"
    echo "  '$DESC' files is:"
    echo
    echo "=== BEGIN ==="
    printf '%s\n%s\n' \
        "$(printf '%s\n' "$HEADER_LINE1_TEMPLATE" | sed "s|{COMMENT_TEMPLATE}|$COMMENT_TYPE|g")" \
        "$(printf '%s\n' "$HEADER_LINE2_TEMPLATE" | sed "s|{COMMENT_TEMPLATE}|$COMMENT_TYPE|g")"
    echo "===  END  ==="
done

cat << EOF

------------------------------------------------------------

  If some of the code in this pull request was not contributed by the original
  author, the files that have been modified exclusively by that code can be
  safely ignored. In such cases, this PR requirement may be bypassed once all
  other files have been reviewed and addressed.
EOF

TMP_DIR=$(mktemp -d /tmp/license-header.XXXXXX) || exit 1
if [ "$FIX" = "true" ]; then
    echo
    echo "license-header.sh: FIX set to true, fixing headers..."

    for file in $SRC_FILES $OTHER_FILES; do
        BASENAME=$(basename "$file")

        case "$BASENAME" in
            CMakeLists.txt) COMMENT_TYPE="#" ;;
            *)
                EXT="${file##*.}"
                case "$EXT" in
                    kts|kt|cpp|h) COMMENT_TYPE="//" ;;
                    cmake|sh|ps1) COMMENT_TYPE="#" ;;
                    *) continue ;;
                esac
                ;;
        esac

        LINE1=$(printf '%s\n' "$HEADER_LINE1_TEMPLATE" | sed "s|{COMMENT_TEMPLATE}|$COMMENT_TYPE|g")
        LINE2=$(printf '%s\n' "$HEADER_LINE2_TEMPLATE" | sed "s|{COMMENT_TEMPLATE}|$COMMENT_TYPE|g")

        TMP="$TMP_DIR/$BASENAME.tmp"
        UPDATED=0

        cp -p $file $TMP
        printf '' > $TMP

        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$UPDATED" -eq 0 ] && echo "$line" | grep "$COPYRIGHT_OWNER" >/dev/null 2>&1; then
                printf '%s\n%s\n' "$LINE1" "$LINE2" >> "$TMP"
                IFS= read -r _ || true
                UPDATED=1
            else
                printf '%s\n' "$line" >> "$TMP"
            fi
        done < "$file"

        if [ "$UPDATED" -eq 0 ]; then
            {
                printf '%s\n%s\n\n' "$LINE1" "$LINE2"
                cat "$TMP"
            } > "$file"
        else
            mv "$TMP" "$file"
        fi

        git add "$file"
    done

    rm -rf "$TMP_DIR"

    echo
    echo "license-header.sh: License headers fixed!"

    if [ "$COMMIT" = "true" ]; then
        echo
        echo "license-header.sh: COMMIT set to true, committing changes..."

        git commit -m "[license] Fix license headers [script]"

        echo
        echo "license-header.sh: Changes committed. You may now push."
    fi
else
    exit 1
fi

