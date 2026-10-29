#!/bin/sh
# Gate umbrella (FR-12): run all quality tiers cheapest-first, fail-fast.
# Locked order (decision 11): lint -> lint:js -> analyse -> audit:deps ->
#   test:unit -> gate:package -> test:js -> build:check -> deps:latest -> test:int -> test:e2e
#
# HOST-INVOKED by design (decision 7 topology): test:e2e can only run on the
# host (Playwright browsers + bin/e2e.sh), test:int can only run in-container
# (wp-tests-config resolves DB host `db`). So the umbrella orchestrates from
# the host and hops into the container for test:int only.
#
# Fail-fast contract: the first non-zero tier stops the run, the failure names
# the tier on stderr, and the tier's REAL exit code is propagated.
set -u

TIERS="lint lint:js analyse audit:deps test:unit gate:package test:js build:check deps:latest test:int test:e2e"

for tier in $TIERS; do
  echo "== gate: $tier =="
  case $tier in
    test:int)
      # In-container tier: wp-tests-config needs the container network's `db` host.
      ddev composer run-script test:int; code=$? ;;
    deps:latest)
      # Host-side and no composer script: a stack template's manifest never has to know it.
      sh bin/deps-latest.sh; code=$? ;;
    gate:package)
      # A package's own checks, kept from its former `gate` script; a site never declares it.
      if composer run-script --list 2>/dev/null | grep -qE '^ *gate:package( |$)'; then
        composer run-script gate:package; code=$?
      else
        echo "gate:package: none declared — skipped"; code=0
      fi ;;
    *)
      composer run-script "$tier"; code=$? ;;
  esac
  if [ "$code" -ne 0 ]; then
    echo "gate: FAILED at tier $tier (exit $code)" >&2
    exit "$code"
  fi
done

echo "gate: all tiers green"
