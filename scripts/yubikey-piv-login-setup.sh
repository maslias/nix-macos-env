#!/usr/bin/env bash
set -euo pipefail

serial=""
slot="9a"
subject=""
valid_days="3650"
algorithm="rsa2048"
touch_policy="never"
force=false
pair=false
pair_hash=""
username="$(id -un)"

usage() {
  cat <<'EOF'
Usage: yubikey-piv-login-setup [options]

Creates a self-signed PIV authentication certificate on the inserted YubiKey
for future macOS smart-card login pairing. Pairing is explicit and optional.

Defaults:
  slot:       9a (PIV Authentication)
  algorithm:  RSA 2048 for broad macOS smart-card compatibility
  PIN policy: once
  touch:      never

Options:
  --serial SERIAL    Use a specific YubiKey serial when multiple keys are inserted
  --slot SLOT        PIV slot to use (default: 9a)
  --subject SUBJECT  Certificate subject, RFC4514 style (default: CN=<user>@<host> YubiKey <serial>)
  --valid-days DAYS  Certificate validity in days (default: 3650)
  --algorithm ALG    PIV key algorithm (default: rsa2048; examples: rsa2048, eccp256)
  --touch-policy POL PIV touch policy (default: never; examples: never, cached, always)
  --force            Overwrite an existing certificate/key in the selected slot
  --pair             After creating the certificate, pair it to the macOS user with sc_auth
  --hash HASH        Public-key hash to use with --pair; otherwise you will be prompted
  --username USER    macOS user to pair with (default: current user)
  -h, --help         Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --serial)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      serial="$2"
      shift
      ;;
    --slot)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      slot="$2"
      shift
      ;;
    --subject)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      subject="$2"
      shift
      ;;
    --valid-days)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      valid_days="$2"
      shift
      ;;
    --algorithm)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      algorithm="$2"
      shift
      ;;
    --touch-policy)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      touch_policy="$2"
      shift
      ;;
    --force) force=true ;;
    --pair) pair=true ;;
    --hash)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      pair_hash="$2"
      shift
      ;;
    --username)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      username="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
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

command -v ykman >/dev/null 2>&1 || fail "missing required tool: ykman"
command -v sc_auth >/dev/null 2>&1 || fail "missing required macOS tool: sc_auth"

mapfile -t serials < <(ykman list --serials 2>/dev/null | awk 'NF')
if ((${#serials[@]} == 0)); then
  fail "no YubiKey detected"
fi

if [[ -z "$serial" ]]; then
  if ((${#serials[@]} == 1)); then
    serial="${serials[0]}"
  else
    cat >&2 <<'EOF'
Multiple YubiKeys detected. Choose one explicitly, for example:
  yubikey-piv-login-setup --serial SERIAL

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

if [[ -z "$subject" ]]; then
  host="$(hostname -s 2>/dev/null || hostname)"
  subject="CN=${username}@${host} YubiKey ${serial}"
fi

existing_cert=false
if ykman --device "$serial" piv certificates export "$slot" - >/dev/null 2>&1; then
  existing_cert=true
fi

skip_create=false
if [[ "$existing_cert" == true && "$force" != true ]]; then
  if [[ "$pair" == true ]]; then
    skip_create=true
  else
    cat >&2 <<EOF
error: PIV slot $slot already has a certificate on YubiKey $serial.
Use --force only if you intentionally want to overwrite that slot.
EOF
    exit 1
  fi
fi

cat <<EOF
Preparing YubiKey PIV smart-card login identity
  user:       $username
  serial:     $serial
  slot:       $slot
  subject:    $subject
  valid days: $valid_days
  algorithm:  $algorithm
  touch:      $touch_policy
  pair now:   $pair

This will generate a new non-exported private key on the YubiKey and write a
self-signed certificate to PIV slot $slot. It does not enforce smart-card login.
EOF

if [[ "$force" == true ]]; then
  cat <<'EOF'

WARNING: --force can overwrite existing PIV key/certificate material in the slot.
EOF
fi

confirm "Continue" || fail "cancelled"

public_key_file="$(mktemp -t yubikey-piv-pubkey.XXXXXX.pem)"
cert_file="$(mktemp -t yubikey-piv-cert.XXXXXX.pem)"
trap 'rm -f "$public_key_file" "$cert_file"' EXIT

if [[ "$skip_create" == true ]]; then
  ykman --device "$serial" piv certificates export "$slot" "$cert_file"
  cat <<EOF

Using existing PIV certificate on YubiKey $serial slot $slot.
Exported temporary certificate for inspection:
  $cert_file
EOF
else
  ykman --device "$serial" piv keys generate \
    --algorithm "$algorithm" \
    --pin-policy once \
    --touch-policy "$touch_policy" \
    "$slot" "$public_key_file"

  ykman --device "$serial" piv certificates generate \
    --subject "$subject" \
    --valid-days "$valid_days" \
    "$slot" "$public_key_file"

  ykman --device "$serial" piv certificates export "$slot" "$cert_file"

  cat <<EOF

Created PIV certificate on YubiKey $serial slot $slot.
Exported temporary certificate for inspection:
  $cert_file
EOF
fi

if command -v openssl >/dev/null 2>&1; then
  openssl x509 -in "$cert_file" -noout -subject -issuer -dates -fingerprint -sha1 || true
fi

cat <<'EOF'

macOS smart-card identities currently visible:
EOF
sc_auth identities || true

if [[ "$pair" != true ]]; then
  cat <<'EOF'

Pairing was not requested. To pair later, run this command again with --pair,
or use sc_auth manually with the public-key hash shown by `sc_auth identities`.
EOF
  exit 0
fi

if [[ -z "$pair_hash" ]]; then
  cat <<'EOF'

To pair, macOS needs the public-key hash from `sc_auth identities` for the new
YubiKey identity. Copy/paste the matching hash below.
EOF
  read -r -p "Public-key hash to pair with user '$username': " pair_hash
fi

[[ -n "$pair_hash" ]] || fail "pairing hash is required"

cat <<EOF

Pairing smart-card identity to macOS user
  user: $username
  hash: $pair_hash
EOF

sudo sc_auth pair -u "$username" -h "$pair_hash"

cat <<'EOF'

Pairing complete. Verify with:
  sc_auth list -u "$USER"

Do not enforce smart-card-only login until recovery and break-glass access are tested.
EOF
