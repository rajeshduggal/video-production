#!/usr/bin/env bash
#
# vfrcheck.sh - Detect whether a video has constant or variable frame rate.
# Usage: ./vfrcheck.sh <video-file>

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <video-file>" >&2
    exit 1
fi

file="$1"

if [[ ! -f "$file" ]]; then
    echo "Error: file not found: $file" >&2
    exit 1
fi

for cmd in ffmpeg ffprobe; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Error: $cmd is not installed" >&2; exit 1; }
done

# Run vfrdet over the first video stream. It prints a summary line like:
#   [Parsed_vfrdet_0 @ 0x...] VFR:0.000000 (0/1234)
output=$(ffmpeg -hide_banner -nostats -i "$file" -map 0:v:0 -vf vfrdet -an -f null - 2>&1 || true)

line=$(grep -o 'VFR:[0-9.]* ([0-9]*/[0-9]*)' <<< "$output" | tail -n 1)

if [[ -z "$line" ]]; then
    echo "Error: could not get vfrdet result (is this a valid video file?)" >&2
    exit 1
fi

vfr_ratio=$(sed -E 's/VFR:([0-9.]+).*/\1/' <<< "$line")

# vfrdet reports the fraction of frames with differing durations.
# 0.000000 means every frame has the same duration -> constant frame rate.
if awk -v r="$vfr_ratio" 'BEGIN { exit !(r == 0) }'; then
    # Use avg_frame_rate for display (e.g. 30000/1001), converted to decimal
    rate=$(ffprobe -v error -select_streams v:0 \
        -show_entries stream=avg_frame_rate \
        -of default=noprint_wrappers=1:nokey=1 "$file")

    decimal=$(awk -F/ '{ if ($2 > 0) printf "%.3f", $1 / $2; else print $1 }' <<< "$rate")

    echo "Constant frame rate: ${decimal} fps (${rate})"
else
    echo "Variable frame rate (vfrdet: ${line})"
fi