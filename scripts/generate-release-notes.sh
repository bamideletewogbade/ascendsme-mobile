#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# generate-release-notes.sh
#
# Reads CHANGELOG.md and generates a polished, business-friendly PDF
# with feature descriptions and testing instructions — no tech jargon.
#
# Usage:
#   ./scripts/generate-release-notes.sh           # normal build
#   ./scripts/generate-release-notes.sh --draft    # mark as DRAFT
#
# Prerequisites:
#   python3, pip3 install weasyprint
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "━━━ AscendSME Release Notes Generator ━━━"
echo ""
echo "📖 Reading CHANGELOG.md..."

if [ ! -f CHANGELOG.md ]; then
    echo "❌ CHANGELOG.md not found in project root."
    echo "   Create one with your release notes written in plain language."
    exit 1
fi

echo "🔄 Generating PDF..."
python3 scripts/generate_release_notes.py "$@"
echo ""

echo "━━━ Done ─────────────────────────────────"
echo ""
echo "   📎 ASCENDSME_UPDATES.pdf"
echo ""
echo "Share the PDF with your team!"
