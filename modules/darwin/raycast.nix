{ lib, pkgs, ... }:

{
  # Raycast is distributed as a proprietary macOS app in nixpkgs.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "google-chrome"
      "raycast"
    ];

  environment.systemPackages = [
    pkgs.raycast
  ];

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
