#!/usr/bin/env bash
set -euo pipefail

username="$(id -un)"
hash_value=""
sc_auth_bin="${YUBIKEY_SC_AUTH:-/usr/sbin/sc_auth}"

usage() {
  cat <<'EOF'
Usage: yubikey-filevault-status [options]

Read-only discovery for macOS FileVault smart-card/YubiKey unlock support.
This command does not enable, disable, or modify FileVault, smart-card pairings,
PAM, login policy, or YubiKeys.

Options:
  --username USER  macOS user to inspect (default: current user)
  --hash HASH      Public-key hash to query with sc_auth filevault status
  -h, --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      username="$2"
      shift
      ;;
    --hash)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      hash_value="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

run_or_report() {
  local label="$1"
  shift

  printf '\n%s:\n' "$label"
  if "$@"; then
    return 0
  fi

  local status=$?
  printf '  command exited with status %d\n' "$status"
  return 0
}

cat <<EOF
YubiKey / macOS FileVault smart-card discovery
  user: $username
EOF

cat <<'EOF'

Safety boundary:
  read-only discovery only; no FileVault or smart-card settings are changed
EOF

if command -v fdesetup >/dev/null 2>&1; then
  run_or_report "FileVault status" fdesetup status
else
  printf '\nFileVault status:\n  fdesetup unavailable\n'
fi

if [[ -x "$sc_auth_bin" ]]; then
  run_or_report "sc_auth pairings for $username" "$sc_auth_bin" list -u "$username"
  run_or_report "sc_auth visible smart-card identities" "$sc_auth_bin" identities

  args=(filevault -o status -u "$username")
  if [[ -n "$hash_value" ]]; then
    args+=(-h "$hash_value")
  fi
  run_or_report "sc_auth FileVault smart-card status for $username" "$sc_auth_bin" "${args[@]}"
else
  printf '\nsc_auth checks:\n  %s unavailable\n' "$sc_auth_bin"
fi

cat <<'EOF'

Interpretation notes:
  - FileVault smart-card unlock is separate from macOS smart-card-only login.
  - FileVault remains password/recovery-key based unless a later explicit enable step succeeds.
  - A message about SecureToken means this Mac/user state must be understood before any enable attempt.
  - Do not enable FileVault smart-card unlock without escrowed recovery key and a tested recovery path.
EOF
