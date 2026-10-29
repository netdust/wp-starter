# Plan review — package-gate (wp-starter: the gate's package shape, `deps:latest`) — round 3
Reviewed-plan: 199b6be0905ccea71d586b7d1f4ff63b486ad4a0 specs/package-gate/plan.md

*Applied after this review (2026-10-29, by the planning session): S1 (the ABSPATH exemption joins the adoption rule in Global Constraints, Task 3 Step 5 and README §6; `composer run-script guard` is run by name), S2 (`(?)` on every fallback phpstan exclude), S3 (a throwaway-only sub-step applies plan 5's exclusions in the clone so `composer gate` is seen green end to end; Test map row 2 says so), Notes 1–5 (package-first jq key order, the `.gitattributes.gate` rule wording, six site-only entries, the slow-not-red clause, the `{{PACKAGE}}` wording). The plan's blob after those edits is `55a6e4f2e85c1c8ae64cc0495354b8adcf54f2e6`; no further review round, per the plan-review skill (Should fix and Note need none).*
Verdict: ready with fixes

(The blob is not in any repo's object store; `/home/ntdst/Sites/wp-starter/specs/package-gate/plan.md` on disk hashes to exactly `199b6be0…` and is what was reviewed. wp-starter HEAD = `origin/master` = `919ae54`; ntdst-core `origin/main` = `ccab89c` 2026-10-19; ntdst-baseline `origin/main` = `c96f22a` 2026-10-27.)

## Round 2's findings, checked against this blob

- **B1** — landed as written. Global Constraints `:27` names both reds, the cause (`bin/guard.sh:12`, `:255-260`, `PackageBootIntegrityTest`'s `sweep()`/`shippedFiles()`) and the adoption rule; Task 3 Step 5 `:215` expects `test:unit` **red** and `gate:package` **red**, quotes the first failing line of each, names the rule; README §6 (Task 5 Step 1 `:273`) carries the rule "for every package". The reading of `:255-260`, `sweep()` `:1051-1065` and `shippedFiles()` `:1432-1438` is exact (all three skip `/vendor/`, `/tests/`, `/specs/` only; `shippedFiles()` is used once, `:1402`, to harvest `_doing_it_wrong` versions). The reading of `guard.sh:12` is **not** exact — it skips `vendor` and `tests/bootstrap.php` only, so `tests/` is swept — and that makes the rule incomplete: S1 below.
- **S1** — landed. `:207` and `:209` carry `-W` with the metapackage reason; `:160` the fix line `composer update$behind --with-dependencies`; `:273` the README row; test (b) `:149` asserts the flag. `composer update --help` on 2.8.9 lists `-w, --with-dependencies` / `-W, --with-all-dependencies`.
- **S2** — landed. `:22` five deltas, `gate/bin/lint-tokens.sh` named as a payload file; `:52` "five files at Task 4, six at the Close"; `:248` five, listed; `:292` six. Consistent.
- Note "aborts at step 13" — landed `:296`, with `:576` and `:590` (`new-site.sh:576` is `(cd … && composer gate) || { …; exit 1; }` under `set -euo pipefail` `:2`; the commit is `:590`; `:202-203` the "leaves the project" text).
- Note `{{PACKAGE}}` exclude — landed `:242`: "no third exclude", with the reason; `:235` still says "the `{{PACKAGE}}` token is a third allowed form" — read with `:242` that means "appears in the overlay", not "a lint exclude"; one word there would remove the ambiguity.
- Note unit suite twice — landed `:215`.
- Note `jq --indent 4` — landed `:117`; closed with one residue, see Note 1.
- Note explicit `excludePaths: analyseAndScan` — landed `:85`; valid form, but without `(?)`: S2 below.
- Note `.gitattributes.gate` written paths only — landed `:117` and test (b) `:103`; see Note 2 on the directory lines.

## Blocking

None.

## Should fix

**S1 — The adoption rule leaves `@guard` red on both packages: the ABSPATH sweep walks `tests/`, and the shape puts four unguarded PHP files there.**
Plan `:27` "walk the package root skipping only `vendor/`, `tests/` and `specs/`" and "plan 5's first adoption step is to exclude `web/` and `node_modules/` from every root-walking sweep (README §6 says so for every package)"; `:215` "names the adoption rule"; `:273` the §6 line.
Source: ntdst-core `origin/main:bin/guard.sh:12` `grep -rL "defined('ABSPATH')" --include='*.php' . | grep -v vendor | grep -v tests/bootstrap.php` — `tests/` is swept, only `tests/bootstrap.php` is exempt (`:4-8` says so); ntdst-baseline `origin/main:bin/guard.sh:14` is the identical line. The shape writes, under `tests/`, `gate/tests/wp-tests-config.php` and `gate/tests/bootstrap-integration.php` (neither contains `defined('ABSPATH')` — checked over every `gate/**/*.php`; only `bootstrap-unit.php`, site-only, has it), the testbed's `tests/bootstrap-site.php` (no ABSPATH line; `:13-20` is the block the plan drops) and `tests/Integration/LoaderTest.php` (`:83` gives it no guard). The first three run before ABSPATH exists, so they cannot carry the exit guard, and INV-1 says the package never patches them. `config/application.php` passes (`~/Sites/ntdst-testbed/config/application.php:164` `if (!defined('ABSPATH'))`). So with `web/` and `node_modules/` excluded, `@guard` still lists those four paths on core and on baseline. The rule is exact for the other sweeps: `guard.sh:258` and `sweep()`/`shippedFiles()` skip `tests/`; baseline's `bin/check-invariants.sh:8` `EXCL='(^|/)vendor/|(^|/)tests/'` (its greps for `get_option(`, `apply_filters(`, `do_action(`, `wp_insert_post(` … over `.` are the baseline reds; "every package" is right). Second precision: under `gate:package` the `@guard` red is never observed — Composer stops a script array at the first failing entry (verified: `"gate": ["@a","@b"]`, `a` = `exit 1` → `@b` never runs, rc 1) and `@test` fails first; Step 5's "`@guard`'s ABSPATH grep and retired-symbol grep fail on them under `gate:package`" is an inference.
Smallest change: `:27` and `:273`: "exclude `web/` and `node_modules/` from every root-walking sweep, and exempt the shape's `tests/bootstrap-*.php`, `tests/wp-tests-config.php` and `tests/Integration/` from the ABSPATH guard the way `tests/bootstrap.php` already is"; Step 5 runs `composer run-script guard` by name so the list is quoted, not inferred. (Giving `LoaderTest.php` the guard at birth is optional; the three bootstraps need the exemption regardless.)

**S2 — The fallback `phpstan.neon`'s exclude list has no `(?)`; PHPStan 2.2.7 refuses a missing path.**
Plan `:85` `excludePaths: analyseAndScan: [{{GATE_WP_DIR}}, {{GATE_CONTENT_DIR}}, vendor, node_modules, .phpstan-cache]`.
Verified with laika's `vendor/bin/phpstan` 2.2.7 on a scratch root carrying exactly that rendered list: with `node_modules` absent → rc 1, "If the excluded path can sometimes exist, append (?) to its config entry"; with all five present → `[OK] No errors`, and the control run without the list reports `web/wp/bad.php` and `web/app/themes/t/bad.php` — so bare relative directory paths beside the neon exclude everything beneath them (the form is valid) and `.phpstan-cache` parses unquoted (`gate/phpstan.neon:26` already writes it so). `.phpstan-cache` is written by the renderer (`gate/.phpstan-cache/.gitignore` is a payload file), `vendor`/`web/wp`/`web/app` exist after `composer install`; `node_modules` only after `npm install` — an adoption line, but not something `analyse` needs, and `gate/phpstan.neon:59-66`, `:83-89` marks every maybe-absent path `(?)`.
Smallest change: `(?)` on each entry (at least `node_modules`), the file's own convention.

**S3 — Row 2's "proven by the run" rests on three tiers run by hand plus stubs; `composer gate` is never seen past `test:unit` on any package.**
Plan `:49` "every tier run and reported"; `:214-215` `composer gate` then the unreached tiers by name; `:145` "Task 3 demonstrates both on the real render".
Source: `gate/bin/gate.sh:25-28` stops at the first red; `test:unit` is red by design (and `lint` may be — core's `composer.json:49` `scripts-descriptions.lint`: "NOT yet in `gate`"), so `gate.sh` never reaches `gate:package`, `deps:latest`, `test:int`, `test:e2e`. The by-name runs call `sh bin/deps-latest.sh`, `ddev composer run-script test:int`, `composer run-script test:e2e` directly; `gate.sh`'s new dispatch (`:162` the `run-script --list | grep` detection, the `sh bin/deps-latest.sh` call, the order) is exercised only by `tests/gate-tiers.test.sh`'s stubs. Decision 6 ("one command is the Close") is therefore not observed in this plan, and the README rule (S1) is written without ever having been tried.
Smallest change: Step 5 gains a throwaway-only sub-step on the precedent of Step 2's PHPUnit 9.6 fallback: after both reds are quoted, apply the corrected rule in the clone (`sed` on `bin/guard.sh:12` and `:258`, the test's two `str_contains` filters at `:1065`/`:1438`; never committed), then `composer gate; echo rc=$?` → `gate: all tiers green`, quoted. Row 2's cell then reads "…and `composer gate` green once the clone carries plan 5's two exclusions". It would have surfaced S1.

## Note

1. **jq — concern closed with one residue.** `jq --indent 4 .` pass-through of core's and baseline's `composer.json` is byte-identical except `—` → `—` (core `:3`, `:49`; baseline `:3` — both files carry the escaped form, not the raw dash round 2 assumed). Composer's full writer (`JsonFile::write`, `JSON_UNESCAPED_UNICODE`) writes `—`; `composer require`'s in-place `JsonManipulator` would keep `—`. jq writes `/` raw, preserves pass-through key order and `0` as `0`. The merged blocks `$gate.X * (.X // {})` come out gate-first (verified: `[roots/wordpress, brain/monkey, phpstan/phpstan, phpunit/phpunit, squizlabs/…]`, `brain/monkey` = `^2.6` the package's), so core's `require-dev` and `config` are reordered in the adoption diff; `(.scripts // {}) + $gate.scripts` keeps package order and appends (`[test, lint, gate]`). If package order matters: `((.X // {}) * $gate.X) * (.X // {})`. Test (g)'s byte-identical re-run holds either way.
2. **`.gitattributes.gate` "only the lines whose path the renderer wrote"** — implementable, but four lines are never a destination: `/web`, `/config`, `/.ddev` (directories) and `/.phpstan-cache` (the renderer writes `.phpstan-cache/.gitignore`); say "a line is appended when its path is a written destination or a directory prefix of one". And "wrote" vs Step 4's "identical → skip": a first run against a package already holding an identical shape file would miss its line; "wrote or found identical, kept tier configs excluded" is what tests (b) `:103` (no `/phpcs.xml` line when kept) and (d) `:105` (`.gitattributes` "likewise", every line on the plain fixture) together pin.
3. **"gate/ minus five site-only files"** (`:7`, `:42`) vs six entries at `:69` (`tests/Unit/`, `tests/bootstrap-unit.php`, `DataLayerRoundTripTest.php`, `phpcs.xml`, `phpstan.neon`, `phpunit.unit.xml`; nine files on disk). One number.
4. **Core's `syntax` and baseline's `lint`** (`find . -name '*.php' -not -path './vendor/*' | xargs php -l`) now lint WordPress and `node_modules`' PHP too — green, ~1,100 files more. One clause in the §6 rule ("slow, not red") keeps plans 5/6 from chasing it.
5. `:235` "the `{{PACKAGE}}` token is a third allowed form" reads as a lint exclude until `:242` says there is none — "appears in the overlay" would do.
6. **Coverage, invention, Test map, simplest design** — re-judged: no new task, no requirement unowned, no contradiction with `wp-testing/SKILL.md:35` (order coarse: `deps:latest` before integration as R9 says) or `:91`; row 2 is the one row whose proof weakened (S3); the simplest-design paragraph is unchanged and still honest.

## Premises checked

- `gate/bin/gate.sh:3-4` order comment, `:15` TIERS, `:19-24` dispatch (`ddev composer run-script test:int` for `test:int`), `:25-28` fail-fast → holds
- `gate/bin/lint-tokens.sh:20` paths `gate/ theme/ mu-plugins/`; `:21-23` the two token excludes + `.phpstan-cache/` → holds
- `gate/tests/bootstrap-integration.php:61` is `require getenv('WP_PHPUNIT__DIR') . '/includes/bootstrap.php'` → holds
- `gate/tests/wp-tests-config.php:23` `declare`, `:24` blank, insert after → holds
- `README.md:20-25` gate bullet, `:27-34` tree, `:187` lint sentence → holds
- `gate/README-testing.md:10` "nine tiers", `:99-101` §4c, `:108-110` §4f 9.6 ceiling → holds; `gate/.ddev/commands/host/gate:3` "9-tier" → holds (stays by rule)
- `.github/workflows/ci.yml:22` loop, `:28` `js-gate behaves` → holds; `tests/js-gate.test.sh:113` summary form → holds
- `gate/` payload includes `.phpstan-cache/.gitignore`, `package-lock.json`, `tsconfig.json`, `playwright.config.ts`, `.ddev/commands/*` → holds (every `.gitattributes.gate` path is written or a prefix of one)
- shape PHP under `tests/` lacks `defined('ABSPATH')` (`wp-tests-config.php`, `bootstrap-integration.php`; testbed `bootstrap-site.php`) → holds → **S1**
- "`guard.sh:12` … skipping only `vendor/`, `tests/` and `specs/`" → `origin/main:bin/guard.sh:12` skips `vendor` and `tests/bootstrap.php` only → **does not hold (S1)**; `:255-260` skips `/vendor/`, `tests/`, `specs/` → holds
- `PackageBootIntegrityTest.php` `sweep()` `:1051-1065`, `shippedFiles()` `:1432-1438` skip `/vendor/`, `/tests/`, `/specs/`; `:135-144` retired-type rows → holds; the other core walkers (`CoreShapeCluster3/4b`, `CoreTrimClusterC`, `TemplateLoaderTest`) walk named dirs, not the root → holds
- baseline `bin/guard.sh:14` identical ABSPATH sweep; `bin/check-invariants.sh:8` `EXCL` vendor/tests only, root greps `:25-83`; `BaselineFilterNamespaceTest.php:50` walks `services/` only → "every package" holds
- core `composer.json` `gate` = `@syntax @test @guard @audit:deps`, `lint` = `phpcs`, `phpunit ^10.5`, `scripts-descriptions.lint` "NOT yet in `gate`"; `.gitignore:4` `composer.lock`; `phpcs.xml:12-17` explicit dirs; `phpunit.xml` → `tests/Unit`; no `phpstan.neon` at root → holds
- baseline `composer.json:14` core `^5.4` in `require`, `lint` = `php -l` find, `gate` five entries; commits `composer.lock` → holds
- Composer stops a script array at the first failing entry → verified (2.8.9) → `@guard` unobserved under `gate:package` (S1)
- `composer update` `-w, --with-dependencies` / `-W, --with-all-dependencies` → holds
- PHPStan 2.2.7: bare relative dir paths under `excludePaths.analyseAndScan` exclude their files; a missing path without `(?)` is a hard error; `.phpstan-cache` unquoted parses → holds / **S2**
- `jq --indent 4 .` on core/baseline `composer.json` byte-identical except `—` → `—`; `*` merge gate-first key order; `+` keeps left order → holds (Note 1)
- testbed `config/application.php:37-55` dotenv block, `:164-165` ABSPATH; `web/wp-config.php:10`; `tests/bootstrap-site.php:13-24`; `tests/bootstrap-integration.php:58-59`; `tests/wp-tests-config.php:25-27`; `bin/test-package:10` `refuse()`, `:19` mu-plugins refusal, 77 lines → holds
- `scaffold-meta.sh:435` `scaffold_wp_starter`, `:548-553` `cp -p` + two-token sed over `find "$starter/gate" -type f` → holds
- `new-site.sh:2` `set -euo pipefail`, `:202-203`, `:514-523` wptests inline, `:557-568` baseline step, `:576` red gate `exit 1`, `:590` commit → holds
- `ARCHITECTURE-INVARIANTS.md:13-19` INV-1, `:17` manifest wiring only → holds
- `wp-testing/SKILL.md:35` one gate two shapes, `deps:latest` wording; `:91` item 4 → the plan contradicts neither → holds
- laika `composer.json`: `roots/wordpress "6.8.2"`, `wp-phpunit "~6.8.0"` exact pins → holds
- `DataLayerRoundTripTest.php:21-31` wptests test → holds
- `gate/bin/js-gate.sh:23-32` marker at root, requires `{{GATE_CONTENT_DIR}}/themes` to exist → holds
- Host tools: jq 1.7, Composer 2.8.9, DDEV v1.25.5, PHP 8.3.6, PHPStan 2.2.7 (laika vendor) → holds

---

# Earlier review (superseded by round 3 — every finding below landed in the plan)

# Plan review — package-gate (wp-starter: the gate's package shape, `deps:latest`) — round 2

Reviewed-plan: 4d141f77da1cc64b10ab3063be4a01a139d268cf specs/package-gate/plan.md
Verdict: not ready

## Round 1's findings, checked against this blob

- **B1** — landed as written. Global Constraints `:27` names `gate` + the ten tiers as shape-owned; Task 1 Step 4 `:117` sets `gate:package` from a differing former `gate`, then `.scripts = ((.scripts // {}) + ($gate.scripts))`; test (d) `:105` has the `own-gate` fixture (`gate:package == ["@syntax","@test"]`, `lint == "phpcs"`), (g) `:108` the re-entry. Verified with jq 1.7: `+` is right-wins, so the eleven keys take the shape's value and `test` stays; a second run does not re-wrap (`gate` is already `sh bin/gate.sh`).
- **S1** — landed. `:23` the lint sweeps `package-gate/` from Task 4; `:87`/`:97` the three fragments are tokenized; `:117` "render() … the two fragments … rendered composer fragment"; (c) `:104` `grep -rl '{{'` empty; Task 4 Step 1 `:242`. No literal left in the overlay list: `config/application.php`'s `'/app'`, `'/web'`, `'/wp/'` and `web/index.php`'s `'/wp/wp-blog-header.php'` do not match `\b(web|app)/(wp|app|content)\b`; the testbed's `bootstrap-site.php:14` literal goes with `$ntdstPackageDir` (`:81`).
- **S2** — landed. `:79` guarded hook (`[ -f {{GATE_WP_DIR}}/wp-load.php ] || … exit 0`), `:117` next steps `composer install` → `npm install` → `ddev start`, `:190` Step 1 in that order, `:273` README. Verified: `ddev exec pwd` = `/var/www/html` (so the relative guard and a root `wp-cli.yml` resolve), `DDEV_PRIMARY_URL` is exported in the web container (`ddev exec printenv` on laika → `https://laika.ddev.site`), `name:` in `config.local.yaml` overrides (`ddev debug configyaml` on a scratch project).
- **S3** — landed. `:83` asserts on `wp_get_mu_plugins()`; `wp-includes/load.php:970` returns `WPMU_PLUGIN_DIR . '/' . $plugin`, and `WPMU_PLUGIN_DIR` defaults to `WP_CONTENT_DIR . '/mu-plugins'` (`default-constants.php:212-213`) with `WP_CONTENT_DIR` = `<root>/web/app` from `gate/tests/wp-tests-config.php:27`.
- **S4** — landed. `:97` `/{{GATE_CONTENT_DIR}}/debug.log`, `/test-results/`, `/playwright-report/`.
- **S5** — landed in form (`:214` each unreached tier by name, `:215` "all eleven with their exit codes") — but the expectations written for `test:unit` and `gate:package` are false in source: see B1 below.
- **S6** — landed. `:28` kept tier configs, `:69` "Tier configs the package may keep", (b) `:103` `kept: phpcs.xml`, `:215` "as `composer lint` already did on main". Neither package has a `phpunit.unit.xml` (core root: `phpunit.xml` only; baseline root: `phpunit.xml` only), so the overlay's never conflicts; core's `phpunit.xml` (`tests/Unit` under `tests/bootstrap.php`) is untouched and still what `@test` runs.
- **S7** — partly. The expected lines are right (`:208` detail view, `versions : * 7.1.3`, `latest : 7.1.4`; wildcard `!`/`~` at `:160`), but the RED and GREEN commands do not do what the step says — see S1 below.
- **S8** — landed. Close 5 `:296` names the bedrock/stackedWP constraint follow-up as manifest wiring INV-1 permits (`ARCHITECTURE-INVARIANTS.md:17`), README §6 `:273` the site-shape note, `:160` the "constraint widened first" sentence. Precision missing: at `new-site.sh:576` a red gate is `exit 1` under `set -euo pipefail` (`:2`) — the scaffold aborts before the commit at `:590` and leaves the project (`:202-203`). See Note.
- **S9** — landed. `:25` Global Constraints, `:117` `git -C "$root" check-ignore -q composer.lock && echo "note: …"`, fixture `git init -q` `:101`, case (f) `:107`. The `&&` list is not the script's last statement, so `set -e` does not fire on a non-ignored lock.
- **S10** — partly. The counts are now consistent with each other (`:22` four then five, `:52`, `:248`, `:292`) and the summary lines match the sibling (`:101`, `:126` vs `tests/js-gate.test.sh:113`) — but the count is wrong by one, because Task 4 Step 1 edits `gate/bin/lint-tokens.sh`, a payload file. See S2 below.
- Round-1 notes: third token owned (`:23`), scaffold reading owned (`:23`), R9 `*` reading (`:27`), PHPUnit-10 deprecation recorded (`:26`, `:196`), "behind … or unresolvable" (`:160`), delivery seam closed (`:37`), host `gate` command stale by rule (`:22`), "77 lines" (`:42`), simpler sub-design adopted (`:28`, `:42`) — all landed.

## Blocking

**B1 — Task 3 Step 5 expects `test:unit` and `gate:package` green on the rendered core; both are red by core's own tree sweeps, which now see a WordPress.**
Plan `:215`: "`test:unit` green (core's Brain Monkey suite through `phpunit.unit.xml`); `gate:package` green (core's `@syntax @test @guard @audit:deps`)"; Global Constraints `:27` keeps the former `gate` "so its own checks (core's `@syntax @guard` …) keep running as a tier".
Source, after the render puts WordPress at `web/wp`, twentytwentyfive at `web/app/themes/` and `node_modules/` at the root:
- ntdst-core `origin/main:bin/guard.sh:12` `grep -rL "defined('ABSPATH')" --include='*.php' . | grep -v vendor | grep -v tests/bootstrap.php` — excludes nothing under `web/` or `node_modules/`: 1,065 WordPress files and 99 theme files lack the guard (counted on laika's 6.8.2 + twentytwentyfive 1.5), and so do the shape's own `config/application.php`, `web/wp-config.php`, `web/index.php`, `tests/bootstrap-integration.php`, `tests/wp-tests-config.php`, `tests/bootstrap-site.php`, `tests/Integration/LoaderTest.php` (core's `tests/` is swept — only `tests/bootstrap.php` is exempt; core's own test files carry the guard, e.g. `tests/Unit/BootstrapOverridesTest.php:43`). `:255-260` the removed-symbol grep excludes only `/vendor/`, `tests/`, `specs/` and its `RETIRED_TYPES` (`'type' *=> *'string'` …) hits WordPress's REST controllers (532 such lines in `wp-includes/rest-api` alone). So `@guard` → `gate:package` is red.
- ntdst-core `origin/main:tests/Unit/PackageBootIntegrityTest.php:1051-1065` `sweep()` and `:1432-1438` `shippedFiles()` walk `dirname(__DIR__, 2)` skipping only `/vendor/`, `/tests/`, `/specs/`; the provider's retired-type rows `:135-144` are the same regexes, and the bare row `get_nonce` matches `wp-includes/class-wp-customize-manager.php:2178` `get_nonces()`. So `test:unit` (overlay `phpunit.unit.xml` → `tests/Unit`) and `@test` inside `gate:package` are red.
Neither red is "core's finding" the way `analyse` is: it is the shape's render colliding with sweeps written for a tree without `web/`. The plan may write nothing into core (`:21`), and a `.gitignore` line does not hide a path from `grep`. Smallest change: Step 5's expectation names both reds and their cause (a package's root-walking sweeps must exclude `web/` and `node_modules/`), recorded as plan 5's first adoption step (`guard.sh:12`/`:255-260` and the test's two path filters); README §6 `:273` gains that adoption rule beside "commit the lock"; the Test map row 2 wording "every tier run and reported" stands. If Stefan would rather the proof be green, the only in-plan alternative is to expect `gate:package` red and strike "keep running as a tier" from `:27`'s justification.

## Should fix

**S1 — Task 3 Step 4's RED and GREEN commands do not move the lock, and the tier's fix line cannot move `roots/wordpress`.**
Plan `:207` RED `composer require --dev roots/wordpress:7.1.3 --no-interaction`; `:209` GREEN `composer require --dev roots/wordpress:'*' --no-interaction`; `:160` the message `fix: composer update$behind`; `:273` README row "`composer update <names>`".
Source (Composer 2.8.9, scratch package with `require-dev.roots/wordpress: *`): `roots/wordpress` is a metapackage requiring `roots/wordpress-no-content: self.version` (laika lock). The RED command fails — "Use the option --with-all-dependencies (-W) … Installation failed, reverting ./composer.json and ./composer.lock" — the constraint stays `*`, the lock stays 7.1.4, `deps:latest` stays green, no RED. With `-W` it downgrades both and the step's expected output appears (`versions : * 7.1.3`, `latest : 7.1.4`, rc=1). The GREEN command without `-W` leaves the lock at 7.1.3 (still red). And `composer update roots/wordpress` prints "Nothing to modify in lock file" (lock stays 7.1.3); `composer update roots/wordpress -w` → 7.1.4. Smallest change: `-W` on both Step 4 commands; `--with-dependencies` in `deps-latest.sh`'s fix line and the README row (`composer update <names> --with-dependencies`); deps-latest test (b)'s "fix line" assertion carries the flag.

**S2 — The intended-delta count misses `gate/bin/lint-tokens.sh`, a payload file.**
Plan `:22` four deltas; `:248` "differences in exactly four files"; `:292` five at the Close; Test map `:52`. Source: Task 4 Step 1 `:242` edits `gate/bin/lint-tokens.sh:20`; `scaffold_wp_starter` copies every file under `gate/` (`scaffold-meta.sh` step 3, `find "$starter/gate" -type f`), and sites carry it (laika `bin/lint-tokens.sh`). Step 2 runs after Step 1, so `diff -rq` shows five files at Task 4 and six at the Close. Smallest change: list it as the fifth intended delta at `:22`; five at Task 4 Step 2, six at Close 1 and in row 5.

## Note

- **Close 5 says "goes red"; the scaffold aborts.** `new-site.sh:576` `(cd "$PROJECT_DIR" && composer gate) || { …; exit 1; }` under `set -euo pipefail` (`:2`) — no commit (`:590`), project left for inspection (`:202-203`). Say "aborts at step 13" so the template follow-up reads as the precondition for any scaffold after the merge, which is what it is.
- **`grep -v '{{PACKAGE}}'` in the lint (`:242`) opens a hole no overlay line needs.** The two existing excludes exist for prose that names tokens beside literals (`lint-tokens.sh:5`); no planned line carries `{{PACKAGE}}` and a layout literal together (the shim and `LoaderTest` build paths from `dirname(__DIR__, 3)` / `WPMU_PLUGIN_DIR`). With the exclude, a future `web/app/mu-plugins/{{PACKAGE}}loader.php` prose line passes. Drop it, or state the line it is for.
- **`composer gate` on an adopted package runs the unit suite twice** — once as `test:unit` through the overlay's `phpunit.unit.xml` (`tests/Unit`), once as `@test` inside `gate:package` through core's `phpunit.xml` (`tests/Unit`). Harmless; Step 5's report should expect it rather than discover it.
- **The jq merge rewrites the whole `composer.json`** at 2-space indent with unescaped unicode (core's file is 4-space with `—`); the adoption diff is the entire file. `jq --indent 4` matches Composer's own writer. Test (g)'s byte-identical re-run still holds either way.
- **`phpstan.neon` "the same excludes" (`:85`)** — the gate's `excludePaths` are content-dir paths (`gate/phpstan.neon:55-89`) and do not cover `paths: [.]`; the phpcs line before it lists `*/web/*`, `*/vendor/*`, `*/node_modules/*`, `*/.phpstan-cache/*`. Write those under `analyseAndScan` explicitly (`web/* (?)` form) so the fallback does not analyse `web/wp`.
- **`.gitattributes.gate` appends `/phpcs.xml` and `/phpstan.neon` export-ignore** (`:97`) even when the package kept its own (`:103`). Harmless for a dist install, but the appended list is the shape's, not what the renderer wrote; one sentence, or append only the written paths.
- **`gate:package` skip vs `js-gate.sh`'s stance** (`:162`, `js-gate.sh:17-45`): consistent — the skip is printed, never silent, and `composer.json` is the declaration; the detection `composer run-script --list | grep -qE '^ *gate:package( |$)'` matches Composer's two-space-indented listing (verified on laika: `gate` matches, `gate:package` does not).
- **`composer/installers` is not in the fragment** (`:89`); it arrives transitively through `wpackagist-theme/twentytwentyfive` (`require: composer/installers ^1.0 || ^2.0`, laika lock), so `installer-paths` applies. Fine; Step 1's "Task 3 corrects the list" covers it.
- **Coverage, invention, test map, simplest design, proof-not-adoption** — re-judged, no finding: R8's file list is Task 1; R9 is Task 2 (tier order, lock-read, the three patterns) with Task 3 as the live run; R17's gate half contradicts neither `wp-testing/SKILL.md:35` nor `:91` (item 4); Decision 6 is the B1 fix plus `gate-tiers.test.sh`, 10 the lift from the testbed, 11 the red tier. The third token (`:23`), the install hook (`:29`, `:38`), `LoaderTest` (`:36`) and `gate:package` (`:27`) each have an owning sentence. Every Test map row is a test or a stated "none"; the denial cases run RED first (`:113`, `:156`, `:243`). Task 3 commits nothing to core and deletes the clone (`:224`). The simplest-design paragraph is honest and "package's own tier config wins" is now in it.

## Premises checked

- `gate/bin/gate.sh:3-4` order comment, `:15` TIERS, `:19-24` dispatch, `:25-28` fail-fast → holds
- `gate/bin/lint-tokens.sh:20` paths and regex; no overlay line in Task 1 Step 1 matches the regex → holds
- `gate/tests/bootstrap-integration.php:61` wp-phpunit require; `wp-tests-config.php:23-25` blank line after `declare` → holds
- `tests/js-gate.test.sh` style; summary `:113` `js-gate.test: N ok, 0 failed` → holds, plan matches
- `.github/workflows/ci.yml:22` loop, `:28` `js-gate behaves` → holds
- `README.md:20-34`, `:187`; `gate/README-testing.md:10` nine tiers, `:99-101` §4c, `:108-110` §4f → holds
- `gate/.ddev/commands/host/gate:3` "9-tier" → holds (stays stale by rule)
- `gate/bin/js-gate.sh:23-32` marker needs `{{GATE_CONTENT_DIR}}/themes` → holds (twentytwentyfive lands there via installers)
- `gate/bin/e2e.sh:17` reads `DDEV_PRIMARY_URL` from the container, `:37-39` seeds → holds; the variable exists in the web container → holds
- `gate/phpunit.unit.xml:18` `tests/Unit`, `:4` bootstrap; core's tests live in `tests/Unit/` → holds
- `gate/phpcs.xml`, `gate/phpstan.neon:55-89` excludes are content-dir paths → holds (see Note on `paths: [.]`)
- `gate/tests/Integration/DataLayerRoundTripTest.php:21-30` → holds
- `gate/tests/E2E/smoke.spec.ts:42-43` visible header/nav on `/`, `:47` `/wp/wp-login.php` → holds
- `gate/.ddev/config.gates.yaml:17` wptests hook; DDEV merges `hooks` from both files → holds (round 1)
- DDEV `exec` hook cwd = project root (`ddev exec pwd` → `/var/www/html`); `name:` overridable in `config.local.yaml` → holds
- `composer run-script --list` prints `  <name>  <description>`; `^ *gate:package( |$)` matches → holds
- jq: `(.scripts // {}) + $gate.scripts` right-wins on the eleven keys, other keys kept; re-entry does not re-wrap → holds
- ntdst-core `composer.json:29-34` `gate` = `@syntax @test @guard @audit:deps`, `:26` `lint` = `phpcs`, `:16` PHPUnit `^10.5`; baseline `:26-32` gate, `:23` lint `php -l`, `:14` core `^5.4` in `require` → holds
- ntdst-core `.gitignore:4` `composer.lock` → holds (plan `:25` says so)
- ntdst-core `phpcs.xml:12-17` explicit dirs (unaffected by `web/`), `:27` `testVersion 8.1-` → holds
- ntdst-core `phpunit.xml:3` `tests/Unit`; no `phpunit.unit.xml` in either package root → holds
- "`gate:package` green on core (`@syntax @test @guard @audit:deps`)" → `bin/guard.sh:12`, `:255-260` sweep `web/wp` and the shape's PHP → **does not hold (B1)**
- "`test:unit` green on core through `phpunit.unit.xml`" → `tests/Unit/PackageBootIntegrityTest.php:1051-1065`, `:1432-1438` walk the root skipping only vendor/tests/specs → **does not hold (B1)**
- `composer require --dev roots/wordpress:7.1.3` rewrites the constraint and downgrades → **does not hold without `-W`** (reverts; `roots/wordpress-no-content: self.version`) **(S1)**; with `-W` → detail view `versions : * 7.1.3` / `latest : 7.1.4`, rc 1 → holds
- `composer update roots/wordpress` moves the lock → **does not hold** ("Nothing to modify"); `-w` → 7.1.4 **(S1)**
- `composer outdated --locked --direct --strict <single>` up to date → rc 0, detail view; wildcard behind → one `!` line, rc 1 → holds
- `wp_get_mu_plugins()` in `wp-includes/load.php:970`, full paths; `WPMU_PLUGIN_DIR` = `WP_CONTENT_DIR . '/mu-plugins'` (`default-constants.php:212-213`) → holds
- `wpackagist-theme/twentytwentyfive` requires `composer/installers`; `roots/wp-config` has no deps → holds
- testbed `config/application.php:37-55` dotenv block, `:79` `CONTENT_DIR '/app'`, `:165` ABSPATH; `web/wp-config.php`; `web/index.php:7`; `wp-cli.yml`; `tests/bootstrap-site.php:13-24`; `.ddev/config.yaml:1-16`; `bin/test-package:10`, `:19`, 77 lines → holds
- `scaffold-meta.sh` `scaffold_wp_starter` step 3 copies every `gate/` file (`lint-tokens.sh` included — laika `bin/`) → holds, and makes the delta count five **(S2)**
- `new-site.sh:576` red gate → `exit 1` under `set -euo pipefail` (`:2`), before `:590` commit → holds (Close 5 should say "aborts")
- `ARCHITECTURE-INVARIANTS.md:13-19` INV-1 manifest wiring only in stack templates → holds
- `wp-testing/SKILL.md:35` one gate two shapes, `:91` item 4 package DDEV recipe; plan contradicts neither → holds
- laika `composer.json`: `roots/wordpress 6.8.2`, `wp-phpunit ~6.8.0` exact pins; scripts/config/extra match the fragment → holds
- Host tools: Composer 2.8.9, jq 1.7, DDEV v1.25.5, PHP 8.3.6 → holds

---

# Earlier review (superseded by rounds 2 and 3 — every finding below landed in the plan)

# Plan review — package-gate (wp-starter: the gate's package shape, `deps:latest`)

Reviewed-plan: 72156aeaa12bbddf835c1b3d4c252923c9473309 specs/package-gate/plan.md
Verdict: not ready

## Blocking

**B1 — "Package wins on every key" leaves both adopters on their old `composer gate`; Task 3 Step 6 and Decision 6 cannot hold.**
Plan: Task 1 Step 4 (`$gate.scripts + (.scripts // {})` — "package values win on every key"), Global Constraints line 27 ("a key the package already has keeps its value"), Task 3 Step 6 (`composer gate; echo rc=$?` → "every tier reached or the first red named … `gate: all tiers green`").
Source: ntdst-core `origin/main:composer.json:29-34` already defines `scripts.gate` = `["@syntax","@test","@guard","@audit:deps"]`; ntdst-baseline `origin/main:composer.json:26-32` defines `scripts.gate` = `["@composer show 'netdust/*'","@lint","@test","@guard","bash bin/check-invariants.sh"]` and `:23` `scripts.lint` = `php -l`.
After the render, `composer gate` on either package still runs the package's own four-step gate — never `sh bin/gate.sh` — and `composer lint` on baseline stays `php -l`, so the shape's `phpcs.xml` is never run. Task 3 Step 6 cannot produce the tier-by-tier run it expects, and Decision 6 (`composer gate` is the whole Close) is false on day one for the two named adopters. The fixture in Step 2 (d) has no `gate`/`lint` script, so the test passes while the real packages fail.
Smallest change: name the gate-owned script keys (`gate` and the ten tier names) as keys where the fragment wins — or make a pre-existing `scripts.gate` with another value a listed conflict the renderer refuses on, and add `scripts.gate` to Task 3 Step 1's throwaway cleanup; add a fixture case to (d) with a pre-existing `scripts.gate`/`scripts.lint`.

## Should fix

**S1 — The fragments cannot be both literal (lint red) and tokenized (test (c)/(d) red).** Task 1 Step 1 writes literal `web/wp` / `web/app` into `wp-cli.yml` (`path: web/wp`), `composer.gate.json` (`web/app/mu-plugins/{$name}/`, `"wordpress-install-dir": "web/wp"`), `.gitignore.gate` (`/web/wp`, `/web/app/plugins` …) and `.gitattributes.gate` (`/web`). Task 4 Step 1 adds `package-gate/` to `gate/bin/lint-tokens.sh:20`, whose regex `\b(web|app)/(wp|app|content)\b` matches every one of those lines — so "token lint: clean" at Task 4 Step 1 and Close 1 cannot hold. If the fragments are tokenized instead, Step 4's renderer never renders them (the three fragment files are excluded from the file list and appended with `grep -qxF` / merged with `jq` straight from the source), so test (c) `grep -rl '{{'` empty and (d) `.extra."wordpress-install-dir" == "web/wp"` fail. Smallest change: tokenize the three fragments and run them through the same token pass into a temp file before the append/merge; state it in Step 4.

**S2 — Task 3 Step 1 starts DDEV before Composer has put WordPress at `web/wp`; the install hook and the `is-installed → 0` expectation fail.** Plan: Task 3 Step 1 (`ddev start` … `ddev exec wp core is-installed; echo $?` → 0) before Step 2's `composer install`; the same order in the renderer's "next steps" (Task 1 Step 4) and the README §6 adoption lines (Task 5 Step 1). `.ddev/config.package.yaml`'s `post-start` runs `wp core is-installed || wp core install` against `wp-cli.yml` `path: web/wp` — absent until `composer install`, so both fail (DDEV continues; `fail_on_hook_fail` defaults false) and the site stays uninstalled; `gate/bin/e2e.sh:37-39` then has nothing to seed. Smallest change: `composer install` (host) before `ddev start`, or `ddev restart` after it, in Step 1, the renderer's next steps and README §6; guard the hook with `[ -f web/wp/wp-load.php ]`. (`ddev auth ssh` in Step 2 is for in-container composer; a host install uses the host agent.)

**S3 — `LoaderTest` calls `get_mu_plugins()`, which is not loaded in the integration process.** Plan: Task 1 Step 1 (`assertArrayHasKey('{{PACKAGE}}loader.php', get_mu_plugins())`). wp-phpunit 7.1.3 `includes/bootstrap.php:301` loads `wp-settings.php` only; none of `bootstrap.php`, `abstract-testcase.php`, `functions.php`, `testcase.php` requires `wp-admin/includes/plugin.php` (only `install.php:42` loads `upgrade.php`, in its own subprocess). The test fatals on an undefined function before the RED/GREEN of Step 3. Smallest change: assert on `wp_get_mu_plugins()` (`wp-includes/load.php`, always loaded, returns full paths), or `require_once ABSPATH . 'wp-admin/includes/plugin.php'` in the test.

**S4 — `.gitignore.gate` misses what the shape itself writes.** Plan: Task 1 Step 1 list. `config/application.php` sets `WP_DEBUG_LOG` true inline → WordPress writes `web/app/debug.log` on the first notice; Playwright leaves `test-results/.last-run.json` on every run (`~/Sites/laika/test-results/.last-run.json`; Bedrock's gitignore covers both: `laika/.gitignore:18` `*.log`, `:34-35` `/test-results/`, `/playwright-report/`). Smallest change: add `/web/app/debug.log` (or `*.log`), `/test-results/`, `/playwright-report/`. The rest of the list matches what Composer and DDEV write (DDEV self-ignores under `.ddev/.gitignore`; `web/.htaccess` is never written under nginx-fpm).

**S5 — Task 3 Step 6 claims tiers it never ran.** Plan: "Either way `test:unit` …, `deps:latest`, `test:int` and `test:e2e` have each run green in Steps 3–5". Steps 3–5 run `test:int`, `test:e2e`, `deps:latest` only; `test:unit`, `lint:js`, `test:js`, `build:check`, `audit:deps` run only inside `composer gate`, which stops at the first red (`gate/bin/gate.sh:25-28`) — and the plan expects `lint`/`analyse` red on core. The "red there is plan 5's finding" clause is honest only if the later tiers are still exercised. Smallest change: when the gate stops early, Step 6 runs each remaining tier by name (`composer run-script <tier>` / the `ddev` mirrors) and reports each.

**S6 — The overlay `phpcs.xml` replaces a stricter one on core and weakens the PHP floor.** Plan: Task 1 Step 1 (PSR-12 on `tests/` only, `testVersion` 8.3 — the site posture) and Review Focus "Boundary" (core's `phpcs.xml` is a conflict to refuse on; Task 3 Step 1 deletes it). ntdst-core `origin/main:phpcs.xml:12-27` runs PSR-12 + Security + DB + PHPCompatibilityWP over all its source with `testVersion 8.1-`, matching `composer.json:13` `php >=8.1`; `composer.json:26` already runs it as `composer lint` (so Step 6's "for the first time" is wrong). The shape's file would pass 8.2/8.3-only syntax on a package whose floor is 8.1. Smallest change: a package's own `phpcs.xml` (and `phpunit.xml`) wins — skip, not refuse — with the overlay as the fallback; the "Boundary" row then names a different conflict file.

**S7 — Task 3 Step 5's expected composer line does not exist.** Plan expects `roots/wordpress 7.1.3 ~> 7.1.4`. For a single named package `composer outdated --locked --direct --strict roots/wordpress` prints the detail view (`versions : * 6.8.2` / `latest : 7.1.4 released …`, rc 1 — verified on `~/Sites/laika`); the one-line list form (`netdust/ntdst-baseline 2.17.0 ! 2.21.3`) appears only for wildcard filters, and composer's markers are `!`/`~`, not `~>` (`composer outdated --help`, Legend). Smallest change: fix the expected lines in Step 5 and the README row.

**S8 — The site shape goes red at birth and on every existing site, and the tier's fix line cannot fix it.** Plan: Close 5 ("Nothing to sync … sites born after the merge get the tier"), Task 5 §1 row ("fix: `composer update <names>`"). Every site pins `roots/wordpress` exactly (`laika/composer.json` `"roots/wordpress": "6.8.2"`, `"wp-phpunit/wp-phpunit": "~6.8.0"`; nine of eleven local sites at an exact 6.8.2–7.1) — the Bedrock template's pin style. `composer outdated --strict` counts a version outside the constraint (verified), so `new-site.sh` step 13's first `composer gate` and every hand-adopting site are red at `deps:latest`, and `composer update roots/wordpress` cannot move an exact pin. R9 wants both shapes; the plan must say what that costs. Smallest change: `deps-latest.sh`'s message names the constraint edit when composer marks `~`; the Close names the `netdust/bedrock` / `stackedWP` manifest follow-up (a constraint, i.e. the manifest wiring INV-1 permits there — `ARCHITECTURE-INVARIANTS.md:17`).

**S9 — core gitignores `composer.lock`; the shape's lock premise fails silently on adoption.** Plan: Global Constraints line 25 ("a package without `composer.lock` is red"), Decision 11's "the packages commit their lock". ntdst-core `origin/main:.gitignore:4` = `composer.lock` (baseline commits one, `.gitattributes:6` export-ignores it). On the throwaway `composer install` writes a lock locally so Steps 5–6 pass, but Step 7's "what a source checkout carries" lacks it and a rendered core never commits one. Smallest change: the renderer refuses (or warns) when `git -C "$root" check-ignore -q composer.lock` succeeds; README §6 lists "commit the lock" as an adoption step; the Premises line records that the spec's "both packages commit composer.lock" does not hold for core.

**S10 — Three counts for one diff.** Global Constraints line 22 "three intended deltas" enumerates four; Task 4 Step 2 "exactly four files … plus `README-testing.md`" (five at Close); Test map row 5 "the four intended files". Also Task 1 Step 6 expects `js-gate: all passed` but the sibling prints `js-gate.test: N ok, M failed` (`tests/js-gate.test.sh:113-115`). Smallest change: one count per moment (four at Task 4, five at Close) and the sibling's real summary line.

## Note

- **Task 3 as proof, not adoption:** sound — a deleted clone, nothing committed to core, within "no package adopts the shape in this plan" — once B1 is fixed; before that it proves core's old gate, not the shape's.
- **Third token:** `{{PACKAGE}}` deviates from R8's "the same two tokens"; R8's own `<package>loader.php` placeholder needs it. One sentence in Global Constraints should own the deviation. Likewise R8 says "the scaffold renders it" and the plan renders from wp-starter's `bin/package-gate.sh`, not `scaffold_wp_starter` — inside "Left to the builder", but say so.
- **R9's "`*` in require-dev":** baseline carries core in `require` at `^5.4` (`origin/main:composer.json:14`); the plan's "require is never touched" is the right reading, and `--strict` still goes red on a tag outside `^5.4` (verified), so the rule bites; whether baseline moves to `*` is plan 6's.
- **PHPUnit 10.5.64 and the 9-schema XMLs:** `gate/phpunit.integration.xml:5` and the overlay's `phpunit.unit.xml` (`cacheResultFile`) validate against a deprecated schema; on 10.5 that is a test-runner *deprecation* (`vendor/phpunit/phpunit/src/TextUI/Configuration/Merger.php:713-717`), and `hasWarnings()` counts only test/PHP warnings, so `failOnWarning` does not trip — the proof prints it every run; record it with the §4f fact. PHPUnit 10 then writes `.phpunit.result.cache` (both packages ignore it already).
- **`deps-latest.sh` conflates "could not resolve" with "behind":** any non-zero composer exit (no SSH agent, offline) is reported as behind; the echoed output shows which — one word in the message ("behind or unresolvable") would do.
- **Delivery seam:** the plan's reasoning covers files; the manifest keys the fragment adds (`require-dev`, `config`, `extra.installer-paths`, `repositories`, `scripts`) are root-only in Composer and so inert in a consumer — one sentence closes the seam.
- **DDEV mirrors:** `gate/.ddev/commands/host/gate:3` says "9-tier" and `README-testing.md:10` "nine tiers"; Task 5 fixes the README, the host command stays stale under the "site shape unchanged" constraint — say so.
- **"`bin/test-package` proved a renderer is 60 lines":** it is 77 lines and a swap-in runner; the point (a small script suffices) stands.
- **Simplest design:** honest; the README-only alternative is rightly rejected (two adopters now, two more on the testbed). The one simpler sub-design not considered is "package wins" for its own tier configs (S6), which also dissolves the day-one conflict on core.
- **Execution-time ruling likely:** whether wp-phpunit 7.1.3's test case runs on PHPUnit 10.5 — the plan handles it as a Step 2/3 fact with a throwaway-only fallback; good.

## Premises checked

- `gate/bin/gate.sh:15` TIERS, `:19-24` per-tier dispatch, `:25-28` fail-fast → holds
- `gate/tests/bootstrap-integration.php:61` is the wp-phpunit require → holds
- `gate/tests/wp-tests-config.php:24` "after the header" (blank line after `declare` at :23; testbed's line at `:25-27`) → holds
- `gate/bin/lint-tokens.sh:20` grep paths; regex matches `web/wp`, `web/app` literals → holds (and bites the fragments, S1)
- `.github/workflows/ci.yml:22` first-job loop, `:28` `js-gate behaves` → holds
- `README.md:20-34` gate bullet + tree, `:187` lint sentence → holds
- `gate/README-testing.md:10` nine tiers, `:99-101` §4c restart, `:108-110` §4f 9.6 ceiling → holds
- `gate/bin/js-gate.sh:23-32` marker needs `{{GATE_CONTENT_DIR}}/themes` present → holds (only after `composer install` on a package)
- `tests/js-gate.test.sh` style (`fixture`/`run`/`check`, PASS/FAIL, temp dir) → holds; summary line `:113` differs from the plan's
- `gate/phpstan.neon:11` includes `phpstan-baseline.neon`; not in `gate/`; `new-site.sh:557-568` template ships and regenerates it → holds
- `gate/phpcs.xml:23-24`, `gate/phpstan.neon:61-63` exclude `mu-plugins/ntdst-*` → holds
- `gate/.ddev/config.gates.yaml:17` wptests hook; `new-site.sh:514-523` inline mirror → holds
- DDEV merges `hooks` from several `config.*.yaml` → `ddev debug configyaml` on a scratch project with `config.gates.yaml` + `config.package.yaml`: `post-start:[exec:echo gates, exec:echo package]` → holds (DDEV v1.25.5)
- `gate/.ddev/commands/host/gate` exists → holds
- `gate/tests/Integration/DataLayerRoundTripTest.php:21-31` wptests test → holds
- `gate/bin/e2e.sh:32` per-run Node password, `:37-39` seeds via `ddev exec wp user create` → holds (needs an installed site, S2)
- `mu-plugins/ntdst-coreloader.php:44` requires `__DIR__ . '/ntdst-core/ntdst-core.php'` → holds
- testbed `bin/test-package:10` `refuse()`, `:19` mu-plugins refusal → holds (77 lines)
- testbed `config/application.php:37-55` dotenv block, `:14-17` `env()`; `config/environments/development.php:11-17`; `web/wp-config.php`; `web/index.php`; `wp-cli.yml` → holds
- testbed `tests/bootstrap-site.php:13-24` (TESTBED_PACKAGE, early return without `site.php`), `tests/bootstrap-integration.php:58-59` F8 require, `tests/wp-tests-config.php:25-27` autoloader → holds
- testbed `.ddev/config.yaml:1-16` keys the plan lists → holds
- `scaffold-meta.sh` `scaffold_wp_starter` (from :435) step 3: copy every `gate/` file, `cp -p`, sed the two tokens → holds
- `ARCHITECTURE-INVARIANTS.md:13-19` INV-1 "manifest wiring only" in stack templates; a tier wired inside `gate.sh` touches none → holds
- "both packages pin `phpunit/phpunit ^10.5`" → core `composer.json:16`, baseline `:40` → holds; core's require-dev = PHPUnit, Brain Monkey, PHPCS → holds
- "`tests/bootstrap.php` is the convention both follow" → both at `origin/main` → holds
- "both export-ignore `tests/`" → core `.gitattributes:1`, baseline `.gitattributes:2` → holds
- "both packages commit `composer.lock`" (spec constraint, Decision 11) → core `.gitignore:4` ignores it; baseline commits it → does not hold for core (S9)
- "`composer gate` after the merge is `sh bin/gate.sh`" → core `composer.json:29-34`, baseline `:26-32` already define `scripts.gate` → does not hold (B1)
- core `phpcs.xml` exists (the Boundary conflict case) → holds; `:23-27` PSR-12 on all source, `testVersion 8.1-` (S6); baseline has none
- laika `composer.json` `scripts`, `require-dev`, `config`, `extra` match the fragment lines → holds; `require.roots/wordpress = "6.8.2"` exact (S8)
- `composer outdated --locked --direct --strict '<wildcard>'`: no match → rc 0, empty; match behind → rc 1 + list line; single package behind → rc 1 + detail view → holds (Composer 2.8.9, on laika)
- newest `roots/wordpress` 7.1.4 (7.1.3 exists), newest `wp-phpunit/wp-phpunit` 7.1.3 → holds
- wp-phpunit 7.1.3 `includes/bootstrap.php:50` PHPUnit ≥ 5.7.21, `:142` polyfills ≥ 1.1.0 → holds
- `dirname('<root>/web/wp/', 2)` → `<root>` (PHP 8.3.6) → holds
- jq: `$gate + $pkg` / `$gate * $pkg` right-hand wins; `.repositories` dedupe by url (`index($u) | not` false for any found index, 0 included) → holds (jq 1.7)
- `get_mu_plugins()` defined in the integration process → wp-phpunit 7.1.3 loads no `wp-admin/includes/plugin.php` → does not hold (S3)
- `.ddev/config.local.yaml` worktree rule → `netdust-devops/skills/parallel-work/SKILL.md:87` → holds
- one gate, two shapes → `netdust-wp/skills/wp-testing/SKILL.md:35`, `:91`; the plan contradicts neither → holds
- WordPress pack trigger → `netdust-gates/skills/policy/SKILL.md:68-69`; wp-starter has no `composer.json` → pack does not apply → holds
- `gate/tests/E2E/smoke.spec.ts:47` logs in at `/wp/wp-login.php` → matches `web/wp` → holds
- site gitignore covers `*.log`, `/test-results/`, `/playwright-report/` (laika `.gitignore:18,34-35`); Playwright leaves `test-results/.last-run.json` → the plan's list misses them (S4)
- Host tools: Composer 2.8.9, jq 1.7, DDEV v1.25.5, PHP 8.3.6 → holds
