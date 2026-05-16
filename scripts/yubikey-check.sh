#!/usr/bin/env bash
set -euo pipefail

warn_only=false

usage() {
  cat <<'EOF'
Usage: yubikey-check [options]

Checks that YubiKey tooling is installed and that at least one YubiKey is visible.

Options:
  --warn-only   Print warnings instead of exiting non-zero for missing key/tools
  -h, --help    Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --warn-only) warn_only=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  if [[ "$warn_only" == true ]]; then
    printf 'warning: %s\n' "$*" >&2
    return 0
  fi

  printf 'error: %s\n' "$*" >&2
  exit 1
}

missing=()
for tool in ykman yubico-piv-tool opensc-tool fido2-token; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    missing+=("$tool")
  fi
done

if ((${#missing[@]} > 0)); then
  fail "missing required YubiKey tools: ${missing[*]}"
fi

if [[ "$(uname -s)" == "Darwin" ]] && ! command -v security >/dev/null 2>&1; then
  fail "missing macOS security command"
fi

if ! command -v ykman >/dev/null 2>&1; then
  exit 0
fi

serials="$(ykman list --serials 2>/dev/null || true)"

if [[ -z "$serials" ]]; then
  fail "no YubiKey detected; insert a YubiKey 5C or rerun setup with --skip-yubikey"
fi

cat <<'EOF'
YubiKey tooling is installed.
Detected YubiKey device(s):
EOF

while IFS= read -r serial; do
  [[ -z "$serial" ]] && continue
  printf '  serial: %s\n' "$serial"
done <<<"$serials"

cat <<'EOF'

Phase 1 only checks tooling and device visibility.
Login, FileVault, sudo/PAM, and smart-card enforcement are not changed yet.
EOF
