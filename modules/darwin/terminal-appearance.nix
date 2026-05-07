{ lib, pkgs, username, ... }:

let
  # Shared terminal appearance: Cyberdream dark palette with JetBrainsMono Nerd Font.
  terminalProfileName = "Cyberdream";
  terminalFontSize = "14.0";
in
{
  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  # Terminal.app does not have first-class nix-darwin profile options. Install a
  # per-user profile with the same Cyberdream palette used by Alacritty.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/sudo -u ${username} /usr/bin/osascript -l JavaScript <<'JXA' || true
    ObjC.import('Cocoa');

    function ns(value) {
      return $.NSString.alloc.initWithUTF8String(String(value));
    }

    function archivedColor(hex) {
      const r = parseInt(hex.slice(0, 2), 16) / 255;
      const g = parseInt(hex.slice(2, 4), 16) / 255;
      const b = parseInt(hex.slice(4, 6), 16) / 255;
      const color = $.NSColor.colorWithSRGBRedGreenBlueAlpha(r, g, b, 1.0);
      return $.NSKeyedArchiver.archivedDataWithRootObject(color);
    }

    function archivedFont(size) {
      const candidates = [
        'JetBrainsMonoNerdFontMono-Regular',
        'JetBrainsMonoNLNerdFontMono-Regular',
        'JetBrainsMono Nerd Font Mono',
        'JetBrains Mono Regular',
        'Menlo-Regular'
      ];

      for (let i = 0; i < candidates.length; i++) {
        const font = $.NSFont.fontWithNameSize(candidates[i], size);
        if (ObjC.unwrap(font)) {
          return $.NSKeyedArchiver.archivedDataWithRootObject(font);
        }
      }

      return $.NSKeyedArchiver.archivedDataWithRootObject(
        $.NSFont.monospacedSystemFontOfSizeWeight(size, 0.0)
      );
    }

    const profileName = '${terminalProfileName}';
    const defaults = $.NSUserDefaults.alloc.initWithSuiteName('com.apple.Terminal');
    const existing = defaults.dictionaryForKey('Window Settings');
    const windowSettings = ObjC.unwrap(existing) ? existing.mutableCopy : $.NSMutableDictionary.dictionary;
    const profile = $.NSMutableDictionary.dictionary;

    profile.setObjectForKey(ns(profileName), ns('name'));
    profile.setObjectForKey(ns('Window Settings'), ns('type'));
    profile.setObjectForKey(ns('2.09'), ns('ProfileCurrentVersion'));
    profile.setObjectForKey(archivedFont(${terminalFontSize}), ns('Font'));
    profile.setObjectForKey(true, ns('FontAntialias'));
    profile.setObjectForKey(1.0, ns('FontHeightSpacing'));
    profile.setObjectForKey(1.0, ns('FontWidthSpacing'));
    profile.setObjectForKey(120, ns('columnCount'));
    profile.setObjectForKey(32, ns('rowCount'));
    profile.setObjectForKey(true, ns('UseBrightBold'));
    profile.setObjectForKey(false, ns('DynamicANSIForegroundColors'));
    profile.setObjectForKey(0, ns('CursorType'));
    profile.setObjectForKey(true, ns('CursorBlink'));

    profile.setObjectForKey(archivedColor('16181a'), ns('BackgroundColor'));
    profile.setObjectForKey(archivedColor('ffffff'), ns('TextColor'));
    profile.setObjectForKey(archivedColor('ffffff'), ns('TextBoldColor'));
    profile.setObjectForKey(archivedColor('5ef1ff'), ns('CursorColor'));
    profile.setObjectForKey(archivedColor('3c4048'), ns('SelectionColor'));

    profile.setObjectForKey(archivedColor('16181a'), ns('ANSIBlackColor'));
    profile.setObjectForKey(archivedColor('ff6e5e'), ns('ANSIRedColor'));
    profile.setObjectForKey(archivedColor('5eff6c'), ns('ANSIGreenColor'));
    profile.setObjectForKey(archivedColor('f1ff5e'), ns('ANSIYellowColor'));
    profile.setObjectForKey(archivedColor('5ea1ff'), ns('ANSIBlueColor'));
    profile.setObjectForKey(archivedColor('bd5eff'), ns('ANSIMagentaColor'));
    profile.setObjectForKey(archivedColor('5ef1ff'), ns('ANSICyanColor'));
    profile.setObjectForKey(archivedColor('ffffff'), ns('ANSIWhiteColor'));
    profile.setObjectForKey(archivedColor('3c4048'), ns('ANSIBrightBlackColor'));
    profile.setObjectForKey(archivedColor('ff6e5e'), ns('ANSIBrightRedColor'));
    profile.setObjectForKey(archivedColor('5eff6c'), ns('ANSIBrightGreenColor'));
    profile.setObjectForKey(archivedColor('f1ff5e'), ns('ANSIBrightYellowColor'));
    profile.setObjectForKey(archivedColor('5ea1ff'), ns('ANSIBrightBlueColor'));
    profile.setObjectForKey(archivedColor('bd5eff'), ns('ANSIBrightMagentaColor'));
    profile.setObjectForKey(archivedColor('5ef1ff'), ns('ANSIBrightCyanColor'));
    profile.setObjectForKey(archivedColor('ffffff'), ns('ANSIBrightWhiteColor'));

    windowSettings.setObjectForKey(profile, ns(profileName));
    defaults.setObjectForKey(windowSettings, ns('Window Settings'));
    defaults.setObjectForKey(ns(profileName), ns('Default Window Settings'));
    defaults.setObjectForKey(ns(profileName), ns('Startup Window Settings'));
    defaults.synchronize;
    JXA
  '';
}
