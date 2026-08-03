# netdust/wp-starter

The single netdust payload installed into **every** scaffolded WP site,
regardless of stack (bedrock | stackwp):

- **ntdst-core mu-plugin** — the framework (`core/ api/ services/ assets/`),
  copied **verbatim**
- **theme, selected by PRESET** — copied then rendered with slug tokens:
  - `theme/` (preset `plain`, default) — self-rendering theme (Tailwind/Alpine/Vite)
  - `theme-yootheme/` (preset `yootheme`) — YOOtheme Pro **child**: no template
    files, no CSS toolchain, styling in `less/theme.<slug>.less`
- **gate layer** — `gate/` mirrors the project root (bin/, tests/, phpunit/phpstan/phpcs
  configs, playwright, root `package.json` + `package-lock.json` e2e harness,
  `.ddev/` gate additions),
  copied to the project root then rendered with the gate tokens (absorbed from
  `netdust/bedrock` in T02 of `specs/new-site-stack-choice`)

```
wp-starter/
├── mu-plugins/
│   ├── ntdst-coreloader.php   ← copied verbatim into the site's mu-plugins/
│   └── ntdst-core/            ← copied verbatim (the framework: core/ api/ services/ assets/)
├── theme/                     ← preset `plain`  → themes/<slug>/, then tokens rendered
├── theme-yootheme/            ← preset `yootheme` → same, but a YOOtheme CHILD
└── gate/                      ← copied to the project ROOT (merge .ddev/), then gate tokens rendered
```

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

Advance ntdst-core **here** (commits, tags). This repo is the source of truth
for the framework payload — it replaces the old "snapshot bumped from Stride"
model.

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
