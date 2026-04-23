#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: capture-peek-window.sh [--crop full|snippet] INPUT [OUTPUT]
       capture-peek-window.sh [--crop full|snippet] INPUT1 OUTPUT1 [INPUT2 OUTPUT2 ...]

Open Terminal, run `peek` on INPUT, and capture a screenshot of the window.
If OUTPUT is omitted, the screenshot is written under assets/screenshots/.
EOF
}

crop_profile="full"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --crop)
      if [[ $# -lt 2 ]]; then
        printf 'capture-peek-window.sh: missing value after --crop\n' >&2
        exit 1
      fi
      crop_profile="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    --*)
      printf 'capture-peek-window.sh: unknown option: %s\n' "$1" >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

case "$crop_profile" in
  full|snippet) ;;
  *)
    printf 'capture-peek-window.sh: unknown crop profile: %s\n' "$crop_profile" >&2
    exit 1
    ;;
esac

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $# -gt 2 ]] && (( $# % 2 != 0 )); then
  printf 'capture-peek-window.sh: expected input/output pairs\n' >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

inputs=()
outputs=()

if [[ $# -eq 1 ]]; then
  input_path="$1"
  if [[ ! -e "$input_path" ]]; then
    printf 'capture-peek-window.sh: missing input file: %s\n' "$input_path" >&2
    exit 1
  fi
  input_abs="$(cd -- "$(dirname -- "$input_path")" && pwd)/$(basename -- "$input_path")"
  output_dir="$repo_root/assets/screenshots"
  mkdir -p "$output_dir"
  output_name="$(basename -- "$input_abs")"
  output_name="${output_name%.*}.png"
  output_path="$output_dir/$output_name"
  inputs+=("$input_abs")
  outputs+=("$output_path")
else
  for (( i = 1; i <= $#; i += 2 )); do
    input_path="${!i}"
    j=$((i + 1))
    output_path="${!j}"
    if [[ ! -e "$input_path" ]]; then
      printf 'capture-peek-window.sh: missing input file: %s\n' "$input_path" >&2
      exit 1
    fi
    input_abs="$(cd -- "$(dirname -- "$input_path")" && pwd)/$(basename -- "$input_path")"
    mkdir -p "$(dirname -- "$output_path")"
    inputs+=("$input_abs")
    outputs+=("$output_path")
  done
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/peek-capture.XXXXXX")"
shell_pid_file="$work_dir/shell.pid"
ready_files=()
go_files=()
window_id=""
shell_pid=""
terminal_was_running=0
batch_command=""
window_left=120
window_top=120
window_right=860
window_bottom=620

for (( i = 0; i < ${#inputs[@]}; i++ )); do
  ready_files+=("$work_dir/ready-$i")
  go_files+=("$work_dir/go-$i")
done

case "$crop_profile" in
  full)
    window_right=860
    window_bottom=620
    ;;
  snippet)
    window_right=1080
    window_bottom=680
    ;;
esac

if pgrep -x Terminal >/dev/null 2>&1; then
  terminal_was_running=1
fi

cleanup_window() {
  for go_file in "${go_files[@]}"; do
    if [[ -n "$go_file" ]]; then
      touch "$go_file" >/dev/null 2>&1 || true
    fi
  done

  if [[ -n "$shell_pid" ]]; then
    for _ in $(seq 1 200); do
      if ! kill -0 "$shell_pid" >/dev/null 2>&1; then
        break
      fi
      sleep 0.05
    done
  fi

  if [[ -n "$window_id" ]]; then
    osascript -e "tell application \"Terminal\"
  try
    close (first window whose id is $window_id) saving no
  end try
  if $terminal_was_running is 0 then
    quit saving no
  end if
end tell" >/dev/null 2>&1 || true
  fi

  rm -rf "$work_dir" >/dev/null 2>&1 || true
}
trap cleanup_window EXIT

window_id="$(
  batch_parts=("bash" "$script_dir/capture-peek-batch.sh" "$shell_pid_file" "$repo_root")
  for (( i = 0; i < ${#inputs[@]}; i++ )); do
    batch_parts+=("${inputs[i]}" "${ready_files[i]}" "${go_files[i]}")
  done
  printf -v batch_command '%q ' "${batch_parts[@]}"
  BATCH_COMMAND="$batch_command" \
  WINDOW_LEFT="$window_left" \
  WINDOW_TOP="$window_top" \
  WINDOW_RIGHT="$window_right" \
  WINDOW_BOTTOM="$window_bottom" \
  osascript <<'APPLESCRIPT'
tell application "Terminal"
  activate
  set previewTab to do script (system attribute "BATCH_COMMAND")
  set previewWindow to missing value
  repeat with i from 1 to 40
    try
      set previewWindow to front window
      if previewWindow is not missing value then exit repeat
    end try
    delay 0.05
  end repeat
  if previewWindow is missing value then error "could not find preview window"
  set bounds of previewWindow to {(system attribute "WINDOW_LEFT") as integer, (system attribute "WINDOW_TOP") as integer, (system attribute "WINDOW_RIGHT") as integer, (system attribute "WINDOW_BOTTOM") as integer}
  return id of previewWindow
end tell
APPLESCRIPT
)"

for _ in $(seq 1 200); do
  if [[ -s "$shell_pid_file" ]]; then
    shell_pid="$(cat "$shell_pid_file")"
    break
  fi
  sleep 0.05
done

if [[ -z "$shell_pid" ]]; then
  printf 'capture-peek-window.sh: could not find shell pid\n' >&2
  exit 1
fi

capture_one() {
  local input_abs="$1"
  local output_path="$2"
  local ready_file="$3"
  local go_file="$4"
  local tmp_capture="${output_path%.png}.window.png"
  local debug_log="${output_path%.png}.debug.log"
  local image_size
  local image_width
  local image_height
  local crop_top
  local crop_bottom
  local crop_height

  for _ in $(seq 1 200); do
    if [[ -e "$ready_file" ]]; then
      break
    fi
    sleep 0.05
  done

  if [[ ! -e "$ready_file" ]]; then
    printf 'capture-peek-window.sh: preview did not become ready for %s\n' "$input_abs" >&2
    exit 1
  fi

  printf 'window_id=%s\n' "$window_id" > "$debug_log"
  screencapture -x -l "$window_id" "$tmp_capture"

  image_size="$(identify -format '%w %h' "$tmp_capture")"
  image_width="${image_size% *}"
  image_height="${image_size#* }"

  case "$crop_profile" in
    full)
      crop_top=34
      crop_bottom=18
      ;;
    snippet)
      crop_top=78
      crop_bottom=18
      ;;
  esac

  crop_height=$((image_height - crop_top - crop_bottom))

  convert "$tmp_capture" \
    -crop "${image_width}x${crop_height}+0+${crop_top}" \
    +repage \
    "$output_path"

  rm -f "$tmp_capture"
  rm -f "$ready_file"
  : > "$go_file"

  printf '%s\n' "$output_path"
}

for (( i = 0; i < ${#inputs[@]}; i++ )); do
  capture_one "${inputs[i]}" "${outputs[i]}" "${ready_files[i]}" "${go_files[i]}"
done
