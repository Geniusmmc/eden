# SPDX-FileCopyrightText: Copyright 2025 Eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

#!/bin/sh

SUM=$(wget -q "$1" -O - | sha512sum)
echo "$SUM" | cut -d " " -f1
