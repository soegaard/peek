#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
usage: capture-peek-batch.sh SHELL_PID_FILE REPO_ROOT INPUT1 READY1 GO1 [INPUT2 READY2 GO2 ...]

Run a batch of peek commands in the current Terminal tab.
For each input, the script writes the shell PID, renders the file, signals
readiness by creating READY, and then waits for GO before continuing.
EOF
}

if [[ $# -lt 5 ]] || (( ( $# - 2 ) % 3 != 0 )); then
  usage >&2
  exit 1
fi

shell_pid_file="$1"
repo_root="$2"
shift 2

printf '%s\n' "$$" > "$shell_pid_file"

cd "$repo_root"

while [[ $# -gt 0 ]]; do
  input_path="$1"
  ready_file="$2"
  go_file="$3"
  shift 3

  printf '\033[H\033[2J\033[3J'
  if [[ "$input_path" == *.peekcmd ]]; then
    bash "$input_path"
  else
    racket -l peek/main "$input_path"
  fi
  : > "$ready_file"

  while [[ ! -e "$go_file" ]]; do
    read -r -t 0.05 -n 0 _ || true
  done

  rm -f "$go_file" "$ready_file"
done
