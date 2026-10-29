#!/bin/sh
# Behavioural test for gate/bin/deps-latest.sh — latest, or red.
#
# Lives OUTSIDE gate/ on purpose (see js-gate.test.sh). composer is stubbed: it records its
# arguments and answers the exit code the case scripts per pattern — this asserts what the tier
# ASKS composer and how it reads the answer, never what composer does with the network.
#
#   sh tests/deps-latest.test.sh
set -u

HERE=$(cd "$(dirname "$0")/.." && pwd)
SUT=$HERE/gate/bin/deps-latest.sh

PASS=0; FAIL=0

# fixture [no-lock] — a project root with the tier, a stub composer on PATH and a composer.lock.
fixture() {
  WORK=$(mktemp -d); SKIP=; LOG=$WORK/composer.log; : > "$LOG"
  mkdir -p "$WORK/bin" "$WORK/stub"
  [ -f "$SUT" ] && cp "$SUT" "$WORK/bin/deps-latest.sh"
  [ "${1:-}" = no-lock ] || : > "$WORK/composer.lock"
  cat > "$WORK/stub/composer" <<'STUB'
#!/bin/sh
echo "composer $*" >> "$LOG"
case "$*" in
  *roots/wordpress*) exit "${STUB_EXIT_WP:-0}" ;;
  *wp-phpunit/wp-phpunit*) exit "${STUB_EXIT_PHPUNIT:-0}" ;;
  *netdust/\**) exit "${STUB_EXIT_NETDUST:-0}" ;;
esac
exit 0
STUB
  chmod +x "$WORK/stub/composer"
}

# run [VAR=value ...] — the tier from the fixture root; a missing script is one FAIL per run.
run() {
  if [ ! -f "$SUT" ]; then
    FAIL=$((FAIL+1)); SKIP=1; RC=127
    printf '  FAIL run — gate/bin/deps-latest.sh does not exist\n'
    return
  fi
  ( cd "$WORK" && env PATH="$WORK/stub:$PATH" LOG="$LOG" "$@" sh bin/deps-latest.sh ) > "$WORK/out" 2> "$WORK/err"
  RC=$?
}

check() {
  [ -n "$SKIP" ] && return
  if [ "$2" = "$3" ]; then
    PASS=$((PASS+1)); printf '  ok   %s\n' "$1"
  else
    FAIL=$((FAIL+1)); printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$1" "$3" "$2"
  fi
}

has() { grep -q -- "$1" "$2" 2>/dev/null && echo yes || echo no; }

echo "deps-latest — everything at its newest tag"
fixture
run
check "exits 0" "$RC" "0"
check "says up to date" "$(has '^deps:latest: up to date$' "$WORK/out")" "yes"
check "asks composer for the lock view, three times" "$(grep -c 'outdated --locked --direct --strict' "$LOG")" "3"
check "the three patterns, in order" "$(sed 's/.* //' "$LOG" | paste -sd' ')" "roots/wordpress wp-phpunit/wp-phpunit netdust/*"
rm -rf "$WORK"

echo "deps-latest — WordPress behind its newest tag"
fixture
run STUB_EXIT_WP=1
check "exits 1" "$RC" "1"
check "names roots/wordpress on stderr" "$(has 'roots/wordpress' "$WORK/err")" "yes"
check "the fix moves the metapackage with its dependents" "$(has 'composer update roots/wordpress --with-dependencies' "$WORK/err")" "yes"
check "still asked about all three" "$(grep -c outdated "$LOG")" "3"
rm -rf "$WORK"

echo "deps-latest — a netdust neighbour behind, or unresolvable"
fixture
run STUB_EXIT_NETDUST=1
check "exits 1" "$RC" "1"
check "names netdust/*" "$(has 'netdust/\*' "$WORK/err")" "yes"
check "says it may be unresolvable" "$(has 'unresolvable' "$WORK/err")" "yes"
check "the fix line quotes the glob" "$(has "composer update 'netdust/\\*' --with-dependencies" "$WORK/err")" "yes"
rm -rf "$WORK"

echo "deps-latest — no composer.lock"
fixture no-lock
run
check "exits 1" "$RC" "1"
check "says there is no lock" "$(has '^deps:latest: no composer.lock' "$WORK/err")" "yes"
check "asked composer nothing" "$(wc -l < "$LOG" | tr -d ' ')" "0"
rm -rf "$WORK"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "deps-latest.test: $PASS ok, 0 failed"
else
  echo "deps-latest.test: $PASS ok, $FAIL failed"
fi
[ "$FAIL" -eq 0 ]
