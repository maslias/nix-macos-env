#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

output="$($script --help)"
printf '%s\n' "$output"

if grep -Fq 'set -euo pipefail' <<<"$output"; then
  fail "usage output should not include implementation lines"
fi

if ! grep -Fq 'Usage:' <<<"$output"; then
  fail "usage output should include usage header"
fi
