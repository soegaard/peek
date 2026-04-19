#!/usr/bin/env bash

# Small bash sample.
export PATH
echo "$PATH"
printf "%s\n" "$(pwd)"
if [ -n "$PATH" ]; then
  echo "ok"
fi
