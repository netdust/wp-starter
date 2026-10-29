# Testing & quality gates — reference card

For a developer who just cloned a project scaffolded from this template.
One rule above all: **the gate's exit code is the truth.** Every check an agent
or CI loop runs is a tier of `composer gate` — no check runs anywhere that
`gate` doesn't run.

## 1. The gates

`composer gate` (mirror: `ddev gate`) runs all eleven tiers cheapest-first,
fail-fast, from the **host**: the first red tier stops the run, names itself on
stderr, and propagates its real exit code (`bin/gate.sh`).

| Tier | Command | DDEV mirror | What it checks | Where it runs | Typical time |
|---|---|---|---|---|---|
| 1 | `composer lint` | `ddev lint` | phpcs: WordPress Security/DB sniffs on `tests/` and our own mu-plugins + themes; PSR-12 + PHP-compat (8.3) on `tests/` only (see phpcs.xml) | either | < 1 s |
| 2 | `composer lint:js` | `ddev lint-js` | ESLint + Stylelint, per theme package | either | ~1 s |
| 3 | `composer analyse` | `ddev analyse` | PHPStan static analysis | **host only** — the phpstan cache is context-coupled; a container run poisons the mounted cache for the host-orchestrated gate | ~1 s |
| 4 | `composer audit:deps` | `ddev audit` | `composer audit` + `npm audit --audit-level=high` (theme) | either | ~3 s |
| 5 | `composer test:unit` | `ddev test-unit` | PHP unit tier: Brain Monkey, no WordPress, no DB | either | ~1 s |
| 6 | `composer gate:package` | — | the package's own checks, kept from its former `gate` script when the shape was adopted (§6); a site never has one, and the gate says `skipped` | either | package-defined |
| 7 | `composer test:js` | `ddev test-js` | Vitest: theme JS unit tests | either | ~1.5 s |
| 8 | `composer build:check` | `ddev build-check` | Vite production build resolves | either | ~1 s |
| 9 | `sh bin/deps-latest.sh` | — (no composer mirror; `gate` runs it) | `composer outdated --locked --direct --strict` on `roots/wordpress`, `wp-phpunit/wp-phpunit` and `netdust/*`: red when any is behind its newest tag or cannot be resolved; fix: widen an exact constraint if Composer marks it `~`, then `composer update <names> --with-dependencies` and commit the lock | host (SSH agent) | ~3 s |
| 10 | `ddev composer test:int` | `ddev test-int` | Real WordPress against the dedicated `wptests` DB | **in-container only** | ~1.5 s |
| 11 | `composer test:e2e` | `ddev test-e2e` | Playwright against the live DDEV URL, wp-cli-seeded fixtures (after a `tsc --noEmit` preflight) | **host only** | ~7 s |
| all | `composer gate` | `ddev gate` | tiers 1–11 in order | host (hops into the container for tier 10) | ~15 s warm |

- Tier 10 is in-container because `tests/wp-tests-config.php` resolves DB host
  `db`, which only exists on the container network; the gate hops in via
  `ddev composer test:int` automatically.
- Tier 11 is host-side because the Playwright browsers live on the host;
  `bin/e2e.sh` derives the site URL from DDEV — never hardcode it.
- `composer format` (Pint) is **deliberately outside the gate**: formatting is
  editor-side. Run `composer format` to check, `composer format:fix` to apply;
  a red format never blocks a green gate.
- "Either" assumes matching platforms for the JS tiers: `node_modules` are
  host-installed with platform-native binaries, and the in-container mirrors
  reuse them — true on Linux/WSL; macOS hosts should run those tiers host-side.

## 2. How to add a test, per tier

**PHP unit** — `tests/Unit/YourThingTest.php`, namespace `NtdstTests\Unit`,
extend the tier's `TestCase` (it wires Brain Monkey + Mockery per test). Stub
WordPress functions with `Functions\when('esc_html')->returnArg()` or verify
calls with `Functions\expect(...)`. No WordPress loads, no DB is touched.
Run: `composer test:unit`.

**PHP integration** — `tests/Integration/YourThingTest.php`, namespace
`NtdstTests\Integration`, extend `WP_UnitTestCase`. Real WordPress (from
`{{GATE_WP_DIR}}`) installs itself into the dedicated `wptests` database on each run —
**never the dev DB**: the bootstrap enforces an allow-list and dies before
install unless `DB_NAME` is `wptests` (or a DB you explicitly name in the
`WP_TESTS_ALLOW_DB` env var — the escape hatch, for when you knowingly point
at another throwaway DB). Run: `ddev composer test:int`.

**JS unit** — `{{GATE_CONTENT_DIR}}/themes/<theme>/src/your-module.test.js`, next to the
code, Vitest. Follow the pattern in the theme's `src/main.test.js`: `vi.mock`
side-effectful imports, and stub `fetch` with a deterministic queue of
responses per endpoint (FIFO, throws on unexpected calls) so ordering can
never vary between runs. Run: `composer test:js`.

**E2E** — `tests/E2E/your-flow.spec.ts`, plain `@playwright/test`. Fixtures
(users, posts) are seeded in `bin/e2e.sh` via wp-cli **before** the suite runs
— never create fixtures through the UI. Credentials and fixture URLs arrive
via env (`E2E_PASS`, `E2E_FIXTURE_URL`); add new fixtures to `bin/e2e.sh` and
export them the same way. Note the Bedrock layout: admin is at `/wp/wp-admin`.
Run: `composer test:e2e` or `ddev test-e2e`.

## 3. Which tier does my bug belong to?

Mocked PHP logic → **unit**; hooks/CPT/DB behaviour → **integration**; theme
JS logic → **JS unit**; user-visible flows → **e2e**.

- **Pure PHP logic whose WP calls can be stubbed** → unit. Example:
  `tests/Unit/BrainMonkeyFunctionsTest.php` proves a renderer calling
  `esc_html()` is testable with zero WordPress loaded.
- **Behaviour that only exists with real WordPress** (hooks firing, CPT/meta
  persistence, queries) → integration. Example:
  `tests/Integration/DataLayerRoundTripTest.php` asserts a model `create()`
  really persists a post + prefixed meta and fires its lifecycle action.
- **Theme JavaScript logic** → JS unit. Example: the theme's
  `src/main.test.js` proves nonce caching and the bounded invalid-nonce retry
  against a mocked `fetch`.
- **A flow the user sees in the browser** → e2e. Example:
  `tests/E2E/smoke.spec.ts` logs `e2e-admin` in at `/wp/wp-login.php` and
  asserts the seeded fixture post renders at its real URL.

## 4. Known limitations & operational notes

a. **Run ONE gate at a time.** Concurrent runs collide at `test:e2e`: each run
   rotates the `e2e-admin` password to a fresh random value, so a parallel
   run's login fails mid-flight (observed: docs/gate-falsifiability.md, A1
   edge run 2). Not a defect — documented behaviour (and `test:int` shares
   one `wptests` install — observed-safe once, not guaranteed).
b. **The root `package.json` (e2e tooling) is dev-only and outside the
   `audit:js` loop** (which scans theme packages only). It currently carries
   3 high transitive advisories in the `@wordpress/e2e-test-utils-playwright`
   tree — zero runtime exposure, deliberately bypassed layer. Revisit if that
   dependency is dropped.
c. **Adopting the gate on an already-running project:** `wptests` is created
   by a post-start hook, so a project that was running before the gate layer
   arrived needs one `ddev restart` before `test:int` works.
d. **When `test:int` is red,** `ddev composer test:int` shows only the exit
   code on the host. For the failing assertion detail run:
   `ddev exec vendor/bin/phpunit -c phpunit.integration.xml`.
e. **A stopped DDEV project self-heals:** `composer gate` auto-starts the
   containers at `test:int` (adds ~18 s; observed cold run ~31 s vs ~13–15 s
   warm — docs/gate-falsifiability.md, A1 edge run 1).
f. **PHPUnit stays on `^9.6`.** wp-phpunit requires `yoast/phpunit-polyfills`, and no
   polyfills release admits PHPUnit 10 (3.x: 6.4–9 and 11; 4.0: 7.5–9, 11 and 12), so a
   manifest pinning `^10.5` cannot even resolve beside wp-phpunit — Composer refuses at
   install. Verified 2026-10-29 on the first package render (ntdst-core on WordPress 7.1.4,
   wp-phpunit 7.1.3): PHPUnit 9.6.38 ran core's 1,229 unit tests and the integration suite
   green. PHPUnit 11 is admitted by polyfills 4.0 but untested on WordPress 7.1's test case;
   on 10+ the 9-schema XMLs (`cacheResultFile`) print a deprecation, not a failure.
g. **PHP-compat sniffs run PHPCompatibility 9.3.5, which predates PHP 8** —
   functions removed in PHP 8.x are not yet flagged; adopt the v10 line when
   released.

## 5. Falsifiability

Every gate tier has a recorded red demonstration — a deliberate violation, the
non-zero exit, and the green re-run — in `docs/gate-falsifiability.md`.
If you add a gate, prove it can fail before you trust it green.

## 6. The package shape

One gate, two shapes (`netdust-wp:wp-testing`; spec wp-ai-base R8–R9). A site is born with
`gate/` through the scaffold; a package — a `composer.json` of type `wordpress-muplugin` —
hosts its own WordPress in `require-dev` and renders the same gate onto its own root, so
`composer gate` runs every tier, integration included, on the package's own DDEV project.
Not used, by name: Playground, Blueprints, wp-env, a shared test site.

**Adopting it**, from a clone of `netdust/wp-starter`, on a package whose main file
`<name>.php` sits at its root:

1. `bash <wp-starter>/bin/package-gate.sh <package-root>` renders the shape, merges the
   composer fragment and appends the `.gitignore` / `.gitattributes` lines; it prints `kept:`
   for a `phpcs.xml` or `phpstan.neon` the package already has — its own tier config wins.
2. `composer install`, then `npm install` (Playwright), then `ddev start`: the post-start
   hook installs WordPress and provisions `wptests` (a running project needs `ddev restart`).
3. Commit `composer.lock` if the renderer said it is gitignored: `deps:latest` reads the lock.
4. Exclude `web/`, `node_modules/`, `.phpstan-cache/` and `.ddev/` from every root-walking
   sweep the package carries — ABSPATH guards, removed-symbol greps, invariant checks,
   integrity tests, and a `php -l` sweep over `.` (PHPStan's `resultCache.php` is not PHP) —
   and exempt the shape's `tests/bootstrap-*.php`, `tests/wp-tests-config.php` and
   `tests/Integration/` from the ABSPATH guard the way `tests/bootstrap.php` already is.
5. A manifest pinning `phpunit/phpunit ^10.5` moves to `^9.6` first (§4f).
6. `composer gate` is the whole Close; the package's former `gate` script runs as `gate:package`.

**What the renderer refuses**, writing nothing: no `composer.json`, a type other than
`wordpress-muplugin`, no `<name>.php` at the root, a path under a site's
`{{GATE_CONTENT_DIR}}/mu-plugins/`, or a shape file that already exists with other content
(`bin/gate.sh`, `tests/bootstrap-integration.php`, …) — move it aside or make it identical.
A second run on an adopted package changes nothing.

**The loader shim** `{{GATE_CONTENT_DIR}}/mu-plugins/<name>loader.php` requires the repo
root's `<name>.php`: the gate tests the working copy, never a composer-installed copy. A
package requiring `netdust/ntdst-core` also gets wp-starter's `ntdst-coreloader.php`; a
neighbour stays wherever the package declares it (`require` or `require-dev`) and
`deps:latest` reads it there. A package that boots on an `NTDST_Bootstrap` config keeps it in
`tests/Integration/site.php`; `tests/bootstrap-site.php` boots it with a site's hook timing,
and a package without that file runs its integration suite on plain WordPress.

**A worktree is its own DDEV project**: `name:` in `.ddev/config.local.yaml` (gitignored).
One gate at a time: `analyse` writes `.phpstan-cache/` while a `php -l` sweep reads it.

**What a site installing the package receives.** Sites install `netdust/*` from source, so
the committed shape travels: `.ddev/`, `.gate-no-theme-js`, `.phpstan-cache/.gitignore`,
`README-testing.md`, `bin/{gate,e2e,js-gate,lint-tokens,deps-latest}.sh`,
`config/application.php`, `package.json`, `package-lock.json`, `phpstan.neon`,
`phpunit.{unit,integration}.xml`, `playwright.config.ts`, `tsconfig.json`, `wp-cli.yml`,
`tests/` (both bootstraps, `wp-tests-config.php`, `bootstrap-site.php`,
`Integration/LoaderTest.php`, `E2E/smoke.spec.ts`), `index.php` and `wp-config.php` under
`web/`, and the shim. Each is inert under `mu-plugins/<name>/`: a nested shim is not
top-level, so WordPress never loads it; that `wp-config.php` sits beside no WordPress;
`.ddev/` is not a project root; the site's `phpcs.xml` / `phpstan.neon` exclude
`mu-plugins/ntdst-*`; and the fragment's manifest keys are root-only in Composer. A dist
install (`git archive`) carries none of it: every path the shape adds is `export-ignore`.

**A site** pinning `roots/wordpress` or `wp-phpunit/wp-phpunit` exactly goes red at
`deps:latest` until the constraint is widened. `roave/security-advisories` is not part of the
shape (`audit:deps` runs `composer audit`): a manifest carrying it beside `platform.php` at
a bare minor stops resolving the day an advisory names that PHP line.
