#!/usr/bin/env bash
set -euo pipefail

primary_serial=""
backup_serial=""
replace_piv_identity=false
replace_sudo_authfile=false
skip_piv_access=false
skip_sudo=false
skip_piv_pairing_check=false
skip_policy=false

authfile="${YUBIKEY_PAM_U2F_AUTHFILE:-$HOME/.config/Yubico/u2f_keys}"

usage() {
  cat <<'EOF'
Usage: yubikey-workstation-rotate [options]

Interactive guided maintenance/rotation for existing primary and backup
workstation YubiKeys.

Safe default rotation covers:
  - verify local primary/backup enrollment state
  - rotate PIV PIN, PUK, and protected management key when confirmed
  - re-register sudo MFA credentials when confirmed
  - check macOS smart-card pairings and policy

Destructive/identity-changing rotation is opt-in only:
  --replace-piv-identity runs yubikey-piv-login-setup --force --pair and can
  overwrite PIV slot 9a key/certificate material. This changes the smart-card
  identity and requires successful re-pairing before smart-card-only login is safe.

Options:
  --primary-serial SERIAL     Pass serial for primary key operations
  --backup-serial SERIAL      Pass serial for backup key operations
  --replace-piv-identity      Replace PIV slot identity with --force --pair
  --replace-sudo-authfile     Backup and truncate pam_u2f authfile before re-registering keys
  --authfile PATH             pam_u2f mapping file (default: ~/.config/Yubico/u2f_keys)
  --skip-piv-access           Skip PIV PIN/PUK/management-key rotation prompts
  --skip-sudo                 Skip sudo MFA re-registration prompts
  --skip-piv-pairing-check    Skip PIV/macOS pairing status checks
  --skip-policy               Skip final policy/status checks
  -h, --help                  Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --primary-serial)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      primary_serial="$2"
      shift
      ;;
    --backup-serial)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      backup_serial="$2"
      shift
      ;;
    --replace-piv-identity) replace_piv_identity=true ;;
    --replace-sudo-authfile) replace_sudo_authfile=true ;;
    --authfile)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      authfile="$2"
      shift
      ;;
    --skip-piv-access) skip_piv_access=true ;;
    --skip-sudo) skip_sudo=true ;;
    --skip-piv-pairing-check) skip_piv_pairing_check=true ;;
    --skip-policy) skip_policy=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

need_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

confirm() {
  local prompt="$1"
  local answer=""
  read -r -p "$prompt [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

pause_for_key() {
  local role="$1"
  cat <<EOF

Insert the $role YubiKey now. Remove other YubiKeys unless you pass --${role}-serial.
EOF
  read -r -p "Press Enter when the $role key is inserted, or Ctrl-C to abort. " _
}

serial_for_role() {
  case "$1" in
    primary) printf '%s' "$primary_serial" ;;
    backup) printf '%s' "$backup_serial" ;;
  esac
}

ykman_device_args_for_role() {
  local serial
  serial="$(serial_for_role "$1")"
  if [[ -n "$serial" ]]; then
    printf '%s\n' --device "$serial"
  fi
}

helper_serial_args_for_role() {
  local serial
  serial="$(serial_for_role "$1")"
  if [[ -n "$serial" ]]; then
    printf '%s\n' --serial "$serial"
  fi
}

run_confirmed() {
  local description="$1"
  shift

  cat <<EOF

Next step: $description
Command: $*
EOF
  if confirm "Run this step now?"; then
    "$@"
  else
    echo "Skipped: $description"
  fi
}

rotate_piv_access() {
  local role="$1"
  local ykman_args=()
  mapfile -t ykman_args < <(ykman_device_args_for_role "$role")

  cat <<EOF

PIV access rotation for $role key
These steps may prompt for current and new PIN/PUK values.
Store new values in the approved secret store before continuing.
Avoid failed guesses; repeated wrong PIN/PUK attempts can block access.
EOF

  run_confirmed "change PIV PIN for $role key" \
    ykman "${ykman_args[@]}" piv access change-pin

  run_confirmed "change PIV PUK for $role key" \
    ykman "${ykman_args[@]}" piv access change-puk

  run_confirmed "rotate protected random PIV management key for $role key" \
    ykman "${ykman_args[@]}" piv access change-management-key --protect --generate
}

replace_piv_identity_for_role() {
  local role="$1"
  local helper_args=()
  mapfile -t helper_args < <(helper_serial_args_for_role "$role")

  cat <<EOF

WARNING: replacing the PIV identity for the $role key overwrites slot 9a and
changes the macOS smart-card identity. Smart-card-only login can break if the
new identity is not paired and tested before logout/reboot.
EOF

  run_confirmed "replace and pair PIV identity for $role key" \
    yubikey-piv-login-setup --force --pair "${helper_args[@]}"
}

for cmd in ykman yubikey-status yubikey-policy-check; do
  need_tool "$cmd"
done
[[ "$skip_sudo" == true ]] || need_tool yubikey-sudo-register
[[ "$replace_piv_identity" == false ]] || need_tool yubikey-piv-login-setup

cat <<'EOF'
YubiKey workstation rotation wizard

Keep an administrator shell open. Do not logout or reboot during rotation.
For smart-card-only hosts, verify one key works before rotating the other.
This wizard does not enable FileVault smart-card unlock.
EOF

if [[ "$replace_piv_identity" == true ]]; then
  cat <<'EOF'

DESTRUCTIVE MODE ENABLED: --replace-piv-identity was passed.
This can overwrite PIV slot 9a key/certificate material.
EOF
  confirm "Continue with destructive PIV identity replacement mode?" || fail "cancelled"
fi

if [[ "$skip_sudo" != true && "$replace_sudo_authfile" == true ]]; then
  mkdir -p "$(dirname "$authfile")"
  touch "$authfile"
  chmod 600 "$authfile"
  backup="${authfile}.rotation.$(date -u '+%Y%m%dT%H%M%SZ').backup"
  cp "$authfile" "$backup"
  : >"$authfile"
  chmod 600 "$authfile"
  cat <<EOF

Backed up and reset sudo MFA authfile:
  backup:  $backup
  current: $authfile
EOF
fi

for role in primary backup; do
  pause_for_key "$role"

  if [[ "$skip_piv_access" != true ]]; then
    rotate_piv_access "$role"
  fi

  if [[ "$skip_sudo" != true ]]; then
    run_confirmed "register fresh sudo MFA credential for $role key" \
      yubikey-sudo-register --authfile "$authfile"
  fi

  if [[ "$replace_piv_identity" == true ]]; then
    replace_piv_identity_for_role "$role"
  elif [[ "$skip_piv_pairing_check" != true ]] && command -v yubikey-piv-login-status >/dev/null 2>&1; then
    run_confirmed "show macOS smart-card pairing status after $role key rotation" \
      yubikey-piv-login-status
  fi

  cat <<EOF

Recommended manual validation for $role key before continuing:
  - sudo works with this key
  - lock/unlock works with this key's PIV PIN if smart-card login is enforced
EOF
  confirm "Continue to next step/key?" || fail "cancelled"
done

if [[ "$skip_policy" != true ]]; then
  cat <<'EOF'

Final read-only checks
EOF
  yubikey-status || true
  yubikey-policy-check --require-piv-pairings 2 || true
  if command -v yubikey-smartcard-policy-status >/dev/null 2>&1; then
    yubikey-smartcard-policy-status --require-pairings 2 || true
  fi
  if command -v yubikey-filevault-status >/dev/null 2>&1; then
    yubikey-filevault-status || true
  fi
fi

cat <<'EOF'

Rotation wizard finished.
Final manual validation still required:
  - test sudo with primary and backup keys
  - test lock/unlock with primary and backup keys
  - confirm recovery/admin access remains available
EOF
