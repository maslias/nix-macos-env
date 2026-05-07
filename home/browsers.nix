{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    # Enterprise policies are visible at about:policies.
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableFirefoxAccounts = true;
      DisableFeedbackCommands = true;
      DisableProfileImport = true;
      DontCheckDefaultBrowser = true;
      SearchSuggestEnabled = false;
      HttpsOnlyMode = "force_enabled";
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://dns.quad9.net/dns-query";
        Fallback = false;
        Locked = true;
      };
      EnableTrackingProtection = {
        Category = "strict";
        Cryptomining = true;
        Fingerprinting = true;
        EmailTracking = true;
        SuspectedFingerprinting = true;
        Locked = true;
      };
      Cookies = {
        Behavior = "reject-tracker-and-partition-foreign";
        BehaviorPrivateBrowsing = "reject-tracker-and-partition-foreign";
        Locked = true;
      };
      FirefoxHome = {
        SponsoredTopSites = false;
        SponsoredPocket = false;
        SponsoredStories = false;
        Pocket = false;
        Stories = false;
        Snippets = false;
        Locked = true;
      };
      FirefoxSuggest = {
        WebSuggestions = false;
        SponsoredSuggestions = false;
        ImproveSuggest = false;
        Locked = true;
      };
      UserMessaging = {
        ExtensionRecommendations = false;
        FeatureRecommendations = false;
        UrlbarInterventions = false;
        SkipOnboarding = true;
        MoreFromMozilla = false;
        FirefoxLabs = false;
        Locked = true;
      };
      Permissions = {
        Location = { BlockNewRequests = true; Locked = true; };
        Notifications = { BlockNewRequests = true; Locked = true; };
        Camera = { BlockNewRequests = true; Locked = true; };
        Microphone = { BlockNewRequests = true; Locked = true; };
        Autoplay = { Default = "block-audio-video"; Locked = true; };
        VirtualReality = { BlockNewRequests = true; Locked = true; };
        ScreenShare = { BlockNewRequests = true; Locked = true; };
      };
    };

    profiles.default = {
      id = 0;
      isDefault = true;
      settings = {
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "browser.send_pings" = false;
        "beacon.enabled" = false;
        "network.predictor.enabled" = false;
        "network.dns.disablePrefetch" = true;
        "network.prefetch-next" = false;
        "browser.urlbar.speculativeConnect.enabled" = false;
        "media.peerconnection.ice.default_address_only" = true;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "toolkit.telemetry.unified" = false;
        "datareporting.healthreport.uploadEnabled" = false;
      };
    };
  };

  programs.google-chrome = {
    enable = true;
    package = pkgs.google-chrome;
  };
}
