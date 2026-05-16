#!/usr/bin/env bash
set -euo pipefail

inventory_file="${YUBIKEY_INVENTORY_FILE:-$HOME/.config/nix-macos/yubikeys.tsv}"
pam_u2f_authfile="${YUBIKEY_PAM_U2F_AUTHFILE:-$HOME/.config/Yubico/u2f_keys}"
strict=false

usage() {
  cat <<'EOF'
Usage: yubikey-status [options]

Reports local YubiKey enrollment, backup-key, and inserted-key hardening status.
This command does not change the YubiKey or macOS authentication settings.

Options:
  --inventory-file PATH  Read enrollment inventory from PATH
  --pam-u2f-authfile PATH Read pam_u2f mapping from PATH
  --strict               Exit non-zero unless ready for future auth enforcement
  -h, --help             Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --strict) strict=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

need_tool() {
  command -v "$1" >/dev/null 2>&1 || return 1
}

user="$(id -un)"
host="$(hostname -s 2>/dev/null || hostname)"

primary_serials=()
backup_serials=()
unknown_serials=()

if [[ -r "$inventory_file" ]]; then
  while IFS=$'\t' read -r _ts rec_user _rec_host serial _action role _status _rest; do
    [[ -n "${serial:-}" ]] || continue
    [[ "${rec_user:-}" == "$user" ]] || continue
    case "${role:-unknown}" in
      primary) primary_serials+=("$serial") ;;
      backup) backup_serials+=("$serial") ;;
      *) unknown_serials+=("$serial") ;;
    esac
  done <"$inventory_file"
fi

unique_lines() {
  awk 'NF && !seen[$0]++'
}

format_list() {
  if (($# == 0)); then
    printf 'missing'
    return 0
  fi
  printf '%s\n' "$@" | unique_lines | paste -sd ', ' -
}

inserted_serials=()
ykman_available=false
if need_tool ykman; then
  ykman_available=true
  mapfile -t inserted_serials < <(ykman list --serials 2>/dev/null | awk 'NF' | unique_lines)
fi

has_primary=false
has_backup=false
has_sudo_mapping=false
inserted_hardened=false

((${#primary_serials[@]} > 0)) && has_primary=true
((${#backup_serials[@]} > 0)) && has_backup=true
if [[ -r "$pam_u2f_authfile" ]] && grep -q "^${user}:" "$pam_u2f_authfile"; then
  has_sudo_mapping=true
fi

cat <<EOF
YubiKey workstation status
  user:                $user
  host:                $host
  inventory file:      $inventory_file
  pam_u2f authfile:    $pam_u2f_authfile

Inventory:
  primary: $(format_list "${primary_serials[@]}")
  backup:  $(format_list "${backup_serials[@]}")
EOF

if ((${#unknown_serials[@]} > 0)); then
  cat <<EOF
  legacy/unknown-role records: $(format_list "${unknown_serials[@]}")
EOF
fi

cat <<EOF

Sudo MFA registration:
  pam_u2f credential: $([[ "$has_sudo_mapping" == true ]] && echo yes || echo no)
EOF

cat <<'EOF'

Inserted keys:
EOF

if [[ "$ykman_available" != true ]]; then
  cat <<'EOF'
  ykman unavailable; cannot inspect inserted keys
EOF
elif ((${#inserted_serials[@]} == 0)); then
  cat <<'EOF'
  none
EOF
else
  printf '  %s\n' "${inserted_serials[@]}"
fi

cat <<'EOF'

Inserted key hardening:
EOF

if [[ "$ykman_available" != true ]]; then
  cat <<'EOF'
  unknown: ykman unavailable
EOF
elif ((${#inserted_serials[@]} == 0)); then
  cat <<'EOF'
  none checked
EOF
else
  for serial in "${inserted_serials[@]}"; do
    piv_info=""
    fido_info=""
    issues=()

    if ! piv_info="$(ykman --device "$serial" piv info 2>/dev/null)"; then
      issues+=("unable to read PIV status")
    fi
    if ! fido_info="$(ykman --device "$serial" fido info 2>/dev/null)"; then
      issues+=("unable to read FIDO2 status")
    fi

    if grep -Fq 'WARNING: Using default PIN!' <<<"$piv_info"; then
      issues+=("default PIV PIN")
    fi
    if grep -Fq 'WARNING: Using default PUK!' <<<"$piv_info"; then
      issues+=("default PIV PUK")
    fi
    if grep -Fq 'WARNING: Using default Management key!' <<<"$piv_info"; then
      issues+=("default PIV management key")
    fi
    if grep -Eq '^PIN:[[:space:]]+Not set$' <<<"$fido_info"; then
      issues+=("missing FIDO2 PIN")
    fi

    if ((${#issues[@]} == 0)); then
      printf '  %s: hardened\n' "$serial"
      inserted_hardened=true
    else
      printf '  %s: needs hardening (%s)\n' "$serial" "$(printf '%s\n' "${issues[@]}" | paste -sd ', ' -)"
    fi
  done
fi

ready=true
reasons=()
if [[ "$has_primary" != true ]]; then
  ready=false
  reasons+=("no primary YubiKey enrolled")
fi
if [[ "$has_backup" != true ]]; then
  ready=false
  reasons+=("no backup YubiKey enrolled")
fi
if [[ "$inserted_hardened" != true ]]; then
  ready=false
  reasons+=("no inserted hardened YubiKey verified")
fi
if [[ "$has_sudo_mapping" != true ]]; then
  ready=false
  reasons+=("no pam_u2f sudo MFA credential registered")
fi

cat <<EOF

Readiness:
  primary enrolled:       $([[ "$has_primary" == true ]] && echo yes || echo no)
  backup enrolled:        $([[ "$has_backup" == true ]] && echo yes || echo no)
  inserted key hardened:  $([[ "$inserted_hardened" == true ]] && echo yes || echo no)
  sudo MFA registered:    $([[ "$has_sudo_mapping" == true ]] && echo yes || echo no)

Result:
EOF

if [[ "$ready" == true ]]; then
  cat <<'EOF'
  ready for future auth enforcement planning
EOF
  exit 0
fi

cat <<'EOF'
  not ready for auth enforcement
EOF
for reason in "${reasons[@]}"; do
  printf '  reason: %s\n' "$reason"
done

if [[ "$strict" == true ]]; then
  exit 1
fi
