#!/usr/bin/env bash
# claude-widgets deploy script
# Usage: deploy.sh <fragment.html> [slug]
#   - wraps a Claude generative-UI fragment in the shell template
#   - commits & pushes to GitHub
#   - copies the iframe URL to clipboard

set -euo pipefail

# Resolve symlinks so REPO_DIR points at the real repo, not ~/.local/bin.
# Handles symlink targets that are relative paths (e.g. ../../foo/deploy.sh).
SCRIPT_PATH="$0"
while [ -L "$SCRIPT_PATH" ]; do
  DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  case "$SCRIPT_PATH" in
    /*) ;;                          # already absolute
    *)  SCRIPT_PATH="$DIR/$SCRIPT_PATH" ;;
  esac
done
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
SHELL_FILE="$REPO_DIR/_shell/shell.html"

if [ $# -lt 1 ]; then
  echo "Usage: $0 <fragment.html> [slug]" >&2
  exit 1
fi

SRC="$1"
[ -f "$SRC" ] || { echo "File not found: $SRC" >&2; exit 1; }

# Derive slug from arg or filename
if [ $# -ge 2 ]; then
  SLUG="$2"
else
  SLUG="$(basename "$SRC" .html | tr '_ ' '--' | tr '[:upper:]' '[:lower:]')"
fi

# Validate slug to prevent path-traversal / weird filenames
case "$SLUG" in
  *[!a-zA-Z0-9._-]* | "" | "." | ".." )
    echo "Invalid slug: '$SLUG' (allowed: a-z A-Z 0-9 . _ -)" >&2
    exit 1 ;;
esac

OUT="$REPO_DIR/widgets/$SLUG.html"
mkdir -p "$REPO_DIR/widgets"

# Title from filename (humanised). Strip HTML-significant chars to prevent
# breaking the <title> tag, then escape '&' which awk's gsub treats as a
# back-reference to the matched string.
RAW_TITLE="$(basename "$SRC" .html | tr '_-' '  ')"
SAFE_TITLE="$(printf '%s' "$RAW_TITLE" | tr -d '<>"&')"

# Substitute {{TITLE}} and {{WIDGET}} (use awk to avoid sed escaping issues).
# Note: TITLE has been pre-sanitised, so direct interpolation is safe.
awk -v title="$SAFE_TITLE" -v widget_file="$SRC" '
  {
    line = $0
    gsub(/\{\{TITLE\}\}/, title, line)
    if (line ~ /\{\{WIDGET\}\}/) {
      while ((getline w < widget_file) > 0) print w
      close(widget_file)
    } else {
      print line
    }
  }
' "$SHELL_FILE" > "$OUT"

# Resolve GitHub user + repo for URL
USER="$(gh api user --jq .login)"
REPO="$(basename "$REPO_DIR")"
URL="https://${USER}.github.io/${REPO}/widgets/${SLUG}.html"
# Hiccup form so auto-resize works (iframe height managed by roam/js listener)
IFRAME=":hiccup [:iframe {:src \"${URL}?theme=dark\" :width \"100%\" :height \"500\" :style {:border \"none\" :border-radius \"10px\"}}]"

# Stage & commit ONLY the widget file so unrelated staged changes in the repo
# don't get swept into this deploy commit.
cd "$REPO_DIR"
git add -- "widgets/$SLUG.html"
if git diff --cached --quiet -- "widgets/$SLUG.html"; then
  echo "No changes to commit (widget already up-to-date)."
else
  git commit -m "deploy: $SLUG" -- "widgets/$SLUG.html" >/dev/null
  git push -q
fi

printf '%s' "$IFRAME" | pbcopy
echo "✓ Deployed: $URL"
echo "✓ Copied to clipboard: $IFRAME"
