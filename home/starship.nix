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
      # host, separator, full path, git info, separated devbox marker, duration right prompt.
      format = "$hostname 󰄾 $directory$git_branch$custom.git_dirty$custom.devbox\n$character";
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

      # Keep git status intentionally compact: any non-clean worktree becomes [*].
      custom.git_dirty = {
        when = ''git rev-parse --is-inside-work-tree >/dev/null 2>&1 && test -n "$(git status --porcelain)"'';
        command = "printf '[*]'";
        format = "[$output](gray)";
      };

      custom.devbox = {
        when = ''test -n "$DEVBOX_SHELL_ENABLED"'';
        command = "printf 'devbox'";
        symbol = "󱄅";
        format = " [|](gray) [$symbol $output](magenta)";
      };

      cmd_duration = {
        min_time = 5000;
        format = "[$duration](orange)";
      };

      character = {
        success_symbol = "[❯](yellow)";
        error_symbol = "[❯](red)";
        vimcmd_symbol = "[❮ NORMAL](blue)";
        vimcmd_replace_one_symbol = "[❮ REPLACE](orange)";
        vimcmd_replace_symbol = "[❮ REPLACE](orange)";
        vimcmd_visual_symbol = "[❮ VISUAL](magenta)";
      };
    };
  };
}
