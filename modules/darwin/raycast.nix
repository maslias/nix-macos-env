{ lib, pkgs, ... }:

{
  # Raycast is distributed as a proprietary macOS app in nixpkgs.
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "raycast" ];

  environment.systemPackages = [
    pkgs.raycast
  ];

  # Free Cmd-Space for Raycast by disabling the default macOS Spotlight shortcut.
  # Raycast hotkeys themselves are best set in Raycast Settings for now; its
  # internal settings database is not a stable declarative interface.
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
