#!/usr/bin/env python3

# SPDX-FileCopyrightText: Copyright 2025 DraVee
# SPDX-License-Identifier: GPL-3.0-or-later

import sys
import pandas as pd
import matplotlib.pyplot as plt
import glob
import os

# Check required Python modules
required_modules = ["pandas", "matplotlib"]
missing_modules = []

for mod in required_modules:
    try:
        __import__(mod)
    except ImportError:
        missing_modules.append(mod)

if missing_modules:
    print(f"Error: Missing required Python modules: {', '.join(missing_modules)}")
    print("Please install them, e.g.:")
    print(f"    python3 -m pip install {' '.join(missing_modules)}")
    sys.exit(1)

# Get log folder from command-line argument
if len(sys.argv) < 2:
    print("Usage: python3 compare_logs.py <log_folder>")
    sys.exit(1)

log_base_folder = os.path.expanduser(sys.argv[1])
if not os.path.isdir(log_base_folder):
    print(f"Error: '{log_base_folder}' is not a valid folder")
    sys.exit(1)

# Find all CSV files recursively (ignore summary CSVs)
csv_files = sorted(glob.glob(os.path.join(log_base_folder, "**/eden_*.csv"), recursive=True))
csv_files = [f for f in csv_files if not f.endswith("_summary.csv")]

if not csv_files:
    print(f"No CSV files found in {log_base_folder} or its subfolders")
    sys.exit(0)

# Prepare plotting
plt.figure(figsize=(14, 7))
colors = plt.colormaps['tab10']

stats = []

# Track which folders have CSVs
folders_with_csv = set()

for i, csv_file in enumerate(csv_files):
    folder = os.path.dirname(csv_file)
    folders_with_csv.add(folder)

    # Corresponding summary file
    summary_file = csv_file.replace(".csv", "_summary.csv")
    
    # Skip empty CSVs
    if os.path.getsize(csv_file) == 0:
        print(f"Skipping {csv_file}: file is empty")
        continue

    # Read main CSV (skip system info lines)
    df = pd.read_csv(csv_file, skiprows=2)
    df.columns = df.columns.str.strip()
    
    if 'fps' not in df.columns:
        print(f"Skipping {csv_file}: no 'fps' column found")
        continue

    y = df['fps']
    x = range(len(y))

    # Compute statistics from main CSV
    mean_fps = y.mean()
    min_fps = y.min()
    max_fps = y.max()

    # Read summary CSV if exists
    summary_text = ""
    if os.path.exists(summary_file):
        try:
            df_sum = pd.read_csv(summary_file)
            avg = float(df_sum['Average FPS'][0])
            p0_1 = float(df_sum['0.1% Min FPS'][0])
            p1 = float(df_sum['1% Min FPS'][0])
            p97 = float(df_sum['97% Percentile FPS'][0])
            summary_text = f" | summary avg={avg:.1f}, 0.1%={p0_1:.1f}, 1%={p1:.1f}, 97%={p97:.1f}"
        except Exception as e:
            print(f"Could not read summary for {summary_file}: {e}")

    stats.append((os.path.basename(csv_file), mean_fps, min_fps, max_fps, summary_text))

    # Plot FPS line with summary info
    plt.plot(x, y, label=f"{os.path.basename(csv_file)} (avg={mean_fps:.1f}){summary_text}", color=colors(i % 10))

# Configure plot
plt.xlabel('Frame')
plt.ylabel('FPS')
plt.title('FPS Comparison Across All Builds')
plt.legend()
plt.grid(True)
plt.tight_layout()

# Save plot
png_file = os.path.join(os.getcwd(), "fps_comparison_all_builds.png")
plt.savefig(png_file, dpi=200)
plt.show()

# Print statistics in terminal
print("\nFPS Summary by file:")
for name, mean_fps, min_fps, max_fps, summary_text in stats:
    print(f"{name}: mean={mean_fps:.1f}, min={min_fps:.1f}, max={max_fps:.1f}{summary_text}")

print("\n----------------------------")
print(f"Total CSV files processed: {len(stats)}")

# Track build folders (without timestamps)
build_folders = set()
for csv_file in csv_files:
    run_folder = os.path.dirname(csv_file)
    build_folder = os.path.dirname(run_folder)
    build_folders.add(build_folder)

print("\nBuild folders containing CSVs:")
for folder in sorted(build_folders):
    print(f" - {folder}")

print(f"Graph saved as: {png_file}")

