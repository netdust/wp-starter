#!/bin/sh
# Behavioural test for bin/package-gate.sh — the renderer of the gate's package shape.
#
# Lives OUTSIDE gate/ and package-gate/ on purpose: both are payload, and a package has no
# business carrying this repo's own tests. Run it by hand or through .github/workflows/ci.yml.
#
#   sh tests/package-gate.test.sh
#
# Each case builds a throwaway wordpress-muplugin package, renders the shape onto it with the
# real jq, and asserts what landed — and, for every refusal, that nothing did.
set -u

HERE=$(cd "$(dirname "$0")/.." && pwd)
SUT=$HERE/bin/package-gate.sh

PASS=0; FAIL=0

# fixture <name> [requires-core] [requires-core-dev] [own-gate] [lock-ignored] [repos-object] — a
# minimal package at $PKG, a git checkout (so check-ignore works), snapshotted for `written`.
fixture() {
  name=$1; shift
  WORK=$(mktemp -d); PKG=$WORK/pkg; SKIP=
  mkdir -p "$PKG/tests"
  printf '{"name":"netdust/%s","type":"wordpress-muplugin","require-dev":{"phpunit/phpunit":"^10.5"},"scripts":{"test":"phpunit"}}\n' "$name" > "$PKG/composer.json"
  printf '<?php\n' > "$PKG/$name.php"
  printf 'vendor/\n' > "$PKG/.gitignore"
  printf 'tests/ export-ignore\n' > "$PKG/.gitattributes"
  printf '<?php\n' > "$PKG/tests/bootstrap.php"
  for opt in "$@"; do
    case $opt in
      requires-core) edit '.require."netdust/ntdst-core" = "^5.4"' ;;
      requires-core-dev) edit '."require-dev"."netdust/ntdst-core" = "*"' ;;
      repos-object) edit '.repositories = {"wpackagist": {"type": "composer", "url": "https://wpackagist.org"}}' ;;
      own-gate) edit '.scripts.gate = ["@syntax","@test"] | .scripts.lint = "php -l"' ;;
      lock-ignored) printf 'composer.lock\n' >> "$PKG/.gitignore" ;;
    esac
  done
  git -C "$PKG" init -q
  stamp
}

# edit <jq filter> — rewrites the fixture's composer.json in place.
edit() {
  jq "$1" "$PKG/composer.json" > "$PKG/composer.json.new" && mv "$PKG/composer.json.new" "$PKG/composer.json"
}

# stamp / written — a checksum of every file under the package (.git excluded) before a run;
# `written` prints nothing when the tree is unchanged, so no mtime assumption is made.
tree_sum() { find "$PKG" -path "$PKG/.git" -prune -o -type f -exec cksum {} + | sort | cksum; }
stamp() { BEFORE=$(tree_sum); }
written() { [ "$(tree_sum)" = "$BEFORE" ] || echo "tree changed"; }

# run <package-root> — the renderer from a neutral cwd, stdout/stderr captured. A missing
# renderer is one FAIL per run and the run's checks are skipped.
run() {
  if [ ! -f "$SUT" ]; then
    FAIL=$((FAIL+1)); SKIP=1; RC=127
    printf '  FAIL %s — bin/package-gate.sh does not exist\n' "$1"
    return
  fi
  ( cd "$WORK" && bash "$SUT" "$@" ) > "$WORK/out" 2> "$WORK/err"
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

has() { grep -q -- "$1" "$2" 2>/dev/null && echo yes || echo no; }      # <pattern> <file>
exists() { [ -e "$PKG/$1" ] && echo yes || echo no; }
same() { cmp -s "$1" "$2" && echo same || echo differs; }
jqv() { jq -c "$1" "$PKG/composer.json"; }

echo "package-gate — refuses a directory without composer.json, writes nothing"
fixture acme; rm "$PKG/composer.json"; stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "names composer.json" "$(has 'composer.json' "$WORK/err")" "yes"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — refuses a type other than wordpress-muplugin"
fixture acme; edit '.type = "project"'; stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "names the type" "$(has 'wordpress-muplugin' "$WORK/err")" "yes"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — refuses a package without <name>.php at its root"
fixture acme; rm "$PKG/acme.php"; stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "names the file" "$(has 'acme.php' "$WORK/err")" "yes"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — refuses a site's installed copy under web/app/mu-plugins"
fixture acme
mkdir -p "$WORK/web/app/mu-plugins" && mv "$PKG" "$WORK/web/app/mu-plugins/acme" && PKG=$WORK/web/app/mu-plugins/acme
stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "says why" "$(has 'installed copy' "$WORK/err")" "yes"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — refuses a site's installed copy under app/content/mu-plugins (stackwp)"
fixture acme
mkdir -p "$WORK/app/content/mu-plugins" && mv "$PKG" "$WORK/app/content/mu-plugins/acme" && PKG=$WORK/app/content/mu-plugins/acme
stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "says why" "$(has 'installed copy' "$WORK/err")" "yes"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — refuses a composer.json whose repositories is an object, writes nothing"
fixture acme repos-object; stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "names repositories" "$(has 'repositories' "$WORK/err")" "yes"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — refuses a conflicting bin/gate.sh and writes nothing"
fixture acme; mkdir -p "$PKG/bin"; printf 'echo mine\n' > "$PKG/bin/gate.sh"; stamp
run "$PKG"
check "exits 64" "$RC" "64"
check "lists bin/gate.sh" "$(has 'bin/gate.sh' "$WORK/err")" "yes"
check "no other shape file landed" "$(exists tests/bootstrap-integration.php)" "no"
check "wrote nothing" "$(written)" ""
rm -rf "$WORK"

echo "package-gate — keeps the package's own phpcs.xml"
fixture acme; printf '<?xml version="1.0"?><ruleset name="mine"/>\n' > "$PKG/phpcs.xml"; cp "$PKG/phpcs.xml" "$WORK/phpcs.before"; stamp
run "$PKG"
check "exits 0" "$RC" "0"
check "phpcs.xml is byte-identical" "$(same "$PKG/phpcs.xml" "$WORK/phpcs.before")" "same"
check "says kept: phpcs.xml" "$(has '^kept: phpcs.xml$' "$WORK/out")" "yes"
check "no export-ignore line for the kept file" "$(has '^/phpcs.xml export-ignore$' "$PKG/.gitattributes")" "no"
check "the fallback phpstan.neon still landed" "$(exists phpstan.neon)" "yes"
rm -rf "$WORK"

echo "package-gate — renders the shape onto a package"
fixture acme
run "$PKG"
check "exits 0" "$RC" "0"
for f in bin/gate.sh bin/e2e.sh bin/js-gate.sh bin/lint-tokens.sh bin/deps-latest.sh \
         tests/bootstrap-integration.php tests/wp-tests-config.php tests/bootstrap-site.php \
         tests/Integration/LoaderTest.php tests/E2E/smoke.spec.ts \
         phpunit.unit.xml phpunit.integration.xml phpcs.xml phpstan.neon playwright.config.ts package.json \
         .ddev/config.yaml .ddev/config.gates.yaml .ddev/config.package.yaml .ddev/commands/host/gate \
         config/application.php web/wp-config.php web/index.php web/app/mu-plugins/acmeloader.php \
         wp-cli.yml .gate-no-theme-js README-testing.md .phpstan-cache/.gitignore; do
  check "has $f" "$(exists "$f")" "yes"
done
for f in tests/Unit tests/bootstrap-unit.php tests/Integration/DataLayerRoundTripTest.php \
         'web/app/mu-plugins/{{PACKAGE}}loader.php' web/app/mu-plugins/ntdst-coreloader.php \
         composer.gate.json .gitignore.gate .gitattributes.gate; do
  check "lacks $f" "$(exists "$f")" "no"
done
check "no token survives (fragments rendered too)" "$(grep -rlE '\{\{(GATE_WP_DIR|GATE_CONTENT_DIR|PACKAGE)\}\}' "$PKG" --exclude-dir=.git | sed "s|^$PKG/||" | paste -sd' ')" ""
check "bin/gate.sh is executable" "$([ -x "$PKG/bin/gate.sh" ] && echo yes || echo no)" "yes"
check "the DDEV project is named after the package" "$(has '^name: acme$' "$PKG/.ddev/config.yaml")" "yes"
check "wp-cli.yml points at web/wp" "$(has '^path: web/wp$' "$PKG/wp-cli.yml")" "yes"
check "the shim requires the root acme.php" "$(has "/acme.php'" "$PKG/web/app/mu-plugins/acmeloader.php")" "yes"
check "no lock note when the lock is not ignored" "$(has 'composer.lock is gitignored' "$WORK/out")" "no"
check "next steps, in order" "$(grep -o '^next: .*' "$WORK/out" | paste -sd'|')" "next: composer install|next: npm install|next: ddev start|next: composer gate"

echo "package-gate — merges the composer fragment: package wins, gate keys are the shape's"
check "phpunit pin kept" "$(jqv '."require-dev"."phpunit/phpunit"')" '"^10.5"'
check "roots/wordpress added at *" "$(jqv '."require-dev"."roots/wordpress"')" '"*"'
check "package key order first" "$(jqv '."require-dev" | keys_unsorted[0]')" '"phpunit/phpunit"'
check "scripts.test kept" "$(jqv '.scripts.test')" '"phpunit"'
check "scripts.gate is the shape's" "$(jqv '.scripts.gate')" '"sh bin/gate.sh"'
check "no gate:package without a former gate" "$(jqv '.scripts | has("gate:package")')" "false"
check "wordpress-install-dir rendered" "$(jqv '.extra."wordpress-install-dir"')" '"web/wp"'
check "installer-paths rendered, mu-plugins first" "$(jqv '.extra."installer-paths" | keys_unsorted[0]')" '"web/app/mu-plugins/{$name}/"'
check "one wpackagist repository" "$(jqv '.repositories | length')" "1"
check "composer.json is 4-space indented" "$(sed -n '2p' "$PKG/composer.json" | cut -c1-4)" "    "
check ".gitignore keeps its own line first" "$(sed -n '1p' "$PKG/.gitignore")" "vendor/"
check ".gitignore gained the rendered /web/wp" "$(grep -c '^/web/wp$' "$PKG/.gitignore")" "1"
check ".gitignore ends with the last gate line" "$(tail -n1 "$PKG/.gitignore")" "/.ddev/config.local.yaml"
check ".gitattributes keeps its own line first" "$(sed -n '1p' "$PKG/.gitattributes")" "tests/ export-ignore"
for p in /web /config /.ddev /bin/gate.sh /bin/e2e.sh /bin/js-gate.sh /bin/lint-tokens.sh /bin/deps-latest.sh /package.json \
         /package-lock.json /playwright.config.ts /tsconfig.json /phpunit.unit.xml /phpunit.integration.xml \
         /phpstan.neon /phpcs.xml /wp-cli.yml /.gate-no-theme-js /README-testing.md /.phpstan-cache; do
  check ".gitattributes export-ignores $p" "$(has "^$p export-ignore$" "$PKG/.gitattributes")" "yes"
done
rm -rf "$WORK"

echo "package-gate — a former gate script survives as gate:package; the tiers take the shape's values"
fixture acme own-gate
run "$PKG"
check "exits 0" "$RC" "0"
check "scripts.gate is the shape's" "$(jqv '.scripts.gate')" '"sh bin/gate.sh"'
check "the former gate is kept as gate:package" "$(jqv '.scripts."gate:package"')" '["@syntax","@test"]'
check "lint takes the shape's value" "$(jqv '.scripts.lint')" '"phpcs"'
check "test is kept" "$(jqv '.scripts.test')" '"phpunit"'

echo "package-gate — a second run on the same package changes nothing"
cp "$PKG/composer.json" "$WORK/composer.first"
run "$PKG"
check "second run exits 0" "$RC" "0"
check "composer.json is byte-identical" "$(same "$PKG/composer.json" "$WORK/composer.first")" "same"
check "gate:package is not re-wrapped" "$(jqv '.scripts."gate:package"')" '["@syntax","@test"]'
check ".gitignore has each gate line once" "$(grep -c '^/vendor$' "$PKG/.gitignore")" "1"
check ".gitattributes has each line once" "$(grep -c '^/web export-ignore$' "$PKG/.gitattributes")" "1"
check "no conflict reported" "$(has 'conflict' "$WORK/err")" "no"
rm -rf "$WORK"

echo "package-gate — a package requiring ntdst-core gets the core loader shim; require is untouched"
fixture acme requires-core
run "$PKG"
check "exits 0" "$RC" "0"
check "ntdst-coreloader.php landed" "$(exists web/app/mu-plugins/ntdst-coreloader.php)" "yes"
check "it is wp-starter's shim, verbatim" "$(same "$PKG/web/app/mu-plugins/ntdst-coreloader.php" "$HERE/mu-plugins/ntdst-coreloader.php")" "same"
check "require is untouched" "$(jqv '.require')" '{"netdust/ntdst-core":"^5.4"}'
rm -rf "$WORK"

echo "package-gate — a package requiring ntdst-core in require-dev gets the core loader shim too"
fixture acme requires-core-dev
run "$PKG"
check "exits 0" "$RC" "0"
check "ntdst-coreloader.php landed" "$(exists web/app/mu-plugins/ntdst-coreloader.php)" "yes"
check "the neighbour stays where it was declared" "$(jqv '."require-dev"."netdust/ntdst-core"')" '"*"'
rm -rf "$WORK"

echo "package-gate — says so when composer.lock is gitignored"
fixture acme lock-ignored
run "$PKG"
check "exits 0" "$RC" "0"
check "notes the ignored lock" "$(has 'composer.lock is gitignored' "$WORK/out")" "yes"
rm -rf "$WORK"

echo
if [ "$FAIL" -eq 0 ]; then
  echo "package-gate.test: $PASS ok, 0 failed"
else
  echo "package-gate.test: $PASS ok, $FAIL failed"
fi
[ "$FAIL" -eq 0 ]
