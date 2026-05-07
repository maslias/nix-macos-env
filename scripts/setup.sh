#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this setup is for macOS/nix-darwin only" >&2
  exit 1
fi

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  cat >&2 <<'EOF'
error: do not run this script with sudo.
Run it as your normal macOS user:
  ./scripts/setup.sh

nix-darwin will ask for administrator privileges when needed.
EOF
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  cat >&2 <<'EOF'
error: nix is not installed or is not on PATH.
Install Nix first, then re-run this script:
  https://nixos.org/download/
EOF
  exit 1
fi

flake_username="$(awk -F'"' '/^[[:space:]]*username = "/ { print $2; exit }' flake.nix)"
flake_hostname="$(awk -F'"' '/^[[:space:]]*hostname = "/ { print $2; exit }' flake.nix)"

if [[ -z "$flake_username" || -z "$flake_hostname" ]]; then
  echo "error: could not read username/hostname from flake.nix" >&2
  exit 1
fi

current_user="$(id -un)"

cat <<EOF
Applying nix-darwin configuration
  repo:     $repo_root
  flake:    .#$flake_hostname
  user:     $flake_username
  mac user: $current_user
EOF

if [[ "$flake_username" != "$current_user" ]]; then
  cat >&2 <<EOF

warning: flake username '$flake_username' does not match current macOS user '$current_user'.
Make sure flake.nix uses your macOS short username before continuing.
EOF
fi

# Recent nix-darwin versions require system activation to run as root.
# Keep this script running as the normal macOS user for config checks, then
# elevate only the actual switch command.
#
# In non-interactive runners there may be no TTY for sudo's password prompt, so
# provide a small macOS GUI askpass helper as a fallback.
askpass_file="$(mktemp -t nix-darwin-askpass.XXXXXX)"
trap 'rm -f "$askpass_file"' EXIT
cat >"$askpass_file" <<'EOF'
#!/usr/bin/env bash
exec osascript -e 'display dialog "Administrator password:" default answer "" with hidden answer buttons {"OK"} default button "OK"' -e 'text returned of result'
EOF
chmod 700 "$askpass_file"
export SUDO_ASKPASS="$askpass_file"

if command -v darwin-rebuild >/dev/null 2>&1; then
  darwin_rebuild_bin="$(command -v darwin-rebuild)"
  exec sudo -A -H "$darwin_rebuild_bin" switch --flake ".#$flake_hostname"
else
  nix_bin="$(command -v nix)"
  exec sudo -A -H "$nix_bin" --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ".#$flake_hostname"
fi
