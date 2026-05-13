{ lib, pkgs, username, ... }:

let
  alacrittyConfig = pkgs.writeText "alacritty.toml" ''
    # Cyberdream Alacritty configuration managed by nix-darwin.
    # Local changes should be made in modules/darwin/alacritty.nix.

    [general]
    live_config_reload = true

    [env]
    # Widely compatible terminal type for local and remote shells.
    TERM = "xterm-256color"

    [window]
    startup_mode = "Windowed"
    decorations = "Full"
    opacity = 0.95
    option_as_alt = "Both"

    [window.padding]
    x = 10
    y = 10

    [font]
    size = 18.0

    [font.normal]
    family = "JetBrainsMono Nerd Font Mono"
    style = "Regular"

    [font.bold]
    family = "JetBrainsMono Nerd Font Mono"
    style = "Bold"

    [font.italic]
    family = "JetBrainsMono Nerd Font Mono"
    style = "Italic"

    [font.bold_italic]
    family = "JetBrainsMono Nerd Font Mono"
    style = "Bold Italic"

    [selection]
    save_to_clipboard = true

    [mouse]
    hide_when_typing = true

    # tmux window navigation. Emit xterm modifyOtherKeys sequences so tmux can
    # parse these as C-Tab and C-S-Tab instead of relying on UserKeys.
    [[keyboard.bindings]]
    key = "Tab"
    mods = "Control"
    chars = "\u001b[27;5;9~"

    [[keyboard.bindings]]
    key = "Tab"
    mods = "Control|Shift"
    chars = "\u001b[27;6;9~"

    # Cyberdream dark palette: https://github.com/scottmckendry/cyberdream.nvim/tree/main/extras/alacritty
    [colors.primary]
    background = "#16181a"
    foreground = "#ffffff"

    [colors.cursor]
    text = "#16181a"
    cursor = "#5ef1ff"

    [colors.selection]
    background = "#3c4048"
    foreground = "#ffffff"

    [colors.normal]
    black = "#16181a"
    red = "#ff6e5e"
    green = "#5eff6c"
    yellow = "#f1ff5e"
    blue = "#5ea1ff"
    magenta = "#bd5eff"
    cyan = "#5ef1ff"
    white = "#ffffff"

    [colors.bright]
    black = "#3c4048"
    red = "#ff6e5e"
    green = "#5eff6c"
    yellow = "#f1ff5e"
    blue = "#5ea1ff"
    magenta = "#bd5eff"
    cyan = "#5ef1ff"
    white = "#ffffff"

    [[colors.indexed_colors]]
    index = 16
    color = "#ffbd5e"

    [[colors.indexed_colors]]
    index = 17
    color = "#ff6e5e"
  '';
in
{
  environment.systemPackages = [
    pkgs.alacritty
    # Provides terminfo entries such as `alacritty` for programs that start
    # before Alacritty's config has overridden TERM to xterm-256color.
    pkgs.ncurses
  ];

  system.activationScripts.postActivation.text = lib.mkAfter ''
    config_dir="/Users/${username}/.config/alacritty"
    config_file="$config_dir/alacritty.toml"

    mkdir -p "$config_dir"
    chown ${username}:staff "$config_dir"
    ln -sfn ${alacrittyConfig} "$config_file"
    chown -h ${username}:staff "$config_file"
  '';
}
