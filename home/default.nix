{ username, ... }:

{
  imports = [
    ./browsers.nix
    ./iterm2.nix
    ./nvim.nix
    ./starship.nix
    ./tmux.nix
    ./vim.nix
    ./zsh.nix
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Keep this stable after the first successful switch.
  # Read the Home Manager release notes before changing it later.
  home.stateVersion = "25.05";
}
