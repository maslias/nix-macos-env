#!/usr/bin/env bash
set -euo pipefail

serial=""
role="primary"
force=false
non_interactive=false
inventory_file="${YUBIKEY_INVENTORY_FILE:-$HOME/.config/nix-macos/yubikeys.tsv}"

usage() {
  cat <<'EOF'
Usage: yubikey-enroll [options]

Safely records a local YubiKey enrollment marker for this macOS user.
This phase does not change macOS login, FileVault, sudo/PAM, or smart-card enforcement.

Options:
  --serial SERIAL        Enroll a specific YubiKey serial when multiple keys are inserted
  --role ROLE            Enrollment role: primary or backup (default: primary)
  --inventory-file PATH  Write enrollment inventory to PATH
  --force                Re-record an already enrolled serial/role
  --non-interactive      Do not prompt for confirmation
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      serial="$2"
      shift
      ;;
    --role)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      role="$2"
      shift
      ;;
    --inventory-file)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      inventory_file="$2"
      shift
      ;;
    --force) force=true ;;
    --non-interactive) non_interactive=true ;;
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
  command -v "$1" >/dev/null 2>&1 || fail "missing required tool: $1"
}

case "$role" in
  primary|backup) ;;
  *) fail "invalid role '$role'; expected primary or backup" ;;
esac

for tool in ykman yubico-piv-tool opensc-tool fido2-token; do
  need_tool "$tool"
done

mapfile -t serials < <(ykman list --serials 2>/dev/null | awk 'NF')

if ((${#serials[@]} == 0)); then
  fail "no YubiKey detected; insert a YubiKey 5C or rerun setup with --skip-yubikey"
fi

if [[ -z "$serial" ]]; then
  if ((${#serials[@]} == 1)); then
    serial="${serials[0]}"
  else
    cat >&2 <<'EOF'
Multiple YubiKeys detected. Choose one explicitly, for example:
  yubikey-enroll --serial SERIAL

Detected serials:
EOF
    printf '  %s\n' "${serials[@]}" >&2
    exit 2
  fi
fi

found=false
for detected in "${serials[@]}"; do
  if [[ "$detected" == "$serial" ]]; then
    found=true
  fi
done
[[ "$found" == true ]] || fail "YubiKey serial $serial is not currently detected"

mkdir -p "$(dirname "$inventory_file")"
touch "$inventory_file"
chmod 600 "$inventory_file"

print_user_inventory_summary() {
  local user="$1"

  if [[ ! -s "$inventory_file" ]]; then
    return 0
  fi

  cat <<EOF

Current local YubiKey inventory records for $user:
EOF
  awk -F '\t' -v user="$user" '
    $2 == user && $4 != "" {
      role = ($6 != "" ? $6 : "unknown")
      status = ($7 != "" ? $7 : $5)
      printf "  serial: %s  role: %s  status: %s  recorded: %s\n", $4, role, status, $1
      found = 1
    }
    END { if (!found) print "  none" }
  ' "$inventory_file"
}

warn_if_missing_backup() {
  local user="$1"

  if awk -F '\t' -v user="$user" '$2 == user && $6 == "backup" { found = 1 } END { exit found ? 0 : 1 }' "$inventory_file"; then
    return 0
  fi

  cat <<'EOF'

warning: no backup YubiKey role is recorded for this user yet.
Enroll a second physical key when available:
  yubikey-enroll --role backup
EOF
}

current_user="$(id -un)"

if awk -F '\t' -v serial="$serial" -v role="$role" '$4 == serial && $6 == role { found = 1 } END { exit found ? 0 : 1 }' "$inventory_file"; then
  if [[ "$force" != true ]]; then
    cat <<EOF
YubiKey serial $serial is already recorded as role '$role' in:
  $inventory_file

Use --force to re-record it.
EOF
    print_user_inventory_summary "$current_user"
    warn_if_missing_backup "$current_user"
    exit 0
  fi
fi

cat <<EOF
Preparing local YubiKey enrollment record
  user:           $(id -un)
  host:           $(hostname -s 2>/dev/null || hostname)
  serial:         $serial
  role:           $role
  inventory file: $inventory_file
EOF

cat <<'EOF'

YubiKey device information:
EOF
ykman --device "$serial" info || true

cat <<'EOF'

PIV status:
EOF
ykman --device "$serial" piv info || true

cat <<'EOF'

FIDO2 status:
EOF
ykman --device "$serial" fido info || true

cat <<'EOF'

Before future login/sudo enforcement, operators should verify:
  - the default PIV PIN has been changed from 123456
  - the default PIV PUK has been changed from 12345678
  - a FIDO2 PIN is configured when FIDO2 will be used
  - a backup YubiKey is enrolled and stored safely
  - FileVault recovery is documented and escrowed outside this Mac

This script records local enrollment state only. It does not store secrets.
EOF

if [[ "$non_interactive" != true ]]; then
  read -r -p "Record this YubiKey as enrolled for this user? [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) ;;
    *) fail "enrollment cancelled" ;;
  esac
fi

timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
user="$current_user"
host="$(hostname -s 2>/dev/null || hostname)"
record="${timestamp}	${user}	${host}	${serial}	phase2-local-record	${role}	enrolled"

printf '%b\n' "$record" >>"$inventory_file"

cat <<EOF

Recorded YubiKey enrollment:
  $inventory_file
EOF

print_user_inventory_summary "$user"
warn_if_missing_backup "$user"
