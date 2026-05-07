{ ... }:

{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;

    settings = {
      # Match the Cyberdream terminal palette used by modules/darwin/alacritty.nix.
      palette = "cyberdream";
      add_newline = true;

      palettes.cyberdream = {
        background = "#16181a";
        foreground = "#ffffff";
        red = "#ff6e5e";
        green = "#5eff6c";
        yellow = "#f1ff5e";
        blue = "#5ea1ff";
        magenta = "#bd5eff";
        cyan = "#5ef1ff";
        orange = "#ffbd5e";
        gray = "#7b8496";
        selection = "#3c4048";
      };

      # Inspired by the previous Oh My Posh zen prompt:
      # host, separator, full path, git info, optional devbox marker, duration right prompt.
      format = "$hostname 󰄾 $directory$git_branch$git_status$custom.devbox\n$character";
      right_format = "$cmd_duration";

      hostname = {
        ssh_only = false;
        format = "[$hostname](blue)";
      };

      directory = {
        format = "[$path](green)";
        truncation_length = 0;
        truncate_to_repo = false;
      };

      git_branch = {
        symbol = "  ";
        format = "[$symbol](magenta)[$branch](gray)";
      };

      git_status = {
        format = "[$all_status$ahead_behind](gray)";
        modified = "\\[\\*\\]";
        staged = "\\[\\*\\]";
        ahead = "\\[!\\]";
        behind = "\\[!\\]";
        diverged = "\\[!\\]";
      };

      custom.devbox = {
        when = ''test -n "$DEVBOX_SHELL_ENABLED"'';
        command = "echo devbox";
        symbol = "󱄅";
        format = " [$symbol](magenta)[$output](gray)";
      };

      cmd_duration = {
        min_time = 5000;
        format = "[$duration](orange)";
      };

      character = {
        success_symbol = "[❯](yellow)";
        error_symbol = "[❯](red)";
      };
    };
  };
}
