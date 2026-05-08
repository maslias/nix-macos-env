{ lib, pkgs, ... }:

let
  # nixpkgs can lag a few Raycast patch releases. Keep this small override local
  # so macOS does not warn that the bundled app is outdated on newer systems.
  raycast = pkgs.raycast.overrideAttrs (_old: rec {
    version = "1.104.15";
    src = pkgs.fetchurl {
      name = "Raycast.dmg";
      url = "https://releases.raycast.com/releases/${version}/download?build=arm";
      hash = "sha256-3Syx0gIoaI5TiKoADVlEKhaGpysCYw2/8P+P/ScGIzs=";
    };
  });

  launchRaycastAtLogin = pkgs.writeShellScript "launch-raycast-at-login" ''
    set -eu

    app="${raycast}/Applications/Raycast.app"

    # At login, LaunchServices can race the GUI session. Delay briefly, then
    # retry so `open` succeeding before Raycast is actually running is not fatal.
    sleep 15
    for _ in 1 2 3 4 5 6; do
      if /usr/bin/pgrep -x Raycast >/dev/null; then
        exit 0
      fi

      /usr/bin/open -g "$app" || true
      sleep 5
    done

    /usr/bin/pgrep -x Raycast >/dev/null
  '';
in
{
  # These apps are distributed as proprietary macOS apps in nixpkgs.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "google-chrome"
      "obsidian"
      "raycast"
      "vscode"
    ];

  environment.systemPackages = [
    raycast
    pkgs.vscode
  ];

  # Raycast does not install a reliable macOS Login Item when it is installed
  # from nixpkgs, so launch it explicitly for the user's Aqua session. Use a
  # delayed retry wrapper: the previous direct `open -gj ...` could run before
  # LaunchServices/Raycast were ready and `-j` also launched Raycast hidden.
  launchd.user.agents.raycast = {
    serviceConfig = {
      ProgramArguments = [ "${launchRaycastAtLogin}" ];
      RunAtLoad = true;
      LimitLoadToSessionType = "Aqua";
      StandardOutPath = "/tmp/org.nixos.raycast.log";
      StandardErrorPath = "/tmp/org.nixos.raycast.log";
    };
  };

  # Free Cmd-Space for Raycast by disabling the default macOS Spotlight shortcut.
  # Raycast command hotkeys live in Raycast's private encrypted database, not in
  # a stable Home Manager/nix-darwin interface. Seed them via Raycast's supported
  # .rayconfig import flow; see docs/raycast.md and scripts/raycast-import-settings.sh.
  system.defaults.CustomUserPreferences = {
    "com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = {
        # Spotlight search: Cmd-Space.
        "64" = { enabled = false; };
        # Finder search window: Cmd-Option-Space. This is close enough to the
        # launcher chord that disabling it avoids accidental conflicts.
        "65" = { enabled = false; };
      };
    };
  };
}
