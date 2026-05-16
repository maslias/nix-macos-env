#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: yubikey-smartcard-policy-disable [options]

Emergency rollback helper for macOS smart-card-only login policy. It removes
this repo's smart-card-only enforcement preference so password fallback can be
restored after rebuild/reboot where macOS permits it.

Options:
  -h, --help   Show this help
EOF
}

if [[ $# -gt 0 ]]; then
  case "$1" in
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
fi

policy_domain="/Library/Preferences/com.apple.security.smartcard"

cat <<'EOF'
Disabling macOS smart-card-only login policy preference.
This does not remove YubiKey pairings and does not change FileVault.
EOF

if defaults read "$policy_domain" enforceSmartCard >/dev/null 2>&1; then
  sudo defaults delete "$policy_domain" enforceSmartCard
  echo "Removed enforceSmartCard preference. Reboot may be required."
else
  echo "enforceSmartCard preference was already unset."
fi
