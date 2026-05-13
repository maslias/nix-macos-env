{ pkgs, ... }:

let
  tmuxContext = pkgs.writeShellApplication {
    name = "tmux-context";
    runtimeInputs = [ pkgs.gawk ];
    text = ''
      set -u

      pane_id="''${1:-}"
      pane_command="''${2:-}"
      pane_title="''${3:-}"
      pane_tty="''${4:-}"

      style_local='#[fg=#7b8496]'
      style_ssh='#[fg=#16181a,bg=#5eff6c,bold]'
      style_serial='#[fg=#ffffff,bg=#6b3fa0,bold]'
      style_reset='#[default]'

      print_styled() {
        kind="$1"
        label="$2"
        case "$kind" in
          ssh) printf '%s %s %s' "$style_ssh" "$label" "$style_reset" ;;
          serial) printf '%s %s %s' "$style_serial" "$label" "$style_reset" ;;
          *) printf '%s %s %s' "$style_local" "$label" "$style_reset" ;;
        esac
      }

      context_file="''${XDG_CACHE_HOME:-$HOME/.cache}/tmux-context/''${pane_id}"
      if [ -n "$pane_id" ] && [ -r "$context_file" ]; then
        label="$(head -n 1 "$context_file")"
        case "$label" in
          ssh\ ::*) print_styled ssh "$label" ;;
          serial\ ::*) print_styled serial "$label" ;;
          *) print_styled local "$label" ;;
        esac
        exit 0
      fi

      full_command=""
      if [ -n "$pane_tty" ]; then
        tty_name="''${pane_tty#/dev/}"
        full_command="$(ps -t "$tty_name" -o command= 2>/dev/null | tail -n 1 || true)"
      fi

      short_host() {
        hostname -s 2>/dev/null || hostname 2>/dev/null || printf unknown
      }

      local_ip() {
        iface="$(route get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)"
        if [ -n "$iface" ]; then
          ipconfig getifaddr "$iface" 2>/dev/null && return 0
        fi
        printf unknown
      }

      ssh_target() {
        # Best-effort parser for common direct ssh invocations. It intentionally
        # stays conservative; explicit context files can override this later.
        # shellcheck disable=SC2086 # Intentional splitting for best-effort argv parsing.
        set -- $full_command
        target=""
        skip_next=0
        for arg in "$@"; do
          if [ "$skip_next" = 1 ]; then
            skip_next=0
            continue
          fi
          case "$arg" in
            ssh|command|env) continue ;;
            -b|-c|-D|-E|-F|-I|-i|-J|-L|-l|-m|-O|-o|-p|-Q|-R|-S|-W|-w) skip_next=1 ;;
            --) ;;
            -*) ;;
            *) target="$arg" ;;
          esac
        done
        printf '%s' "$target"
      }

      serial_device() {
        printf '%s\n' "$full_command" | awk '{ for (i = 1; i <= NF; i++) if ($i ~ /^\/dev\//) { print $i; exit } }'
      }

      case "$pane_command" in
        ssh|mosh)
          target="$(ssh_target)"
          if [ -z "$target" ]; then
            target="$pane_title"
          fi
          user="''${target%@*}"
          host="''${target#*@}"
          if [ "$user" = "$host" ]; then
            user="$(whoami)"
          fi
          print_styled ssh "ssh :: $user :: $host"
          ;;
        screen|cu|minicom|picocom)
          device="$(serial_device)"
          if [ -z "$device" ]; then
            device="$pane_title"
          fi
          print_styled serial "serial :: $pane_title :: $device"
          ;;
        *)
          print_styled local "$(short_host) :: $(local_ip)"
          ;;
      esac
    '';
  };

  tmuxYankLog = pkgs.writeShellApplication {
    name = "tmux-yank-log";
    runtimeInputs = [ pkgs.coreutils pkgs.tmux ];
    text = ''
      selection_file="$(mktemp)"
      trap 'rm -f "$selection_file"' EXIT
      cat > "$selection_file"

      get_tmux_option() {
        option="$1"
        default_value="$2"
        option_value="$(tmux show-option -gqv "$option")"
        if [ -z "$option_value" ]; then
          printf '%s\n' "$default_value"
        else
          printf '%s\n' "$option_value"
        fi
      }

      # Match tmux-logging's filename convention:
      # tmux-<kind>-#{session_name}-#{window_index}-#{pane_index}-%Y%m%dT%H%M%S.log
      filename_suffix='#{session_name}-#{window_index}-#{pane_index}-%Y%m%dT%H%M%S.log'
      logging_path="$(get_tmux_option "@logging-path" "$HOME")"
      yank_log_path="$(get_tmux_option "@yank-log-path" "$logging_path")"
      yank_log_filename="$(get_tmux_option "@yank-log-filename" "tmux-yank-$filename_suffix")"

      file="$(tmux display-message -p "$yank_log_path/$yank_log_filename")"
      mkdir -p "''${file%/*}"
      cp "$selection_file" "$file"

      if command -v pbcopy >/dev/null 2>&1; then
        pbcopy < "$selection_file"
        tmux display-message "Yanked selection copied and saved to $file"
      else
        tmux display-message "Yanked selection saved to $file"
      fi
    '';
  };
in
{
  home.packages = [ tmuxContext tmuxYankLog ];

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    baseIndex = 1;
    mouse = true;
    historyLimit = 100000;
    keyMode = "vi";
    escapeTime = 10;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-save 'S'
          set -g @resurrect-restore 'R'
        '';
      }
      continuum
      {
        plugin = logging;
        extraConfig = ''
          set -g @logging_key 'P'
          set -g @screen-capture-key 'G'
          set -g @save-complete-history-key 'A'
          set -g @clear-history-key 'X'
        '';
      }
      {
        plugin = vim-tmux-navigator;
        extraConfig = ''
          set -g @vim_navigator_mapping_left 'C-h'
          set -g @vim_navigator_mapping_down 'C-j'
          set -g @vim_navigator_mapping_up 'C-k'
          set -g @vim_navigator_mapping_right 'C-l'
        '';
      }
      {
        plugin = yank;
        extraConfig = ''
          # Disable normal-mode prefix y/Y by moving them to unused high function
          # keys; keep copy-mode yank behavior.
          set -g @yank_line 'F13'
          set -g @yank_pane_pwd 'F14'
          set -g @copy_mode_yank 'y'
          set -g @copy_mode_put 'p'
          # Disable copy-mode yank+put and yank-without-newline extras.
          set -g @copy_mode_yank_put 'F15'
          set -g @copy_mode_yank_wo_newline 'F16'
        '';
      }
      {
        plugin = open;
        extraConfig = ''
          set -g @open 'o'
          set -g @open-editor 'e'
        '';
      }
    ];

    extraConfig = ''
      # tmux configuration managed by Home Manager.
      # Local changes should be made in home/tmux.nix.

      # ───────────────────────────────────────────────────────────────────────
      # Ops cockpit core
      # ───────────────────────────────────────────────────────────────────────
      set -g default-terminal "tmux-256color"
      set -ag terminal-overrides ",xterm-256color:RGB,alacritty:RGB,tmux-256color:RGB"
      setw -g pane-base-index 1
      set -g renumber-windows on
      set -g focus-events on
      set -g set-clipboard on
      set -g detach-on-destroy off
      set -g remain-on-exit failed

      # Keep pane/window titles useful without allowing shell prompts to rename
      # windows unexpectedly.
      set -g set-titles on
      set -g set-titles-string "#S:#I:#W - #h"
      set -g allow-rename off
      setw -g automatic-rename on

      # ───────────────────────────────────────────────────────────────────────
      # Plugin settings
      # ───────────────────────────────────────────────────────────────────────
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '10'
      set -g @resurrect-capture-pane-contents 'on'
      set -g @resurrect-strategy-vim 'session'
      set -g @resurrect-strategy-nvim 'session'

      # ───────────────────────────────────────────────────────────────────────
      # Cyberdream ops status bar
      # ───────────────────────────────────────────────────────────────────────
      set -g status on
      set -g status-position bottom
      set -g status-justify left
      set -g status-interval 2
      set -g status-left-length 80
      set -g status-right-length 140

      set -g status-style "bg=default,fg=#ffffff"
      set -g pane-border-style "fg=#3c4048"
      set -g pane-active-border-style "fg=#5ea1ff"
      # tmux command prompt / command line (prefix + :): yellow status-line
      # replacement with dark text. tmux uses message-style for the prompt area
      # and message-command-style for the editable command text.
      set -g message-style "bg=#f1ff5e,fg=#16181a,bold"
      set -g message-command-style "bg=#f1ff5e,fg=#16181a,bold"
      set -g mode-style "bg=#5eff6c,fg=#16181a,bold"

      # Window list / middle module: transparent/neutral background.
      # Inactive windows are dark gray, current window is pink.
      set -g window-status-style "bg=default,fg=#3c4048"
      set -g window-status-current-style "bg=default,fg=#ff6e9f,bold"
      set -g window-status-activity-style "bg=#16181a,fg=#ffbd5e,bold"
      set -g window-status-bell-style "bg=#ff6e5e,fg=#16181a,bold"
      set -g window-status-separator "#[fg=#3c4048] || #[default]"

      # Left/session module: orange background normally. State is indicated by
      # changing the whole left color: prefix -> yellow, readonly -> red.
      # If pane logging is active, add a white REC marker before the session name.
      set -g status-left "#[fg=#16181a,bg=#ffbd5e,bold]#{?client_prefix,#[fg=#16181a#,bg=#f1ff5e#,bold],}#{?client_readonly,#[fg=#16181a#,bg=#ff6e5e#,bold],}#{?pane_pipe, #[fg=#ffffff]● REC #[fg=#16181a], }#S #[default]  "

      # Right side: connection context, then a far-right one-space module that
      # mirrors the left module's dynamic color.
      set -g status-right "#(${tmuxContext}/bin/tmux-context '#{pane_id}' '#{pane_current_command}' '#{pane_title}' '#{pane_tty}')#[fg=#16181a,bg=#ffbd5e,bold]#{?client_prefix,#[fg=#16181a#,bg=#f1ff5e#,bold],}#{?client_readonly,#[fg=#16181a#,bg=#ff6e5e#,bold],} #[default]"

      set -g window-status-format "#[fg=#3c4048]#I:#W"
      set -g window-status-current-format "#[fg=#ff6e9f,bold]#I:#W"

      # Optional pane border labels. Kept off by default for a cleaner cockpit.
      set -g pane-border-status off
      set -g pane-border-format " #[fg=#5ea1ff]#{pane_index} #[fg=#7b8496]#{pane_current_command} "

      # ───────────────────────────────────────────────────────────────────────
      # Minimal keybindings, close to tmux defaults
      # ───────────────────────────────────────────────────────────────────────
      # Core cockpit controls.
      bind-key r source-file ~/.config/tmux/tmux.conf \; display-message "tmux config reloaded"
      bind-key : command-prompt -p "tmux command line" "%%"
      unbind-key -q y
      unbind-key -q Y
      unbind-key -q F13
      unbind-key -q F14
      unbind-key -T copy-mode-vi -q Y
      unbind-key -T copy-mode-vi -q I
      unbind-key -T copy-mode-vi -q '!'
      unbind-key -T copy-mode-vi -q F15
      unbind-key -T copy-mode-vi -q F16
      bind-key -T copy-mode-vi Y send-keys -X copy-pipe-and-cancel "${tmuxYankLog}/bin/tmux-yank-log"

      # Fast global navigation. Panes use Ctrl-h/j/k/l via vim-tmux-navigator;
      # windows use Ctrl-,/Ctrl-. to avoid macOS Option/Cmd shortcuts and
      # terminal word-movement keys.
      bind-key -n C-, previous-window
      bind-key -n C-. next-window

      # Layout: default split keys, but preserve the current pane path.
      bind-key % split-window -h -c "#{pane_current_path}"
      bind-key '"' split-window -v -c "#{pane_current_path}"
      bind-key c new-window -c "#{pane_current_path}"

      # Pane movement and resize. Ctrl-h/j/k/l is handled by vim-tmux-navigator.
      bind-key h select-pane -L
      bind-key j select-pane -D
      bind-key k select-pane -U
      bind-key l select-pane -R

      bind-key H resize-pane -L 5
      bind-key J resize-pane -D 5
      bind-key K resize-pane -U 5
      bind-key L resize-pane -R 5

      # Plugin binds, configured above. Prefix commands deliberately use plain
      # keys only, with no Ctrl/Meta modifiers:
      # - Recovery: prefix S save, prefix R restore
      # - Logging: prefix P toggle recording, prefix G capture screen,
      #   prefix A save complete history, prefix X clear pane history
      # - Copy-mode yank/open: y yank, Y yank+save as tmux-yank log,
      #   p put, o open, e open in editor
      # - Vim navigation: C-h/C-j/C-k/C-l across Vim and tmux panes
      # - Windows: C-. next window, C-, previous window

      # Copy-mode basics.
      bind-key -T copy-mode-vi v send-keys -X begin-selection
    '';
  };
}
