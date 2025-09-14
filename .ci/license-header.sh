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
    echo "  FIX=true    | Automatically add the correct license headers to offending files."
    echo "  UPDATE=true | Automatically update current license headers of offending files."
    echo "  COMMIT=true | If FIX=true, commit the changes automatically."
    echo
    echo "Usage Examples:"
    echo "  # Just check headers (will fail if headers are missing)"
    echo "  .ci/license-header.sh"
    echo
    echo "  # Fix headers only"
    echo "  FIX=true .ci/license-header.sh"
    echo
    echo "  # Update headers only"
    echo "  #   if COPYRIGHT_OWNER is '$COPYRIGHT_OWNER'"
    echo "  #   or else will have 'FIX=true' behavior)"
    echo "  UPDATE=true .ci/license-header.sh"
    echo
    echo "  # Fix headers and commit changes"
    echo "  FIX=true COMMIT=true .ci/license-header.sh"
    echo
    echo "  # Update headers and commit changes"
    echo "  #   if COPYRIGHT_OWNER is '$COPYRIGHT_OWNER'"
    echo "  #   or else will have 'FIX=true' behavior)"
    echo "  UPDATE=true COMMIT=true .ci/license-header.sh"
    exit 0
fi

SRC_FILES=""
OTHER_FILES=""

BASE=$(git merge-base master HEAD)
if git diff --quiet "$BASE"..HEAD; then
    echo
    echo "license-header.sh: No commits on this branch different from master."
    exit 0
fi
FILES=$(git diff --name-only "$BASE")

echo_header() {
    COMMENT_TYPE="$1"
    echo "$COMMENT_TYPE SPDX-FileCopyrightText: Copyright $COPYRIGHT_YEAR $COPYRIGHT_OWNER"
    echo "$COMMENT_TYPE SPDX-License-Identifier: $COPYRIGHT_LICENSE"
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

    HEADER=$(echo_header "$COMMENT_TYPE")
    HEAD_LINES=$(head -n5 "$file")

    CORRECT_COPYRIGHT=$(echo "$HEAD_LINES" | awk \
        -v line1="$(echo "$HEADER" | sed -n '1p')" \
        -v line2="$(echo "$HEADER" | sed -n '2p')" \
        '($0==line1){getline; if($0==line2){f=1}else{f=0}} END{print (f?f:0)}')

    if [ "$CORRECT_COPYRIGHT" != "1" ]; then
        case "$COMMENT_TYPE" in
            "//") SRC_FILES="$SRC_FILES $file" ;;
            "#")  OTHER_FILES="$OTHER_FILES $file" ;;
        esac
    fi
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
    echo_header "$COMMENT_TYPE"
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
if [ "$FIX" = "true" ] || [ "$UPDATE" = "true" ]; then
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

        TMP="$TMP_DIR/$BASENAME.tmp"
        UPDATED=0
        cp -p "$file" "$TMP"
        > "$TMP"

        # this logic is bit hacky but sed don't work well with $VARIABLES
        # it's this or complete remove this logic and keep only the old way
        if [ "$UPDATE" = "true" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                if [ "$UPDATED" -eq 0 ] && echo "$line" | grep "$COPYRIGHT_OWNER" >/dev/null 2>&1; then
                    echo_header "$COMMENT_TYPE" >> "$TMP"
                    IFS= read -r _ || true
                    UPDATED=1
                else
                    echo "$line" >> "$TMP"
                fi
            done < "$file"
        fi

        if [ "$UPDATED" -eq 0 ]; then
            {
                echo_header "$COMMENT_TYPE"
                echo
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

