#!/bin/sh
# Run npm commands in every non-vendored theme package.
# Usage: js-gate.sh <label> <npm-args>...   e.g.  js-gate.sh lint:js "run lint" "run lint:css"
set -eu
label=$1; shift
n=0
for f in {{GATE_CONTENT_DIR}}/themes/*/package.json; do
  [ -f "$f" ] || continue
  d=${f%/package.json}
  [ "$d" = {{GATE_CONTENT_DIR}}/themes/twentytwentyfive ] && continue
  for cmd in "$@"; do
    # shellcheck disable=SC2086 -- word-splitting IS the argument format
    npm $cmd --prefix "$d"
  done
  n=$((n+1))
done
if [ "$n" -eq 0 ]; then
  # Zero packages normally means the gate silently did nothing — the failure
  # this guard exists to catch. But a project can legitimately have no theme of
  # its own (YOOtheme, a page builder, a headless front end), and then there is
  # no theme JS to gate. That has to be DECLARED: the marker is a deliberate
  # act, so a project that merely lost its theme dir still goes red.
  if [ -f .gate-no-theme-js ]; then
    echo "$label: skipped — this project declares no theme JS (.gate-no-theme-js)"
    exit 0
  fi
  echo "$label: no theme package.json found — gate did not run" >&2
  exit 1
fi
echo "$label: ran $n package(s)"
