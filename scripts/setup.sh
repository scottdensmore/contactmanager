#!/bin/bash
#
# setup.sh — scaffold the per-developer signing override.
#
# Your Apple Developer team is personal, so it lives in a gitignored
# DeveloperSettings.xcconfig (pulled in by SharedSettings.xcconfig's
# `#include?`), not in the shared, committed config. Run this once after
# cloning if you want signed local builds from Xcode. (Plain `make build` /
# CI build with signing disabled, so this is only needed for signed runs.)
#
# Usage: ./scripts/setup.sh [TEAM_ID]
#   TEAM_ID defaults to $DEVELOPMENT_TEAM, else a placeholder you can edit.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
# Location matches SharedSettings.xcconfig's `#include? "../DeveloperSettings.xcconfig"`
# (relative to ContactManager/Config/ → ContactManager/).
dest="$root/ContactManager/DeveloperSettings.xcconfig"
team="${1:-${DEVELOPMENT_TEAM:-}}"

if [ -f "$dest" ]; then
  echo "DeveloperSettings.xcconfig already exists — leaving it untouched:"
  sed 's/^/  /' "$dest"
  exit 0
fi

if [ -z "$team" ]; then
  team="YOUR_TEAM_ID"
  echo "No team id given. Find yours in Xcode ▸ Settings ▸ Accounts, then"
  echo "edit the file below or re-run: ./scripts/setup.sh <TEAM_ID>"
fi

cat > "$dest" <<EOF
//
//  DeveloperSettings.xcconfig
//
//  Per-developer signing override (gitignored). Pulled in by
//  SharedSettings.xcconfig's \`#include?\`. Set your Apple Developer team here.
//
DEVELOPMENT_TEAM = $team
EOF

echo "Wrote $dest"
echo "  DEVELOPMENT_TEAM = $team"
