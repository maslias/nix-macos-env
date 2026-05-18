#!/usr/bin/env bash
set -euo pipefail

username="$(id -un)"
hash_value=""
mode="dry-run"
recovery_check_window_hours=24
sc_auth_bin="${YUBIKEY_SC_AUTH:-/usr/sbin/sc_auth}"
sudo_bin="${YUBIKEY_SUDO:-sudo}"
checkpoint_file="${YUBIKEY_FILEVAULT_RECOVERY_CHECKPOINT:-$HOME/.config/nix-macos/filevault-smartcard-recovery.tsv}"

usage() {
  cat <<'EOF'
Usage: yubikey-filevault-enable [options]

Guided preflight and optional enablement for macOS FileVault smart-card/YubiKey
unlock. Default mode is --dry-run and makes no changes.

Options:
  --username USER  macOS user to enable (default: current user)
  --hash HASH      paired smart-card public-key hash to enable
  --dry-run        run preflight only; do not enable (default)
  --verify-recovery
                   verify recovery/admin readiness and write a local checkpoint
  --execute        experimental enable attempt; blocked when smart-card-only login is enforced
  --recovery-check-window-hours HOURS
                   require recovery checkpoint newer than HOURS for --execute (default: 24)
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
    --dry-run) mode="dry-run" ;;
    --verify-recovery) mode="verify-recovery" ;;
    --execute) mode="execute" ;;
    --recovery-check-window-hours)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      recovery_check_window_hours="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

failures=0
warnings=0

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

check() {
  printf '  [CHECK] %s\n' "$*"
  failures=$((failures + 1))
}

warn() {
  printf '  [WARN] %s\n' "$*"
  warnings=$((warnings + 1))
}

pass() { printf '  [OK] %s\n' "$*"; }
manual() { printf '  [MANUAL] %s\n' "$*"; }

if [[ ! "$recovery_check_window_hours" =~ ^[0-9]+$ ]] || ((recovery_check_window_hours < 1)); then
  fail "--recovery-check-window-hours must be a positive integer"
fi

require_command() {
  if command -v "$1" >/dev/null 2>&1; then
    pass "found $1"
  else
    check "missing required command: $1"
  fi
}

extract_hashes() {
  awk '
    /^Hash:[[:space:]]*/ { print $2; next }
    /^[[:xdigit:]]{40}/ { print $1; next }
  '
}

contains_line() {
  local needle="$1"
  grep -Fxq "$needle"
}

prompt_exact() {
  local expected="$1"
  local answer=""
  printf '\nType exactly to continue:\n  %s\n> ' "$expected"
  read -r answer
  [[ "$answer" == "$expected" ]]
}

checkpoint_now() {
  mkdir -p "$(dirname "$checkpoint_file")"
  printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$username" "${data_volume_uuid:-unknown}" "recovery-verified" >>"$checkpoint_file"
}

latest_checkpoint_epoch() {
  [[ -f "$checkpoint_file" ]] || return 1
  awk -F'\t' -v user="$username" -v uuid="${data_volume_uuid:-unknown}" '
    $2 == user && ($3 == uuid || uuid == "unknown" || $3 == "unknown") && $4 == "recovery-verified" { latest=$1 }
    END { if (latest != "") print latest; else exit 1 }
  ' "$checkpoint_file"
}

cat <<EOF
YubiKey FileVault smart-card unlock enablement
  user: $username
  mode: $mode

Safety boundary:
  --dry-run makes no changes
  --execute can affect pre-boot FileVault unlock; recovery key and RecoveryOS must be ready
  --verify-recovery automates recovery/admin checks and records a local checkpoint
EOF

cat <<'EOF'

Tool availability:
EOF
require_command uname
require_command fdesetup
require_command sysadminctl
require_command dscl
require_command diskutil
require_command security
if command -v ykman >/dev/null 2>&1; then
  pass "found ykman"
else
  warn "ykman unavailable; cannot preflight YubiKey PIV slot 9d key-management certificate"
fi
if [[ -x "$sc_auth_bin" ]]; then
  pass "found $sc_auth_bin"
else
  check "missing required command: $sc_auth_bin"
fi
if [[ "$mode" == "execute" || "$mode" == "verify-recovery" ]]; then
  if command -v "$sudo_bin" >/dev/null 2>&1; then
    pass "found $sudo_bin"
  else
    check "missing required command: $sudo_bin"
  fi
fi

cat <<'EOF'

Platform:
EOF
arch="$(uname -m 2>/dev/null || true)"
if [[ "$arch" == "arm64" ]]; then
  pass "Apple silicon architecture detected: $arch"
else
  check "FileVault smart-card unlock is only supported by this workflow on Apple silicon; detected: ${arch:-unknown}"
fi

cat <<'EOF'

macOS smart-card login policy:
EOF
smartcard_policy_raw="unset"
smartcard_only_enforced=false
if command -v defaults >/dev/null 2>&1; then
  smartcard_policy_raw="$(defaults read /Library/Preferences/com.apple.security.smartcard enforceSmartCard 2>/dev/null || true)"
  case "$smartcard_policy_raw" in
    1|true|TRUE|YES|yes) smartcard_only_enforced=true ;;
    "") smartcard_policy_raw="unset" ;;
  esac
else
  smartcard_policy_raw="defaults unavailable"
fi
if [[ "$smartcard_only_enforced" == true ]]; then
  if [[ "$mode" == "execute" ]]; then
    check "smart-card-only login is enforced; refusing FileVault smart-card enablement after observed pre-boot lockout"
    printf '\nExecute blocked before privileged checks: %d blocking check(s), %d warning(s)\n' "$failures" "$warnings"
    exit 1
  else
    warn "smart-card-only login is enforced; FileVault smart-card enablement is blocked by this workflow"
  fi
else
  pass "smart-card-only login enforcement is not enabled ($smartcard_policy_raw)"
fi

cat <<'EOF'

FileVault and account state:
EOF
fv_status="$(fdesetup status 2>/dev/null || true)"
if grep -Fq 'FileVault is On.' <<<"$fv_status"; then
  pass "FileVault is on"
else
  check "FileVault is not on or status is unavailable: ${fv_status:-no output}"
fi

secure_token_output="$(sysadminctl -secureTokenStatus "$username" 2>&1 || true)"
if grep -Fqi 'Secure token is ENABLED' <<<"$secure_token_output"; then
  pass "SecureToken is enabled for $username"
else
  check "SecureToken is not confirmed for $username: ${secure_token_output:-no output}"
fi

generated_uid="$(dscl . -read "/Users/$username" GeneratedUID 2>/dev/null | awk '{ print $2; exit }' || true)"
if [[ -n "$generated_uid" ]]; then
  pass "GeneratedUID for $username: $generated_uid"
else
  check "cannot read GeneratedUID for $username"
fi

apfs_users="$(diskutil apfs listUsers / 2>/dev/null || true)"
if [[ -n "$generated_uid" ]] && grep -Fq -- "$generated_uid" <<<"$apfs_users"; then
  pass "$username appears in APFS cryptographic users"
  if awk -v uid="$generated_uid" '
    index($0, uid) { found=1; next }
    found && /Volume Owner:[[:space:]]*Yes/ { ok=1; exit }
    found && /^\+--/ { exit }
    END { exit ok ? 0 : 1 }
  ' <<<"$apfs_users"; then
    pass "$username is APFS volume owner"
  else
    check "$username is not confirmed as APFS volume owner"
  fi
else
  check "$username is not found in APFS cryptographic users"
fi

data_volume_uuid="$(diskutil info /System/Volumes/Data 2>/dev/null | awk -F': *' '/Volume UUID/{ print $2; exit }' || true)"
if [[ -n "$data_volume_uuid" ]]; then
  pass "APFS Data volume UUID: $data_volume_uuid"
else
  warn "APFS Data volume UUID unavailable; RecoveryOS skip-enforcement command cannot be prefilled"
fi

fdesetup_list=""
if [[ "$mode" == "execute" || "$mode" == "verify-recovery" ]]; then
  fdesetup_list="$($sudo_bin fdesetup list 2>/dev/null || true)"
else
  fdesetup_list="$(fdesetup list 2>/dev/null || true)"
fi
if [[ -n "$fdesetup_list" ]] && grep -Fq -- "$username," <<<"$fdesetup_list"; then
  pass "$username is FileVault-authorized"
elif [[ "$mode" == "dry-run" ]]; then
  warn "could not confirm $username in fdesetup list without sudo; --execute/--verify-recovery will require this check"
else
  check "$username is not confirmed in sudo fdesetup list"
fi

cat <<'EOF'

Recovery/admin readiness:
EOF
admin_members="$(dscl . -read /Groups/admin GroupMembership 2>/dev/null | cut -d: -f2- | xargs || true)"
if [[ -n "$admin_members" ]]; then
  pass "admin group has member(s): $admin_members"
  if grep -Eq "(^|[[:space:]])$username($|[[:space:]])" <<<"$admin_members"; then
    pass "$username is an admin user"
  else
    warn "$username is not listed in the admin group; ensure another admin recovery path is available"
  fi
elif [[ "$mode" == "dry-run" ]]; then
  warn "cannot confirm any local admin users; run --verify-recovery for blocking recovery checks"
else
  check "cannot confirm any local admin users"
fi

if [[ "$mode" == "execute" || "$mode" == "verify-recovery" ]]; then
  if $sudo_bin -v; then
    pass "sudo authentication works for $username"
  else
    check "sudo authentication failed for $username"
  fi

  personal_recovery_key="$($sudo_bin fdesetup haspersonalrecoverykey 2>/dev/null || true)"
  case "$personal_recovery_key" in
    true) pass "FileVault reports a personal recovery key is configured" ;;
    false) check "FileVault reports no personal recovery key" ;;
    *) warn "could not determine personal recovery key state: ${personal_recovery_key:-no output}" ;;
  esac
else
  warn "sudo/admin and personal recovery key checks skipped in --dry-run; run --verify-recovery"
fi

cat <<'EOF'

Smart-card pairing state:
EOF
pairing_output=""
identity_output=""
if [[ -x "$sc_auth_bin" ]]; then
  pairing_output="$($sc_auth_bin list -u "$username" 2>/dev/null || true)"
  identity_output="$($sc_auth_bin identities 2>/dev/null || true)"
fi

mapfile -t paired_hashes < <(printf '%s\n' "$pairing_output" | extract_hashes | sort -u)
if ((${#paired_hashes[@]} > 0)); then
  pass "found ${#paired_hashes[@]} paired smart-card hash(es) for $username"
  printf '%s\n' "${paired_hashes[@]}" | sed 's/^/    /'
else
  check "no paired smart-card hashes found for $username"
fi

if [[ -n "$identity_output" ]]; then
  pass "sc_auth identities returned smart-card information"
else
  check "no visible smart-card identities; insert the target YubiKey"
fi

if [[ -z "$hash_value" ]]; then
  candidates=()
  for h in "${paired_hashes[@]}"; do
    if grep -Fq -- "$h" <<<"$identity_output"; then
      candidates+=("$h")
    fi
  done
  if ((${#candidates[@]} == 1)); then
    hash_value="${candidates[0]}"
    pass "selected inserted paired hash: $hash_value"
  elif ((${#candidates[@]} > 1)); then
    check "multiple inserted paired hashes are visible; rerun with --hash HASH"
  else
    check "could not select an inserted paired hash; insert one paired YubiKey or pass --hash HASH"
  fi
else
  if printf '%s\n' "${paired_hashes[@]}" | contains_line "$hash_value"; then
    pass "requested hash is paired for $username: $hash_value"
  else
    check "requested hash is not paired for $username: $hash_value"
  fi
  if grep -Fq -- "$hash_value" <<<"$identity_output"; then
    pass "requested hash is visible on the inserted smart card"
  else
    check "requested hash is not visible; insert the matching YubiKey or choose the visible hash"
  fi
fi

cat <<'EOF'

PIV key-management readiness:
EOF
if command -v ykman >/dev/null 2>&1; then
  mapfile -t inserted_serials < <(ykman list --serials 2>/dev/null | awk 'NF' || true)
  if ((${#inserted_serials[@]} == 1)); then
    inserted_serial="${inserted_serials[0]}"
    if ykman --device "$inserted_serial" piv certificates export 9d - >/dev/null 2>&1; then
      pass "inserted YubiKey $inserted_serial has a PIV slot 9d key-management certificate"
    else
      check "inserted YubiKey $inserted_serial has no PIV slot 9d key-management certificate; FileVault unlock needs a suitable key-management/wrapping key"
    fi
  elif ((${#inserted_serials[@]} == 0)); then
    check "no YubiKey detected by ykman; insert the target YubiKey"
  else
    warn "multiple YubiKeys detected by ykman; insert only the target key to preflight PIV slot 9d"
  fi
else
  warn "skipping PIV slot 9d check because ykman is unavailable"
fi

cat <<'EOF'

Current FileVault smart-card status:
EOF
if [[ -n "$hash_value" && -x "$sc_auth_bin" ]]; then
  $sc_auth_bin filevault -o status -u "$username" -h "$hash_value" || true
elif [[ -x "$sc_auth_bin" ]]; then
  $sc_auth_bin filevault -o status -u "$username" || true
else
  printf '  skipped: sc_auth unavailable\n'
fi

cat <<'EOF'

Required manual confirmations before enablement:
EOF
manual "FileVault recovery key is escrowed outside this Mac"
manual "recovery key retrieval has been tested"
manual "macOS RecoveryOS boot has been tested"
manual "password or alternate admin recovery path remains available"
manual "primary and backup YubiKeys have been tested for macOS smart-card login"

cat <<'EOF'

Recovery commands to keep available:
EOF
if [[ -n "$hash_value" ]]; then
  printf '  Disable after boot, if needed:\n'
  printf '    sudo /usr/sbin/sc_auth filevault -o disable -u %q -h %q\n' "$username" "$hash_value"
fi
if [[ -n "$data_volume_uuid" ]]; then
  printf '  RecoveryOS one-login bypass, if smart-card enforcement blocks login:\n'
  printf '    security filevault skip-sc-enforcement %q set\n' "$data_volume_uuid"
fi

cat <<'EOF'

Preflight result:
EOF
if ((failures > 0)); then
  printf '  failed: %d blocking check(s), %d warning(s)\n' "$failures" "$warnings"
  exit 1
fi
printf '  passed: %d warning(s)\n' "$warnings"

if [[ "$mode" == "verify-recovery" ]]; then
  cat <<EOF

Recovery verification checkpoint
  checkpoint file: $checkpoint_file
EOF
  prompt_exact "I HAVE STORED THE FILEVAULT RECOVERY KEY OUTSIDE THIS MAC" || fail "confirmation failed"
  prompt_exact "I HAVE TESTED MACOS RECOVERYOS BOOT" || fail "confirmation failed"
  checkpoint_now
  cat <<EOF

Recovery verification complete. Checkpoint recorded.
FileVault smart-card execute remains blocked on hosts with smart-card-only login enforced.
EOF
  exit 0
fi

if [[ "$mode" == "dry-run" ]]; then
  cat <<EOF

Dry run complete. No changes were made.
Before any future FileVault experiment, run:
  yubikey-filevault-enable --verify-recovery --hash $hash_value
Execute is blocked on hosts with smart-card-only login enforced after the observed pre-boot lockout.
EOF
  exit 0
fi

[[ -n "$hash_value" ]] || fail "internal error: no selected hash after successful preflight"

checkpoint_epoch="$(latest_checkpoint_epoch || true)"
if [[ -z "$checkpoint_epoch" ]]; then
  check "no recovery verification checkpoint found; run yubikey-filevault-enable --verify-recovery --hash $hash_value first"
else
  now_epoch="$(date +%s)"
  max_age_seconds=$((recovery_check_window_hours * 3600))
  checkpoint_age=$((now_epoch - checkpoint_epoch))
  if ((checkpoint_age <= max_age_seconds)); then
    pass "recovery verification checkpoint is recent (${checkpoint_age}s old)"
  else
    check "recovery verification checkpoint is too old (${checkpoint_age}s > ${max_age_seconds}s); rerun --verify-recovery"
  fi
fi

if ((failures > 0)); then
  printf '\nExecute blocked: %d blocking check(s), %d warning(s)\n' "$failures" "$warnings"
  exit 1
fi

cat <<EOF

About to enable FileVault smart-card unlock with:
  /usr/sbin/sc_auth filevault -o enable -u $username -h $hash_value

This command must run as the logged-in user, not through sudo.
EOF

prompt_exact "I HAVE THE FILEVAULT RECOVERY KEY" || fail "confirmation failed"
prompt_exact "I CAN BOOT RECOVERYOS" || fail "confirmation failed"
prompt_exact "ENABLE FILEVAULT YUBIKEY UNLOCK FOR $username" || fail "confirmation failed"

enable_status=0
enable_output="$("$sc_auth_bin" filevault -o enable -u "$username" -h "$hash_value" 2>&1)" || enable_status=$?
printf '%s\n' "$enable_output"
if ((enable_status != 0)) || grep -Eqi 'failed|no suitable key|unable|error' <<<"$enable_output"; then
  cat <<'EOF' >&2

FileVault smart-card enablement did not complete successfully.
No reboot test should be performed until this is resolved.
EOF
  exit 1
fi

cat <<'EOF'

Post-enable status:
EOF
post_status="$("$sc_auth_bin" filevault -o status -u "$username" -h "$hash_value" 2>&1)" || true
printf '%s\n' "$post_status"
if grep -Eqi 'SecureToken .*not present|not enabled|failed|error' <<<"$post_status"; then
  cat <<'EOF' >&2

FileVault smart-card status did not confirm enablement.
Treat this as failed and do not reboot-test FileVault smart-card unlock.
EOF
  exit 1
fi

cat <<'EOF'

Enable command finished with non-failing status. Before relying on this configuration:
  - keep recovery key available
  - reboot once with local support/recovery path available
  - test the primary YubiKey at FileVault pre-boot unlock
  - repeat enablement for the backup YubiKey only after primary succeeds
EOF
