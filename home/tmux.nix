{ pkgs, ... }:

{
  home.packages = [ pkgs.tmux ];

  home.file.".tmux.conf".text = ''
    # tmux configuration managed by Home Manager.
    # Local changes should be made in home/tmux.nix.

    # ─────────────────────────────────────────────────────────────────────────
    # Cyberdream theme
    # ─────────────────────────────────────────────────────────────────────────
    # Palette shared with Alacritty, iTerm2, Terminal.app, and Starship.
    # background #16181a, foreground #ffffff, selection #3c4048
    # red #ff6e5e, green #5eff6c, yellow #f1ff5e, blue #5ea1ff,
    # magenta #bd5eff, cyan #5ef1ff, orange #ffbd5e, gray #7b8496

    set -g status-style "bg=#16181a,fg=#ffffff"
    set -g pane-border-style "fg=#3c4048"
    set -g pane-active-border-style "fg=#5ef1ff"
    set -g message-style "bg=#3c4048,fg=#ffffff"
    set -g message-command-style "bg=#3c4048,fg=#ffffff"
    set -g mode-style "bg=#5ef1ff,fg=#16181a,bold"

    set -g window-status-style "bg=#16181a,fg=#7b8496"
    set -g window-status-current-style "bg=#3c4048,fg=#5ef1ff,bold"
    set -g window-status-activity-style "bg=#16181a,fg=#ffbd5e,bold"
    set -g window-status-bell-style "bg=#ff6e5e,fg=#16181a,bold"
    set -g window-status-separator ""

    # ─────────────────────────────────────────────────────────────────────────
    # General behavior
    # ─────────────────────────────────────────────────────────────────────────
    set -g default-terminal "tmux-256color"
    set -ag terminal-overrides ",xterm-256color:RGB,alacritty:RGB,tmux-256color:RGB"
    set -g base-index 1
    setw -g pane-base-index 1
    set -g renumber-windows on
    set -g mouse on
    set -g history-limit 50000
    set -g escape-time 0
    set -g focus-events on
    set -g set-clipboard on
    setw -g mode-keys vi

    # Keep pane/window titles useful without allowing shell prompts to rename
    # windows unexpectedly.
    set -g set-titles on
    set -g set-titles-string "#S:#I:#W - #h"
    set -g allow-rename off
    setw -g automatic-rename on

    # ─────────────────────────────────────────────────────────────────────────
    # Session protection from imported config
    # ─────────────────────────────────────────────────────────────────────────
    # Keep panes alive after shell exit so pane-died can decide whether to
    # respawn the last pane or clean up dead split panes.
    set -g remain-on-exit on
    set-hook -g pane-died \
      'if-shell -F "#{&&:#{==:#{session_windows},1},#{==:#{window_panes},1}}" \
        "respawn-pane" "kill-pane"'

    # ─────────────────────────────────────────────────────────────────────────
    # Status bar
    # ─────────────────────────────────────────────────────────────────────────
    set -g status on
    set -g status-position bottom
    set -g status-justify left
    set -g status-interval 2
    set -g status-left-length 80
    set -g status-right-length 100

    CYBERDREAM_SESSION='#[fg=#16181a,bg=#5ef1ff,bold]  #S  '
    CYBERDREAM_READ_ONLY='#[fg=#f1ff5e,bg=#3c4048,bold]#{?client_readonly, READ-ONLY ,}'
    CYBERDREAM_USER_HOST='#[fg=#5eff6c,bg=#3c4048] #(whoami)@#h '
    CYBERDREAM_SSH='#[fg=#ffbd5e,bg=#3c4048]#{?SSH_CONNECTION,via SSH ,}#[fg=#5ef1ff,bg=#3c4048]#(printf "%s" "$SSH_CONNECTION" | cut -d" " -f1)'

    set -g status-left "''${CYBERDREAM_SESSION}''${CYBERDREAM_READ_ONLY}#[default]"
    set -g status-right "#[bg=#3c4048]''${CYBERDREAM_USER_HOST}''${CYBERDREAM_SSH}#[default]"

    set -g window-status-format " #[fg=#7b8496]#I:#W#{?window_flags,#{window_flags},} "
    set -g window-status-current-format "#[bg=#3c4048,fg=#5ef1ff,bold] #I:#W#{?window_flags,#{window_flags},} "

    # Optional pane border labels. Kept off by default for a cleaner look.
    set -g pane-border-status off
    set -g pane-border-format " #[fg=#5ea1ff]#{pane_index} #[fg=#7b8496]#{pane_current_command} "

    # ─────────────────────────────────────────────────────────────────────────
    # Minimal keybinds
    # ─────────────────────────────────────────────────────────────────────────
    # Keep bindings mnemonic and prefix-scoped to avoid conflicts with shells,
    # Neovim, terminal shortcuts, and macOS system shortcuts.
    bind-key r source-file ~/.tmux.conf \; display-message "tmux config reloaded"

    bind-key | split-window -h -c "#{pane_current_path}"
    bind-key - split-window -v -c "#{pane_current_path}"

    bind-key h select-pane -L
    bind-key j select-pane -D
    bind-key k select-pane -U
    bind-key l select-pane -R

    bind-key H resize-pane -L 5
    bind-key J resize-pane -D 5
    bind-key K resize-pane -U 5
    bind-key L resize-pane -R 5

    bind-key -T copy-mode-vi v send-keys -X begin-selection
    bind-key -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "pbcopy"
  '';
}
