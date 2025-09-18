#!/bin/bash -e

# SPDX-FileCopyrightText: 2025 eden Emulator Project
# SPDX-License-Identifier: GPL-3.0-or-later

QT_VERSION="6.8.3"
QT_SRC_DIR="$HOME/qt-src-$QT_VERSION"
QT_BUILD_DIR="$HOME/qt-build-$QT_VERSION"
QT_INSTALL_DIR="$HOME/qt-clang-$QT_VERSION"
CLANG_BIN="/usr/bin/clang"
CLANGPP_BIN="/usr/bin/clang++"

if [ "${INSTALL_DEPS}" = "ON" ]; then
    sudo apt-get update
    sudo apt-get install -y build-essential perl python3 git \
        "^libxcb.*" libx11-dev libx11-xcb-dev libxcb-xinerama0-dev \
        libxcb-keysyms1-dev libxcb-icccm4-dev libxcb-image0-dev \
        libxkbcommon-dev libxkbcommon-x11-dev libgl-dev libdbus-1-dev \
        libasound2-dev libpulse-dev libudev-dev libfontconfig1-dev \
        libcap-dev libssl-dev
fi

if [ ! -d "$QT_SRC_DIR" ]; then
    mkdir -p "$QT_SRC_DIR"
    cd "$QT_SRC_DIR"
    wget https://download.qt.io/archive/qt/6.8/$QT_VERSION/single/qt-everywhere-src-$QT_VERSION.tar.xz
    tar xf qt-everywhere-src-$QT_VERSION.tar.xz --strip-components=1
fi

mkdir -p "$QT_BUILD_DIR"
cd "$QT_BUILD_DIR"

"$QT_SRC_DIR/configure" \
    -prefix "$QT_INSTALL_DIR" \
    -opensource -confirm-license \
    -nomake examples -nomake tests \
    -no-pch \
    -skip qt3d \
    -skip qtcanvas3d \
    -skip qtconnectivity \
    -skip qtdatavis3d \
    -skip qtdoc \
    -skip qtgraphicaleffects \
    -skip qtgamepad \
    -skip qtquick3d \
    -skip qtquicktimeline \
    -skip qtx11extras \
    -skip qtwebengine \
    -skip qtgraphs \
    -skip qtquick3dphysics \
    -skip qtspeech \
    -platform linux-clang \
    -device-option CXX="$CLANGPP_BIN" \
    -device-option CC="$CLANG_BIN" \
    -release \
    -force-debug-info \
    "CFLAGS=-march=native -mtune=native -O3 -pipe" \
    "CXXFLAGS=-march=native -mtune=native -O3 -pipe"

cmake --build . --parallel $(nproc)

cmake --install .
