{ config, lib, pkgs, ... }:

let
  cfg = config.gdca.yubikey;
  minSmartCardPairings = toString cfg.smartCardOnly.minimumPairings;
  pamU2fLine = ''
    auth       required       ${pkgs.pam_u2f}/lib/security/pam_u2f.so authfile=.config/Yubico/u2f_keys openasuser cue pinverification=1 userverification=0
  '';
in
{
  options.gdca.yubikey = {
    sudoMfa.enable = lib.mkEnableOption "YubiKey pam_u2f MFA for sudo";

    smartCardOnly = {
      enable = lib.mkEnableOption "macOS smart-card-only login policy using paired PIV identities";
      minimumPairings = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Minimum sc_auth pairings required before enabling smart-card-only login.";
      };
    };
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

      (writeShellApplication {
        name = "yubikey-smartcard-policy-status";
        text = builtins.readFile ../../scripts/yubikey-smartcard-policy-status.sh;
      })
    ];

    # Disabled by default. When enabled, sudo requires a registered YubiKey via
    # pam_u2f before the normal sudo authentication stack continues. Keep this
    # opt-in until every user has a hardened primary and backup key plus a tested
    # recovery path.
    security.pam.services.sudo_local.text = lib.mkIf cfg.sudoMfa.enable (lib.mkBefore pamU2fLine);

    # Dangerous and disabled by default. When enabled, macOS requires a paired
    # smart card for login/unlock and removes ordinary password-only fallback for
    # affected accounts. The activation guard refuses to apply unless enough
    # local smart-card pairings already exist for the console user.
    system.activationScripts.yubikeySmartCardOnly.text = lib.mkIf cfg.smartCardOnly.enable ''
      console_user="$(/usr/bin/stat -f %Su /dev/console 2>/dev/null || true)"
      if [ -z "$console_user" ] || [ "$console_user" = "root" ] || [ "$console_user" = "loginwindow" ]; then
        echo "error: cannot determine a logged-in console user for smart-card-only enforcement" >&2
        exit 1
      fi

      pairing_count="$(/usr/bin/sc_auth list -u "$console_user" 2>/dev/null | /usr/bin/awk 'NF { count++ } END { print count + 0 }')"
      if [ "$pairing_count" -lt ${minSmartCardPairings} ]; then
        echo "error: refusing to enable smart-card-only login for $console_user" >&2
        echo "error: found $pairing_count sc_auth pairing(s), require at least ${minSmartCardPairings}" >&2
        exit 1
      fi

      echo "Enabling macOS smart-card-only login policy for paired users"
      /usr/bin/defaults write /Library/Preferences/com.apple.security.smartcard enforceSmartCard -bool true
      /bin/chmod 0644 /Library/Preferences/com.apple.security.smartcard.plist
    '';
  };
}
