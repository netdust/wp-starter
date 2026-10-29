#!/bin/sh
# Behavioural test for gate/bin/gate.sh — the tier order, fail-fast, and the two tiers that
# are not composer scripts: deps:latest (sh bin/deps-latest.sh) and the optional gate:package.
#
# Lives OUTSIDE gate/ on purpose (see js-gate.test.sh). composer, ddev and bin/deps-latest.sh
# are stubs that log what the gate dispatched and exit as the case scripts.
#
#   sh tests/gate-tiers.test.sh
set -u

HERE=$(cd "$(dirname "$0")/.." && pwd)
SUT=$HERE/gate/bin/gate.sh

PASS=0; FAIL=0

# fixture <scripts> — a project root with bin/gate.sh, a stub bin/deps-latest.sh and stub
# composer + ddev on PATH; <scripts> is what `composer run-script --list` will name.
fixture() {
  WORK=$(mktemp -d); LOG=$WORK/gate.log; : > "$LOG"
  mkdir -p "$WORK/bin" "$WORK/stub"
  cp "$SUT" "$WORK/bin/gate.sh"
  printf '#!/bin/sh\necho deps-latest >> "$LOG"\nexit "${STUB_DEPS:-0}"\n' > "$WORK/bin/deps-latest.sh"
  cat > "$WORK/stub/composer" <<'STUB'
#!/bin/sh
[ "$1" = run-script ] || exit 0
if [ "$2" = --list ]; then
  for s in $STUB_SCRIPTS; do printf '  %s  Runs the %s script\n' "$s" "$s"; done
  exit 0
fi
echo "$2" >> "$LOG"
[ "$2" = "${STUB_FAIL_AT:-}" ] && exit "${STUB_FAIL_CODE:-1}"
exit 0
STUB
  printf '#!/bin/sh\n[ "$1 $2" = "composer run-script" ] && echo "$3" >> "$LOG"\nexit 0\n' > "$WORK/stub/ddev"
  chmod +x "$WORK/stub/composer" "$WORK/stub/ddev"
  SCRIPTS=$1
}

# run [VAR=value ...] — the gate from the fixture root.
run() {
  ( cd "$WORK" && env PATH="$WORK/stub:$PATH" LOG="$LOG" STUB_SCRIPTS="$SCRIPTS" "$@" sh bin/gate.sh ) > "$WORK/out" 2> "$WORK/err"
  RC=$?
}

check() {
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$3" "$2"
  fi
}

has() { grep -q -- "$1" "$2" 2>/dev/null && echo yes || echo no; }
dispatched() { paste -sd' ' "$LOG"; }

SITE="lint lint:js analyse audit:deps test:unit test:js build:check test:int test:e2e gate"

echo "gate-tiers — a site: every tier green, no gate:package declared"
fixture "$SITE"
run
check "exits 0" "$RC" "0"
check "dispatches the eleven tiers in the locked order" "$(dispatched)" "lint lint:js analyse audit:deps test:unit test:js build:check deps-latest test:int test:e2e"
check "says gate:package was skipped, and why" "$(has '^gate:package: none declared — skipped$' "$WORK/out")" "yes"
check "ends green" "$(tail -n1 "$WORK/out")" "gate: all tiers green"
rm -rf "$WORK"

echo "gate-tiers — a package declaring gate:package"
fixture "$SITE gate:package"
run
check "exits 0" "$RC" "0"
check "runs gate:package right after test:unit" "$(dispatched)" "lint lint:js analyse audit:deps test:unit gate:package test:js build:check deps-latest test:int test:e2e"
check "does not say it skipped" "$(has 'skipped' "$WORK/out")" "no"
rm -rf "$WORK"

echo "gate-tiers — deps:latest red stops the gate before the integration tier"
fixture "$SITE"
run STUB_DEPS=1
check "exits 1" "$RC" "1"
check "names the tier on stderr" "$(has '^gate: FAILED at tier deps:latest (exit 1)$' "$WORK/err")" "yes"
check "never reaches test:int" "$(has 'test:int' "$LOG")" "no"
rm -rf "$WORK"

echo "gate-tiers — a red composer tier propagates its own exit code"
fixture "$SITE"
run STUB_FAIL_AT=analyse STUB_FAIL_CODE=3
check "exits 3" "$RC" "3"
check "names the tier on stderr" "$(has '^gate: FAILED at tier analyse (exit 3)$' "$WORK/err")" "yes"
check "nothing after analyse" "$(dispatched)" "lint lint:js analyse"
rm -rf "$WORK"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "gate-tiers.test: $PASS ok, 0 failed"
else
  echo "gate-tiers.test: $PASS ok, $FAIL failed"
fi
[ "$FAIL" -eq 0 ]
