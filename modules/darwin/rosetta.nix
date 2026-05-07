{ lib, ... }:

{
  # Apple Silicon only: install Rosetta 2 so x86_64 macOS binaries can run.
  # This is useful for vendor tools and other software that has not shipped an
  # arm64 build yet. The activation script is idempotent and skipped on Intel.
  system.activationScripts.rosetta.text = lib.mkAfter ''
    if [ "$(/usr/bin/uname -m)" = "arm64" ]; then
      if ! /usr/sbin/pkgutil --pkg-info com.apple.pkg.RosettaUpdateAuto >/dev/null 2>&1; then
        echo "Installing Rosetta 2 for x86_64 binary compatibility..."
        /usr/sbin/softwareupdate --install-rosetta --agree-to-license
      fi
    fi
  '';

  # Let Nix consider x86_64-darwin derivations runnable on Apple Silicon once
  # Rosetta is present. Determinate Nix manages the daemon, but this records the
  # intended platform support in the nix-darwin configuration.
  nix.settings.extra-platforms = [
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}
