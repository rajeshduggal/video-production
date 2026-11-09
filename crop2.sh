#!/usr/bin/env bash
# crop2.sh - extract two rectangular regions of a video into two files
#
# Usage:
#   ./crop2.sh input.mp4 W1:H1:X1:Y1 W2:H2:X2:Y2 [output1] [output2]
#
# Example:
#   ./crop2.sh input.mp4 640:360:100:50 800:600:1000:400
#   ./crop2.sh input.mp4 640:360:100:50 800:600:1000:400 left.mp4 right.mp4

set -euo pipefail

if [ "$#" -lt 1 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 input W1:H1:X1:Y1 W2:H2:X2:Y2 [output1] [output2]" >&2
  exit 1
fi

input="$1"
rect1="${2:-1440:900:0:90}"
rect2="${3:-480:270:1442:406}"

if [ ! -f "$input" ]; then
  echo "Error: input file '$input' not found" >&2
  exit 1
fi

# Validate rectangle format: four integers separated by colons
re='^[0-9]+:[0-9]+:[0-9]+:[0-9]+$'
for r in "$rect1" "$rect2"; do
  if ! [[ "$r" =~ $re ]]; then
    echo "Error: '$r' is not in W:H:X:Y format (e.g. 640:360:100:50)" >&2
    exit 1
  fi
done

# Default output names: <input-name>_crop1.<ext>, <input-name>_crop2.<ext>
base="${input%.*}"
ext="${input##*.}"
out1="${4:-${base}_crop1.${ext}}"
out2="${5:-${base}_crop2.${ext}}"

ffmpeg -hide_banner -i "$input" -filter_complex \
  "[0:v]split=2[a][b]; \
   [a]crop=${rect1}[out1]; \
   [b]crop=${rect2}[out2]" \
  -map "[out1]" -map 0:a? -c:a copy "$out1" \
  -map "[out2]" -map 0:a? -c:a copy "$out2"

echo "Done: $out1, $out2"
