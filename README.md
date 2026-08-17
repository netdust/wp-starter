# netdust/wp-starter

The single netdust payload installed into **every** scaffolded WP site,
regardless of stack (bedrock | stackwp):

- **the framework** — `netdust/ntdst-core` (the DI/data/routing layer) and
  `netdust/ntdst-baseline` (security headers, head cleanup, SEO, schema,
  maintenance, cache headers) are **composer packages**, each its own
  canonical repo (`github.com/netdust/ntdst-core`, `github.com/netdust/ntdst-baseline`),
  installed like any other dependency — **not** vendored/copied into this
  payload. This repo ships only the two one-line loader shims
  (`mu-plugins/ntdst-coreloader.php`, `mu-plugins/ntdst-baselineloader.php`);
  `scaffold_wp_starter` copies the shims verbatim and injects the composer
  `repositories`/`require` entries into the scaffolded project (see
  "Framework as composer packages" below).
- **theme, selected by PRESET** — copied then rendered with slug tokens:
  - `theme/` (preset `plain`, default) — self-rendering theme (Tailwind/Alpine/Vite)
  - `theme-yootheme/` (preset `yootheme`) — YOOtheme Pro **child**: no template
    files, no CSS toolchain, styling in `less/theme.<slug>.less`
- **gate layer** — `gate/` mirrors the project root (bin/, tests/, phpunit/phpstan/phpcs
  configs, playwright, root `package.json` + `package-lock.json` e2e harness,
  `.ddev/` gate additions),
  copied to the project root then rendered with the gate tokens (absorbed from
  `netdust/bedrock` in T02 of `specs/new-site-stack-choice`)
- **flow layer** — `flow/` mirrors the project root (`.flow/` delivery road +
  gates + floors, `.claude/settings.json` hook wiring), copied to the project
  root then rendered with `{{SLUG}}`. The runtime it drives is
  `netdust/flow`, a **composer package** consumed exactly like `ntdst-core`
  (see "Flow layer" below); the payload commits only the road, the
  WordPress-shaped gates, and two thin hook shims that exec the
  composer-installed kernel (absorbed from `netdust/WordPress-site-pack`).

```
wp-starter/
├── mu-plugins/
│   ├── ntdst-coreloader.php       ← copied verbatim; requires the composer-installed package
│   └── ntdst-baselineloader.php   ← copied verbatim; requires the composer-installed package
├── theme/                     ← preset `plain`  → themes/<slug>/, then tokens rendered
├── theme-yootheme/            ← preset `yootheme` → same, but a YOOtheme CHILD
├── gate/                      ← copied to the project ROOT (merge .ddev/), then gate tokens rendered
└── flow/                      ← copied to the project ROOT (.flow/ + .claude/), {{SLUG}} rendered
```

Neither `ntdst-core/` nor `ntdst-baseline/` directories exist in this repo —
composer installs them into the scaffolded project's
`{{GATE_CONTENT_DIR}}/mu-plugins/` at `composer update` time, beside the two
shims above.

## Framework as composer packages

`netdust/ntdst-core` and `netdust/ntdst-baseline` are consumed exactly like
any other composer dependency, via a VCS repository pointing at the private
GitHub repo:

```json
"repositories": [
    { "type": "vcs", "url": "git@github.com:netdust/ntdst-core.git" },
    { "type": "vcs", "url": "git@github.com:netdust/ntdst-baseline.git" }
],
"require": {
    "netdust/ntdst-core": "^2.2",
    "netdust/ntdst-baseline": "^1.0"
}
```

`scaffold_wp_starter` (`netdust-wp-manager/scripts/scaffold-meta.sh`) injects
this `repositories`/`require` block into the scaffolded project's
`composer.json` (root manifest on Bedrock, `app/composer.json` on stackwp)
and prints a follow-up instruction — it does not run `composer update`
itself; see "Where composer must run" below.

Both packages declare `"type": "wordpress-muplugin"`, so composer's
`installer-paths` (already present in the bedrock/stackwp templates) resolve
them into `{{GATE_CONTENT_DIR}}/mu-plugins/ntdst-core/` and
`{{GATE_CONTENT_DIR}}/mu-plugins/ntdst-baseline/` automatically — no new
installer-paths entry is needed.

### SSH read access is required

Both repos are **private**. Every machine that runs `composer install` /
`composer update` against them — every developer's machine AND every deploy
target (Ploi/Combell) — needs an SSH key with **read access to the
`netdust` GitHub org** registered, the same way it already needs a key for
any other private git dependency. Without it, `composer update
netdust/ntdst-core netdust/ntdst-baseline` fails with a permission-denied
clone error, not a silent skip.

### Where composer must run

Run `composer update netdust/ntdst-core netdust/ntdst-baseline` **on the
host**, not inside the DDEV container. The container has no access to the
host's SSH agent/keys by default, so a `ddev composer update` against a
private VCS repository fails even when the host's own `composer update`
would succeed. `scaffold_wp_starter` deliberately does NOT run the update
itself (it can't assume the caller has forwarded SSH into the container) —
it prints the exact command to run on the host after wiring the manifest.

### Vendor posture: externally managed, never hand-edited

Both package directories are externally managed, the same posture the
project already gives `vendor/`:

- **gitignored** — `{{GATE_CONTENT_DIR}}/mu-plugins/ntdst-core/` and
  `{{GATE_CONTENT_DIR}}/mu-plugins/ntdst-baseline/` are never committed to a
  consumer's repo (`scaffold_wp_starter` appends the entries to the
  scaffolded project's `.gitignore`).
- **excluded from static analysis / lint** — `gate/phpstan.neon`
  (`excludePaths`) and `gate/phpcs.xml` (`exclude-pattern`) ship both dirs
  excluded out of the box, at the `{{GATE_CONTENT_DIR}}` token so the
  exclude is correct on both bedrock and stackwp renders. This payload ships
  no `pint.json` — a consumer project that adds Pint must exclude both dirs
  there too (see daan's `pint.json` for the pattern:
  `"web/app/mu-plugins/ntdst-core"`).
- **their own gate, their own reviewers** — bugs/regressions in the
  framework are fixed and reviewed in `github.com/netdust/ntdst-core` /
  `ntdst-baseline`, then consumed by bumping the composer constraint here.
  A consumer project's tree-audit / drift instruments must treat both dirs
  as externally managed, the same way they already treat `vendor/`.

### Branch conventions (both framework repos)

- Security or bug fixes land on `fix/{name-of-fix}`.
- Features land on `feature/{name}`, always with a **named consumer** — see
  the minimalism rule below.
- Both merge to `main` with `--no-ff` so the history shows the branch.

**Minimalism rule.** Only upstream a change to `ntdst-core` /
`ntdst-baseline` when a feature is actually asked for by a named consumer.
Neither repo may be bloated — they are minimal WordPress layers: solid,
secure code, features enter only with a named consumer.

## Flow layer

The `flow/` payload gives every scaffolded site the netdust-flow
delivery road:

    __start__ → brief ⊨gate → plan ⊨gate → YOUR APPROVAL ⊨seal
              → build ⟲ ledger
              → security scan → gate umbrella (bin/gate.sh) → render → a11y
              → YOUR SHAKE-OUT ⊨seal(--fresh) → __end__

Two human stops, recorded as seals. Everything between them is exit
codes. The check battery is the starter's own `gate/` umbrella; the
flow adds the road around it, the WordPress-shaped scans the umbrella
lacks (security heuristics, real-render, a11y), and the rule that
`__end__` is reachable only through your recorded, still-fresh seal.

**Runtime via composer.** The kernel (walker, Stop hook, evidence
stores, lint) is `netdust/flow` — consumed exactly like `ntdst-core`:

```json
"repositories": [
    { "type": "vcs", "url": "git@github.com:netdust/netdust-flow.git" }
],
"require-dev": {
    "netdust/flow": "^0.1"
}
```

`scaffold_wp_starter` injects this alongside the framework entries.
`composer.lock` pins the exact runtime revision, so a runtime update is
a reviewed lockfile diff — never a silent change to what "finished"
means for a live site.

**What is committed vs installed.** The site commits `.flow/` (road,
gates, floors, render-routes, craft, tests) and two thin hook shims in
`.flow/hooks/` wired by `.claude/settings.json`; the shims exec the
composer-installed kernel. A clone that skipped `composer install`
degrades to an ordinary unharnessed session (arming is impossible
without the runtime — `flow-arm.py` IS the runtime), never to a
fake-harnessed one.

**Where netdust-agent fits.** The graph deliberately names only
pack-local craft, so a site never hard-depends on a personal plugin
install (arm-time craft checks would refuse on a machine without it).
The plugin participates at run time instead: its intake router routes
delivery work into `/flow`, its skills are ambient while the driving
session works the build node, and the I5 review cluster the plan gate
forces into `tasks.md` is executed by dispatching its reviewer
personas with `.flow/craft/wp-reviewer.md` as the brief (see
`site-builder.md` § Dispatching the review cluster). Without the
plugin, the road still runs — any fresh-context agent can carry the
reviewer brief.

**For agents (and humans) changing the road:** the payload ships
`.flow/README.md` — the editing checklist (yaml → compile → pack-tests
→ commit both), the three shape rules every edit must keep, and how to
add a gate. It rides the scaffold into every site so a fresh session
learns the workflow by reading, not by refusal.

**Per site, before the first run:** edit `.flow/render-routes.txt`
(every URL that must render — an unlisted route is a route nothing
checks) and tune `.flow/floors.yaml` to the codebase. Then arm:

    /flow build/<feature> site

**Verify the payload** after editing it here:

    python3 <netdust-flow>/bin/flow-lint.py flow/.flow/flows/site.yaml --compile
    python3 flow/.flow/tests/pack-tests.py     # gate fixtures + graph shape
    python3 flow/.flow/tests/fixture-syntax.py # fixtures must parse (php -l)

`pack-tests.py` asserts the pack's entire trust claim: no machine gate
routes a red exit anywhere but back to `build`, `__end__` is reachable
only through the seal gate, and the finishing seal is `--fresh`. An
edge added later must not be able to void that quietly.

## Token vocabulary

Rendered by `scaffold_wp_starter` in `netdust-wp-manager/scripts/scaffold-meta.sh`:

| Token | Example (`acme-client`) | Where |
|---|---|---|
| `{{SLUG}}` | `acme-client` | dir name, textdomain, handles, asset paths |
| `{{SLUG_SNAKE}}` | `acme_client` | PHP namespace |
| `{{SLUG_CONST}}` | `ACME_CLIENT` | constants (VERSION/DIR/URI) |
| `{{SLUG_TITLE}}` | `Acme Client` | style.css Theme Name |
| `{{GATE_CONTENT_BASE}}` | `content` (stackwp) / `app` (bedrock) | Vite `base` — the content dir MINUS the docroot, i.e. the public URL prefix |

Gate tokens, rendered by `scaffold_wp_starter` across the copied `gate/` files:

| Token | bedrock | stackwp | Meaning |
|---|---|---|---|
| `{{GATE_WP_DIR}}` | `web/wp` | `app/wp` | WordPress core dir, relative to project root |
| `{{GATE_CONTENT_DIR}}` | `web/app` | `app/content` | Content dir (mu-plugins/, themes/), relative to project root |

## Consumers

- `netdust-wp-manager` `scripts/new-site.sh` — via `scaffold_wp_starter`
- env override: `WP_STARTER_REPO`

## Update workflow

Advance `ntdst-core` / `ntdst-baseline` in **their own repos**
(`github.com/netdust/ntdst-core`, `github.com/netdust/ntdst-baseline`) —
commits, tags, their own gate. This repo (`wp-starter`) no longer vendors the
framework; bump the `^2.2` / `^1.0` constraints documented above when a new
tag needs picking up. Advance the theme and gate layer **here**, the same way
as before.

**Before pushing payload changes, run `sh gate/bin/lint-tokens.sh`** (exit 0 =
clean). It fails on layout literals (`web/wp`, `app/content`, …) that should be
`{{GATE_WP_DIR}}` / `{{GATE_CONTENT_DIR}}` tokens. A hardcoded path is
correct-by-coincidence on a Bedrock render and silently wrong on a stackwp one,
so nothing catches it until a stackwp site's gate goes red.

The theme's JS config handle is `window.{{SLUG_SNAKE}}Config` — emitted by the
PHP side (`wp_add_inline_script` in
`theme/services/frontend/hooks/AssetHooks.php`) and read in
`theme/src/main.js`; both render from the same token, so they stay consistent
per site.

## Theme

The theme wires into ntdst-core (`NTDST_Bootstrap` + `NTDST_Theme` via `theme-config.php`)
and ships a Tailwind 3 + Alpine + Vite build. It degrades gracefully before the first
`npm run build` (AssetHooks no-ops when `dist/manifest.json` is absent). After scaffolding:
`cd <themes>/<slug> && npm install && npm run build`, then set brand colors in
`src/css/tokens.css`.

Origin: distilled from Stride's `stridence` theme (LMS code removed).
Gate tooling (theme JS side: eslint flat config, stylelint, vitest + example suite,
vite 7, committed package-lock) extracted from the gate-harness pilot
(`~/Sites/gate-pilot`) on 2026-07-31 — see `specs/wp-gate-harness` in
netdust-wp-manager (pilot deleted after extraction; evidence preserved in
`specs/wp-gate-harness/` + each project's `docs/gate-falsifiability.md`).


## Presets

`new-site.sh --preset=<plain|yootheme>` selects the theme payload;
`scaffold_wp_starter` maps preset → dir and HARD-ERRORS on an unknown value
(never a silent fallback to `plain`).

**STACK and PRESET are independent axes.** Stack is the project LAYOUT (bedrock
`web/app` vs stackwp `app/content`); preset is the THEME SHAPE. A YOOtheme site
can be either stack — 5 of 7 Netdust sites are YOOtheme, across both.

### `theme-yootheme/`

A YOOtheme Pro **child**. What makes it different from `theme/`:

- **No template files.** No `header/footer/page/single/index/404/front-page/
  searchform.php`, no `partials/`, no nav walker. Those override the parent and
  bypass the builder — the whole point of YOOtheme.
- **`Template: yootheme`** in `style.css`. This is what makes it a child.
- **No CSS toolchain.** No Tailwind/PostCSS/stylelint, no `src/css/`. Styling is
  `less/theme.{{SLUG}}.less`, renamed to the real slug at scaffold time because
  YOOtheme derives the style ID from the filename.
- Vite is retained for **JS only** (Alpine).

The `less/` skeleton is generated from the same source as
`netdust-wp:ntdst-yootheme → templates/theme.child.less.md`; keep them in sync.

**The YOOtheme Pro PARENT is not in this payload** — ~41MB and licensed. It is
never committed and never fetched from a public source. `new-site.sh` copies it
from `YOOTHEME_PARENT_DIR` (default `~/Sites/_assets/yootheme`) and, if absent,
scaffolds the child but does NOT activate it — because activating a child with
no parent silently pins the `template` option to the child, and activating the
parent later does not repair it.
