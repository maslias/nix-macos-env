#!/usr/bin/env bash
set -euo pipefail

serial=""
check_only=false
inventory_file="${YUBIKEY_INVENTORY_FILE:-$HOME/.config/nix-macos/yubikeys.tsv}"

usage() {
  cat <<'EOF'
Usage: yubikey-harden [options]

Interactively hardens a YubiKey for future workstation authentication use.
This script does not change macOS login, FileVault, sudo/PAM, or smart-card enforcement.

Options:
  --serial SERIAL        Harden/check a specific YubiKey serial when multiple keys are inserted
  --inventory-file PATH  Write hardening inventory to PATH
  --check-only           Only report hardening status; do not prompt or change the key
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
    --inventory-file)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      inventory_file="$2"
      shift
      ;;
    --check-only) check_only=true ;;
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

confirm() {
  local prompt="$1"
  local answer=""
  read -r -p "$prompt [y/N] " answer
  case "$answer" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

for tool in ykman yubico-piv-tool opensc-tool fido2-token; do
  need_tool "$tool"
done

mapfile -t serials < <(ykman list --serials 2>/dev/null | awk 'NF')

if ((${#serials[@]} == 0)); then
  fail "no YubiKey detected; insert a YubiKey 5C"
fi

if [[ -z "$serial" ]]; then
  if ((${#serials[@]} == 1)); then
    serial="${serials[0]}"
  else
    cat >&2 <<'EOF'
Multiple YubiKeys detected. Choose one explicitly, for example:
  yubikey-harden --serial SERIAL

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

piv_info_file="$(mktemp -t yubikey-piv-info.XXXXXX)"
fido_info_file="$(mktemp -t yubikey-fido-info.XXXXXX)"
trap 'rm -f "$piv_info_file" "$fido_info_file"' EXIT

refresh_status() {
  ykman --device "$serial" piv info >"$piv_info_file" 2>&1 || true
  ykman --device "$serial" fido info >"$fido_info_file" 2>&1 || true
}

print_status() {
  cat <<EOF
YubiKey hardening status
  user:           $(id -un)
  host:           $(hostname -s 2>/dev/null || hostname)
  serial:         $serial
  inventory file: $inventory_file

PIV status:
EOF
  cat "$piv_info_file"
  cat <<'EOF'

FIDO2 status:
EOF
  cat "$fido_info_file"
}

has_default_piv_pin() { grep -Fq 'WARNING: Using default PIN!' "$piv_info_file"; }
has_default_piv_puk() { grep -Fq 'WARNING: Using default PUK!' "$piv_info_file"; }
has_default_mgmt_key() { grep -Fq 'WARNING: Using default Management key!' "$piv_info_file"; }
has_missing_fido_pin() { grep -Eq '^PIN:[[:space:]]+Not set$' "$fido_info_file"; }

print_findings() {
  local issues=0

  if has_default_piv_pin; then
    echo "- PIV PIN is still the default value."
    issues=$((issues + 1))
  fi
  if has_default_piv_puk; then
    echo "- PIV PUK is still the default value."
    issues=$((issues + 1))
  fi
  if has_default_mgmt_key; then
    echo "- PIV management key is still the default value."
    issues=$((issues + 1))
  fi
  if has_missing_fido_pin; then
    echo "- FIDO2 PIN is not set."
    issues=$((issues + 1))
  fi

  if ((issues == 0)); then
    echo "No hardening issues detected by ykman."
  fi

  return "$issues"
}

record_hardened() {
  mkdir -p "$(dirname "$inventory_file")"
  touch "$inventory_file"
  chmod 600 "$inventory_file"

  local timestamp user host record
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  user="$(id -un)"
  host="$(hostname -s 2>/dev/null || hostname)"
  record="${timestamp}	${user}	${host}	${serial}	phase2-hardened-local-check"
  printf '%b\n' "$record" >>"$inventory_file"
}

refresh_status
print_status

cat <<'EOF'

Detected hardening findings:
EOF
if print_findings; then
  findings=0
else
  findings=$?
fi

if [[ "$check_only" == true ]]; then
  if ((findings > 0)); then
    exit 1
  fi
  exit 0
fi

if ((findings == 0)); then
  record_hardened
  cat <<EOF

YubiKey already appears hardened. Recorded local hardening check:
  $inventory_file
EOF
  exit 0
fi

cat <<'EOF'

The following steps are interactive and may prompt for current and new PIN/PUK values.
Store the new values in your organization's approved password/secret store.
Avoid failed guesses: repeated wrong PIN/PUK attempts can block access.
EOF

if has_default_piv_pin && confirm "Change the default PIV PIN now?"; then
  ykman --device "$serial" piv access change-pin
fi

if has_default_piv_puk && confirm "Change the default PIV PUK now?"; then
  ykman --device "$serial" piv access change-puk
fi

if has_default_mgmt_key && confirm "Replace the default PIV management key with a random PIN-protected key now?"; then
  ykman --device "$serial" piv access change-management-key --protect --generate
fi

if has_missing_fido_pin && confirm "Set a FIDO2 PIN now?"; then
  ykman --device "$serial" fido access change-pin
fi

refresh_status

cat <<'EOF'

Updated hardening findings:
EOF
if print_findings; then
  record_hardened
  cat <<EOF

YubiKey hardening complete. Recorded local hardening check:
  $inventory_file
EOF
else
  cat <<'EOF'

YubiKey still has hardening findings. Re-run yubikey-harden after completing the remaining items.
EOF
  exit 1
fi
