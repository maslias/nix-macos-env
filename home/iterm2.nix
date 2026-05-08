{ lib, pkgs, ... }:

let
  color = red: green: blue: {
    "Color Space" = "sRGB";
    "Red Component" = red;
    "Green Component" = green;
    "Blue Component" = blue;
  };

  cyberdream = {
    background = color 0.086 0.094 0.102; # 16181a
    foreground = color 1.0 1.0 1.0;       # ffffff
    selection = color 0.235 0.251 0.282;  # 3c4048
    red = color 1.0 0.431 0.369;          # ff6e5e
    green = color 0.369 1.0 0.424;        # 5eff6c
    yellow = color 0.945 1.0 0.369;       # f1ff5e
    blue = color 0.369 0.631 1.0;         # 5ea1ff
    magenta = color 0.741 0.369 1.0;      # bd5eff
    cyan = color 0.369 0.945 1.0;         # 5ef1ff
  };

  profileName = "Cyberdream";
  profileGuid = "nix-managed-cyberdream";

  profile = {
    Name = profileName;
    Guid = profileGuid;

    # Match modules/darwin/alacritty.nix as closely as iTerm2 supports.
    "Terminal Type" = "xterm-256color";
    "Normal Font" = "JetBrainsMonoNerdFontMono-Regular 18";
    "Non Ascii Font" = "JetBrainsMonoNerdFontMono-Regular 18";
    "Use Non-ASCII Font" = false;
    "Use Bold Font" = true;
    "Use Italic Font" = true;
    "ASCII Ligatures" = true;
    "Non-ASCII Ligatures" = true;
    "Horizontal Spacing" = 1.0;
    "Vertical Spacing" = 1.0;

    "Columns" = 120;
    "Rows" = 32;
    "Transparency" = 0.05; # Alacritty opacity = 0.95
    "Blur" = false;
    "Window Type" = 0;
    "Use Bright Bold" = true;
    "Blinking Cursor" = true;
    "Cursor Type" = 2; # vertical bar, closest to Alacritty's default beam cursor
    "Unlimited Scrollback" = true;
    "Scrollback Lines" = 0;
    "Silence Bell" = true;
    "Visual Bell" = false;
    "Flashing Bell" = false;
    "Mouse Reporting" = true;
    "Hide Mouse Cursor in Terminal Windows" = true;

    # Equivalent to Alacritty option_as_alt = "Both" for macOS option-key input.
    "Left Option Key Sends" = 2;
    "Right Option Key Sends" = 2;

    # Alacritty-style padding.
    "Use Custom Window Size" = true;
    "Top/Bottom Margin" = 10;
    "Left/Right Margin" = 10;

    "Foreground Color" = cyberdream.foreground;
    "Background Color" = cyberdream.background;
    "Bold Color" = cyberdream.foreground;
    "Cursor Color" = cyberdream.cyan;
    "Cursor Text Color" = cyberdream.background;
    "Selection Color" = cyberdream.selection;
    "Selected Text Color" = cyberdream.foreground;

    "Ansi 0 Color" = cyberdream.background;
    "Ansi 1 Color" = cyberdream.red;
    "Ansi 2 Color" = cyberdream.green;
    "Ansi 3 Color" = cyberdream.yellow;
    "Ansi 4 Color" = cyberdream.blue;
    "Ansi 5 Color" = cyberdream.magenta;
    "Ansi 6 Color" = cyberdream.cyan;
    "Ansi 7 Color" = cyberdream.foreground;
    "Ansi 8 Color" = cyberdream.selection;
    "Ansi 9 Color" = cyberdream.red;
    "Ansi 10 Color" = cyberdream.green;
    "Ansi 11 Color" = cyberdream.yellow;
    "Ansi 12 Color" = cyberdream.blue;
    "Ansi 13 Color" = cyberdream.magenta;
    "Ansi 14 Color" = cyberdream.cyan;
    "Ansi 15 Color" = cyberdream.foreground;
  };
in
{
  home.packages = [ pkgs.iterm2 ];

  # iTerm2 loads JSON profiles from this directory automatically.
  home.file."Library/Application Support/iTerm2/DynamicProfiles/nix-cyberdream.json".text = builtins.toJSON {
    Profiles = [ profile ];
  };

  # Make the nix-managed profile the default/startup profile, mirroring how the
  # Alacritty module owns ~/.config/alacritty/alacritty.toml.
  home.activation.configureIterm2 = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD /usr/bin/defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "${profileGuid}"
    $DRY_RUN_CMD /usr/bin/defaults write com.googlecode.iterm2 "Startup Bookmark Guid" -string "${profileGuid}"
    $DRY_RUN_CMD /usr/bin/defaults write com.googlecode.iterm2 "PromptOnQuit" -bool false
    $DRY_RUN_CMD /usr/bin/defaults write com.googlecode.iterm2 "HideTab" -bool true
  '';
}
