# claude-widgets

Self-hosted gallery for Claude **generative-UI** widgets (the inline `show_widget`
fragments rendered in the chat stream — *not* Artifacts), wrapped for standalone
viewing and `iframe` embedding (e.g. into Roam Research notes).

## Why

Claude's generative-UI download is a raw HTML fragment that depends on
claude.ai's design tokens (`--color-text-primary`, `--border-radius-md`, …).
Opened directly it renders unstyled. This repo provides:

- `_shell/tokens.css` — polyfill of the Claude design tokens (light + dark,
  verbatim from the claude.ai MCP host context)
- `_shell/shell.html` — full-document wrapper that hosts the fragment, with
  `sendPrompt` / `openLink` polyfills and an iframe auto-resize emitter
- `scripts/deploy.sh` — one-shot deploy: wrap → commit → push → copy iframe URL

GitHub Pages serves the result; the URL is embeddable in any iframe-aware tool.

## Use

```bash
# one-time install
ln -s "$(pwd)/scripts/deploy.sh" ~/.local/bin/claude-deploy

# every download from claude.ai
claude-deploy ~/Downloads/http_methods_and_status_codes.html
# → pushes, prints URL, copies a hiccup-form :iframe snippet to clipboard
# → paste into Roam
```

## Structure

```
claude-widgets/
├── _shell/
│   ├── shell.html      # wrapper template (theme switch, polyfills, auto-resize)
│   └── tokens.css      # Claude design tokens polyfill (light + dark)
├── widgets/            # one html per deployed widget
├── scripts/
│   └── deploy.sh
├── .nojekyll           # disable Jekyll so _shell/ is served (see below)
└── README.md
```

## Deployment notes

### `.nojekyll` is required
GitHub Pages defaults to Jekyll, which **ignores any directory whose name starts
with `_`** (so `_shell/tokens.css` would 404). The empty `.nojekyll` file at
the repo root tells Pages to serve files as-is. Don't delete it.

### Initial Pages setup (one-time)

```bash
gh repo create claude-widgets --public --add-readme
gh api -X POST repos/<USER>/claude-widgets/pages \
  -f source[branch]=main -f source[path]=/
```

## URL parameters

The shell understands one query parameter:

| Param          | Effect                                               |
|----------------|------------------------------------------------------|
| `?theme=dark`  | Force dark mode regardless of OS preference          |
| `?theme=light` | Force light mode regardless of OS preference         |
| (none)         | Follow OS preference via `prefers-color-scheme`      |

`deploy.sh` defaults its hiccup snippet to `?theme=dark` for the Claude look.

## Embedding in Roam Research

Two layers are needed for the best experience:

### 1. Embed via hiccup (gives you control over iframe attributes)

```clojure
:hiccup [:iframe {:src "https://<USER>.github.io/claude-widgets/widgets/<slug>.html?theme=dark"
                  :width "100%"
                  :height "500"
                  :style {:border "none" :border-radius "10px"}}]
```

(`{{iframe: URL}}` works too but you can't customise width/height/style.)

### 2. Auto-resize listener (`roam/js`)

Without this, the iframe stays at the height you set and clicks that expand
content cause inner scrollbars. Add this `{{[[roam/js]]}}` block under your
`roam/js` page (and enable JavaScript in Roam → Settings → Code):

```javascript
// Claude widgets — auto-resize iframe to content height
(() => {
  if (window.__claudeWidgetResizer) return;
  window.__claudeWidgetResizer = true;

  // Only trust resize messages from your own GitHub Pages origin.
  const TRUSTED_ORIGIN = 'https://<USER>.github.io';

  window.addEventListener('message', (e) => {
    if (e.origin !== TRUSTED_ORIGIN) return;
    const d = e && e.data;
    if (!d || d.type !== 'claude-widget-resize' || !d.src) return;
    for (const f of document.querySelectorAll('iframe')) {
      if (f.src === d.src && f.contentWindow === e.source) {
        const h = Math.ceil(d.height) + 4; // small buffer
        if (parseInt(f.height, 10) !== h) f.height = h;
        f.style.height = h + 'px';
      }
    }
  });
})();
```

Replace `<USER>` with your GitHub username. The origin check prevents other
embeds (e.g. third-party iframes) from spoofing resize events.

## How auto-resize works

```
┌─ widget (iframe) ─────────────┐
│  click → DOM 高度变化         │
│       ↓                       │
│  ResizeObserver(__widget_root)│
│       ↓                       │
│  postMessage({height})  ──────┼──→ Roam parent
└───────────────────────────────┘                │
                                                 ↓
                                          roam/js listener
                                                 ↓
                                  iframe.height = 内容真实高度
```

Critical: the shell measures `#__widget_root` (the content wrapper), **not**
`document.body`. Measuring body would echo the iframe's set height back to the
parent (via `100vh` cascading) and create an infinite growth loop.

## Caveats

- **`Anthropic Sans` is not bundled.** It falls back to system sans. If you have
  it locally installed it will be used.
- **`window.fs` is not polyfilled.** Widgets that read user files via Claude's
  filesystem API won't work outside claude.ai.
- **CDN-loaded libraries** (Chart.js, D3, etc. via `<script src=...>`) work
  fine inside the iframe — they're loaded from the same allowlist Claude uses.

## Credits

Tokens verbatim from
[anthropics/claude-ai-mcp#202](https://github.com/anthropics/claude-ai-mcp/issues/202).
SVG ramp classes adapted from
[Michaelliv/pi-generative-ui](https://github.com/Michaelliv/pi-generative-ui).
Background and reverse-engineering write-up by
[Michael Livshits](https://michaellivs.com/blog/reverse-engineering-claude-generative-ui/).
