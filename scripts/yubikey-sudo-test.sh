#!/usr/bin/env bash
set -euo pipefail

pam_u2f_authfile="${YUBIKEY_PAM_U2F_AUTHFILE:-$HOME/.config/Yubico/u2f_keys}"
run_sudo=true

usage() {
  cat <<'EOF'
Usage: yubikey-sudo-test [options]

Guided validation for YubiKey-backed sudo MFA. It checks local pam_u2f
registration and then optionally runs `sudo -k` + `sudo -v`.

Options:
  --pam-u2f-authfile PATH  Read pam_u2f mapping from PATH
  --check-only             Only check files/config; do not run sudo validation
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pam-u2f-authfile)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      pam_u2f_authfile="$2"
      shift
      ;;
    --check-only) run_sudo=false ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

warn() {
  printf 'warning: %s\n' "$*" >&2
}

user="$(id -un)"

cat <<EOF
YubiKey sudo MFA test
  user:             $user
  pam_u2f authfile: $pam_u2f_authfile
EOF

if [[ ! -r "$pam_u2f_authfile" ]]; then
  fail "pam_u2f mapping file is missing or unreadable; run yubikey-sudo-register first"
fi

if ! grep -q "^${user}:" "$pam_u2f_authfile"; then
  fail "no pam_u2f credential mapping found for user '$user'; run yubikey-sudo-register"
fi

if [[ -r /etc/pam.d/sudo_local ]]; then
  if grep -q 'pam_u2f.so' /etc/pam.d/sudo_local; then
    echo "PAM sudo_local: pam_u2f is enabled"
  else
    warn "PAM sudo_local does not currently contain pam_u2f; Nix option may not be applied yet"
  fi
else
  warn "/etc/pam.d/sudo_local is not readable; cannot inspect active PAM config"
fi

if command -v yubikey-status >/dev/null 2>&1; then
  cat <<'EOF'

Current YubiKey readiness status:
EOF
  yubikey-status || true
fi

if [[ "$run_sudo" != true ]]; then
  cat <<'EOF'

Check-only mode complete. Sudo validation was not run.
EOF
  exit 0
fi

cat <<'EOF'

About to validate sudo MFA with:
  sudo -k
  sudo -v

Keep another administrator shell open while testing. With the current host
policy, touch the YubiKey if it blinks; FIDO2 PIN entry is not required for the
YubiKey sudo factor unless the Nix sudoMfa.pinVerification option is enabled.
EOF

read -r -p "Run sudo validation now? [y/N] " answer
case "$answer" in
  y|Y|yes|YES) ;;
  *) fail "sudo validation cancelled" ;;
esac

sudo -k
if sudo -v; then
  cat <<'EOF'

sudo MFA validation succeeded.
EOF
  exit 0
fi

cat <<'EOF' >&2

sudo MFA validation failed.
Recovery:
  1. Keep or open an administrator/root-authenticated shell if available.
  2. Disable `gdca.yubikey.sudoMfa.enable` in the Nix config.
  3. Re-run darwin-rebuild switch.
EOF
exit 1
