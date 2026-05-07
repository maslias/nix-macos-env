#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat >"$tmpdir/id" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-u" && $# -eq 1 ]]; then printf '0\n'; elif [[ "${1:-}" == "-u" ]]; then printf '501\n'; elif [[ "${1:-}" == "-un" ]]; then printf 'root\n'; else /usr/bin/id "$@"; fi
STUB
chmod +x "$tmpdir/id"

cat >"$tmpdir/stat" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-f" ]]; then printf 'alice\n'; else /usr/bin/stat "$@"; fi
STUB
chmod +x "$tmpdir/stat"

cat >"$tmpdir/launchctl" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "asuser" ]]; then shift 2; exec "$@"; fi
if [[ "${1:-}" == "print-disabled" ]]; then
  cat <<'OUTPUT'
disabled services = {
  "com.apple.screensharing" => disabled
  "com.apple.AppleFileServer" => disabled
  "com.apple.smbd" => disabled
  "com.apple.RemoteDesktop.agent" => disabled
  "com.apple.RemoteAppleEvents" => disabled
}
OUTPUT
fi
exit 0
STUB
chmod +x "$tmpdir/launchctl"

cat >"$tmpdir/sudo" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "-u" ]]; then shift 2; exec "$@"; fi
exec "$@"
STUB
chmod +x "$tmpdir/sudo"

cat >"$tmpdir/defaults" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" != "read" ]]; then exit 0; fi
case "${2:-}:${3:-}" in
  com.apple.NetworkBrowser:DisableAirDrop) printf '1\n' ;;
  com.apple.coreservices.useractivityd:ActivityAdvertisingAllowed) printf '0\n' ;;
  com.apple.coreservices.useractivityd:ActivityReceivingAllowed) printf '0\n' ;;
  com.apple.airport.preferences:AskToJoinMode) printf 'DoNotAsk\n' ;;
  com.apple.airport.preferences:AskToJoinHotspot) printf '0\n' ;;
  com.apple.assistant.support:Assistant\ Enabled) printf '0\n' ;;
  com.apple.assistant.support:Search\ Queries\ Data\ Sharing\ Status) printf '2\n' ;;
  com.apple.assistant.support:Siri\ Data\ Sharing\ Opt-In\ Status) printf '2\n' ;;
  com.apple.Spotlight:SuggestionsEnabled) printf '0\n' ;;
  com.apple.ncprefs:show_on_lock_screen) printf '0\n' ;;
  com.apple.ncprefs:summaries_enabled) printf '0\n' ;;
  com.apple.AdLib:allowApplePersonalizedAdvertising) printf '0\n' ;;
  com.apple.SubmitDiagInfo:AutoSubmit) printf '0\n' ;;
  *) printf 'unknown\n' ;;
esac
STUB
chmod +x "$tmpdir/defaults"

cat >"$tmpdir/socketfilterfw" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  --getglobalstate) printf 'Firewall is enabled. (State = 1)\n' ;;
  --getstealthmode) printf 'Stealth mode enabled\n' ;;
  --getallowsigned) printf 'Automatically allow built-in signed software DISABLED\n' ;;
  --getallowsignedapp) printf 'Automatically allow downloaded signed software DISABLED\n' ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$tmpdir/socketfilterfw"

cat >"$tmpdir/blueutil" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "--power" ]]; then printf '0\n'; fi
STUB
chmod +x "$tmpdir/blueutil"

cat >"$tmpdir/systemsetup" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  -getusingnetworktime) printf 'Network Time: On\n' ;;
  -getnetworktimeserver) printf 'Network Time Server: pool.ntp.org\n' ;;
  *) exit 0 ;;
esac
STUB
chmod +x "$tmpdir/systemsetup"

for cmd in spctl fdesetup; do
  cat >"$tmpdir/$cmd" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "$tmpdir/$cmd"
done

output="$(PATH="$tmpdir:$PATH" SOCKETFILTERFW="$tmpdir/socketfilterfw" "$script")"
printf '%s\n' "$output"

for expected in \
  '[OK] Firewall does not automatically allow built-in signed software' \
  '[OK] Firewall does not automatically allow downloaded signed software' \
  '[OK] Wi-Fi ask-to-join networks disabled' \
  '[OK] Wi-Fi ask-to-join hotspots disabled' \
  '[OK] Bluetooth disabled' \
  '[OK] Handoff disabled' \
  '[OK] Spotlight improvement sharing disabled' \
  '[OK] Network time server is pool.ntp.org'; do
  if ! grep -Fq "$expected" <<<"$output"; then
    fail "expected report line: $expected"
  fi
done
