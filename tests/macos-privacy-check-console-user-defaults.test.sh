#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/id" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "-u" && $# -eq 1 ]]; then
  printf '0\n'
elif [[ "$1" == "-u" && "$2" == "alice" ]]; then
  printf '501\n'
elif [[ "$1" == "-un" ]]; then
  printf 'root\n'
else
  /usr/bin/id "$@"
fi
STUB
chmod +x "$tmpdir/id"

cat >"$tmpdir/stat" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "-f" && "$2" == "%Su" && "$3" == "/dev/console" ]]; then
  printf 'alice\n'
else
  /usr/bin/stat "$@"
fi
STUB
chmod +x "$tmpdir/stat"

cat >"$tmpdir/launchctl" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "asuser" ]]; then
  shift 2
  exec "$@"
elif [[ "$1" == "print-disabled" && "$2" == "system" ]]; then
  exit 0
fi
exit 0
STUB
chmod +x "$tmpdir/launchctl"

cat >"$tmpdir/sudo" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "-u" && "$2" == "alice" ]]; then
  shift 2
  SUDO_USER_CONTEXT=alice exec "$@"
fi
exec "$@"
STUB
chmod +x "$tmpdir/sudo"

cat >"$tmpdir/defaults" <<'STUB'
#!/usr/bin/env bash
if [[ "${SUDO_USER_CONTEXT:-}" != "alice" ]]; then
  printf 'unknown\n'
  exit 0
fi
case "$2:$3" in
  com.apple.NetworkBrowser:DisableAirDrop) printf '1\n' ;;
  com.apple.assistant.support:Assistant\ Enabled) printf '0\n' ;;
  com.apple.AdLib:allowApplePersonalizedAdvertising) printf '0\n' ;;
  com.apple.SubmitDiagInfo:AutoSubmit) printf '0\n' ;;
  *) printf 'unknown\n' ;;
esac
STUB
chmod +x "$tmpdir/defaults"

output="$(PATH="$tmpdir:$PATH" "$script")"
printf '%s\n' "$output"

for expected in \
  '[OK] AirDrop disabled' \
  '[OK] Siri disabled' \
  '[OK] Personalized ads disabled' \
  '[OK] Diagnostics auto-submit disabled'; do
  if ! grep -Fq "$expected" <<<"$output"; then
    fail "expected console-user defaults check to report: $expected"
  fi
done
