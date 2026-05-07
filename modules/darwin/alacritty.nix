{ pkgs, username, ... }:

let
  alacrittyConfig = pkgs.writeText "alacritty.toml" ''
    # Stable, minimal Alacritty configuration managed by nix-darwin.
    # Local changes should be made in modules/darwin/alacritty.nix.

    live_config_reload = true

    [env]
    # Widely compatible terminal type for local and remote shells.
    TERM = "xterm-256color"

    [window]
    startup_mode = "Windowed"
    decorations = "Full"
    opacity = 1.0
    option_as_alt = "Both"

    [window.padding]
    x = 8
    y = 8

    [font]
    size = 13.0

    [font.normal]
    family = "Menlo"
    style = "Regular"

    [font.bold]
    family = "Menlo"
    style = "Bold"

    [font.italic]
    family = "Menlo"
    style = "Italic"

    [font.bold_italic]
    family = "Menlo"
    style = "Bold Italic"

    [selection]
    save_to_clipboard = true

    [mouse]
    hide_when_typing = true

    [colors.primary]
    background = "#0f1117"
    foreground = "#d8dee9"

    [colors.normal]
    black = "#3b4252"
    red = "#bf616a"
    green = "#a3be8c"
    yellow = "#ebcb8b"
    blue = "#81a1c1"
    magenta = "#b48ead"
    cyan = "#88c0d0"
    white = "#e5e9f0"

    [colors.bright]
    black = "#4c566a"
    red = "#bf616a"
    green = "#a3be8c"
    yellow = "#ebcb8b"
    blue = "#81a1c1"
    magenta = "#b48ead"
    cyan = "#8fbcbb"
    white = "#eceff4"
  '';
in
{
  environment.systemPackages = [
    pkgs.alacritty
  ];

  system.activationScripts.alacrittyConfig.text = ''
    config_dir="/Users/${username}/.config/alacritty"
    config_file="$config_dir/alacritty.toml"

    mkdir -p "$config_dir"
    chown ${username}:staff "$config_dir"
    ln -sfn ${alacrittyConfig} "$config_file"
    chown -h ${username}:staff "$config_file"
  '';
}
