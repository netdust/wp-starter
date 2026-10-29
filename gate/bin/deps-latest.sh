#!/bin/sh
# deps:latest — latest, or red. Reads the lock: red when roots/wordpress, wp-phpunit/wp-phpunit
# or any netdust/* dependency is behind its newest tag, or cannot be resolved; it fixes nothing
# (the gate rewrites no tree). Host-side like analyse: composer reaches packagist and the private
# netdust repos through the host's SSH key. Called by bin/gate.sh — no composer script mirrors it.
set -u

[ -f composer.lock ] || { echo "deps:latest: no composer.lock — the gate reads the lock; commit one" >&2; exit 1; }

behind=""; fix=""
for p in roots/wordpress wp-phpunit/wp-phpunit 'netdust/*'; do
  if ! composer outdated --locked --direct --strict --no-interaction "$p"; then
    behind="$behind $p"
    case $p in *\**) fix="$fix '$p'" ;; *) fix="$fix $p" ;; esac
  fi
done

if [ -n "$behind" ]; then
  echo "deps:latest: behind the newest tag, or unresolvable (no network, no SSH agent):$behind — fix: composer update$fix --with-dependencies and commit the lock; a version outside the constraint (Composer's ~) needs the constraint widened first" >&2
  exit 1
fi
echo "deps:latest: up to date"
