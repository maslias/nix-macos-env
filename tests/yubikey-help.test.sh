#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

scripts=(
  yubikey-check.sh
  yubikey-enroll.sh
  yubikey-harden.sh
  yubikey-status.sh
  yubikey-sudo-register.sh
  yubikey-sudo-test.sh
  yubikey-piv-login-setup.sh
  yubikey-piv-login-status.sh
  yubikey-policy-check.sh
  yubikey-smartcard-policy-status.sh
  yubikey-smartcard-policy-disable.sh
)

for name in "${scripts[@]}"; do
  script="$repo_root/scripts/$name"
  output="$($script --help)"
  printf '%s\n' "--- $name --help ---"
  printf '%s\n' "$output"

  if ! grep -Fq 'Usage:' <<<"$output"; then
    fail "$name help output should include usage header"
  fi

  for leaked in '#!/usr/bin/env bash' 'set -euo pipefail' 'case "$1" in' 'trap ' 'mktemp '; do
    if grep -Fq "$leaked" <<<"$output"; then
      fail "$name help output should not include implementation detail: $leaked"
    fi
  done
done
