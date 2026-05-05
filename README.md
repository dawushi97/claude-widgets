# claude-widgets

Self-hosted gallery for Claude **generative-UI** widgets (the inline `show_widget`
fragments rendered in the chat stream — *not* Artifacts), wrapped for standalone
viewing and `iframe` embedding (e.g. into Roam Research notes).

## Why

Claude's generative-UI download is a raw HTML fragment that depends on
claude.ai's design tokens (`--color-text-primary`, `--border-radius-md`, …).
Opened directly it renders unstyled. This repo provides:

- `_shell/tokens.css` — polyfill of the Claude design tokens (light + dark)
- `_shell/shell.html` — full-document wrapper that hosts the fragment
- `scripts/deploy.sh` — one-shot deploy: wrap → commit → push → copy iframe URL

GitHub Pages serves the result; the URL is embeddable in any `iframe`-aware tool.

## Use

```bash
# one-time install
ln -s "$(pwd)/scripts/deploy.sh" ~/.local/bin/claude-deploy

# every download from claude.ai
claude-deploy ~/Downloads/http_methods_and_status_codes.html
# → pushes, prints URL, copies "{{iframe: …}}" to clipboard
# → paste into Roam
```

## Structure

```
claude-widgets/
├── _shell/
│   ├── shell.html      # wrapper template
│   └── tokens.css      # Claude design tokens polyfill
├── widgets/            # one html per deployed widget
└── scripts/
    └── deploy.sh
```

## Credits

Tokens and SVG ramp classes adapted from
[Michaelliv/pi-generative-ui](https://github.com/Michaelliv/pi-generative-ui)
(reverse-engineered from claude.ai).
