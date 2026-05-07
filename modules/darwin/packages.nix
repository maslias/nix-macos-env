{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "macos-privacy-check";
      text = builtins.readFile ../../scripts/macos-privacy-check.sh;
    })
  ];
}
