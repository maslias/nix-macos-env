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
  *)
    printf 'unexpected fdesetup invocation:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    exit 99
    ;;
esac
EOF_FDESETUP
chmod +x "$fakebin/fdesetup"

cat >"$fakebin/sysadminctl" <<'EOF_SYSADMINCTL'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 2 && "$1" == "-secureTokenStatus" ]]; then
  printf 'Secure token is ENABLED for user %s\n' "$2"
  exit 0
fi
printf 'unexpected sysadminctl invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_SYSADMINCTL
chmod +x "$fakebin/sysadminctl"

cat >"$fakebin/dscl" <<'EOF_DSCL'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$*" == *"GeneratedUID"* ]]; then
  printf 'GeneratedUID: FAKE-GENERATED-UID\n'
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
printf 'unexpected diskutil invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_DISKUTIL
chmod +x "$fakebin/diskutil"

cat >"$fakebin/security" <<'EOF_SECURITY'
#!/usr/bin/env bash
set -euo pipefail
printf 'unexpected security invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_SECURITY
chmod +x "$fakebin/security"

cat >"$fakesbin/sc_auth" <<'EOF_SC_AUTH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  list)
    printf 'Hash: HASH_FOR_PRIMARY\nHash: HASH_FOR_BACKUP\n'
    ;;
  identities)
    printf 'SmartCard: com.apple.pivtoken:FAKE\nPaired identities which are used for authentication:\nHASH_FOR_PRIMARY\ttestuser - Certificate For PIV Authentication\n'
    ;;
  filevault)
    if [[ "$2" == "-o" && "$3" == "status" ]]; then
      printf 'SecureToken for user testuser is needed and is not present\n'
      exit 0
    fi
    printf 'unexpected sc_auth filevault invocation:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    exit 99
    ;;
  *)
    printf 'unexpected sc_auth invocation:' >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    exit 99
    ;;
esac
EOF_SC_AUTH
chmod +x "$fakesbin/sc_auth"

output="$(PATH="$fakebin:$PATH" YUBIKEY_SC_AUTH="$fakesbin/sc_auth" "$script" --username testuser --dry-run --hash HASH_FOR_PRIMARY)"
printf '%s\n' "$output"

for expected in \
  'mode: dry-run' \
  '[OK] Apple silicon architecture detected: arm64' \
  '[OK] testuser is FileVault-authorized' \
  '[OK] requested hash is visible on the inserted smart card' \
  'Dry run complete. No changes were made.'; do
  if ! grep -Fq "$expected" <<<"$output"; then
    fail "expected output: $expected"
  fi
done
