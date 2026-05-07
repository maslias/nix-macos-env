#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
script="$repo_root/scripts/macos-privacy-check.sh"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
log="$tmpdir/calls.log"
touch "$log"

mkdir -p "$tmpdir/usr/libexec/ApplicationFirewall"

make_stub() {
  local path="$1"
  local name
  name="$(basename "$path")"
  cat >"$tmpdir/$path" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >>"$CALL_LOG"
case "$(basename "$0")" in
  id)
    if [[ "${1:-}" == "-u" && $# -eq 1 ]]; then printf '0\n'; elif [[ "${1:-}" == "-u" ]]; then printf '501\n'; else /usr/bin/id "$@"; fi ;;
  stat)
    if [[ "${1:-}" == "-f" ]]; then printf 'alice\n'; else /usr/bin/stat "$@"; fi ;;
  launchctl)
    if [[ "${1:-}" == "asuser" ]]; then shift 2; exec "$@"; fi; exit 0 ;;
  sudo)
    if [[ "${1:-}" == "-u" ]]; then shift 2; exec "$@"; fi; exec "$@" ;;
  networksetup)
    if [[ "${1:-}" == "-listallhardwareports" ]]; then printf 'Hardware Port: Wi-Fi\nDevice: en0\n'; fi; exit 0 ;;
  defaults|systemsetup|blueutil|socketfilterfw|spctl|fdesetup|killall)
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$tmpdir/$path"
  if [[ "$path" == */* ]]; then
    ln -sf "$tmpdir/$path" "$tmpdir/$name"
  fi
}

for cmd in id stat launchctl sudo defaults systemsetup networksetup blueutil spctl fdesetup killall usr/libexec/ApplicationFirewall/socketfilterfw; do
  make_stub "$cmd"
done

CALL_LOG="$log" PATH="$tmpdir:$PATH" SOCKETFILTERFW="$tmpdir/usr/libexec/ApplicationFirewall/socketfilterfw" "$script" --apply >/dev/null

require_call() {
  local needle="$1"
  if ! grep -Fq "$needle" "$log"; then
    printf 'Recorded calls:\n' >&2
    cat "$log" >&2
    fail "expected call: $needle"
  fi
}

require_call 'socketfilterfw --setglobalstate on'
require_call 'socketfilterfw --setstealthmode on'
require_call 'socketfilterfw --setallowsigned off'
require_call 'socketfilterfw --setallowsignedapp off'
require_call 'networksetup -setairportpower en0 off'
require_call 'defaults write com.apple.airport.preferences AskToJoinMode DoNotAsk'
require_call 'defaults write com.apple.airport.preferences AskToJoinHotspot -bool false'
require_call 'blueutil --power 0'
require_call 'defaults write com.apple.coreservices.useractivityd ActivityAdvertisingAllowed -bool false'
require_call 'defaults write com.apple.coreservices.useractivityd ActivityReceivingAllowed -bool false'
require_call 'systemsetup -setusingnetworktime on'
require_call 'systemsetup -setnetworktimeserver pool.ntp.org'
