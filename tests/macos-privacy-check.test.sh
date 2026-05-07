#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

stealth_raw="$(/usr/libexec/ApplicationFirewall/socketfilterfw --getstealthmode 2>/dev/null || true)"
if [[ "$stealth_raw" != *"is on"* ]]; then
  printf 'SKIP: stealth mode is not on in this environment; raw output: %s\n' "$stealth_raw"
  exit 0
fi

output="$($script)"
printf '%s\n' "$output"

if ! grep -Fq '[OK] Stealth mode enabled' <<<"$output"; then
  fail "expected script to report stealth mode enabled when socketfilterfw says: $stealth_raw"
fi
