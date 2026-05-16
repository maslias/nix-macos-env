#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/yubikey-filevault-status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

fakebin="$tmpdir/bin"
fakesbin="$tmpdir/sbin"
mkdir -p "$fakebin" "$fakesbin"

cat >"$fakebin/fdesetup" <<'EOF_FDESETUP'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$#" -eq 1 && "$1" == "status" ]]; then
  printf 'FileVault is On.\n'
  exit 0
fi
printf 'unexpected fdesetup invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
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
if [[ "$*" == *"AuthenticationAuthority"* ]]; then
  printf 'AuthenticationAuthority: ;SecureToken; ;tokenidentity;HASH_FOR_PRIMARY ;tokenidentity;HASH_FOR_BACKUP\n'
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
printf 'unexpected diskutil invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_DISKUTIL
chmod +x "$fakebin/diskutil"

cat >"$fakesbin/sc_auth" <<'EOF_SC_AUTH'
#!/usr/bin/env bash
set -euo pipefail
case "$1" in
  list)
    printf 'Hash: HASH_FOR_PRIMARY\nHash: HASH_FOR_BACKUP\n'
    ;;
  identities)
    printf 'SmartCard identities visible\n'
    ;;
  filevault)
    printf 'SecureToken for user testuser is needed and is not present\n'
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

output="$(PATH="$fakebin:$PATH" YUBIKEY_SC_AUTH="$fakesbin/sc_auth" "$script" --username testuser --hash HASH_FOR_PRIMARY)"
printf '%s\n' "$output"

if ! grep -Fq 'read-only discovery only' <<<"$output"; then
  fail "expected safety boundary"
fi
if ! grep -Fq 'FileVault is On.' <<<"$output"; then
  fail "expected FileVault status output"
fi
if ! grep -Fq 'Hash: HASH_FOR_PRIMARY' <<<"$output"; then
  fail "expected sc_auth pairing output"
fi
if ! grep -Fq 'SecureToken for user testuser is needed and is not present' <<<"$output"; then
  fail "expected sc_auth FileVault status output"
fi
