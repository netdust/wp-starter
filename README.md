# netdust/wp-starter

The single netdust payload installed into **every** scaffolded WP site,
regardless of stack (bedrock | stackwp):

- **ntdst-core mu-plugin** — the framework (`core/ api/ services/ assets/`),
  copied **verbatim**
- **clean starter theme** — copied then rendered with slug tokens
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
├── theme/                     ← copied to the site's themes/<slug>/, then tokens rendered
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
