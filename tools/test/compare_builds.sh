#!/bin/bash -e

# SPDX-FileCopyrightText: Copyright 2025 DraVee
# SPDX-License-Identifier: GPL-3.0-or-later

# Usage/help
show_help() {
    echo "Usage: $0 [--temp | <log_folder>]"
    echo
    echo "Options:"
    echo "  --temp       Use a temporary folder (mktemp) for logs"
    echo "  <log_folder> Use the specified folder for logs"
    echo "  -h, --help   Show this help message"
}

# Parse arguments
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ "$1" == "--temp" ]]; then
    BASE_LOG_DIR=$(mktemp -d)
    echo "Using temporary log folder: $BASE_LOG_DIR"
elif [[ -n "$1" ]]; then
    BASE_LOG_DIR="$1"
else
    BASE_LOG_DIR="$HOME/.cache/test-logs"
fi

mkdir -p "$BASE_LOG_DIR"

# Check required programs
for cmd in python3 mangohud find; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Error: $cmd is not installed. Please install it before running this script."
        exit 1
    fi
done

# Log duration
WAIT_DURATION=5
LOG_DURATION=$((30 + WAIT_DURATION))

# Loop through all build*/bin/eden executables
for eden_bin in build*/bin/eden; do
    if [[ ! -x "$eden_bin" ]]; then
        echo "Skipping $eden_bin: not executable"
        continue
    fi

    # Extract build name
    build_name=$(dirname "$eden_bin" | cut -d'/' -f1)

    # Timestamp for unique log folder
    timestamp=$(date +%Y-%m-%d_%H-%M-%S)
    log_dir="$BASE_LOG_DIR/$build_name/$timestamp"
    mkdir -p "$log_dir"

    echo "Running $eden_bin → logs will be saved in $log_dir"

    # Set MangoHud environment variables
    export MANGOHUD=1
    export MANGOHUD_LOG=1
    export MANGOHUD_CONFIG="output_folder=$log_dir;log_duration=$LOG_DURATION;autostart_log=$WAIT_DURATION"

    # Run Eden in background and capture its PID
    QT_QPA_PLATFORM=xcb "$eden_bin" &
    EDEN_PID=$!

    # Monitor MangoHud logs in real time for _summary.csv creation
    summary_file=""
    while [[ ! -f "$summary_file" ]]; do
        summary_file=$(find "$log_dir" -name "*_summary.csv" | head -n 1)
        sleep 0.5
    done

    echo "Summary detected: $summary_file"
    echo "Stopping $eden_bin..."

    # Kill the Eden process
    kill "$EDEN_PID"
    sleep 5
    kill -9 "$EDEN_PID" 2>/dev/null || true
    wait "$EDEN_PID" 2>/dev/null || true
done

# Run comparison script
echo "All builds finished. Running compare_logs.py..."
python3 tools/test/compare_logs.py "$BASE_LOG_DIR"

