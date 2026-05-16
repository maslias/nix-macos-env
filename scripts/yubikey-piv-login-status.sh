#!/usr/bin/env bash
set -euo pipefail

username="$(id -un)"

usage() {
  cat <<'EOF'
Usage: yubikey-piv-login-status [options]

Reports macOS smart-card/PIV identity visibility and pairings for a user.
This command does not change login policy or enforce smart-card-only login.

Options:
  --username USER  macOS user to inspect (default: current user)
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
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v sc_auth >/dev/null 2>&1 || fail "missing required macOS tool: sc_auth"

cat <<EOF
YubiKey PIV / macOS smart-card login status
  user: $username

Visible smart-card identities:
EOF

if ! sc_auth identities; then
  echo "  unable to read smart-card identities"
fi

cat <<EOF

Paired smart-card public keys for $username:
EOF

if ! sc_auth list -u "$username"; then
  echo "  unable to read smart-card pairings"
fi

cat <<'EOF'

FileVault smart-card status:
EOF
if sc_auth filevault -o status -u "$username" 2>/dev/null; then
  true
else
  cat <<'EOF'
  unavailable or not enabled for this user
EOF
fi

cat <<'EOF'

Current policy note:
  Smart-card/PIV login is paired as an additional unlock method.
  This repo does not enforce smart-card-only login.
  macOS password fallback should remain available unless a separate policy changes it.
EOF
