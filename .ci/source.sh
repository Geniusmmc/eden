#!/bin/bash -ex

# SPDX-FileCopyrightText: 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

# git-archive-all
export PATH="$PATH:/home/$USER/.local/bin"

GITDATE="$(git show -s --date=short --format='%ad' | sed 's/-//g')"
GITREV="$(git show -s --format='%h')"
REV_NAME="eden-unified-source-${GITDATE}-${GITREV}"

COMPAT_LIST='dist/compatibility_list/compatibility_list.json'

mkdir artifacts

touch "${COMPAT_LIST}"
git describe --abbrev=0 --always HEAD > GIT-COMMIT
git describe --tags HEAD > GIT-TAG || echo 'unknown' > GIT-TAG
git-archive-all --include "${COMPAT_LIST}" --include GIT-COMMIT --include GIT-TAG --force-submodules artifacts/"${REV_NAME}.tar"

cd artifacts/
xz -T0 -9 "${REV_NAME}.tar"
sha256sum "${REV_NAME}.tar.xz" > "${REV_NAME}.tar.xz.sha256sum"
cd ..
