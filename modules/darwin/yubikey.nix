{ config, lib, pkgs, ... }:

let
  cfg = config.gdca.yubikey;
  pamU2fLine = ''
    auth       required       ${pkgs.pam_u2f}/lib/security/pam_u2f.so authfile=.config/Yubico/u2f_keys openasuser cue pinverification=1 userverification=0
  '';
in
{
  options.gdca.yubikey = {
    sudoMfa.enable = lib.mkEnableOption "YubiKey pam_u2f MFA for sudo";
  };

  config = {
    environment.systemPackages = with pkgs; [
      # YubiKey/FIDO/PIV tooling. Enrollment remains imperative because each
      # user's key material, PINs, certificates, and macOS account state differ.
      yubikey-manager # ykman
      yubico-piv-tool
      opensc
      libfido2 # fido2-token
      pam_u2f # pam_u2f.so and pamu2fcfg
      gnupg
      pinentry_mac

      (writeShellApplication {
        name = "yubikey-check";
        text = builtins.readFile ../../scripts/yubikey-check.sh;
      })

      (writeShellApplication {
        name = "yubikey-enroll";
        text = builtins.readFile ../../scripts/yubikey-enroll.sh;
      })

      (writeShellApplication {
        name = "yubikey-harden";
        text = builtins.readFile ../../scripts/yubikey-harden.sh;
      })

      (writeShellApplication {
        name = "yubikey-status";
        text = builtins.readFile ../../scripts/yubikey-status.sh;
      })

      (writeShellApplication {
        name = "yubikey-sudo-register";
        text = builtins.readFile ../../scripts/yubikey-sudo-register.sh;
      })

      (writeShellApplication {
        name = "yubikey-sudo-test";
        text = builtins.readFile ../../scripts/yubikey-sudo-test.sh;
      })

      (writeShellApplication {
        name = "yubikey-piv-login-setup";
        text = builtins.readFile ../../scripts/yubikey-piv-login-setup.sh;
      })

      (writeShellApplication {
        name = "yubikey-piv-login-status";
        text = builtins.readFile ../../scripts/yubikey-piv-login-status.sh;
      })

      (writeShellApplication {
        name = "yubikey-policy-check";
        text = builtins.readFile ../../scripts/yubikey-policy-check.sh;
      })
    ];

    # Disabled by default. When enabled, sudo requires a registered YubiKey via
    # pam_u2f before the normal sudo authentication stack continues. Keep this
    # opt-in until every user has a hardened primary and backup key plus a tested
    # recovery path.
    security.pam.services.sudo_local.text = lib.mkIf cfg.sudoMfa.enable (lib.mkBefore pamU2fLine);
  };
}
