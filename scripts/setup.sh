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

ensure_nix_on_path() {
  if command -v nix >/dev/null 2>&1; then
    return 0
  fi

  # The Determinate installer writes this profile hook for multi-user Nix.
  if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  if [[ -x /nix/var/nix/profiles/default/bin/nix ]]; then
    export PATH="/nix/var/nix/profiles/default/bin:$PATH"
  fi

  command -v nix >/dev/null 2>&1
}

install_nix() {
  cat <<'EOF'
Nix is not installed or is not on PATH.
Installing Determinate Nix because this repository's nix-darwin config expects it.
EOF

  if ! command -v curl >/dev/null 2>&1; then
    echo "error: curl is required to install Nix" >&2
    exit 1
  fi

  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm

  if ! ensure_nix_on_path; then
    cat >&2 <<'EOF'
error: Nix was installed, but the nix command is still unavailable in this shell.
Open a new terminal or source the Nix daemon profile, then re-run:
  ./scripts/setup.sh
EOF
    exit 1
  fi
}

if ! ensure_nix_on_path; then
  install_nix
fi

if ! grep -q 'nix-darwin' flake.nix || ! grep -q 'home-manager' flake.nix; then
  cat >&2 <<'EOF'
error: this repository must declare both nix-darwin and home-manager in flake.nix.
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

# Ensure newly added flake inputs, such as home-manager, are present in flake.lock
# before the privileged nix-darwin switch runs.
nix --extra-experimental-features "nix-command flakes" flake lock

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
