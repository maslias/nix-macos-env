#!/usr/bin/env bash
set -euo pipefail

username="$(id -un)"
require_pairings=0

usage() {
  cat <<'EOF'
Usage: yubikey-smartcard-policy-status [options]

Reports macOS smart-card-only login policy state and local PIV pairings.
This command does not change login policy, FileVault, PAM, or YubiKeys.

Options:
  --username USER            macOS user to inspect (default: current user)
  --require-pairings NUM     Exit non-zero unless at least NUM pairings exist
  -h, --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      username="$2"
      shift
      ;;
    --require-pairings)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      require_pairings="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

failures=0

check() {
  printf '  [CHECK] %s\n' "$*"
  failures=$((failures + 1))
}

pass() { printf '  [OK] %s\n' "$*"; }
manual() { printf '  [MANUAL] %s\n' "$*"; }

if [[ ! "$require_pairings" =~ ^[0-9]+$ ]]; then
  printf 'error: --require-pairings must be a non-negative integer\n' >&2
  exit 2
fi

policy_domain="/Library/Preferences/com.apple.security.smartcard"
enforce_raw="unset"
enforce_enabled=false

if command -v defaults >/dev/null 2>&1; then
  enforce_raw="$(defaults read "$policy_domain" enforceSmartCard 2>/dev/null || true)"
  case "$enforce_raw" in
    1|true|TRUE|YES|yes) enforce_enabled=true ;;
    "") enforce_raw="unset" ;;
  esac
else
  enforce_raw="defaults unavailable"
fi

pairing_output=""
pairing_count=0
if command -v sc_auth >/dev/null 2>&1; then
  pairing_output="$(sc_auth list -u "$username" 2>/dev/null || true)"
  pairing_count="$(awk 'NF { count++ } END { print count + 0 }' <<<"$pairing_output")"
fi

cat <<EOF
YubiKey smart-card-only login policy status
  user:             $username
  policy domain:    $policy_domain
  enforceSmartCard: $enforce_raw
EOF

cat <<'EOF'

Smart-card-only enforcement:
EOF
if [[ "$enforce_enabled" == true ]]; then
  pass "macOS smart-card-only policy is enabled"
else
  pass "macOS smart-card-only policy is not enabled"
fi

cat <<EOF

Paired smart-card public keys for $username:
EOF
if ! command -v sc_auth >/dev/null 2>&1; then
  check "sc_auth unavailable; cannot inspect smart-card pairings"
elif [[ -n "$pairing_output" ]]; then
  printf '%s\n' "$pairing_output" | sed 's/^/  /'
else
  check "no sc_auth pairings found for $username"
fi

cat <<'EOF'

Readiness for smart-card-only login:
EOF
if ((pairing_count >= require_pairings)); then
  pass "sc_auth pairing count is $pairing_count (required: $require_pairings)"
else
  check "sc_auth pairing count is $pairing_count (required: $require_pairings)"
fi
manual "verify primary YubiKey PIV unlock works before enabling smart-card-only login"
manual "verify backup YubiKey PIV unlock works before enabling smart-card-only login"
manual "verify recovery/admin access outside this account before enabling smart-card-only login"
manual "FileVault remains password/recovery-key based; this policy is not FileVault pre-boot unlock"

cat <<'EOF'

Result:
EOF
if ((failures == 0)); then
  cat <<'EOF'
  smart-card policy status checks passed; review MANUAL items before enforcement
EOF
  exit 0
fi

printf '  smart-card policy checks need attention (%d failing check(s))\n' "$failures"
exit 1
