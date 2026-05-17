#!/usr/bin/env bash
set -euo pipefail

skip_harden=false
skip_sudo=false
skip_piv=false
skip_policy=false
skip_filevault=false
primary_serial=""
backup_serial=""

usage() {
  cat <<'EOF'
Usage: yubikey-workstation-setup [options]

Interactive guided setup for a primary and backup YubiKey on this workstation.
The wizard calls the existing focused helpers and pauses before steps that may
prompt for PINs, touch, sudo, or smart-card pairing.

What it can guide:
  - enroll primary and backup roles in local inventory
  - harden/check each key
  - register each key for sudo MFA
  - create/pair PIV smart-card login identities
  - run final status/policy checks
  - optionally run FileVault smart-card unlock preflight/recovery verification/enablement

Safety boundaries:
  - does not enable FileVault smart-card unlock unless explicitly selected and confirmed
  - does not enforce new policy by itself beyond the current Nix config
  - does not use --force for PIV slots

Options:
  --primary-serial SERIAL  Pass serial for primary enrollment/hardening/PIV steps
  --backup-serial SERIAL   Pass serial for backup enrollment/hardening/PIV steps
  --skip-harden            Skip yubikey-harden steps
  --skip-sudo              Skip yubikey-sudo-register steps
  --skip-piv               Skip yubikey-piv-login-setup --pair steps
  --skip-policy            Skip final policy/status checks
  --skip-filevault         Skip optional FileVault smart-card unlock preflight/enable step
  -h, --help               Show this help
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
    --skip-harden) skip_harden=true ;;
    --skip-sudo) skip_sudo=true ;;
    --skip-piv) skip_piv=true ;;
    --skip-policy) skip_policy=true ;;
    --skip-filevault) skip_filevault=true ;;
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

run_or_skip() {
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

serial_args_for_role() {
  local role="$1"
  local serial=""
  case "$role" in
    primary) serial="$primary_serial" ;;
    backup) serial="$backup_serial" ;;
  esac

  if [[ -n "$serial" ]]; then
    printf '%s\n' --serial "$serial"
  fi
}

for cmd in yubikey-enroll yubikey-status yubikey-policy-check; do
  need_tool "$cmd"
done
[[ "$skip_harden" == true ]] || need_tool yubikey-harden
[[ "$skip_sudo" == true ]] || need_tool yubikey-sudo-register
[[ "$skip_piv" == true ]] || need_tool yubikey-piv-login-setup
[[ "$skip_filevault" == true ]] || need_tool yubikey-filevault-enable

cat <<'EOF'
YubiKey workstation guided setup

Keep an administrator shell open while testing authentication changes.
Have both physical YubiKeys available: primary and backup.
Store any PIN/PUK values in the approved secret store.

This wizard is a guide around existing helpers. Review every prompt.
EOF

for role in primary backup; do
  pause_for_key "$role"
  mapfile -t serial_args < <(serial_args_for_role "$role")

  run_or_skip "record $role enrollment" \
    yubikey-enroll --role "$role" "${serial_args[@]}"

  if [[ "$skip_harden" != true ]]; then
    run_or_skip "harden/check $role YubiKey" \
      yubikey-harden "${serial_args[@]}"
  fi

  if [[ "$skip_sudo" != true ]]; then
    run_or_skip "register $role YubiKey for sudo MFA" \
      yubikey-sudo-register
  fi

  if [[ "$skip_piv" != true ]]; then
    run_or_skip "create or pair $role PIV identity for macOS smart-card login" \
      yubikey-piv-login-setup --pair "${serial_args[@]}"
  fi
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

if [[ "$skip_filevault" != true ]]; then
  cat <<'EOF'

Optional FileVault smart-card/YubiKey unlock

This affects pre-boot authentication and is intentionally separate from normal
macOS smart-card login. The recommended first run is preflight only.
EOF
  if confirm "Run FileVault YubiKey unlock preflight now?"; then
    yubikey-filevault-enable --dry-run || true
  fi
  if confirm "Run recovery/admin verification checkpoint now?"; then
    yubikey-filevault-enable --verify-recovery || true
  fi
  if confirm "Enable FileVault YubiKey unlock now? Only say yes if recovery verification passed"; then
    yubikey-filevault-enable --execute
  else
    echo "Skipped: FileVault YubiKey unlock enablement"
  fi
fi

cat <<'EOF'

Guided setup finished.
Manual validation still required:
  - test sudo MFA with primary and backup keys
  - test macOS lock/unlock with primary and backup PIV PINs
  - verify recovery/admin access remains available
  - keep FileVault password/recovery-key unlock documented
EOF
