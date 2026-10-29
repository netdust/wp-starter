# package-gate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** wp-starter's gate gains its package shape — a `wordpress-muplugin` package renders it onto its own root, hosts the newest WordPress in `require-dev`, is its own DDEV project, and `composer gate` runs every tier on it, with a `deps:latest` tier that goes red the day WordPress, wp-phpunit or a `netdust/*` neighbour is behind its newest tag.

**Architecture:** The site shape stays what it is: `gate/`, copied whole to a site root by `scaffold_wp_starter`. The package shape is `gate/` minus six site-only entries plus an overlay folder `package-gate/` (bedrock-lite `config/` and `web/`, the loader shim, the package's DDEV project, the composer fragment), rendered onto a package root by `bin/package-gate.sh` with three tokens. The two shapes share every tier script; `deps:latest` is one new script in `gate/bin/`, called by `gate.sh` directly so no stack-template manifest changes; a package's own former `gate` script survives as the `gate:package` tier. The proof is a throwaway render on a clone of ntdst-core: real WordPress 7.1, real `wptests`, real browser.

**First working version:** Task 1 — `bin/package-gate.sh <dir>` renders the shape onto a scratch package and refuses a non-package; the first thing Stefan can run.

**Tech Stack:** POSIX sh (the payload's `bin/*.sh` are `/bin/sh`), bash and `jq` for the renderer on the host, Composer 2.8 (`outdated --locked --direct --strict`), DDEV 1.25 (`config.*.yaml` merging — hooks from both files run, verified by the plan review with `ddev debug configyaml`), wp-phpunit 7.1.x, PHPUnit as the package pins it, Playwright through the existing `bin/e2e.sh`.

**Spec:** `netdust-plugins/specs/wp-ai-base/spec.md` (`~/Projects/netdust-plugins/specs/wp-ai-base/spec.md`, on `main` since `340902b`) — R8, R9 and the gate half of R17. Decisions 6, 10, 11. Nothing of R10, R11 or R18 is built here: no package adopts the shape in this plan; plans 5–7 do.

**Branch:** `feature/package-gate`, cut from `origin/master` — wp-starter's production branch is `master`, not `main` (`919ae54` on 2026-10-29; re-read at the coder start) — in its own worktree. First commits: this plan, `specs/package-gate/plan-review.md`. wp-starter has no `specs/` yet; this plan creates it.

## Global Constraints

wp-starter carries no `site.yml` and no `composer.json`; the WordPress pack does not apply. The spec's own:

- One gate, one home (netdust-wp-manager INV-1): every gate file this plan writes lives in wp-starter. Nothing lands in ntdst-core, ntdst-baseline, netdust/bedrock, netdust/stackedWP or `~/Sites/ntdst-testbed`; the testbed is read, never edited, and retires with its remaining consumers (spec Non-goals).
- The site shape renders unchanged except for five intended deltas — the tiers in `gate/bin/gate.sh`, the new `gate/bin/deps-latest.sh`, the guarded `bootstrap-site.php` require in `gate/tests/bootstrap-integration.php`, the autoloader line in `gate/tests/wp-tests-config.php`, the sweep paths in `gate/bin/lint-tokens.sh` (a payload file too: sites carry it) — and, once Task 5 lands, `gate/README-testing.md`: six. Task 4 proves it by diffing a site render before and after. `gate/.ddev/commands/host/gate:3` keeps saying "9-tier"; it stays, by this rule.
- Every payload file is tokenized: `sh gate/bin/lint-tokens.sh` exits 0, and from Task 4 on it also sweeps `package-gate/`, fragments included. Layout tokens `{{GATE_WP_DIR}}` and `{{GATE_CONTENT_DIR}}` as today; the package shape adds `{{PACKAGE}}` (the composer name after the slash) and nothing else — a deviation from R8's "the same two tokens" that R8's own `<package>loader.php` placeholder needs. R8's "the scaffold renders it" is read as wp-starter's `bin/package-gate.sh`, not `scaffold_wp_starter` (netdust-wp-manager, another repo): the spec leaves the selection to the builder.
- Every shell program parses: `for f in gate/bin/*.sh bin/*.sh; do bash -n "$f"; done` exits 0 (CI's first job). New gate scripts are `/bin/sh` like their siblings; `bin/package-gate.sh` is bash with `jq` — it runs on the operator's host at adoption time, never in a gate tier.
- `deps:latest` runs on the host, like `analyse`: `composer outdated` reaches packagist and netdust's private VCS repos through the host's SSH agent. It reads the lock (`--locked`): no `composer.lock` is red with that message, never silently green (Decision 11: the gate rewrites nothing). The spec's "both packages commit `composer.lock`" holds for baseline only — ntdst-core gitignores its lock (`origin/main:.gitignore:4`); the renderer says so when it sees that, and committing the lock is plan 5's first adoption step.
- The PHPUnit pin is verified on the day in Task 3: wp-phpunit 7.1.3's bootstrap requires only PHPUnit ≥ 5.7.21 and polyfills ≥ 1.1.0 (`includes/bootstrap.php:50`, `:142`), both packages pin `phpunit/phpunit ^10.5`, and `gate/README-testing.md` §4f still claims a 9.6 ceiling from the 6.8 era. The fragment never overwrites a package's own pin; whether 10.5 runs the WordPress test case on 7.1 is a fact the proof produces and the README section records — together with PHPUnit 10's deprecation notice for the 9-schema XMLs (`cacheResultFile`), which is printed, not failed.
- The fragment merges: the package's value wins on every key except the gate-owned script keys — `gate` and the ten tiers (`lint`, `lint:js`, `analyse`, `audit:deps`, `audit:js`, `test:unit`, `test:js`, `build:check`, `test:int`, `test:e2e`) — where the shape wins, and a package's former `gate` value is kept under `gate:package` so its own checks (core's `@syntax @guard`, baseline's `check-invariants.sh`) keep running as a tier. On core, that tier and `test:unit` go red at the first render, by core's own design: `bin/guard.sh:255-260` and `tests/Unit/PackageBootIntegrityTest.php`'s `sweep()`/`shippedFiles()` walk the package root skipping only `vendor/`, `tests/` and `specs/`, and `guard.sh:12`'s ABSPATH sweep skips only `vendor` and `tests/bootstrap.php` — so they now meet WordPress under `web/wp`, the theme under `web/app/themes`, `node_modules/`, and the shape's own unguarded files under `tests/` (the two bootstraps and `wp-tests-config.php` run before ABSPATH exists and cannot carry the guard). Baseline's `bin/guard.sh:14` and `bin/check-invariants.sh:8` walk the same way. The plan writes nothing into core, so Task 3 expects both reds, names the cause, and plan 5's (and 6's) first adoption step is the rule README §6 states for every package: exclude `web/` and `node_modules/` from every root-walking sweep, and exempt the shape's `tests/bootstrap-*.php`, `tests/wp-tests-config.php` and `tests/Integration/` from the ABSPATH guard the way `tests/bootstrap.php` already is. Task 3 tries that rule in the throwaway clone so `composer gate` is seen green end to end once. `require` is never touched: a runtime neighbour like baseline's `netdust/ntdst-core ^5.4` stays where the package declares it, and `deps:latest` reads `netdust/*` wherever declared — R9's "`*` in require-dev" is the dev-only-neighbour case; whether baseline widens `^5.4` is plan 6's.
- A package's own tier configs win: an existing `phpcs.xml` or `phpstan.neon` is kept and the overlay's is the fallback (ntdst-core's `phpcs.xml` runs PSR-12 and PHPCompatibilityWP at `testVersion 8.1-` over all its source, stricter and truer to its `php >=8.1` floor than the shape's). Every other existing file with different content is a conflict, and the renderer writes nothing on refusal: every check runs before the first file is written.
- No `/shakeout`: the browser the plan drives is the gate's own e2e tier on a throwaway site; nothing here is a surface a person uses. No `## Threat model`: no auth, session, capability, nonce, user-URL fetch or stored credential is written — the DDEV admin the install hook creates gets a random password nobody records, the e2e credential stays `bin/e2e.sh`'s per-run one, and `config/application.php` carries DDEV's fixed `db`/`db` pair that every DDEV project on this machine already uses.
- Evidence: every task report quotes the command as run and its summary line; a run that could not happen is reported as not run.

## Review Focus

- **Boundary** — a destination that exists with different content and is not a tier config (a package that already has a `bin/gate.sh`, a `web/wp-config.php`, a `tests/bootstrap-integration.php` of its own): the renderer lists every conflict, exits 1 and has written nothing. Row 1's denial test, RED first.
- **Denied actor** — a directory that is not a package: no `composer.json`, `type` ≠ `wordpress-muplugin`, no `<package>.php` at its root, or a site's installed copy under `web/app/mu-plugins/` (the testbed refused that too, `bin/test-package:19`). Row 1.
- **Empty** — `netdust/*` matches nothing in core: `composer outdated 'netdust/*'` prints nothing and the tier is green, not an error; a package with no tests beyond the shape's `LoaderTest` still has a meaningful `test:int`; a package with no former `gate` script has no `gate:package` tier and the gate says so. Rows 2, 3 and 4.
- **Delivery seam** — sites install `netdust/*` from source (`config.preferred-install`), so export-ignore does nothing for them and the committed shape files travel into `mu-plugins/<package>/`. Each is inert there: a nested `web/app/mu-plugins/*loader.php` is not top-level so WordPress never loads it, `web/wp-config.php` is not beside a WordPress, `.ddev/` is not a project root, the site's `phpcs.xml`/`phpstan.neon` already exclude `mu-plugins/ntdst-*`, and the manifest keys the fragment adds (`require-dev`, `config`, `extra`, `repositories`, `scripts`) are root-only in Composer. Row 2 lists what a source checkout carries; export-ignore still keeps a dist install clean.
- **Re-entry** — a second `bin/package-gate.sh` run on the same package: identical files are fine, fragments are appended once, exit 0. A package worktree is its own DDEV project through `.ddev/config.local.yaml` (`netdust-devops:parallel-work`); `wptests` on an already-running project needs one `ddev restart` (README-testing §4c); `composer install` must precede `ddev start`, or the install hook finds no WordPress. Rows 1 and 2.

## Simplest design

The simplest change that meets R8 is a README section telling plans 5 and 6 to copy `gate/` by hand and add twelve files. Rejected: two hand adoptions of fifteen files with three tokens and a composer merge drift from each other the day they are written, and a third package (atelier, studio-plugin, netdust-studio) would make a fourth copy — the renderer is the one home INV-1 asks for, and the testbed's `bin/test-package` (77 lines) already showed a small script suffices. Keeping the testbed as the package runtime is Decision 10's rejected option. Within the renderer the plan takes the smallest shapes: no `--force`, no per-file skip list on the command line, no second preset, and "the package's own tier config wins" instead of a conflict rule that would make core's `phpcs.xml` a refusal on day one — the site shape is untouched and the package shape is `gate/` minus six entries plus an overlay, so a gate fix lands once and reaches both.

## Test map

| Unit | Seam | Tests: tier · file · command | E2E flows |
|---|---|---|---|
| The package shape: `package-gate/` overlay + `bin/package-gate.sh` | `bin/package-gate.sh <package-root>` | bash · `tests/package-gate.test.sh` · `sh tests/package-gate.test.sh` (temp fixture package, real `jq`; denial cases RED first) | none |
| The shape on real WordPress | `ddev composer test:int`, `composer test:e2e`, `sh bin/deps-latest.sh`, `composer gate` on a throwaway render of ntdst-core | none committed — proven by the run, quoted: `LoaderTest` green on `wptests`, e2e smoke green, deps:latest red then green, every tier run and reported by name, and `composer gate` green end to end once the clone carries plan 5's exclusions (throwaway only) | the gate's own e2e smoke, on the throwaway site |
| `deps:latest` tier | `sh bin/deps-latest.sh` (called by `gate.sh`) | bash · `tests/deps-latest.test.sh` · `sh tests/deps-latest.test.sh` (stub `composer` on PATH records its arguments and answers scripted exit codes) | none |
| `gate.sh` tier order, fail-fast, the optional `gate:package` tier | `composer gate` | bash · `tests/gate-tiers.test.sh` · `sh tests/gate-tiers.test.sh` (stub `composer`, stub `ddev`, stub `bin/deps-latest.sh`) | none |
| Token lint over the overlay; the site render unchanged | `sh gate/bin/lint-tokens.sh`; a site render diff | the lint's own exit code (RED on a planted literal, then clean); `diff -rq` of two site renders, before and after: five files at Task 4, six at the Close | none |
| `README-testing.md` §package, root `README.md` | reference text | none — proven by review against R8, R9, R17 and the Task 3 facts | none |
| CI | `.github/workflows/ci.yml` | the run on the pushed branch, green (`gh run list --branch feature/package-gate`) | none |

Riskiest first: the shape and its refusals, then the tier, then the real run that can only happen once both exist.

---

### Task 1: The package shape — overlay and renderer

**Files:**
- Create: `package-gate/.ddev/config.yaml`, `package-gate/.ddev/config.package.yaml`, `package-gate/wp-cli.yml`, `package-gate/config/application.php`, `package-gate/web/wp-config.php`, `package-gate/web/index.php`, `package-gate/web/app/mu-plugins/{{PACKAGE}}loader.php`, `package-gate/tests/bootstrap-site.php`, `package-gate/tests/Integration/LoaderTest.php`, `package-gate/phpunit.unit.xml`, `package-gate/phpcs.xml`, `package-gate/phpstan.neon`, `package-gate/composer.gate.json`, `package-gate/.gate-no-theme-js`, `package-gate/.gitignore.gate`, `package-gate/.gitattributes.gate`
- Create: `bin/package-gate.sh`
- Modify: `gate/tests/bootstrap-integration.php:61` (one guarded require before the wp-phpunit bootstrap), `gate/tests/wp-tests-config.php:24` (the autoloader line the testbed added, after the blank line that follows `declare`)
- Test: `tests/package-gate.test.sh`

**Interfaces:**
- Produces: `bin/package-gate.sh <package-root>` — exit 0 and the rendered shape, or exit 64 with every refusal on stderr and nothing written. Tokens: `{{GATE_WP_DIR}}` → `web/wp`, `{{GATE_CONTENT_DIR}}` → `web/app`, `{{PACKAGE}}` → `jq -r .name composer.json | cut -d/ -f2`. Site-only files never copied: `tests/Unit/`, `tests/bootstrap-unit.php`, `tests/Integration/DataLayerRoundTripTest.php`, `phpcs.xml`, `phpstan.neon`, `phpunit.unit.xml` (the overlay carries the package versions of the last three). Tier configs the package may keep: `phpcs.xml`, `phpstan.neon`. Task 3 renders with it; Task 5 documents it.
- Produces: `scripts.gate:package` when the package had a `gate` of its own; Task 2's `gate.sh` runs it as a tier.
- Produces: the DDEV project name `{{PACKAGE}}` in `.ddev/config.yaml`; a worktree overrides it in `.ddev/config.local.yaml`.

- [ ] **Step 1: The overlay files, lifted from the testbed**

`config/application.php`: the testbed's file (`~/Sites/ntdst-testbed/config/application.php`) with the dotenv block (`:37-55`) removed and no `env()` — no `.env`, no `vlucas/phpdotenv`, no `oscarotero/env`. `WP_HOME` and `WP_SITEURL` from `getenv('DDEV_PRIMARY_URL')`; `DB_NAME`/`DB_USER`/`DB_PASSWORD` `db`, `DB_HOST` `db`; `WP_ENV` `development`; `CONTENT_DIR` `/app`; the `development.php` constants inline (`WP_DEBUG`, `WP_DEBUG_LOG`, `SCRIPT_DEBUG`, `DISALLOW_INDEXING`, `WP_DISABLE_FATAL_ERROR_HANDLER`); `Config::apply()`; a header comment saying it is the gate's bedrock-lite for a package and reads only DDEV's environment. `web/wp-config.php` and `web/index.php`: the testbed's, verbatim. `wp-cli.yml`: `path: {{GATE_WP_DIR}}` and `server.docroot: web`.

`web/app/mu-plugins/{{PACKAGE}}loader.php` (the file name carries the token; the renderer renames it): `defined('ABSPATH') || exit; require_once dirname(__DIR__, 3) . '/{{PACKAGE}}.php';` with a four-line header: it loads the working copy at the repo root, never a composer-installed copy, so the gate tests the code being edited.

`.ddev/config.yaml`: `name: {{PACKAGE}}`, `type: wordpress`, `docroot: web`, `php_version: "8.3"`, `webserver_type: nginx-fpm`, `database: {type: mariadb, version: "11.8"}`, `nodejs_version: "24"`, `disable_settings_management: true`. `.ddev/config.package.yaml`: one `post-start` `exec` hook — `[ -f {{GATE_WP_DIR}}/wp-load.php ] || { echo "package gate: no WordPress at {{GATE_WP_DIR}} — run composer install, then ddev restart"; exit 0; }; wp core is-installed 2>/dev/null || wp core install --url="$DDEV_PRIMARY_URL" --title="{{PACKAGE}} gate" --admin_user=gate-admin --admin_password="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')" --admin_email=gate@example.test --skip-email` — so `bin/e2e.sh`'s `ddev exec wp user create` has a site to seed. `gate/.ddev/config.gates.yaml` (wptests) is copied as for a site; DDEV runs both files' hooks (verified, DDEV 1.25.5).

`tests/bootstrap-site.php`: the testbed's (`~/Sites/ntdst-testbed/tests/bootstrap-site.php`) with `TESTBED_PACKAGE` and `$ntdstPackageDir` replaced by the repo root (`dirname(__DIR__)`) and the fatal guard dropped; it returns early when `tests/Integration/site.php` is absent, so the shape works on a package that boots on plain WordPress.

`tests/Integration/LoaderTest.php` (`NtdstTests\Integration`, `WP_UnitTestCase`): `test_suite_runs_against_the_dedicated_wptests_database` as `DataLayerRoundTripTest.php:21-30`; `test_the_loader_shim_loaded_the_working_copy` — `assertContains(realpath(dirname(ABSPATH, 2) . '/{{PACKAGE}}.php'), array_map('realpath', get_included_files()))` and `assertContains(realpath(WPMU_PLUGIN_DIR . '/{{PACKAGE}}loader.php'), array_map('realpath', wp_get_mu_plugins()))` — `wp_get_mu_plugins()` lives in `wp-includes/load.php` and is always loaded; `get_mu_plugins()` is admin-only and is not.

`phpunit.unit.xml`: the gate's with `bootstrap="tests/bootstrap.php"` — the convention both packages already follow. `phpcs.xml`, the fallback for a package without one: `<file>.</file>`, PSR-12 on `tests/` only, WordPress security and DB sniffs on everything, excludes `*/web/*`, `*/vendor/*`, `*/node_modules/*`, `*/.phpstan-cache/*`. `phpstan.neon`, the fallback: the gate's without the `phpstan-baseline.neon` include (a site generates that per project, `new-site.sh:557-568`), `paths: [.]`, and — because the gate's `excludePaths` are content-dir paths that do not cover a root walk — an explicit `excludePaths: analyseAndScan: [{{GATE_WP_DIR}} (?), {{GATE_CONTENT_DIR}} (?), vendor (?), node_modules (?), .phpstan-cache (?)]` — `(?)` on each, the gate file's own convention, because PHPStan 2.x refuses a missing path without it and `node_modules` exists only after `npm install` — the same three `scanFiles`.

`composer.gate.json`, the fragment — tokenized like every payload file; the renderer renders it before merging. Package values win except on the gate-owned script keys (Global Constraints):
```json
{"require-dev": {"roots/wordpress": "*", "roots/wp-config": "*", "wp-phpunit/wp-phpunit": "*", "yoast/phpunit-polyfills": "^4.0", "wpackagist-theme/twentytwentyfive": "*", "brain/monkey": "^2.7", "phpstan/phpstan": "^2.2", "szepeviktor/phpstan-wordpress": "^2.0", "php-stubs/wp-cli-stubs": "^2.12", "wp-coding-standards/wpcs": "^3.4", "phpcompatibility/phpcompatibility-wp": "^2.1", "dealerdirect/phpcodesniffer-composer-installer": "^1.2", "roave/security-advisories": "dev-latest"},
 "repositories": [{"type": "composer", "url": "https://wpackagist.org", "only": ["wpackagist-plugin/*", "wpackagist-theme/*"]}],
 "config": {"platform": {"php": "8.3"}, "process-timeout": 0, "preferred-install": {"netdust/*": "source", "*": "dist"}, "allow-plugins": {"composer/installers": true, "roots/wordpress-core-installer": true, "dealerdirect/phpcodesniffer-composer-installer": true}},
 "extra": {"installer-paths": {"{{GATE_CONTENT_DIR}}/mu-plugins/{$name}/": ["type:wordpress-muplugin"], "{{GATE_CONTENT_DIR}}/plugins/{$name}/": ["type:wordpress-plugin"], "{{GATE_CONTENT_DIR}}/themes/{$name}/": ["type:wordpress-theme"]}, "wordpress-install-dir": "{{GATE_WP_DIR}}"},
 "scripts": {"lint": "phpcs", "analyse": "phpstan analyse --no-progress", "audit:deps": ["@composer audit", "@audit:js"], "audit:js": "sh bin/js-gate.sh audit:js 'audit --audit-level=high'", "lint:js": "sh bin/js-gate.sh lint:js 'run lint' 'run lint:css'", "test:unit": "vendor/bin/phpunit -c phpunit.unit.xml", "test:js": "sh bin/js-gate.sh test:js 'run test'", "build:check": "sh bin/js-gate.sh build:check 'run build'", "test:int": "vendor/bin/phpunit -c phpunit.integration.xml", "test:e2e": "sh bin/e2e.sh", "gate": "sh bin/gate.sh"}}
```
No `phpunit/phpunit` line: the packages pin PHPUnit themselves. Task 3 corrects the list from the real install if `composer install` asks for more. The `repositories` entry is appended only when no entry with that `url` exists.

`.gitignore.gate` (tokenized, appended): `/{{GATE_WP_DIR}}`, `/{{GATE_CONTENT_DIR}}/plugins`, `/{{GATE_CONTENT_DIR}}/themes`, `/{{GATE_CONTENT_DIR}}/uploads`, `/{{GATE_CONTENT_DIR}}/upgrade`, `/{{GATE_CONTENT_DIR}}/mu-plugins/*/`, `/{{GATE_CONTENT_DIR}}/debug.log`, `/vendor`, `/node_modules`, `/.phpunit.cache`, `/.phpunit.result.cache`, `/.phpstan-cache/*`, `/tests/E2E/.auth`, `/test-results/`, `/playwright-report/`, `/.ddev/config.local.yaml`. `.gitattributes.gate` (appended): every path the shape adds, `export-ignore`, one per line (`/web`, `/config`, `/.ddev`, `/bin/gate.sh`, `/bin/e2e.sh`, `/bin/js-gate.sh`, `/bin/lint-tokens.sh`, `/bin/deps-latest.sh`, `/package.json`, `/package-lock.json`, `/playwright.config.ts`, `/tsconfig.json`, `/phpunit.unit.xml`, `/phpunit.integration.xml`, `/phpstan.neon`, `/phpcs.xml`, `/wp-cli.yml`, `/.gate-no-theme-js`, `/README-testing.md`, `/.phpstan-cache`), `tests/` and `.gitattributes` left to the package (both already export-ignore them).

- [ ] **Step 2: Write the failing test**

`tests/package-gate.test.sh`, in the style of `tests/js-gate.test.sh` (`fixture`/`run`/`check`, PASS/FAIL counters, temp dir, summary `package-gate.test: N ok, M failed`, exit 1 on any FAIL). `fixture <name> [requires-core] [own-gate] [lock-ignored]` writes `$WORK/pkg/composer.json` (`{"name":"netdust/<name>","type":"wordpress-muplugin","require-dev":{"phpunit/phpunit":"^10.5"},"scripts":{"test":"phpunit"}}`), `<name>.php`, `.gitignore` (`vendor/`), `.gitattributes` (`tests/ export-ignore`), `tests/bootstrap.php`, and `git init -q` so `check-ignore` works; `requires-core` adds `.require."netdust/ntdst-core" = "^5.4"`; `own-gate` adds `.scripts.gate = ["@syntax","@test"]` and `.scripts.lint = "php -l"`; `lock-ignored` appends `composer.lock` to `.gitignore`. Cases, one `ok`/`bad` line per assertion:
- (a) **refusals, nothing written** — no `composer.json`; `type` `project`; `<name>.php` missing; a path under `web/app/mu-plugins/`: each exits 64, stderr names the reason, and `find "$WORK/pkg" -newer "$WORK/stamp"` is empty.
- (b) **conflict** — the fixture already has a `bin/gate.sh` with other content: exit 64, stderr lists `bin/gate.sh`, and no other shape file exists afterwards (`! -f tests/bootstrap-integration.php`). **Kept tier config** — the fixture has its own `phpcs.xml`: exit 0, the file is byte-identical afterwards, stdout says `kept: phpcs.xml`, and `.gitattributes` gained no `/phpcs.xml export-ignore` line (only written paths are appended).
- (c) **render** — exit 0; these exist: `bin/gate.sh`, `bin/e2e.sh`, `bin/js-gate.sh`, `bin/deps-latest.sh` (from Task 2; until then the test lists what `gate/bin/` holds), `tests/bootstrap-integration.php`, `tests/wp-tests-config.php`, `tests/bootstrap-site.php`, `tests/Integration/LoaderTest.php`, `tests/E2E/smoke.spec.ts`, `phpunit.unit.xml`, `phpunit.integration.xml`, `phpcs.xml`, `phpstan.neon`, `playwright.config.ts`, `package.json`, `.ddev/config.yaml`, `.ddev/config.gates.yaml`, `.ddev/config.package.yaml`, `.ddev/commands/host/gate`, `config/application.php`, `web/wp-config.php`, `web/index.php`, `web/app/mu-plugins/<name>loader.php`, `wp-cli.yml`, `.gate-no-theme-js`, `README-testing.md`; these do not: `tests/Unit`, `tests/bootstrap-unit.php`, `tests/Integration/DataLayerRoundTripTest.php`, `web/app/mu-plugins/{{PACKAGE}}loader.php`, `composer.gate.json`, `.gitignore.gate`; `grep -rl '{{' "$WORK/pkg" --exclude-dir=vendor --exclude-dir=.git` is empty (fragments rendered too); `bin/gate.sh` is executable; `.ddev/config.yaml` has `name: <name>`; `wp-cli.yml` has `path: web/wp`; the loader requires `/<name>.php`.
- (d) **merge** — `jq` reads back: `."require-dev"."phpunit/phpunit" == "^10.5"` (kept), `."require-dev"."roots/wordpress" == "*"` (added), `.scripts.test == "phpunit"` (kept), `.scripts.gate == "sh bin/gate.sh"`, `.extra."wordpress-install-dir" == "web/wp"`, `.extra."installer-paths" | keys[0] == "web/app/mu-plugins/{$name}/"`, `.repositories | length == 1`; `.gitignore` ends with the rendered `.gitignore.gate` lines after its own (`/web/wp` literal present); `.gitattributes` likewise. With `own-gate`: `.scripts.gate == "sh bin/gate.sh"`, `.scripts."gate:package" == ["@syntax","@test"]`, `.scripts.lint == "phpcs"`; without: `.scripts | has("gate:package") | not`.
- (e) **neighbour** — with `requires-core`: `web/app/mu-plugins/ntdst-coreloader.php` exists and equals `mu-plugins/ntdst-coreloader.php`; without: absent.
- (f) **lock** — with `lock-ignored`: exit 0 and stdout has `composer.lock is gitignored`; without: no such line.
- (g) **re-entry** — a second run exits 0, `.gitignore` has each gate line once, `composer.json` is byte-identical to after the first run, and the `own-gate` fixture's `gate:package` is not re-wrapped.

- [ ] **Step 3: Run it to see it fail**

Run: `sh tests/package-gate.test.sh`
Expected: `package-gate.test: 0 ok, N failed` — `bin/package-gate.sh` does not exist (the test's `run` reports the missing script as one `bad` line per case, (a)'s four refusals included).

- [ ] **Step 4: `bin/package-gate.sh`**

bash, `set -euo pipefail`, `refuse() { echo "refused: $1" >&2; exit 64; }` as `bin/test-package` does. Order: resolve `root` from `$1` (`realpath -e`, else refuse); refuse a path under `*/web/app/mu-plugins/*`; `name=$(jq -r '.name // empty' composer.json)` (refuse when empty or `type != "wordpress-muplugin"`); `pkg=${name#*/}`; refuse when `$root/$pkg.php` is missing. `render()` seds the three tokens from a source into a temp file. Build the file list: `find gate -type f` minus the six site-only entries, then `find package-gate -type f` minus the three fragments; the overlay's path wins where both exist; the loader shim's destination name is rendered too. For every destination, render and compare with an existing destination: identical → skip; a tier config (`phpcs.xml`, `phpstan.neon`) that exists → `kept: <file>`, skip; different otherwise → collect. Any collected conflict → list them all, exit 64 (nothing written yet). Then write: `mkdir -p`, `cp -p` the rendered temp file (exec bits travel). Append each rendered line of the two fragments that `grep -qxF` does not already find — for `.gitattributes.gate`, a line is appended when its path is a destination the renderer wrote or found identical, or a directory prefix of one (`/web`, `/config`, `/.ddev`, `/.phpstan-cache`); a kept tier config gets no export-ignore from the shape. Merge the rendered composer fragment with `jq --indent 4` (Composer's own writer; jq keeps key order and writes unicode raw, so the adoption diff is the keys, not the whole file): `require-dev`, `config`, `extra` as `((.X // {}) * $gate.X) * (.X // {})` (package wins, package key order first, the shape's keys appended); `repositories` appended where no entry with that `url` exists; `scripts` — when the package's `gate` exists and differs from `sh bin/gate.sh` and `gate:package` is absent, set `."gate:package"` to it; then `.scripts = ((.scripts // {}) + ($gate.scripts))` so the eleven gate-owned keys take the shape's value and every other key stays. `require` untouched. Copy `mu-plugins/ntdst-coreloader.php` when `jq -e '.require."netdust/ntdst-core"'` succeeds. `git -C "$root" check-ignore -q composer.lock && echo "note: composer.lock is gitignored — deps:latest reads the lock; remove the ignore line and commit it"`. End with the next steps on stdout, in this order: `composer install`, `npm install`, `ddev start`, `composer gate`.

- [ ] **Step 5: The two shared-file edits**

`gate/tests/bootstrap-integration.php`, before the `require getenv('WP_PHPUNIT__DIR')` line: `if (is_file(__DIR__ . '/bootstrap-site.php')) { require __DIR__ . '/bootstrap-site.php'; }` with the testbed's one-line comment (`framework-tests F8`). `gate/tests/wp-tests-config.php`, after the blank line that follows `declare(strict_types=1);`: the testbed's `require_once dirname(__DIR__) . '/vendor/autoload.php';` with its two-line comment (the installer runs this file in its own process).

- [ ] **Step 6: Run the tests to see them pass**

Run: `sh tests/package-gate.test.sh && sh tests/js-gate.test.sh && for f in gate/bin/*.sh bin/*.sh; do bash -n "$f"; done && sh gate/bin/lint-tokens.sh`
Expected: `package-gate.test: N ok, 0 failed`, `js-gate.test: N ok, 0 failed`, no parse error, `token lint: clean` (the overlay is swept from Task 4; here the lint still sees `gate/` only).

- [ ] **Step 7: Commit**

```bash
git add package-gate bin/package-gate.sh tests/package-gate.test.sh gate/tests/bootstrap-integration.php gate/tests/wp-tests-config.php
git commit -m "gate(package): the package shape — gate/ minus the site-only five plus the package-gate/ overlay, rendered by bin/package-gate.sh; the package keeps its own tier configs and its former gate as gate:package; a non-package or a conflict is refused before anything is written"
```

---

### Task 2: `deps:latest` — latest, or red — and the `gate:package` tier

**Files:**
- Create: `gate/bin/deps-latest.sh`
- Modify: `gate/bin/gate.sh:3-4` (the locked order comment), `:15` (`TIERS`), `:19-24` (the per-tier dispatch)
- Test: `tests/deps-latest.test.sh`, `tests/gate-tiers.test.sh`

**Interfaces:**
- Produces: `sh bin/deps-latest.sh` — exit 0 when every `roots/wordpress`, `wp-phpunit/wp-phpunit` and `netdust/*` entry in `composer.lock` is at its newest tag; exit 1 naming each pattern that is behind or could not be resolved, or `deps:latest: no composer.lock` when there is no lock. `gate.sh` runs it as the tier after `build:check` and before `test:int`, as `sh bin/deps-latest.sh` — no composer script, so no stack-template manifest changes. `gate:package` runs after `test:unit` when `composer run-script --list` names it. Task 3 demonstrates both on the real render.

- [ ] **Step 1: Write the failing tests**

`tests/deps-latest.test.sh`: a fixture dir with `bin/deps-latest.sh` copied in, a stub `composer` on PATH that appends its arguments to `$LOG` and exits with the code `$STUB_EXIT_<pattern>` names (`roots/wordpress` → `STUB_EXIT_WP`, `wp-phpunit/wp-phpunit` → `STUB_EXIT_PHPUNIT`, `netdust/*` → `STUB_EXIT_NETDUST`, default 0), and a `composer.lock` present unless the case removes it. Cases: (a) all 0 → exit 0, stdout `deps:latest: up to date`; (b) WP 1 → exit 1, stderr contains `roots/wordpress` and the fix line with `--with-dependencies` (a metapackage like `roots/wordpress` moves only with its dependents); (c) NETDUST 1 → exit 1 naming `netdust/*`; (d) no lock → exit 1, stderr `deps:latest: no composer.lock`, `$LOG` empty; (e) every stub call carries `outdated --locked --direct --strict` and exactly the three patterns, in that order.

`tests/gate-tiers.test.sh`: a fixture with `bin/gate.sh` (no tokens in it; copy as is) and a stub `bin/deps-latest.sh` exiting `$STUB_DEPS`, stub `composer` that logs `run-script <tier>`, answers `run-script --list` with `$STUB_SCRIPTS` (one script name per line) and exits per `$STUB_FAIL_AT`, stub `ddev` logging `composer run-script test:int`. Cases: (a) all green, `STUB_SCRIPTS` without `gate:package` → `$LOG` is exactly `lint lint:js analyse audit:deps test:unit test:js build:check deps-latest test:int test:e2e` in that order, stdout has `gate:package: none declared — skipped` and ends `gate: all tiers green`; (b) `STUB_SCRIPTS` with `gate:package` → `$LOG` has `run-script gate:package` right after `test:unit`; (c) `STUB_DEPS=1` → exit 1, stderr `gate: FAILED at tier deps:latest (exit 1)`, `$LOG` has no `test:int`; (d) `composer run-script analyse` exiting 3 → exit 3, nothing after `analyse` in `$LOG`.

- [ ] **Step 2: Run them to see them fail**

Run: `sh tests/deps-latest.test.sh; sh tests/gate-tiers.test.sh`
Expected: deps-latest — every case `bad` (no script); gate-tiers — (a) `bad`: `$LOG` lacks `deps-latest`, no skip line; (b) `bad`: no `gate:package`; (c) `bad`: the gate reaches `test:int`; (d) passes already (fail-fast exists).

- [ ] **Step 3: `gate/bin/deps-latest.sh` and the two tiers**

`/bin/sh`, `set -u`. `[ -f composer.lock ] || { echo "deps:latest: no composer.lock — the gate reads the lock; commit one" >&2; exit 1; }`. `behind=""`; for `p` in `roots/wordpress wp-phpunit/wp-phpunit 'netdust/*'`: `composer outdated --locked --direct --strict --no-interaction "$p" || behind="$behind $p"`, output left on stdout so the names and versions show (a wildcard prints Composer's list with its `!`/`~` markers; a single name prints the detail view with `latest :`). If `$behind` is non-empty: `echo "deps:latest: behind the newest tag, or unresolvable (no network, no SSH agent):$behind — fix: composer update$behind --with-dependencies and commit the lock; a version outside the constraint (Composer's ~) needs the constraint widened first" >&2; exit 1`. Else `echo "deps:latest: up to date"`.

`gate.sh`: `TIERS="lint lint:js analyse audit:deps test:unit gate:package test:js build:check deps:latest test:int test:e2e"`; in the loop, `deps:latest` dispatches `sh bin/deps-latest.sh; code=$?`; `gate:package` dispatches `composer run-script gate:package` only when `composer run-script --list 2>/dev/null | grep -qE '^ *gate:package( |$)'`, else prints `gate:package: none declared — skipped` with `code=0` (a site never declares it; a package that lost it says so in its own `composer.json`); the header comment's locked order gains both.

- [ ] **Step 4: Run the tests to see them pass**

Run: `sh tests/deps-latest.test.sh && sh tests/gate-tiers.test.sh && sh tests/package-gate.test.sh && bash -n gate/bin/deps-latest.sh gate/bin/gate.sh`
Expected: `deps-latest.test: N ok, 0 failed`, `gate-tiers.test: N ok, 0 failed`, `package-gate.test: N ok, 0 failed` (case (c) now finds `bin/deps-latest.sh` in the render).

- [ ] **Step 5: Commit**

```bash
git add gate/bin/deps-latest.sh gate/bin/gate.sh tests/deps-latest.test.sh tests/gate-tiers.test.sh tests/package-gate.test.sh
git commit -m "gate: deps:latest — red when WordPress, wp-phpunit or a netdust/* neighbour is behind its newest tag, read from the lock, fixing nothing; gate:package runs a package's own checks when it declares them"
```

---

### Task 3: The shape on real WordPress — a throwaway render of ntdst-core

**Files:**
- Modify: `package-gate/composer.gate.json` only if the real install corrects it (Step 2); `package-gate/tests/Integration/LoaderTest.php` only if the real run corrects it
- Scratch, never committed: `$SCRATCH/core-gate-proof` (a fresh `git clone git@github.com:netdust/ntdst-core.git` at `origin/main`), its DDEV project `ntdst-core-gate-proof`

**Interfaces:**
- Consumes: Task 1's renderer, Task 2's tiers.
- Produces: the facts Task 5 writes down — which PHPUnit the shape ran on 7.1 and what it printed, what a source checkout carries, the `deps:latest` red/green transcript, the per-tier result on core.

- [ ] **Step 1: Render, install, start**

Run, from the clone: `bash <wp-starter>/bin/package-gate.sh "$PWD"` (expect `kept: phpcs.xml`, the `composer.lock is gitignored` note, `gate:package` set from core's `["@syntax","@test","@guard","@audit:deps"]`, the next-steps lines); `composer install --no-interaction 2>&1 | tail -20`; `npm install`; `npx playwright install chromium` if the host lacks it; write `.ddev/config.local.yaml` with `name: ntdst-core-gate-proof`; `ddev start`; `ddev debug configyaml | grep -A6 post-start` shows both hooks; `ddev exec wp core is-installed; echo $?` → 0.
Expected: Composer resolves `roots/wordpress 7.1.4` and `wp-phpunit/wp-phpunit 7.1.3` (or newer that day — note the numbers) beside core's `phpunit/phpunit ^10.5`. If Composer refuses a fragment line, fix the fragment (Task 1's file) and the test's expectation in the same commit, and say which line.

- [ ] **Step 2: The integration tier — RED first, then green**

RED: `sed -i 's/get_included_files()/[]/' tests/Integration/LoaderTest.php`, run `ddev composer test:int`.
Expected: `Integration suite DB: wptests`, PHPUnit 10's deprecation line about the 9-schema XML (printed, not a failure), one failure in `test_the_loader_shim_loaded_the_working_copy`. If instead the wp-phpunit bootstrap or test case refuses PHPUnit 10.5 (a fatal before the first test), that is the fact: record "wp-phpunit 7.1.x + PHPUnit 10.5: refused at <line>" for §4f and plan 5, and re-run with `composer require --dev phpunit/phpunit:^9.6 --no-interaction` in the throwaway only — the fragment stays silent on PHPUnit.
GREEN: restore the test, run again.
Expected: `OK (2 tests, N assertions)` on `wptests`.

- [ ] **Step 3: The e2e tier on the throwaway site**

Run: `composer test:e2e`
Expected: `bin/e2e.sh` seeds `e2e-admin` and the fixture post through `ddev exec wp`, Playwright runs `tests/E2E/smoke.spec.ts`, `2 passed` (or the spec's count). The front page is twentytwentyfive's; the login is at `/wp/wp-login.php`.

- [ ] **Step 4: `deps:latest` — red, then green, for real**

RED: `composer require --dev roots/wordpress:7.1.3 -W --no-interaction` (one patch behind; `-W` because `roots/wordpress` is a metapackage over `roots/wordpress-no-content: self.version` and Composer reverts the change without it), then `sh bin/deps-latest.sh; echo rc=$?`.
Expected: Composer's detail view for `roots/wordpress` with `versions : * 7.1.3` and `latest : 7.1.4`, the stderr line naming `roots/wordpress` with the fix, `rc=1`.
GREEN: `composer require --dev roots/wordpress:'*' -W --no-interaction` (back to the fragment's constraint, dependents moved with it), run again.
Expected: `deps:latest: up to date`, `rc=0`. Then once in a copy without `composer.lock`: `rc=1`, `no composer.lock`.

- [ ] **Step 5: Every tier, reported by name**

Run: `composer gate; echo rc=$?`, then — if it stopped before `test:e2e` — each tier it did not reach, by name: `composer run-script lint`, `analyse`, `audit:deps`, `test:unit`, `gate:package`, `lint:js`, `test:js`, `build:check`, `sh bin/deps-latest.sh`, `ddev composer run-script test:int`, `composer run-script test:e2e`, each with `echo rc=$?`.
Expected: `lint` runs core's own `phpcs.xml` (kept) as `composer lint` already did on main; `analyse` runs the shape's `phpstan.neon` over core at level 6 for the first time — a red there is core's finding for plan 5, its first three lines in the task report, not fixed here; `test:unit` **red** and `gate:package` **red**, both by core's root-walking sweeps meeting `web/`, `node_modules/` and the shape's `tests/` files (Global Constraints): `PackageBootIntegrityTest`'s sweep fails on WordPress's own files under `test:unit`; `gate:package` stops at its `@test` (Composer stops a script array at the first failing entry; its `@test` re-runs the unit suite through core's `phpunit.xml` — the suite runs twice on an adopted package, by design, until plan 5 trims the duplicate), so run `composer run-script guard` by name too and quote its list: the ABSPATH grep names WordPress's files, the theme's, and the shape's `tests/bootstrap-integration.php`, `tests/wp-tests-config.php`, `tests/bootstrap-site.php`, `tests/Integration/LoaderTest.php`; the retired-symbol grep names `wp-includes/rest-api` lines. `audit:deps` green; `syntax` green but slow (it now lints WordPress's PHP too: not red, noted for plan 5); the three JS tiers skip by the marker; `deps:latest`, `test:int`, `test:e2e` green as in Steps 2–4. The report lists all eleven with their exit codes and names the adoption rule.

Then, throwaway only, on Step 2's precedent: apply the rule in the clone — `sed` the `web/` and `node_modules/` exclusions into `bin/guard.sh:12` and `:258` and the two path filters of `PackageBootIntegrityTest.php` (`:1065`, `:1438`), and the four `tests/` exemptions into `guard.sh:12` — never committed; then `composer gate; echo rc=$?`.
Expected: `gate: all tiers green`, `rc=0`, quoted in full: the one command of Decision 6, seen once on a real package with `gate.sh`'s own dispatch of `gate:package`, `deps:latest`, `test:int` and `test:e2e`. If `lint` or `analyse` stay red on core's code, run the remaining tiers by name as above and say so: those two are core's findings, the rest is the shape's proof.

- [ ] **Step 6: What a source checkout carries**

Run, in the throwaway: `git add -A && git commit -qm scratch`, then `git ls-files | grep -vE '^(vendor|web/wp|web/app/(plugins|themes|uploads|mu-plugins/[^/]+/)|node_modules)' | sort` (the source-install view, lock absent because core ignores it) and `git archive HEAD --worktree-attributes | tar -t | sort` (the dist view).
Expected: the first list is the committed shape; the second lacks every `.gitattributes.gate` path. Record both lists for Task 5's README section, with the inert-reason per file class from Review Focus.

- [ ] **Step 7: Tear down, keep the evidence**

Run: `ddev delete -Oy ntdst-core-gate-proof && rm -rf "$SCRATCH/core-gate-proof"`. Commit only if Step 1 or 2 changed a tracked file:
```bash
git add package-gate/composer.gate.json package-gate/tests/Integration/LoaderTest.php tests/package-gate.test.sh
git commit -m "gate(package): corrections from the first real render on ntdst-core — <which line, and why>"
```

---

### Task 4: Token lint over the overlay, the site render unchanged, CI

**Files:**
- Modify: `gate/bin/lint-tokens.sh:20` (the grep's paths gain `package-gate/`; the `{{PACKAGE}}` token appears in the overlay but needs no lint exclude)
- Modify: `.github/workflows/ci.yml` (three new steps)
- Scratch: two site renders

- [ ] **Step 1: The lint, RED first**

Plant `web/app/mu-plugins` as a literal in `package-gate/tests/bootstrap-site.php`'s comment, run `sh gate/bin/lint-tokens.sh; echo rc=$?`.
Expected: `rc=0` — the lint does not look at `package-gate/` yet (that is the gap). Edit `:20` to `gate/ package-gate/ theme/ mu-plugins/` — no third exclude: no overlay line carries `{{PACKAGE}}` beside a layout literal (the shim and `LoaderTest` build their paths from `dirname(__DIR__, 3)` and `WPMU_PLUGIN_DIR`, and prose uses the layout tokens), so an exclude would only open a hole; run again.
Expected: `FAIL: untokenized layout literals`, the planted line, `rc=1`. Remove the literal; run again: `token lint: clean`, `rc=0` — the tokenized fragments pass.

- [ ] **Step 2: The site shape renders unchanged**

Run: render `origin/master`'s `gate/` (`git archive origin/master gate | tar -x -C <tmp>`) and the branch's `gate/` the way `scaffold_wp_starter` does (`scaffold-meta.sh` step 3: copy every file, `sed` the two tokens to `web/wp` and `web/app`) into two temp dirs, then `diff -rq`.
Expected: differences in exactly five files — `bin/gate.sh`, `bin/deps-latest.sh` (only in the branch), `bin/lint-tokens.sh` (Step 1), `tests/bootstrap-integration.php`, `tests/wp-tests-config.php`. Quote the `diff -rq` lines. The Close repeats it and expects `README-testing.md` as the sixth.

- [ ] **Step 3: CI**

`.github/workflows/ci.yml`, after `js-gate behaves`: `package-gate renders and refuses` → `sh tests/package-gate.test.sh`; `deps:latest and the tier order` → `sh tests/deps-latest.test.sh && sh tests/gate-tiers.test.sh`; `payload is tokenized` → `sh gate/bin/lint-tokens.sh`. The first job's loop becomes `for f in gate/bin/*.sh bin/*.sh`. `jq` and `git` are on `ubuntu-latest`.

- [ ] **Step 4: Run everything locally, then commit**

Run: `for f in gate/bin/*.sh bin/*.sh; do bash -n "$f"; done && sh tests/js-gate.test.sh && sh tests/package-gate.test.sh && sh tests/deps-latest.test.sh && sh tests/gate-tiers.test.sh && sh gate/bin/lint-tokens.sh`
Expected: four `… 0 failed` lines and `token lint: clean`.
```bash
git add gate/bin/lint-tokens.sh .github/workflows/ci.yml
git commit -m "gate: the token lint sweeps package-gate/ and allows {{PACKAGE}}; CI runs the three new behaviour tests and the lint"
```

---

### Task 5: The words — README-testing §package, the root README

**Files:**
- Modify: `gate/README-testing.md` (§1's tier table gains two rows; §4f reworded to the Task 3 fact; one new §6 after §5)
- Modify: `README.md:20-34` (the tree gains `package-gate/` and `bin/package-gate.sh`; one paragraph), `:187` (the lint sentence names `package-gate/`)

- [ ] **Step 1: README-testing**

§1 table: a row `gate:package` · `composer gate:package` · "the package's own checks, kept from its former `gate` script when the shape was adopted; a site never has one, the gate says `skipped`" · either · package-defined; a row `deps:latest` · `sh bin/deps-latest.sh` (no composer mirror; `gate` runs it) · "`composer outdated --locked --direct --strict` on `roots/wordpress`, `wp-phpunit/wp-phpunit`, `netdust/*`; red when any is behind its newest tag or cannot be resolved; fix: widen an exact constraint if Composer marks `~`, `composer update <names> --with-dependencies`, commit the lock" · host (SSH agent) · ~3 s. §1's "nine tiers" becomes eleven. §4f: replace the 9.6 ceiling claim with Task 3's fact, dated, including the PHPUnit 10 deprecation line the 9-schema XMLs print. New §6 "The package shape", under 60 lines, speaking of "a package" never "this project" (it renders into every site too): what it is (one gate, two shapes — cite `netdust-wp:wp-testing`, spec R8–R9); adoption in seven lines (`bash <wp-starter>/bin/package-gate.sh <package-root>` from a wp-starter clone; `composer install`; `npm install`; `ddev start`; commit the lock if it was ignored; exclude `web/` and `node_modules/` from every root-walking sweep the package carries — guard scripts, invariant checks, integrity tests — because a WordPress now lives under its root, and exempt the shape's `tests/bootstrap-*.php`, `tests/wp-tests-config.php` and `tests/Integration/` from the ABSPATH guard the way `tests/bootstrap.php` already is (a `php -l` sweep over `.` stays green, only slower); `composer gate`); the worktree rule (`.ddev/config.local.yaml` `name:`); what the renderer refuses, that it writes nothing on refusal, and that a package's own `phpcs.xml`/`phpstan.neon` win; the loader shim's meaning (the working copy, never a composer copy); the neighbour rule (`netdust/*` stays where the package declares it; `deps:latest` reads it there); the Task 3 lists (what a source install of the package carries, each inert; what a dist install omits); `tests/Integration/site.php` for a package that needs an `NTDST_Bootstrap` config (from `bootstrap-site.php`); and the site-shape note — a site pinning `roots/wordpress` exactly goes red at `deps:latest` until its constraint is widened (the stack templates' manifest wiring, Close 5). Not used, by name: Playground, Blueprints, wp-env, a shared test site.

- [ ] **Step 2: Root README**

The tree block gains `├── package-gate/   ← the package overlay: rendered over gate/ onto a package root by bin/package-gate.sh` and `└── bin/package-gate.sh`; one paragraph under the gate-layer bullet: two shapes, one home, where the proof ran. `:187`'s sentence: "…run `sh gate/bin/lint-tokens.sh` (it sweeps `gate/`, `package-gate/`, `theme/` and `mu-plugins/`)".

- [ ] **Step 3: Lint and commit**

Run: `sh gate/bin/lint-tokens.sh && awk '/^## 6/,0' gate/README-testing.md | wc -l`
Expected: clean; the new section under 60 lines.
```bash
git add gate/README-testing.md README.md
git commit -m "docs(gate): the package shape — adoption, the deps:latest and gate:package tiers, what a source install carries; README-testing §4f states the PHPUnit fact from the 7.1 render"
```

---

## Close

1. Every suite once more: `for f in gate/bin/*.sh bin/*.sh; do bash -n "$f"; done && sh tests/js-gate.test.sh && sh tests/package-gate.test.sh && sh tests/deps-latest.test.sh && sh tests/gate-tiers.test.sh && sh gate/bin/lint-tokens.sh` — the project's gate (no `make gate` here: wp-starter is the payload, not a site). Task 4 Step 2's render diff once more: six files.
2. Push `feature/package-gate`; `gh run list --branch feature/package-gate --limit 1` green (the CI row of the Test map).
3. The feature review: `/feature-review package-gate` from the reviewer's checkout; one fix pass, each fix RED→GREEN through the test that owns it; `specs/package-gate/review.md` committed with it.
4. No shake-out (Global Constraints). The one-gate grep: `grep -rniE 'playground|blueprint|wp-env|testbed' gate package-gate README.md` finds only the "not used" sentences.
5. Push; the merge into `master` is Stefan's. Nothing to sync: `scaffold_wp_starter` clones `master` at scaffold time, so a site born after the merge carries the tier — and `new-site.sh` **aborts at step 13** (`:576`: a red `composer gate` is `exit 1` under `set -euo pipefail`, before the commit at `:590`; the project is left for inspection) while `netdust/bedrock` and `netdust/stackedWP` pin `roots/wordpress` and `wp-phpunit/wp-phpunit` exactly (laika's manifest: `6.8.2`, `~6.8.0`). The follow-up is theirs, manifest wiring INV-1 permits: both templates' constraints to `*` so a site is born latest and `composer update --with-dependencies` can keep it there; a Studio task on project wp-ai-base, and the precondition for any scaffold after this merge. Existing sites adopt by hand as README-testing says. Then plans 5 and 6 run `bin/package-gate.sh` on their packages, and the testbed retires when atelier and studio-plugin follow.
