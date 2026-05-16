#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/yubikey-smartcard-policy-status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

fakebin="$tmpdir/bin"
mkdir -p "$fakebin"

cat >"$fakebin/defaults" <<'EOF_DEFAULTS'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 3 && "$1" == "read" && "$2" == "/Library/Preferences/com.apple.security.smartcard" && "$3" == "enforceSmartCard" ]]; then
  printf '0\n'
  exit 0
fi
printf 'unexpected defaults invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_DEFAULTS
chmod +x "$fakebin/defaults"

cat >"$fakebin/sc_auth" <<'EOF_SC_AUTH'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -ge 3 && "$1" == "list" && "$2" == "-u" ]]; then
  printf 'HASH_FOR_PRIMARY\nHASH_FOR_BACKUP\n'
  exit 0
fi
printf 'unexpected sc_auth invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_SC_AUTH
chmod +x "$fakebin/sc_auth"

output="$(PATH="$fakebin:$PATH" "$script" --username testuser --require-pairings 2)"
printf '%s\n' "$output"

if ! grep -Fq 'enforceSmartCard: 0' <<<"$output"; then
  fail "expected disabled enforceSmartCard status"
fi
if ! grep -Fq '[OK] macOS smart-card-only policy is not enabled' <<<"$output"; then
  fail "expected smart-card-only policy to report not enabled"
fi
if ! grep -Fq '[OK] sc_auth pairing count is 2 (required: 2)' <<<"$output"; then
  fail "expected fake pairing count policy to pass"
fi
if ! grep -Fq 'smart-card policy status checks passed' <<<"$output"; then
  fail "expected overall status result to pass"
fi
