{ pkgs, ... }:

{
  programs.zsh.enable = true;

  # We manage completion setup below. Disable nix-darwin's default zsh
  # completion/prompt snippets so /etc/zshrc does not run compinit twice after
  # plugins have wrapped widgets.
  programs.zsh.enableCompletion = false;
  programs.zsh.enableBashCompletion = false;
  programs.zsh.promptInit = "";

  environment.systemPackages = with pkgs; [
    fzf
    oh-my-zsh
    starship
    vivid
    zsh-autosuggestions
    zsh-completions
    zsh-fzf-tab
    zsh-syntax-highlighting
  ];

  programs.zsh.interactiveShellInit = ''
    # History: keep a useful shared history across terminal sessions.
    HISTSIZE=10000
    SAVEHIST=10000

    setopt appendhistory
    setopt inc_append_history
    setopt sharehistory

    setopt hist_ignore_space
    setopt hist_ignore_dups
    setopt hist_ignore_all_dups
    setopt hist_save_no_dups
    setopt hist_find_no_dups

    # Completion: enable zsh completions with simple, forgiving matching.
    fpath=(${pkgs.zsh-completions}/share/zsh/site-functions $fpath)

    autoload -Uz compinit
    compinit

    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    # fzf-tab renders the completion menu, so disable zsh's native menu selection.
    zstyle ':completion:*' menu no

    # Completion colors and fzf-tab previews.
    export LS_COLORS="$(${pkgs.vivid}/bin/vivid generate cyberdream)"
    zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
    # Also accept fzf-tab completion selections with Ctrl-y.
    zstyle ':fzf-tab:*' fzf-bindings 'ctrl-y:accept'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview '${pkgs.coreutils}/bin/ls --color=always -la $realpath'

    # fzf: fuzzy finder keybinds/completion and clean default UI.
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
    export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    # Also accept fzf history/file selections with Ctrl-y.
    export FZF_CTRL_R_OPTS='--bind=ctrl-y:accept'
    export FZF_CTRL_T_OPTS='--bind=ctrl-y:accept'
    source <(fzf --zsh)

    # Shared operator-friendly zsh plugins.
    # fzf-tab must be loaded after compinit, and before plugins that wrap widgets.
    source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh

    # Load autosuggestions before syntax highlighting so highlighting can wrap widgets last.
    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

    # Vi editing mode.
    bindkey -v

    # Edit the current command line in $EDITOR.
    autoload -Uz edit-command-line
    zle -N edit-command-line
    bindkey -M viins '^X^E' edit-command-line
    bindkey -M vicmd 'v' edit-command-line

    # History search keybinds.
    # Ctrl-p/Ctrl-n search backward/forward for commands matching the current prefix.
    bindkey -M viins '^P' history-search-backward
    bindkey -M viins '^N' history-search-forward

    # Autosuggestions: accept the whole suggestion with Ctrl-y in vi insert mode.
    # In vi insert mode Ctrl-y is self-insert by default, so this avoids a useful conflict.
    # Right arrow/end-of-line also accept suggestions through plugin defaults.
    bindkey -M viins '^Y' autosuggest-accept

    # Shell behavior: quieter and better for pasted/documented commands.
    setopt no_beep
    setopt interactive_comments

    # Prompt: Home Manager writes ~/.config/starship.toml, while nix-darwin
    # owns /etc/zshrc for interactive shells on this machine.
    eval "$(${pkgs.starship}/bin/starship init zsh)"
  '';
}
