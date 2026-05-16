#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/yubikey-enroll.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

set +e
output="$($script --role tertiary --non-interactive 2>&1)"
status=$?
set -e

printf '%s\n' "$output"

if [[ "$status" -eq 0 ]]; then
  fail "invalid role should fail"
fi

if ! grep -Fq "invalid role 'tertiary'; expected primary or backup" <<<"$output"; then
  fail "invalid role error should explain accepted roles"
fi

if grep -Fq "missing required tool" <<<"$output"; then
  fail "role validation should happen before checking YubiKey tooling"
fi
