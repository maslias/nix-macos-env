{ hostname, ... }:

{
  imports = [
    ../modules/darwin/nix.nix
    ../modules/darwin/packages.nix
    ../modules/darwin/macos-defaults.nix
    ../modules/darwin/security.nix
    ../modules/darwin/raycast.nix
    ../modules/darwin/alacritty.nix
    ../modules/darwin/zsh.nix
    ../modules/darwin/vim.nix
    ../modules/darwin/system.nix
    ../users
  ];

  networking.hostName = hostname;
  networking.computerName = hostname;
  system.defaults.smb.NetBIOSName = hostname;

  # Apple Silicon Macs: aarch64-darwin
  # Intel Macs:         x86_64-darwin
  nixpkgs.hostPlatform = "aarch64-darwin";
}
