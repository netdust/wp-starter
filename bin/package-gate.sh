#!/usr/bin/env bash
# bin/package-gate.sh — render the gate's package shape onto a wordpress-muplugin package.
#
#   bash <wp-starter>/bin/package-gate.sh <package-root>
#
# The shape is gate/ minus its site-only entries plus the package-gate/ overlay, rendered with
# {{GATE_WP_DIR}} → web/wp, {{GATE_CONTENT_DIR}} → web/app and {{PACKAGE}} → the composer name
# after the slash. A package keeps its own phpcs.xml and phpstan.neon when it has them, and its
# former `gate` script survives as `gate:package`. Every check runs before the first write: a
# non-package or a conflicting file is refused (exit 64) with nothing written. Runs on the
# operator's host at adoption time — bash and jq, never a gate tier.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
wp_dir=web/wp
content_dir=web/app

refuse() { echo "refused: $1" >&2; exit 64; }

[[ $# -eq 1 ]] || refuse "usage: bin/package-gate.sh <package-root>"
root="$(realpath -e "$1" 2>/dev/null)" || refuse "$1 does not exist"
[[ "$root" != */web/app/mu-plugins/* ]] || refuse "$root is a site's installed copy; render onto the package's own checkout"
[[ -f "$root/composer.json" ]] || refuse "$root has no composer.json"
name="$(jq -r '.name // empty' "$root/composer.json")" || refuse "$root/composer.json is not valid JSON"
[[ -n "$name" ]] || refuse "$root/composer.json declares no name"
type="$(jq -r '.type // empty' "$root/composer.json")"
[[ "$type" == wordpress-muplugin ]] || refuse "$root/composer.json is type '${type:-none}', not wordpress-muplugin"
pkg="${name#*/}"
[[ -f "$root/$pkg.php" ]] || refuse "$root/$pkg.php is missing — a package's main file sits at its root"

site_only() {
  case $1 in
    tests/Unit/*|tests/bootstrap-unit.php|tests/Integration/DataLayerRoundTripTest.php|phpcs.xml|phpstan.neon|phpunit.unit.xml) return 0 ;;
  esac
  return 1
}
fragment() { case $1 in composer.gate.json|.gitignore.gate|.gitattributes.gate) return 0 ;; esac; return 1; }
tier_config() { case $1 in phpcs.xml|phpstan.neon) return 0 ;; esac; return 1; }

tokens=(-e "s|{{GATE_WP_DIR}}|$wp_dir|g" -e "s|{{GATE_CONTENT_DIR}}|$content_dir|g" -e "s|{{PACKAGE}}|$pkg|g")
render() { sed "${tokens[@]}" "$1"; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The file list: gate/ minus the site-only entries, the overlay on top (it wins where both exist),
# and the core loader shim for a package that requires ntdst-core.
declare -A src=()
while IFS= read -r -d '' f; do
  rel="${f#"$here/gate/"}"
  site_only "$rel" || src["$rel"]="$f"
done < <(find "$here/gate" -type f -print0)
while IFS= read -r -d '' f; do
  rel="${f#"$here/package-gate/"}"
  fragment "$rel" || src["$rel"]="$f"
done < <(find "$here/package-gate" -type f -print0)
if jq -e '.require."netdust/ntdst-core"' "$root/composer.json" >/dev/null; then
  src["$content_dir/mu-plugins/ntdst-coreloader.php"]="$here/mu-plugins/ntdst-coreloader.php"
fi

# Render every file into $tmp and sort its destination: new, identical, kept (a tier config the
# package already has) or a conflict. Nothing reaches the package until every file is sorted.
new=(); same=(); kept=(); conflicts=()
mapfile -t rels < <(printf '%s\n' "${!src[@]}" | sort)
for rel in "${rels[@]}"; do
  dest="${rel//"{{PACKAGE}}"/$pkg}"
  mkdir -p "$tmp/$(dirname "$dest")"
  cp -p "${src[$rel]}" "$tmp/$dest"
  sed -i "${tokens[@]}" "$tmp/$dest"
  if [[ ! -e "$root/$dest" ]]; then new+=("$dest")
  elif cmp -s "$tmp/$dest" "$root/$dest"; then same+=("$dest")
  elif tier_config "$dest"; then kept+=("$dest")
  else conflicts+=("$dest")
  fi
done
if (( ${#conflicts[@]} )); then
  for dest in "${conflicts[@]}"; do echo "conflict: $dest exists with other content" >&2; done
  refuse "${#conflicts[@]} conflicting file(s) — nothing written; move them aside or make them identical"
fi

for dest in "${new[@]}"; do
  mkdir -p "$root/$(dirname "$dest")"
  cp -p "$tmp/$dest" "$root/$dest"
  echo "wrote: $dest"
done
for dest in "${kept[@]}"; do echo "kept: $dest"; done

# The two line fragments: each line once, after the package's own. An export-ignore line is
# appended only for a path the shape placed (written or found identical) or a directory above one.
placed=("${new[@]}" "${same[@]}")
placed_has() { local x; for x in "${placed[@]}"; do [[ "$x" == "$1" || "$x" == "$1/"* ]] && return 0; done; return 1; }
append_once() {
  [[ -f "$1" ]] || : > "$1"
  grep -qxF -- "$2" "$1" && return 0
  [[ ! -s "$1" || -z "$(tail -c1 "$1")" ]] || echo >> "$1"
  printf '%s\n' "$2" >> "$1"
}
while IFS= read -r line; do
  [[ -n "$line" ]] && append_once "$root/.gitignore" "$line"
done < <(render "$here/package-gate/.gitignore.gate")
while IFS= read -r line; do
  path="${line%% *}"
  [[ -n "$line" ]] && placed_has "${path#/}" && append_once "$root/.gitattributes" "$line"
done < <(render "$here/package-gate/.gitattributes.gate")

# The composer fragment, through Composer's own indent: the package wins on every key except the
# gate-owned script keys, where the shape wins and a former `gate` is kept as `gate:package`.
render "$here/package-gate/composer.gate.json" > "$tmp/composer.gate.json"
jq --indent 4 --slurpfile g "$tmp/composer.gate.json" '
  . as $pkg | $g[0] as $gate | ($pkg.repositories // []) as $repos
  | ."require-dev" = ((($pkg."require-dev" // {}) * $gate."require-dev") * ($pkg."require-dev" // {}))
  | .config = ((($pkg.config // {}) * $gate.config) * ($pkg.config // {}))
  | .extra = ((($pkg.extra // {}) * $gate.extra) * ($pkg.extra // {}))
  | .repositories = ($repos + [$gate.repositories[] | select(.url as $u | ($repos | map(.url) | index($u)) == null)])
  | .scripts = (($pkg.scripts // {})
      | if (.gate != null and .gate != $gate.scripts.gate and (has("gate:package") | not))
        then . + {"gate:package": .gate} else . end)
  | .scripts = (.scripts + $gate.scripts)
' "$root/composer.json" > "$tmp/composer.json"
cat "$tmp/composer.json" > "$root/composer.json"
echo "merged: composer.json"

if git -C "$root" check-ignore -q composer.lock 2>/dev/null; then
  echo "note: composer.lock is gitignored — deps:latest reads the lock; remove the ignore line and commit it"
fi
echo "next: composer install"
echo "next: npm install"
echo "next: ddev start"
echo "next: composer gate"
