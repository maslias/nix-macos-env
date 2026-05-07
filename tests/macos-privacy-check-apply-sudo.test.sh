#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/sudo" <<'STUB'
#!/usr/bin/env bash
printf 'sudo: a terminal is required to read the password\n' >&2
exit 1
STUB
chmod +x "$tmpdir/sudo"

set +e
output="$(PATH="$tmpdir:$PATH" "$script" --apply 2>&1)"
status=$?
set -e

printf '%s\n' "$output"
printf 'exit=%s\n' "$status"

if [[ "$status" -eq 0 ]]; then
  printf 'FAIL: expected --apply to fail when sudo credentials are unavailable\n' >&2
  exit 1
fi

if grep -Fq 'sudo: a terminal is required' <<<"$output"; then
  printf 'FAIL: expected script to replace raw sudo failure with an actionable message\n' >&2
  exit 1
fi

if ! grep -Fq 'Run this script from an interactive terminal after sudo -v, or run it with sudo' <<<"$output"; then
  printf 'FAIL: expected actionable sudo preflight guidance for this session\n' >&2
  exit 1
fi
