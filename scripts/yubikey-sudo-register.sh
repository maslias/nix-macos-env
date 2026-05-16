#!/usr/bin/env bash
set -euo pipefail

username="$(id -un)"
authfile="${YUBIKEY_PAM_U2F_AUTHFILE:-$HOME/.config/Yubico/u2f_keys}"
pin_verification=false

usage() {
  cat <<'EOF'
Usage: yubikey-sudo-register [options]

Registers the inserted YubiKey for pam_u2f sudo MFA by updating the user's
U2F/FIDO mapping file. This does not enable sudo MFA by itself; nix-darwin
must opt in separately.

Options:
  --username USER        Username to register (default: current user)
  --authfile PATH        Mapping file path (default: ~/.config/Yubico/u2f_keys)
  --pin-verification     Require FIDO2 PIN verification for this credential
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --username)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      username="$2"
      shift
      ;;
    --authfile)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      authfile="$2"
      shift
      ;;
    --pin-verification) pin_verification=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

command -v pamu2fcfg >/dev/null 2>&1 || fail "missing required tool: pamu2fcfg from pam_u2f"
command -v ykman >/dev/null 2>&1 || fail "missing required tool: ykman"

mapfile -t serials < <(ykman list --serials 2>/dev/null | awk 'NF')
if ((${#serials[@]} == 0)); then
  fail "no YubiKey detected; insert the key to register for sudo MFA"
fi

mkdir -p "$(dirname "$authfile")"
touch "$authfile"
chmod 700 "$(dirname "$authfile")"
chmod 600 "$authfile"

cat <<EOF
Registering YubiKey for sudo MFA
  user:     $username
  authfile: $authfile
  keys:     ${serials[*]}

You may be asked to touch the key. If --pin-verification was used, you may
also be prompted for the YubiKey FIDO2 PIN.
EOF

args=(--username "$username")
if [[ "$pin_verification" == true ]]; then
  args+=(--pin-verification)
fi

if grep -q "^${username}:" "$authfile"; then
  registration="$(pamu2fcfg --nouser "${args[@]}")"
  [[ -n "$registration" ]] || fail "pamu2fcfg produced an empty registration"

  tmp="$(mktemp -t u2f_keys.XXXXXX)"
  trap 'rm -f "$tmp"' EXIT
  awk -v user="$username" -v registration="$registration" 'BEGIN { FS = OFS = ":" } $1 == user { print $0 ":" registration; next } { print }' "$authfile" >"$tmp"
  mv "$tmp" "$authfile"
else
  pamu2fcfg "${args[@]}" >>"$authfile"
fi

chmod 600 "$authfile"

cat <<EOF

Registered YubiKey sudo MFA credential in:
  $authfile

This only creates the user mapping. sudo MFA is enabled only when the
nix-darwin option for this repo is turned on.
EOF
