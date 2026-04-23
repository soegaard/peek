#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: capture-peek-window.sh INPUT [OUTPUT]

Open Terminal, run `peek` on INPUT, and capture a screenshot of the window.
If OUTPUT is omitted, the screenshot is written under assets/screenshots/.
EOF
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
input_path="$1"

if [[ ! -e "$input_path" ]]; then
  printf 'capture-peek-window.sh: missing input file: %s\n' "$input_path" >&2
  exit 1
fi

input_abs="$(cd -- "$(dirname -- "$input_path")" && pwd)/$(basename -- "$input_path")"

if [[ $# -eq 2 ]]; then
  output_path="$2"
else
  output_dir="$repo_root/assets/screenshots"
  mkdir -p "$output_dir"
  output_name="$(basename -- "$input_abs")"
  output_name="${output_name%.*}.png"
  output_path="$output_dir/$output_name"
fi

mkdir -p "$(dirname -- "$output_path")"

debug_log="${output_path%.png}.debug.log"
window_id=""
terminal_was_running=0
if pgrep -x Terminal >/dev/null 2>&1; then
  terminal_was_running=1
fi
cleanup_window() {
  if [[ -n "$window_id" ]]; then
    osascript -e "tell application \"Terminal\"
  try
    close (first window whose id is $window_id)
  end try
  if $terminal_was_running is 0 then
    quit
  end if
end tell" >/dev/null 2>&1 || true
  fi
}
trap cleanup_window EXIT

window_id="$(
  REPO_ROOT="$repo_root" INPUT_PATH="$input_abs" osascript <<'APPLESCRIPT'
tell application "Terminal"
  activate
  set peekCommand to "racket -l peek/main " & quoted form of (system attribute "INPUT_PATH")
  set previewCommand to "cd " & quoted form of (system attribute "REPO_ROOT") & " && printf '\\033[H\\033[2J\\033[3J' && sh -c " & quoted form of (peekCommand & " ; sleep 2 ; exec sleep 5")
  set previewTab to do script ""
  set previewWindow to missing value
  repeat with i from 1 to 100
    try
      set previewWindow to window of previewTab
      if previewWindow is not missing value then exit repeat
    end try
    delay 0.1
  end repeat
  if previewWindow is missing value then
    repeat with i from 1 to 50
      try
        set previewWindow to front window
        if previewWindow is not missing value then exit repeat
      end try
      delay 0.1
    end repeat
  end if
  if previewWindow is missing value then error "could not find preview window"
  set bounds of previewWindow to {120, 120, 640, 480}
  do script previewCommand in previewTab
  return id of previewWindow
end tell
APPLESCRIPT
)"

printf 'window_id=%s\n' "$window_id" > "$debug_log"
tmp_capture="${output_path%.png}.window.png"
screencapture -x -l "$window_id" "$tmp_capture"

image_size="$(identify -format '%w %h' "$tmp_capture")"
image_width="${image_size% *}"
image_height="${image_size#* }"
crop_top=78
crop_bottom=18
crop_height=$((image_height - crop_top - crop_bottom))

convert "$tmp_capture" \
  -crop "${image_width}x${crop_height}+0+${crop_top}" \
  +repage \
  "$output_path"

rm -f "$tmp_capture"

printf '%s\n' "$output_path"
