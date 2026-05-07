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

cat >"$tmpdir/launchctl" <<'STUB'
#!/usr/bin/env bash
if [[ "$1" == "print-disabled" && "$2" == "system" ]]; then
  cat <<'OUTPUT'
disabled services = {
	"com.apple.screensharing" => disabled
	"com.apple.AppleFileServer" => disabled
	"com.apple.smbd" => disabled
	"com.apple.RemoteDesktop.agent" => disabled
	"com.apple.RemoteAppleEvents" => disabled
}
OUTPUT
  exit 0
fi
exit 0
STUB
chmod +x "$tmpdir/launchctl"

output="$(PATH="$tmpdir:$PATH" "$script")"
printf '%s\n' "$output"

for service in \
  com.apple.screensharing \
  com.apple.AppleFileServer \
  com.apple.smbd \
  com.apple.RemoteDesktop.agent \
  com.apple.RemoteAppleEvents; do
  if ! grep -Fq "[OK] $service disabled" <<<"$output"; then
    fail "expected script to treat launchctl '=> disabled' as disabled for $service"
  fi
done
