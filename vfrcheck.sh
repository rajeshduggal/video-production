#!/usr/bin/env bash
# vfrcheck.sh - report whether videos have a variable or constant frame rate
# Accepts files and/or directories. Directories are searched recursively
# for .mp4, .avi and .mov files (case-insensitive).
set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: ${0##*/} <file-or-directory> [file-or-directory ...]" >&2
  exit 1
fi

command -v ffmpeg >/dev/null || { echo "Error: ffmpeg is not installed" >&2; exit 1; }

# Returns 0 = constant, 2 = variable, 1 = error
check_file() {
  local file=$1 output vfr fps

  if [[ ! -f $file ]]; then
    echo "$file: Error: file not found" >&2
    return 1
  fi

  # Decode the first video stream through the vfrdet filter; results go to stderr
  if ! output=$(ffmpeg -nostdin -hide_banner -nostats -i "$file" -map 0:v:0 -vf vfrdet -an -f null - 2>&1); then
    echo "$file: Error: ffmpeg could not process file (no video stream?)" >&2
    return 1
  fi

  vfr=$(grep -oE 'VFR:[0-9.]+' <<<"$output" | tail -1 | cut -d: -f2 || true)
  fps=$(grep -oE '[0-9.]+ fps' <<<"$output" | head -1 | awk '{print $1}' || true)

  if [[ -z $vfr ]]; then
    echo "$file: Error: could not determine frame rate mode" >&2
    return 1
  fi

  if awk -v v="$vfr" 'BEGIN { exit !(v + 0 == 0) }'; then
    echo "$file: Constant frame rate: ${fps:-unknown} fps"
    return 0
  else
    echo "$file: Variable frame rate (VFR score: $vfr)"
    return 2
  fi
}

had_error=0
had_vfr=0

# Runs the check on one file and records the result for the final exit code
run_check() {
  local rc=0
  check_file "$1" || rc=$?
  case $rc in
    1) had_error=1 ;;
    2) had_vfr=1 ;;
  esac
}

for arg in "$@"; do
  if [[ -d $arg ]]; then
    found=0
    # NUL-delimited so filenames with spaces or newlines are handled safely
    while IFS= read -r -d '' f; do
      found=1
      run_check "$f"
    done < <(find "$arg" -type f \( -iname '*.mp4' -o -iname '*.avi' -o -iname '*.mov' \) -print0 | sort -z)

    if (( ! found )); then
      echo "$arg: No mp4, avi or mov files found" >&2
    fi
  else
    run_check "$arg"
  fi
done

# Exit status: 1 if any file errored, else 2 if any file was VFR, else 0
(( had_error )) && exit 1
(( had_vfr )) && exit 2
exit 0