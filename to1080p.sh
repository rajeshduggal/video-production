#!/usr/bin/env bash
# to1080p.sh - scale a video to exactly 1920x1080 without distortion
# (letterboxes/pillarboxes with black bars if the aspect ratio differs)
#
# Usage:
#   ./to1080p.sh input.mp4 [output.mp4]
#
# Example:
#   ./to1080p.sh clip.mov
#   ./to1080p.sh clip.mov youtube_ready.mp4

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
  echo "Usage: $0 input [output]" >&2
  exit 1
fi

input="$1"

if [ ! -f "$input" ]; then
  echo "Error: input file '$input' not found" >&2
  exit 1
fi

# Default output name: <input-name>_1080p.mp4
base="${input%.*}"
output="${2:-${base}_1080p.mp4}"

ffmpeg -hide_banner -i "$input" \
  -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
  -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p \
  -c:a aac -b:a 192k \
  -movflags +faststart \
  "$output"

echo "Done: $output"