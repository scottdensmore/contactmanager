#!/usr/bin/env bash
#
# setup.sh — scaffold the per-developer build settings so anyone can clone,
# set their own signing team + organization identifier, and build.
#
# Writes ContactManager/DeveloperSettings.xcconfig (gitignored) from the
# tracked DeveloperSettings.template.xcconfig. SharedSettings.xcconfig pulls
# it in via `#include?` and derives the bundle id from ORGANIZATION_IDENTIFIER,
# so every developer gets their own bundle id (and iCloud container).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_PATH="${SCRIPT_DIR}/ContactManager/DeveloperSettings.template.xcconfig"
SETTINGS_PATH="${SCRIPT_DIR}/ContactManager/DeveloperSettings.xcconfig"

TEAM_ID="${DEV_TEAM_ID:-}"
ORG_IDENTIFIER="${ORG_IDENTIFIER:-}"
NON_INTERACTIVE=false
FORCE=false

usage() {
  cat <<'USAGE'
Usage: ./setup.sh [options]

Creates ContactManager/DeveloperSettings.xcconfig (gitignored) for signed
local builds. Plain `make build` / CI build with signing off and don't need it.

Options:
  --non-interactive          Run without prompts (requires all values)
  --dev-team-id <id>         Apple Developer Team ID
  --org-identifier <value>   Reverse-domain identifier (e.g. com.example)
  --force                    Overwrite an existing DeveloperSettings.xcconfig
  -h, --help                 Show this help

Environment fallbacks: DEV_TEAM_ID, ORG_IDENTIFIER
USAGE
}

require_option_value() {
  if [ -z "${2:-}" ]; then
    echo "error: $1 requires a value" >&2
    exit 1
  fi
}

has_placeholder_value() { [[ "$1" == \<*\> ]]; }

validate_settings() {
  local missing=()
  [ -z "${TEAM_ID}" ] && missing+=("DEV_TEAM_ID/--dev-team-id")
  [ -z "${ORG_IDENTIFIER}" ] && missing+=("ORG_IDENTIFIER/--org-identifier")
  if [ "${#missing[@]}" -gt 0 ]; then
    echo "error: setup requires all values." >&2
    printf 'missing: %s\n' "${missing[@]}" >&2
    exit 1
  fi
  if has_placeholder_value "${TEAM_ID}" || has_placeholder_value "${ORG_IDENTIFIER}"; then
    echo "error: replace placeholder values before running setup." >&2
    exit 1
  fi
  if [[ "${ORG_IDENTIFIER}" != *.* ]]; then
    echo "error: --org-identifier should be a reverse-domain value, e.g. com.example" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --non-interactive) NON_INTERACTIVE=true; shift ;;
    --force) FORCE=true; shift ;;
    --dev-team-id) require_option_value "$1" "${2:-}"; TEAM_ID="$2"; shift 2 ;;
    --org-identifier) require_option_value "$1" "${2:-}"; ORG_IDENTIFIER="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [ -f "${SETTINGS_PATH}" ] && [ "${FORCE}" = false ]; then
  echo "ContactManager/DeveloperSettings.xcconfig already exists — leaving it untouched."
  echo "Re-run with --force to overwrite it."
  exit 0
fi

if [ "${NON_INTERACTIVE}" = false ]; then
  if [ -z "${TEAM_ID}" ]; then
    echo "1. Enter your Apple Developer Team ID:"
    read -r TEAM_ID
  fi
  if [ -z "${ORG_IDENTIFIER}" ]; then
    echo "2. Enter your organization identifier (reverse-domain, e.g. com.example):"
    read -r ORG_IDENTIFIER
  fi
fi

validate_settings

if [ ! -f "${TEMPLATE_PATH}" ]; then
  echo "error: template not found at ${TEMPLATE_PATH}" >&2
  exit 1
fi

echo "Creating ${SETTINGS_PATH}"
content="$(< "${TEMPLATE_PATH}")"
content="${content//<YOUR_APPLE_TEAM_ID>/${TEAM_ID}}"
content="${content//<YOUR_REVERSED_DOMAIN>/${ORG_IDENTIFIER}}"
printf '%s\n' "${content}" > "${SETTINGS_PATH}"
chmod 600 "${SETTINGS_PATH}"
echo "Done. Open ContactManager.xcodeproj in Xcode and build ContactManager."
