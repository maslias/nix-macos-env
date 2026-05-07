{ pkgs, ... }:

{
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    fzf
    oh-my-zsh
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
    zstyle ':completion:*' menu select

    # fzf: fuzzy finder keybinds/completion and clean default UI.
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
    export FZF_DEFAULT_COMMAND='find . -type f -not -path "*/.git/*"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    source <(fzf --zsh)

    # Shared operator-friendly zsh plugins.
    source ${pkgs.oh-my-zsh}/share/oh-my-zsh/plugins/ssh-agent/ssh-agent.plugin.zsh
    source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
    source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

    # Vi editing mode.
    bindkey -v

    # History search keybinds.
    # Ctrl-p/Ctrl-n search backward/forward for commands matching the current prefix.
    bindkey -M viins '^P' history-search-backward
    bindkey -M viins '^N' history-search-forward

    # Shell behavior: quieter and better for pasted/documented commands.
    setopt no_beep
    setopt interactive_comments
  '';
}
