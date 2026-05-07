{
  # Clear security wins without changing Gatekeeper policy.
  # Gatekeeper is intentionally not configured here; it should be a team decision.

  networking.applicationFirewall = {
    enable = true;
    blockAllIncoming = false;
    enableStealthMode = true;
  };

  system.defaults.CustomUserPreferences = {
    # Reduce Apple advertising personalization.
    "com.apple.AdLib" = {
      allowApplePersonalizedAdvertising = false;
      allowIdentifierForAdvertising = false;
      forceLimitAdTracking = true;
    };

    # Reduce diagnostics / analytics sharing.
    "com.apple.SubmitDiagInfo" = {
      AutoSubmit = false;
      AutoSubmitVersion = 4;
      ThirdPartyDataSubmit = false;
      ThirdPartyDataSubmitVersion = 4;
    };

    # Disable Wi-Fi prompts for unknown networks and hotspots.
    "com.apple.airport.preferences" = {
      AskToJoinMode = "DoNotAsk";
      AskToJoinHotspot = false;
    };

    # Disable Handoff between this Mac and other Apple devices.
    "com.apple.coreservices.useractivityd" = {
      ActivityAdvertisingAllowed = false;
      ActivityReceivingAllowed = false;
    };

    # Disable Siri and Apple search improvement sharing where scriptable.
    "com.apple.assistant.support" = {
      "Assistant Enabled" = false;
      "Search Queries Data Sharing Status" = 2;
      "Siri Data Sharing Opt-In Status" = 2;
    };

    "com.apple.Siri" = {
      StatusMenuVisible = false;
      UserHasDeclinedEnable = true;
    };

    # Disable Spotlight suggestion/improvement sharing. Do not disable local indexing here.
    "com.apple.Spotlight" = {
      SuggestionsEnabled = false;
    };

    # Reduce notification exposure in sensitive contexts where these defaults apply.
    "com.apple.ncprefs" = {
      content_visibility = 0;
      show_on_lock_screen = false;
      show_in_carplay = false;
      summaries_enabled = false;
    };

    # Best-effort opt-out for Apple Intelligence feature enrollment where present.
    "com.apple.CloudSubscriptionFeatures.optIn" = {
      "545129924" = false;
    };
  };
}
