{ ... }:

{
  programs.zsh.enable = true;

  # Point zsh at the XDG config directory without requiring ~/.zshenv in $HOME.
  environment.etc."zshenv".text = ''
    if [ -n "$HOME" ]; then
      export ZDOTDIR="$HOME/.config/zsh"
    fi
  '';

  # User zsh config lives in ~/.config/zsh/.zshrc. Keep nix-darwin's global
  # zsh setup minimal so it does not run completion or prompt setup before it.
  programs.zsh.enableCompletion = false;
  programs.zsh.enableBashCompletion = false;
  programs.zsh.promptInit = "";
}
