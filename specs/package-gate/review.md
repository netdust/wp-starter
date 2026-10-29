# Feature review — package-gate

Reviewed: `origin/feature/package-gate` at `7365bf373c5b97cec0c306cd586db54d7d0d1284`, base `919ae54c48dbfb93989874a4e28b9620a0f5d96d` (origin/master, merge-base). Plan `specs/package-gate/plan.md`, spec `netdust-plugins/specs/wp-ai-base/spec.md` (R8–R9, R17's gate half). Level: full. Reviewers: superpowers' code reviewer (fresh `general-purpose` subagent, most capable model) on a detached checkout of the head. No joiners applied: no `## Threat model`, no `ARCHITECTURE-INVARIANTS.md` in wp-starter, not a WordPress site project. Dispatched by `/feature-review package-gate` from the reviewer session on 2026-10-29.

Findings: 0 Blocking · 1 Should fix · 7 Note

Reviewer's rulings on the findings (2026-10-29): I1 fixed in the fix pass (the neighbour shim for `require-dev` too — a plan defect the code carried; R9 and README §6 were right). M1, M2 (one refusal line each, with a test case), M3, M4 (README-testing §6 wording and order), M5 (a deterministic "wrote nothing" check), M6, M7 (labels) taken in the same pass. The declined-to-judge list stands as written; the third-adopter exclusion in the site shape's `phpcs.xml`/`phpstan.neon` is a later wp-starter change, noted on Studio.

---

## Review — `package-gate` (wp-starter, 919ae54..7365bf3)

Everything below was run or read in the detached checkout; renders and probes went to my scratchpad only. The checkout, the testbed (`git status --short` empty), ntdst-core (clean) are untouched; ntdst-baseline's `?? tasks/todo.md` is dated 2026-10-25, before this feature.

### Strengths

- **The renderer writes nothing before every check passes — verified by control flow, not by the report.** `bin/package-gate.sh:20-29` refuse; `:49-75` render every file into `$tmp` and sort it (new / same / kept / conflict); `:76-79` list all conflicts and `refuse`; the first write to `$root` is `:81-85`. Fragments and the composer merge come after. Probes P1/P7 confirm (invalid JSON → `refused`, rc 64, nothing written).
- **The jq merge does what the constraint says.** Package wins on `require-dev`/`config`/`extra` including nested objects and a scalar `preferred-install: "dist"` (probe P8: package's `allow-plugins.composer/installers: false` kept, shape's keys appended; `sort-packages` kept); `repositories` deduped by url (P4); the eleven gate-owned script keys take the shape's value; `gate:package` is set only when the former `gate` differs from `sh bin/gate.sh` (P5: a pre-existing `sh bin/gate.sh` is not wrapped; test (g) pins re-entry byte-identical). `composer validate` on the merged manifest: only the license warning.
- **`.gitattributes.gate` append rule is exact** (`:90-91`, `placed_has`): written-or-identical paths and directory prefixes only; a kept `phpcs.xml` gets no line (test pins it). Fragments are rendered through `render()` before append/merge (`:98-104`, `:108`).
- **Site shape unchanged beyond six files — reproduced**: `git archive` of `919ae54` vs head `gate/`, both tokens rendered, `diff -rq` → `README-testing.md`, `bin/deps-latest.sh` (head only), `bin/gate.sh`, `bin/lint-tokens.sh`, `tests/bootstrap-integration.php`, `tests/wp-tests-config.php`. Exactly the plan's six.
- **Suites green here**: `bash -n` clean over `gate/bin/*.sh bin/*.sh`; js-gate 17 ok; package-gate 116 ok; deps-latest 14 ok; gate-tiers 13 ok; `token lint: clean`. CI run 40874858043 is the head commit's and succeeded. One-gate grep finds only README-testing:133.
- **Tests are real and denial-first**: real `jq`, real `git init`, real filesystem; the four refusals and the conflict case come before the render case; stubs log the exact argv (`outdated --locked --direct --strict`, the three patterns in order) and exit per env — honest about what they can assert.
- **POSIX/bash hygiene**: `gate.sh`, `deps-latest.sh`, `lint-tokens.sh` have no bashisms (`case`, `[ ]`, no arrays); the renderer's `set -euo pipefail` is safe (`name="$(jq …)" || refuse`, `trap … EXIT` cleanup, `cp -p` + GNU `sed -i` preserve exec bits — test pins `bin/gate.sh -x`).
- **`gate.sh:35` grep `'^ *gate:package( |$)'`** cannot match `gate:packaged` — checked against a real `composer run-script --list` (two-space indent, name, spaces).
- **Security posture as planned**: `config/application.php` reads only `DDEV_PRIMARY_URL` and exits without it (`:16-17`), no `.env`/dotenv (diffed against the testbed's: the dotenv block, `env()`, salts and `DATABASE_URL` are gone); `config.package.yaml` hook is guarded on `wp-load.php` and the `$(…urandom…)` password is expanded inside `wp core install`'s argv, never echoed; `LoaderTest` asserts via `wp_get_mu_plugins()`.
- **Task 3 facts verified on the host**: `yoast/phpunit-polyfills` 4.0.0 requires `phpunit ^7.5||^8.0||^9.0||^11.0||^12.0` (no 10); `roave/security-advisories dev-latest` conflicts `php <8.2.35|>=8.3,<8.3.36|…` — against `platform.php 8.3` the removal is right.
- **The coder's rulings hold**: roave out (audit:deps runs `composer audit`); polyfills `^4.0` with the PHPUnit pin as the package's fact; `DISALLOW_INDEXING` omitted (Bedrock's disallow-indexing mu-plugin is not in the shape, so the constant would do nothing) and `AUTOMATIC_UPDATER_DISABLED`/`DISALLOW_FILE_MODS` coherent with "Composer owns web/"; the fallback neon's `analyse` vs `analyseAndScan` split is right (neighbour scanned, not reported); test (c) grepping the three full tokens is justified — P1 shows the rendered `bin/lint-tokens.sh:6,21,22` legitimately carry `{{SLUG*}}`/`{{GATE_` in its own prose and grep, so a bare `{{` sweep would false-fail.
- README-testing §6: 59 lines, says "a package" (no "this project"), names Playground/Blueprints/wp-env/a shared test site, states the adoption rule and the PHPUnit fact; §1's 1–11 numbering matches `TIERS` (gate:package 6th, deps:latest 9th).

### Issues

#### Critical (Must Fix)

None.

#### Important (Should Fix)

**I1 — The core-loader shim is copied only for `require`; R9 puts the neighbour in `require-dev`, and README §6 promises both.**
`bin/package-gate.sh:57` `jq -e '.require."netdust/ntdst-core"'`. Spec R9: "its neighbour (core, for baseline) is `"*"` in `require-dev`". README-testing.md:160-162: "A package requiring `netdust/ntdst-core` also gets wp-starter's `ntdst-coreloader.php`; a neighbour stays wherever the package declares it (`require` or `require-dev`)". Probe P2 (core in `require-dev` only) renders rc 0 with only `acmeloader.php` under `web/app/mu-plugins/` — no `ntdst-coreloader.php`. Effect: a package that follows R9 boots its integration suite on WordPress without core; `tests/bootstrap-site.php:18` then fatals on `NTDST_Bootstrap` for any package with a `site.php`. Plan 6 (baseline) is the first to trip it the day it moves core to `*` in require-dev as R9 says. This is a **plan defect carried faithfully** (Task 1 Step 4 says `.require`), so the executor rules — but the README already contradicts the code. Fix: `jq -e '((.require // {}) + (."require-dev" // {}))."netdust/ntdst-core"'` and a `requires-core-dev` fixture option in `tests/package-gate.test.sh`, RED first.

#### Minor (Nice to Have)

**M1 — `repositories` in Composer's object form crashes the merge after the shape files are written.** `bin/package-gate.sh:114` `$repos + [...]`; probe P3 (`"repositories": {"core": {...}}`) → `jq: error … object and array cannot be added`, rc 5, with `bin/`, `web/`, `.ddev/`… already on disk and `composer.json` unmerged. Neither adopter uses the form (core: none; baseline: array), so it is a reasonable-person gap, not a plan one. Cheapest: refuse up front (`jq -e '.repositories | type == "object"'` → `refuse`) beside the other checks at `:20-29`.

**M2 — The installed-copy refusal is Bedrock-only.** `bin/package-gate.sh:22` `*/web/app/mu-plugins/*`; stackwp's content dir is `app/content` (scaffold-meta.sh). Probe P6 renders the shape into `<site>/app/content/mu-plugins/acme` with rc 0. The plan named only `web/app/mu-plugins`; `*/mu-plugins/*` costs nothing and covers both stacks.

**M3 — README §6:178 "`.ddev/` is not a project root" is not how DDEV discovers projects.** DDEV resolves the nearest `.ddev/config.yaml` upward from cwd, so `ddev …` run from inside a site's `mu-plugins/<package>/` (a source checkout carrying the committed `.ddev/config.yaml`, `name: <package>`) addresses the package's project, not the site's. Not destructive, but the sentence promises inertness it does not have. Reword: "run `ddev` from the site root; inside the package directory DDEV would resolve the package's own project".

**M4 — README §6 adoption order.** Step 5 (`:149`, "a manifest pinning `phpunit/phpunit ^10.5` moves to `^9.6` first") comes after step 2 (`:141`, `composer install`), which §4f itself says Composer refuses on `^10.5`. Both adopters pin `^10.5`. Move the pin change into step 1/2.

**M5 — `written()` rests on mtime ordering.** `tests/package-gate.test.sh:48-50` `find -newer stamp`. Measured here (ext4): a file created immediately after the stamp is NOT `-newer`; at 5 ms it is. It works because the renderer spends longer than that before any write, but a `find -type f | sort` + `cksum` snapshot before/after would pin "wrote nothing" without a timing assumption.

**M6 — Label nit.** `tests/gate-tiers.test.sh:62` "dispatches the eleven tiers" — the log pins ten (gate:package is skipped, not dispatched); the assertion is right, the label is not.

**M7 — Cosmetic.** `gate/bin/deps-latest.sh:16` the suggested fix line can read `composer update roots/wordpress netdust/* --with-dependencies` — an unquoted glob in a line meant to be pasted; `'netdust/*'` in the message.

### Declined to judge

- Site `gate/phpcs.xml:23-24` and `gate/phpstan.neon:61-63` exclude only `mu-plugins/ntdst-core` and `ntdst-baseline`; a third adopter's travelled shape files (atelier, studio-plugin) would be swept by a site's lint/analyse — no package adopts in this plan (plans 5–7); the fix is a later wp-starter change.
- `gate/.ddev/commands/host/gate:3` still says "9-tier" — stays by the site-shape-unchanged constraint, as the plan rules.
- README §1 "~15 s warm" total unchanged while `deps:latest` adds ~3 s — prose, no behaviour.
- The unit suite (and now `@audit:deps`) running twice on an adopted core via `gate:package` — accepted in the plan as harmless until plan 5 trims it.
- Core's `scripts-descriptions.lint` ("NOT yet in gate") goes stale after a render — core's file, plan 5's.
- `bin/package-gate.sh` needs bash ≥ 4.4 (`declare -A`, `mapfile`, empty arrays under `set -u` on re-entry) — the host (WSL Ubuntu) and `ubuntu-latest` satisfy it; no macOS host in the fleet.
- Bedrock/stackedWP exact pins making `new-site.sh` abort at step 13 after this merge — Close 5 names it as the templates' manifest wiring; out of this repo.
- `config/application.php` defines no salts (WordPress stores generated ones in options) and turns `WP_DEBUG_DISPLAY` on — a throwaway DDEV site; the proof's e2e passed on it.
- The fallback `phpstan.neon` does not exclude `.ddev/` although DDEV writes `.ddev/xhprof/xhprof_prepend.php` on every project — I ran PHPStan 2.2.7 over that file with a root-walk config: under `.ddev/` it reports "No files found" (Symfony Finder skips dot-directories), under a plain directory it errors. No hole; `.phpstan-cache (?)` is likewise redundant but harmless.

### Recommendations

1. Fix I1 in the one fix pass: the jq expression plus a `requires-core-dev` fixture case, RED→GREEN through `tests/package-gate.test.sh`; it changes nothing for the site shape.
2. Take M1 and M2 in the same pass — both are one line in the refusal block, and both are "writes nothing on refusal" promises the README makes.
3. M3 and M4 are README-testing edits (the §6 line budget has one line left; M3 can replace the wrong clause in place).
4. Note for plan 6: it may move core to `require-dev` at `*` (R9) only once I1 is in.

### Assessment

**Ready to merge?** With fixes

**Reasoning:** The implementation matches the plan task for task — control flow, merge semantics, tier dispatch, the six-file site delta and the CI wiring all verified by execution, not by the Close report — and the Task 3 corrections are factually right. The one Important finding is a gap the plan wrote and the code inherited (shim on `require` only while R9 and README §6 say `require-dev` too); it is a one-line jq change plus a test case and should land before plan 6 depends on it.
