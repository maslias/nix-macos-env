#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/yubikey-policy-check.sh"

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

cat >"$fakebin/sc_auth" <<'EOF_SC_AUTH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ge 3 && "$1" == "list" && "$2" == "-u" ]]; then
  printf 'HASH_FOR_PRIMARY\nHASH_FOR_BACKUP\n'
  exit 0
fi

printf 'unexpected sc_auth invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 99
EOF_SC_AUTH
chmod +x "$fakebin/sc_auth"

before_inventory="$(shasum -a 256 "$inventory")"
before_authfile="$(shasum -a 256 "$authfile")"

output="$(PATH="$fakebin:$PATH" "$script" --inventory-file "$inventory" --pam-u2f-authfile "$authfile" --require-piv-pairings 2)"
printf '%s\n' "$output"

if ! grep -Fq '[OK] primary YubiKey enrollment recorded' <<<"$output"; then
  fail "expected primary enrollment policy to pass"
fi
if ! grep -Fq '[OK] backup YubiKey enrollment recorded' <<<"$output"; then
  fail "expected backup enrollment policy to pass"
fi
if ! grep -Fq '[OK] pam_u2f sudo MFA mapping present' <<<"$output"; then
  fail "expected sudo MFA mapping policy to pass"
fi
if ! grep -Fq '[OK] sc_auth pairing count is 2 (required: 2)' <<<"$output"; then
  fail "expected fake PIV pairing count policy to pass"
fi
if ! grep -Fq 'policy checks passed' <<<"$output"; then
  fail "expected overall policy result to pass"
fi

if [[ "$(shasum -a 256 "$inventory")" != "$before_inventory" ]]; then
  fail "policy check should not mutate inventory file"
fi
if [[ "$(shasum -a 256 "$authfile")" != "$before_authfile" ]]; then
  fail "policy check should not mutate pam_u2f authfile"
fi
