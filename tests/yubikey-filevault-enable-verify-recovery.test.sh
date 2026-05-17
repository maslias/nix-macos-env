#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/yubikey-filevault-enable.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

fakebin="$tmpdir/bin"
fakesbin="$tmpdir/sbin"
checkpoint="$tmpdir/recovery.tsv"
mkdir -p "$fakebin" "$fakesbin"

cat >"$fakebin/uname" <<'EOF_UNAME'
#!/usr/bin/env bash
printf 'arm64\n'
EOF_UNAME
chmod +x "$fakebin/uname"

cat >"$fakebin/fdesetup" <<'EOF_FDESETUP'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  status)
    printf 'FileVault is On.\n'
    ;;
  list)
    printf 'testuser,FAKE-GENERATED-UID\n'
    ;;
  haspersonalrecoverykey)
    printf 'true\n'
    ;;
  *)
    printf 'unexpected fdesetup invocation:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    exit 99
    ;;
esac
EOF_FDESETUP
chmod +x "$fakebin/fdesetup"

cat >"$fakebin/sudo" <<EOF_SUDO
#!/usr/bin/env bash
set -euo pipefail
if [[ "\${1:-}" == "-v" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "fdesetup" ]]; then
  shift
fi
exec "$fakebin/fdesetup" "\$@"
EOF_SUDO
chmod +x "$fakebin/sudo"

cat >"$fakebin/sysadminctl" <<'EOF_SYSADMINCTL'
#!/usr/bin/env bash
set -euo pipefail
printf 'Secure token is ENABLED for user %s\n' "$2"
EOF_SYSADMINCTL
chmod +x "$fakebin/sysadminctl"

cat >"$fakebin/dscl" <<'EOF_DSCL'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"GeneratedUID"* ]]; then
  printf 'GeneratedUID: FAKE-GENERATED-UID\n'
  exit 0
fi
if [[ "$*" == *"/Groups/admin"* ]]; then
  printf 'GroupMembership: root testuser\n'
  exit 0
fi
printf 'unexpected dscl invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_DSCL
chmod +x "$fakebin/dscl"

cat >"$fakebin/diskutil" <<'EOF_DISKUTIL'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 3 && "$1" == "apfs" && "$2" == "listUsers" ]]; then
  printf 'Cryptographic users for diskFAKE (1 found)\n+-- FAKE-GENERATED-UID\n    Type: Local Open Directory User\n    Volume Owner: Yes\n'
  exit 0
fi
if [[ "$#" -eq 2 && "$1" == "info" && "$2" == "/System/Volumes/Data" ]]; then
  printf '   Volume UUID: FAKE-DATA-VOLUME-UUID\n'
  exit 0
fi
exit 99
EOF_DISKUTIL
chmod +x "$fakebin/diskutil"

cat >"$fakebin/security" <<'EOF_SECURITY'
#!/usr/bin/env bash
exit 99
EOF_SECURITY
chmod +x "$fakebin/security"

cat >"$fakesbin/sc_auth" <<'EOF_SC_AUTH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  list) printf 'Hash: HASH_FOR_PRIMARY\n' ;;
  identities) printf 'HASH_FOR_PRIMARY\ttestuser - Certificate For PIV Authentication\n' ;;
  filevault) printf 'SecureToken for user testuser is needed and is not present\n' ;;
  *) exit 99 ;;
esac
EOF_SC_AUTH
chmod +x "$fakesbin/sc_auth"

input=$'I HAVE STORED THE FILEVAULT RECOVERY KEY OUTSIDE THIS MAC\nI HAVE TESTED MACOS RECOVERYOS BOOT\n'
output="$(printf '%s' "$input" | PATH="$fakebin:$PATH" YUBIKEY_SC_AUTH="$fakesbin/sc_auth" YUBIKEY_SUDO=sudo YUBIKEY_FILEVAULT_RECOVERY_CHECKPOINT="$checkpoint" "$script" --username testuser --verify-recovery --hash HASH_FOR_PRIMARY)"
printf '%s\n' "$output"

for expected in \
  'mode: verify-recovery' \
  '[OK] sudo authentication works for testuser' \
  '[OK] FileVault reports a personal recovery key is configured' \
  'Recovery verification complete. Checkpoint recorded.'; do
  if ! grep -Fq "$expected" <<<"$output"; then
    fail "expected output: $expected"
  fi
done

if ! grep -Fq 'recovery-verified' "$checkpoint"; then
  fail 'expected recovery checkpoint record'
fi
