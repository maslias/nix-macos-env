#!/usr/bin/env bash
set -euo pipefail

username="$(id -un)"
inventory_file="${YUBIKEY_INVENTORY_FILE:-$HOME/.config/nix-macos/yubikeys.tsv}"
pam_u2f_authfile="${YUBIKEY_PAM_U2F_AUTHFILE:-$HOME/.config/Yubico/u2f_keys}"
require_piv_pairings=0

usage() {
  cat <<'EOF'
Usage: yubikey-policy-check [options]

Reports local YubiKey operational-policy compliance without changing YubiKeys,
PAM, macOS login, FileVault, or smart-card policy.

Default required checks:
  - one primary YubiKey enrollment record for the user
  - one backup YubiKey enrollment record for the user
  - one pam_u2f sudo MFA mapping for the user

Options:
  --username USER              User to inspect (default: current user)
  --inventory-file PATH        Read enrollment inventory from PATH
  --pam-u2f-authfile PATH      Read pam_u2f mapping from PATH
  --require-piv-pairings NUM   Require at least NUM sc_auth pairings for USER
  -h, --help                   Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      username="$2"
      shift
      ;;
    --inventory-file)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      inventory_file="$2"
      shift
      ;;
    --pam-u2f-authfile)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      pam_u2f_authfile="$2"
      shift
      ;;
    --require-piv-pairings)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      require_piv_pairings="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

failures=0

pass() { printf '  [OK] %s\n' "$*"; }
check() {
  printf '  [CHECK] %s\n' "$*"
  failures=$((failures + 1))
}
manual() { printf '  [MANUAL] %s\n' "$*"; }

is_non_negative_integer() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

if ! is_non_negative_integer "$require_piv_pairings"; then
  printf 'error: --require-piv-pairings must be a non-negative integer\n' >&2
  exit 2
fi

primary_count=0
backup_count=0
unknown_count=0
if [[ -r "$inventory_file" ]]; then
  while IFS=$'\t' read -r _ts rec_user _rec_host serial _action role _status _rest; do
    [[ -n "${serial:-}" ]] || continue
    [[ "${rec_user:-}" == "$username" ]] || continue
    case "${role:-unknown}" in
      primary) primary_count=$((primary_count + 1)) ;;
      backup) backup_count=$((backup_count + 1)) ;;
      *) unknown_count=$((unknown_count + 1)) ;;
    esac
  done <"$inventory_file"
fi

has_sudo_mapping=false
if [[ -r "$pam_u2f_authfile" ]] && grep -q "^${username}:" "$pam_u2f_authfile"; then
  has_sudo_mapping=true
fi

cat <<EOF
YubiKey operational policy check
  user:                $username
  inventory file:      $inventory_file
  pam_u2f authfile:    $pam_u2f_authfile
EOF

cat <<'EOF'

Enrollment policy:
EOF
if ((primary_count >= 1)); then
  pass "primary YubiKey enrollment recorded ($primary_count)"
else
  check "primary YubiKey enrollment missing"
fi

if ((backup_count >= 1)); then
  pass "backup YubiKey enrollment recorded ($backup_count)"
else
  check "backup YubiKey enrollment missing"
fi

if ((unknown_count > 0)); then
  manual "legacy/unknown-role enrollment records present ($unknown_count); re-record with --role primary|backup if needed"
fi

cat <<'EOF'

Sudo MFA policy:
EOF
if [[ "$has_sudo_mapping" == true ]]; then
  pass "pam_u2f sudo MFA mapping present"
else
  check "pam_u2f sudo MFA mapping missing"
fi
manual "confirm every authorized physical YubiKey has been registered with yubikey-sudo-register"

cat <<'EOF'

macOS PIV/smart-card policy:
EOF
if ((require_piv_pairings == 0)); then
  manual "PIV pairings are informational by default; run with --require-piv-pairings NUM to enforce a local count check"
else
  if ! command -v sc_auth >/dev/null 2>&1; then
    check "sc_auth unavailable; cannot verify required PIV pairings"
  else
    pairing_output="$(sc_auth list -u "$username" 2>/dev/null || true)"
    pairing_count="$(awk 'NF { count++ } END { print count + 0 }' <<<"$pairing_output")"
    if ((pairing_count >= require_piv_pairings)); then
      pass "sc_auth pairing count is $pairing_count (required: $require_piv_pairings)"
    else
      check "sc_auth pairing count is $pairing_count (required: $require_piv_pairings)"
    fi
  fi
fi
manual "password fallback must remain tested unless a separate smart-card-only policy is approved"

cat <<'EOF'

FileVault policy:
EOF
manual "FileVault remains password/recovery-key based; verify recovery key escrow outside this Mac"
manual "do not assume YubiKey-only FileVault pre-boot unlock"

cat <<'EOF'

Result:
EOF
if ((failures == 0)); then
  cat <<'EOF'
  policy checks passed; review MANUAL items before relying on enforcement
EOF
  exit 0
fi

printf '  policy checks need attention (%d failing check(s))\n' "$failures"
exit 1
