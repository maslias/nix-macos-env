# YubiKey smart-card-only macOS login

This repo includes a disabled opt-in for macOS smart-card-only login.

Default module state: **disabled**. The `gdca-maintaince` host is configured to enable this policy because primary and backup YubiKey PIV unlock were validated.

## What it changes

When enabled, macOS `enforceSmartCard` policy requires smart-card authentication for login/unlock for affected paired users. In practice this removes ordinary password-only fallback for those login/unlock flows.

Current safe setup remains:

- YubiKey PIV PIN unlock works
- macOS password fallback works
- sudo MFA works separately through pam_u2f
- FileVault remains password/recovery-key based

Smart-card-only enforcement changes that login posture to:

- paired YubiKey/smart card required for macOS login/unlock
- password-only login/unlock fallback no longer available for affected accounts
- FileVault pre-boot unlock still not provided by this repo

## Nix option

The option should remain disabled until tested with a recovery path. On validated hosts it can be enabled explicitly:

```nix
gdca.yubikey.smartCardOnly.enable = true;
```

The module requires at least two local `sc_auth` pairings by default before it will apply the policy:

```nix
gdca.yubikey.smartCardOnly.minimumPairings = 2;
```

This guard is not a complete safety proof. It only prevents enabling the policy when the local pairing count is obviously too low.

## Status check

Report current policy and pairing state:

```sh
yubikey-smartcard-policy-status --require-pairings 2
```

This command is read-only. It does not change login policy, FileVault, PAM, or YubiKeys.

## Required validation before enabling

Before enabling smart-card-only login on any host:

1. Confirm primary YubiKey unlock works with PIV PIN.
2. Confirm backup YubiKey unlock works with PIV PIN.
3. Confirm `sc_auth list -u "$USER"` shows both pairings.
4. Confirm another admin/recovery path is available.
5. Confirm FileVault recovery key is escrowed outside this Mac.
6. Keep an administrator shell open during the first rebuild and test.
7. Do not enable this remotely or unattended.

## Recovery / rollback

If smart-card-only login causes problems, use an already-open administrator shell or boot/authenticate using a known recovery/admin path and remove the policy:

```sh
yubikey-smartcard-policy-disable
```

Equivalent manual command:

```sh
sudo defaults delete /Library/Preferences/com.apple.security.smartcard enforceSmartCard
```

Then rebuild with:

```nix
gdca.yubikey.smartCardOnly.enable = false;
```

Depending on macOS state, a reboot may be required after changing the policy.

## Important limitations

- This does not implement FileVault YubiKey pre-boot unlock.
- This does not change sudo MFA behavior.
- This does not replace the need for recovery-key escrow.
- Anything written to the YubiKey itself follows the physical key; macOS pairing and enforcement remain per macOS installation.
