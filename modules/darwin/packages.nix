{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bat
    fd
    git
    ripgrep
    tldr

    (writeShellApplication {
      name = "macos-privacy-check";
      text = builtins.readFile ../../scripts/macos-privacy-check.sh;
    })
  ];
}
