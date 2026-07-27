#!/bin/sh
# Guard: CLAUDE.md must stay a thin pointer that imports AGENTS.md — the single
# source of truth every coding agent reads. Any other content (most likely a note
# appended by Claude Code's `#` memory shortcut, which writes to CLAUDE.md) is
# drift: Claude Code would see it via CLAUDE.md, but agents that read AGENTS.md
# would not. Such content belongs in AGENTS.md instead.
#
# Rule: every non-blank line of CLAUDE.md must be a Markdown heading (`#…`), a
# blockquote note (`>…`), or the exact import line `@AGENTS.md`, and the import
# must be present. Anything else fails the check.
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
file="$root/CLAUDE.md"

if [ ! -f "$file" ]; then
    echo "check-claude-md: CLAUDE.md is missing" >&2
    exit 1
fi

if ! grep -qxF '@AGENTS.md' "$file"; then
    echo "check-claude-md: CLAUDE.md must contain the import line '@AGENTS.md' (the canonical guide)." >&2
    exit 1
fi

# Lines that are NOT blank, a heading, a blockquote, or the import line.
offending=$(grep -nvE '^[[:space:]]*$|^#|^>|^@AGENTS\.md$' "$file" || true)
if [ -n "$offending" ]; then
    echo "check-claude-md: CLAUDE.md has content beyond the AGENTS.md pointer." >&2
    echo "Move it into AGENTS.md (edit that file, not CLAUDE.md). Offending line(s):" >&2
    echo "$offending" >&2
    exit 1
fi

echo "check-claude-md: OK — CLAUDE.md is a clean pointer to AGENTS.md"
