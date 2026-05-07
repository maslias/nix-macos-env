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
    if [[ "${1:-}" == "-u" && $# -eq 1 ]]; then printf '0\n'; elif [[ "${1:-}" == "-u" ]]; then printf '501\n'; elif [[ "${1:-}" == "-un" ]]; then printf 'root\n'; else /usr/bin/id "$@"; fi ;;
  stat)
    if [[ "${1:-}" == "-f" ]]; then printf 'alice\n'; else /usr/bin/stat "$@"; fi ;;
  launchctl)
    if [[ "${1:-}" == "asuser" ]]; then shift 2; exec "$@"; fi; exit 0 ;;
  sudo)
    if [[ "${1:-}" == "-u" ]]; then shift 2; exec "$@"; fi; exec "$@" ;;
  mdutil)
    if [[ "${1:-}" == "-a" && "${2:-}" == "-s" ]]; then printf '/:\n\tIndexing disabled.\n'; fi; exit 0 ;;
  defaults|systemsetup|networksetup|blueutil|socketfilterfw|spctl|fdesetup|killall)
    exit 0 ;;
  *) exit 0 ;;
esac
STUB
  chmod +x "$tmpdir/$path"
  if [[ "$path" == */* ]]; then
    ln -sf "$tmpdir/$path" "$tmpdir/$name"
  fi
}

for cmd in id stat launchctl sudo defaults systemsetup networksetup blueutil mdutil spctl fdesetup killall usr/libexec/ApplicationFirewall/socketfilterfw; do
  make_stub "$cmd"
done

output="$(CALL_LOG="$log" PATH="$tmpdir:$PATH" SOCKETFILTERFW="$tmpdir/usr/libexec/ApplicationFirewall/socketfilterfw" "$script" --apply)"
printf '%s\n' "$output"

for expected_call in \
  'mdutil -a -i off' \
  'mdutil -a -E'; do
  if ! grep -Fq "$expected_call" "$log"; then
    printf 'Recorded calls:\n' >&2
    cat "$log" >&2
    fail "expected call: $expected_call"
  fi
done

if ! grep -Fq '[OK] Spotlight indexing disabled' <<<"$output"; then
  fail 'expected report to show Spotlight indexing disabled'
fi
