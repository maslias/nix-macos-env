#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/raycast-import-settings.sh [path/to/settings.rayconfig]

Starts Raycast's import flow for an exported .rayconfig file.

This is intentionally semi-automated: Raycast stores settings/hotkeys in an
internal encrypted database, so the stable supported path is Raycast's own
Import Settings & Data command. You still need to enter the export passphrase
and choose which categories to import.

Recommended categories for this repo:
  - Settings, Aliases & Hotkeys
  - Window Management Layouts
  - Extensions installed from the Store, if your seed export intentionally has them

Avoid importing from a personal backup unless you really want its personal data
such as clipboard history, notes, AI chats, etc.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

rayconfig="${1:-}"

if [[ -z "$rayconfig" ]]; then
  for candidate in \
    "$PWD/assets/raycast/default.rayconfig" \
    "$PWD/secrets/raycast/default.rayconfig" \
    "$HOME/.config/raycast/default.rayconfig"; do
    if [[ -f "$candidate" ]]; then
      rayconfig="$candidate"
      break
    fi
  done
fi

if [[ -z "$rayconfig" ]]; then
  usage >&2
  echo >&2
  echo "error: no .rayconfig file supplied or found in the default locations" >&2
  exit 2
fi

if [[ ! -f "$rayconfig" ]]; then
  echo "error: file does not exist: $rayconfig" >&2
  exit 2
fi

case "$rayconfig" in
  *.rayconfig) ;;
  *) echo "warning: file does not end in .rayconfig: $rayconfig" >&2 ;;
esac

open -a Raycast || true
sleep 1

# Opening the .rayconfig is the least fragile way to enter Raycast's supported
# import UI. It is equivalent to selecting Import Settings & Data and choosing
# the file, while avoiding direct writes to Raycast's private database.
open "$rayconfig"

cat <<EOF

Raycast import opened for:
  $rayconfig

In Raycast:
  1. Enter the export passphrase.
  2. Select only the categories you want.
  3. Recommended: Settings, Aliases & Hotkeys; Window Management Layouts.
  4. Grant Accessibility permission when Window Management first asks for it.
EOF
