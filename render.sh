#!/usr/bin/env bash
# =================================================================
# Vibe-code audits — in-repo asset render
#
# This is the lightweight in-repo version of the render pipeline.
# It handles the one operation that recurs over the repo's lifetime:
# rendering a per-teardown OG image from docs/og-teardown.html.
#
# For the full design-team pipeline (canonical repo OG + LinkedIn
# carousel PDF + sanity screenshots), see the staging dir the design
# team produced at integration time. That pipeline is launch-layer;
# it is not part of the in-repo workflow.
#
# Usage:
#   bash render.sh                  → re-render the current og-teardown.html
#                                      to docs/og-teardown.png (debug preview)
#   bash render.sh 01-lovable       → render docs/og-teardown.html to
#                                      docs/og-teardown-01-lovable.png
# =================================================================
set -euo pipefail

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [[ ! -x "$CHROME" ]]; then
  echo "Chrome not found at: $CHROME"
  echo "Edit this script's CHROME path if you're on Linux or non-standard macOS install."
  exit 1
fi

if [[ ! -f "$HERE/docs/og-teardown.html" ]]; then
  echo "Source not found: docs/og-teardown.html"
  echo "This script renders the per-teardown OG template. Fill the template per docs/og-teardown.html's inline slots, then run."
  exit 1
fi

SUFFIX="${1:-}"
if [[ -z "$SUFFIX" ]]; then
  OUT="$HERE/docs/og-teardown.png"
  echo "Rendering preview → $OUT"
else
  OUT="$HERE/docs/og-teardown-${SUFFIX}.png"
  echo "Rendering per-teardown OG → $OUT"
fi

# Virtual-time-budget advances chrome's virtual clock so any pending
# resources finish loading before screenshot capture. 1500ms is enough
# for the self-contained template (no external font fetches).
"$CHROME" \
  --headless=new \
  --disable-gpu \
  --hide-scrollbars \
  --no-sandbox \
  --force-device-scale-factor=1 \
  --virtual-time-budget=1500 \
  --window-size=1200,630 \
  --screenshot="$OUT" \
  "file://$HERE/docs/og-teardown.html" \
  > /dev/null 2>&1

if [[ -f "$OUT" ]]; then
  echo "✓ Rendered: $OUT"
  ls -lh "$OUT"
else
  echo "✗ Render failed. Check Chrome path + that docs/og-teardown.html opens cleanly in a browser first."
  exit 1
fi
