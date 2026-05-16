#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/yubikey-status.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

user="$(id -un)"
host="$(hostname -s 2>/dev/null || hostname)"
inventory="$tmpdir/yubikeys.tsv"
authfile="$tmpdir/u2f_keys"
fakebin="$tmpdir/bin"
mkdir -p "$fakebin"

cat >"$inventory" <<EOF_INVENTORY
2026-01-01T00:00:00Z	$user	$host	31021632	phase2-local-record	primary	enrolled
2026-01-01T00:00:01Z	$user	$host	31021618	phase2-local-record	backup	enrolled
EOF_INVENTORY
cat >"$authfile" <<EOF_AUTH
$user:fake-pam-u2f-registration
EOF_AUTH

cat >"$fakebin/ykman" <<'EOF_YKMAN'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ge 2 && "$1" == "list" && "$2" == "--serials" ]]; then
  printf '31021632\n'
  exit 0
fi

if [[ "$#" -ge 4 && "$1" == "--device" && "$3" == "piv" && "$4" == "info" ]]; then
  cat <<'EOF_PIV'
PIV version: 5.7.0
PIN tries remaining: 3/3
EOF_PIV
  exit 0
fi

if [[ "$#" -ge 4 && "$1" == "--device" && "$3" == "fido" && "$4" == "info" ]]; then
  cat <<'EOF_FIDO'
PIN: Set
EOF_FIDO
  exit 0
fi

printf 'unexpected ykman invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_YKMAN
chmod +x "$fakebin/ykman"

before_inventory="$(shasum -a 256 "$inventory")"
before_authfile="$(shasum -a 256 "$authfile")"

output="$(PATH="$fakebin:$PATH" "$script" --inventory-file "$inventory" --pam-u2f-authfile "$authfile" --strict)"
printf '%s\n' "$output"

if ! grep -Fq 'primary enrolled:       yes' <<<"$output"; then
  fail "expected primary enrollment to be reported"
fi
if ! grep -Fq 'backup enrolled:        yes' <<<"$output"; then
  fail "expected backup enrollment to be reported"
fi
if ! grep -Fq 'inserted key hardened:  yes' <<<"$output"; then
  fail "expected fake inserted key to be reported as hardened"
fi
if ! grep -Fq 'sudo MFA registered:    yes' <<<"$output"; then
  fail "expected pam_u2f registration to be reported"
fi
if ! grep -Fq 'ready for future auth enforcement planning' <<<"$output"; then
  fail "expected strict status to be ready with complete temp state"
fi

if [[ "$(shasum -a 256 "$inventory")" != "$before_inventory" ]]; then
  fail "status script should not mutate inventory file"
fi
if [[ "$(shasum -a 256 "$authfile")" != "$before_authfile" ]]; then
  fail "status script should not mutate pam_u2f authfile"
fi
