# {{SLUG_TITLE}} — YOOtheme Pro child theme

A thin **child of YOOtheme Pro**, wired into **ntdst-core**. YOOtheme's builder
owns rendering; this theme carries the site's own wiring and one LESS style.

## Stack

- **YOOtheme Pro (parent)** — page templates + the builder. Not in this repo:
  ~41MB, licensed, gitignored, installed per host.
- **LESS** — `less/theme.{{SLUG}}.less` maps the design tokens onto UIkit
  variables. Select it in *Customizer → Theme → Style*.
- **Alpine.js + Vite** — JS only. **There is no CSS build.**
- **ntdst-core** — bootstrap, `theme-config.php`, helpers, REST wrapper.

## What this theme deliberately does NOT have

- **No template files.** No `header.php`, `footer.php`, `page.php`,
  `single.php`, `index.php`, `404.php`, `front-page.php`, `searchform.php`,
  `partials/`, no nav walker. A child's template files OVERRIDE the parent and
  bypass the builder — which is the entire reason to use YOOtheme.
- **No Tailwind / PostCSS / stylelint**, no `src/css/`. Styling lives in LESS.

If you need custom rendering, add a **builder element** or a **Dynamic Content
source** (see `netdust-wp:ntdst-yootheme`), not a template file.

## Styling

`less/theme.{{SLUG}}.less` has two halves, and they behave differently:

1. **Tokens** (`@{{SLUG_SNAKE}}-*`) — the design system's own values.
2. **The UIkit mapping** (`@global-*`, `@base-*`, `@button-*`, …) — what makes
   builder elements correct out of the box. Filling section 1 alone changes
   nothing on screen.

⚠ **The Customizer can edit section 2 but CANNOT see section 1.** It exposes
variables by pattern whitelist, and `@{{SLUG_SNAKE}}-*` matches none of them. So
a colour changed in *Customizer → Global → Colors* silently diverges from the
token it came from, and the DB copy wins at runtime. **Change brand values in
this file**; use the Customizer for fonts and per-page work.

## Fonts

Pick them in *Customizer → Theme → Style → Fonts*. YOOtheme downloads and
**self-hosts** the woff2 files (GDPR-friendly, same-origin, no preconnect
needed). Do **not** `wp_enqueue_style` the same families — that loads them
twice, from Google's CDN.

## Verify it compiles

YOOtheme compiles LESS **in the browser**; there is no PHP compile step, so
"the style is listed" does not mean "the style compiles":

```bash
npm install less@4 --no-save
cd less && ../node_modules/.bin/lessc --no-color theme.{{SLUG}}.less /tmp/out.css
# exit 0 = good. Don't pipe to `head` — SIGPIPE fakes a non-zero exit.
```

## Setup

```bash
npm install
npm run dev     # Vite dev server (JS)
npm run build   # production JS bundle
```

⚠ **The parent must exist before this theme is activated.** Activating a child
with no parent pins the `template` option to the child, and WordPress silently
falls back to `theme-compat` — activating the parent afterwards does NOT repair
it. Correct order: install parent → activate parent → activate child → verify
`get_template_directory()` points at `yootheme/`.

More: `netdust-wp:ntdst-yootheme` → `references/yootheme-less.md`.
