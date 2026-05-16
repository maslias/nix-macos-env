{
  description = "Declarative macOS setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, home-manager, ... }:
  let
    # Change these two values for each machine.
    username = "mliebreich";
    hostname = "gdca-maintaince";
  in
  {
    darwinConfigurations.${hostname} = nix-darwin.lib.darwinSystem {
      specialArgs = {
        inherit inputs self username hostname;
      };

      modules = [
        ./hosts
        home-manager.darwinModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs self username hostname;
          };
          home-manager.users.${username} = import ./home;
        }
        {
          # Host-specific opt-in: gdca-maintaince has enrolled, hardened, and
          # tested primary and backup YubiKeys for sudo MFA. Do not enable this
          # globally for new machines until their own keys and recovery path are
          # validated.
          gdca.yubikey.sudoMfa.enable = true;
          # Daily sudo still requires a registered YubiKey touch plus the normal
          # sudo authentication stack, but does not require the FIDO2 PIN.
          gdca.yubikey.sudoMfa.pinVerification = false;

          # Host-specific smart-card-only login enforcement. This removes normal
          # password-only login/unlock fallback after activation; FileVault still
          # remains password/recovery-key based. The YubiKey module refuses to
          # apply this unless the console user has at least two sc_auth pairings.
          gdca.yubikey.smartCardOnly.enable = true;
          gdca.yubikey.smartCardOnly.minimumPairings = 2;
        }
      ];
    };

    # Convenience: `nix build .#darwinPackages.<package>`
    darwinPackages = self.darwinConfigurations.${hostname}.pkgs;
  };
}
