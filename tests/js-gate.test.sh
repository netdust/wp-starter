#!/bin/sh
# Behavioural test for gate/bin/js-gate.sh.
#
# Lives OUTSIDE gate/ on purpose: gate/ is the payload copied into every
# project, and a project has no business carrying this repo's own tests.
# Run it by hand or through .github/workflows/ci.yml.
#
#   sh tests/js-gate.test.sh
#
# The script under test is written with {{GATE_CONTENT_DIR}} unrendered, so
# each case renders it into a throwaway copy the way scaffold_wp_starter would,
# and runs it against a fixture tree. npm is stubbed — this asserts which
# packages the gate DECIDES to run, never what npm does with them.
set -u

HERE=$(cd "$(dirname "$0")/.." && pwd)
SUT=$HERE/gate/bin/js-gate.sh
CONTENT=app/content          # the stackwp rendering; bedrock's web/app behaves identically

PASS=0; FAIL=0

# Build a project root in $WORK: a rendered js-gate.sh, a stub npm, the theme
# dirs named in $1 (space-separated, "" for none), and the marker when $2 is set.
fixture() {
  themes=$1; marker=${2:-}
  WORK=$(mktemp -d)
  mkdir -p "$WORK/bin" "$WORK/$CONTENT/themes" "$WORK/stub"
  sed "s|{{GATE_CONTENT_DIR}}|$CONTENT|g" "$SUT" > "$WORK/bin/js-gate.sh"
  # Stub npm: records its arguments instead of touching the network.
  printf '#!/bin/sh\necho "npm $*" >> "$NPM_LOG"\n' > "$WORK/stub/npm"
  chmod +x "$WORK/stub/npm"
  for t in $themes; do
    mkdir -p "$WORK/$CONTENT/themes/$t"
    printf '{"name":"%s","scripts":{"lint":"true"}}\n' "$t" > "$WORK/$CONTENT/themes/$t/package.json"
  done
  [ -n "$marker" ] && : > "$WORK/$marker"
  NPM_LOG=$WORK/npm.log; : > "$NPM_LOG"
}

# run <label-for-output> — executes the rendered gate from the fixture root.
run() {
  ( cd "$WORK" && PATH="$WORK/stub:$PATH" NPM_LOG="$NPM_LOG" sh bin/js-gate.sh lint:js 'run lint' ) \
    > "$WORK/out" 2> "$WORK/err"
  RC=$?
}

check() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$3" "$2"
  fi
}

echo "js-gate — no theme package.json, no marker"
fixture ""
run
check "exits 1" "$RC" "1"
check "says the gate did not run" "$(grep -c 'gate did not run' "$WORK/err")" "1"
check "ran no npm" "$(wc -l < "$WORK/npm.log" | tr -d ' ')" "0"
rm -rf "$WORK"

echo "js-gate — no theme package.json, .gate-no-theme-js declared"
fixture "" ".gate-no-theme-js"
run
check "exits 0" "$RC" "0"
check "ran no npm" "$(wc -l < "$WORK/npm.log" | tr -d ' ')" "0"
check "says WHY it skipped, on stdout" "$(grep -c 'gate-no-theme-js' "$WORK/out")" "1"
check "does not claim the gate failed" "$(grep -c 'gate did not run' "$WORK/err")" "0"
rm -rf "$WORK"

echo "js-gate — a theme package.json exists"
fixture "acme"
run
check "exits 0" "$RC" "0"
check "ran npm once" "$(wc -l < "$WORK/npm.log" | tr -d ' ')" "1"
check "ran it in the theme dir" "$(grep -c -- "--prefix $CONTENT/themes/acme" "$WORK/npm.log")" "1"
rm -rf "$WORK"

echo "js-gate — marker set but the theme tree is not there at all"
# The hole the marker opened: n==0 also means "the gate cannot see the themes",
# e.g. a mis-rendered {{GATE_CONTENT_DIR}} or a deleted content dir. Skipping
# then reports "no theme JS" about a tree nobody looked at.
fixture "" ".gate-no-theme-js"
rm -rf "$WORK/$CONTENT/themes"
run
check "refuses to skip" "$RC" "1"
check "names the missing directory" "$(grep -c 'does not exist' "$WORK/err")" "1"
check "ran no npm" "$(wc -l < "$WORK/npm.log" | tr -d ' ')" "0"
rm -rf "$WORK"

echo "js-gate — marker set, themes/ exists but is empty"
# The legitimate case the marker is FOR: the directory is there, it simply holds
# no theme of this project's own. Must still skip cleanly.
fixture "" ".gate-no-theme-js"
run
check "skips" "$RC" "0"
check "ran no npm" "$(wc -l < "$WORK/npm.log" | tr -d ' ')" "0"
rm -rf "$WORK"

echo "js-gate — a theme package.json exists AND the marker is present"
# The marker declares "this project has no theme JS". A theme that DOES carry a
# package.json contradicts it, and the real packages win: skipping them because
# a stale marker was left behind would silently drop the whole JS tier.
fixture "acme" ".gate-no-theme-js"
run
check "exits 0" "$RC" "0"
check "marker does not suppress a real package" "$(wc -l < "$WORK/npm.log" | tr -d ' ')" "1"
rm -rf "$WORK"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "js-gate.test: $PASS ok, 0 failed"
else
  echo "js-gate.test: $PASS ok, $FAIL failed"
fi
[ "$FAIL" -eq 0 ]
