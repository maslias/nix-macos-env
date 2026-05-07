{
  description = "Declarative macOS setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, ... }:
  let
    # Change these two values for each machine.
    username = "new-user";
    hostname = "new-hostname";
  in
  {
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs self username hostname;
      };

      modules = [
        ./hosts
      ];
    };

    # Convenience: `nix build .#darwinPackages.<package>`
    darwinPackages = self.darwinConfigurations.${hostname}.pkgs;
  };
}
