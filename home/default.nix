{ username, ... }:

{
  imports = [
    ./browsers.nix
    ./starship.nix
  ];

  home.username = username;
  home.homeDirectory = "/Users/${username}";

  # Keep this stable after the first successful switch.
  # Read the Home Manager release notes before changing it later.
  home.stateVersion = "25.05";
}
