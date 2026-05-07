{ lib, username, ... }:

{
  # nix-darwin's first-class `power.sleep.*` options apply one global profile via
  # systemsetup. Use pmset directly here so AC power and battery can differ.
  system.activationScripts.powerProfiles.text = lib.mkAfter ''
    # AC power: keep the machine, display, and disk awake indefinitely.
    /usr/bin/pmset -c sleep 0 displaysleep 0 disksleep 0

    # Battery power: sleep/display-sleep after 15 minutes of idle time.
    /usr/bin/pmset -b sleep 15 displaysleep 15 disksleep 15 || true

    # Prefer macOS Low Power Mode on battery when supported; keep it off on AC.
    /usr/bin/pmset -b lowpowermode 1 || true
    /usr/bin/pmset -c lowpowermode 0 || true

    # macOS screensaver idle time is not exposed by nix-darwin as a per-power-source
    # option. Keep the screensaver disabled globally and rely on battery display
    # sleep above for the 15-minute battery behavior.
    /usr/bin/sudo -u ${username} /usr/bin/defaults -currentHost write com.apple.screensaver idleTime -int 0 || true
  '';
}
