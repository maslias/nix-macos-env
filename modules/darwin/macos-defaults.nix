{
  # Minimal, clean macOS appearance.
  system.defaults = {
    dock = {
      autohide = true;              # Keep the Dock out of the way.
      show-recents = false;         # Do not show recent apps in the Dock.
      mru-spaces = false;           # Do not reorder Spaces automatically.
      tilesize = 48;                # Slightly smaller Dock icons.
      orientation = "bottom";       # Keep Dock placement predictable.
    };

    finder = {
      AppleShowAllExtensions = true; # Always show file extensions.
      AppleShowAllFiles = false;     # Keep hidden files hidden by default.
      ShowPathbar = true;            # Show the current path at the bottom.
      ShowStatusBar = true;          # Show item count and free space.
      FXPreferredViewStyle = "clmv"; # Column view by default.
    };

    loginwindow = {
      SHOWFULLNAME = true; # Show username/password fields instead of user icons.
    };

    screencapture = {
      location = "~/Pictures/Screenshots";
      type = "png";
    };
  };

  # Settings not covered by first-class nix-darwin options.
  system.defaults.CustomUserPreferences = {
    "com.apple.WindowManager" = {
      EnableStandardClickToShowDesktop = false; # Do not reveal desktop when clicking wallpaper.
      StandardHideWidgets = true;               # Hide desktop widgets for a cleaner desktop.
    };
  };
}
