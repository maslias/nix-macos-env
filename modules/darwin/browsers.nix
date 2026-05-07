{ lib, pkgs, username, ... }:

let
  # Chrome enterprise policies are visible at chrome://policy.
  chromePolicies = {
    # Keep Google account, sync, telemetry, prediction, and ad features quiet.
    BrowserSignin = 0;
    SyncDisabled = true;
    MetricsReportingEnabled = false;
    UrlKeyedAnonymizedDataCollectionEnabled = false;
    SafeBrowsingExtendedReportingEnabled = false;
    SearchSuggestEnabled = false;
    AlternateErrorPagesEnabled = false;
    NetworkPredictionOptions = 2;
    DnsOverHttpsMode = "secure";
    DnsOverHttpsTemplates = "https://dns.quad9.net/dns-query";
    PrivacySandboxAdTopicsEnabled = false;
    PrivacySandboxSiteEnabledAdsEnabled = false;
    PrivacySandboxAdMeasurementEnabled = false;
    PrivacySandboxPromptEnabled = false;
    GenAiDefaultSettings = 2;

    # Safer defaults for site permissions and local-device APIs.
    DefaultGeolocationSetting = 2;
    DefaultNotificationsSetting = 2;
    DefaultSensorsSetting = 2;
    DefaultWebBluetoothGuardSetting = 2;
    DefaultWebUsbGuardSetting = 2;
    DefaultSerialGuardSetting = 2;
    DefaultFileSystemReadGuardSetting = 2;
    DefaultFileSystemWriteGuardSetting = 2;
    AudioCaptureAllowed = false;
    VideoCaptureAllowed = false;
    ScreenCaptureAllowed = false;

    # Web/privacy hardening.
    BlockThirdPartyCookies = true;
    HttpsOnlyMode = "force_enabled";
    DefaultJavaScriptJitSetting = 2;
    WebRtcIPHandling = "disable_non_proxied_udp";
    EnableMediaRouter = false;
    BackgroundModeEnabled = false;

    # Prefer external, dedicated managers for secrets/payment data.
    PasswordManagerEnabled = false;
    PasswordLeakDetectionEnabled = false;
    AutofillAddressEnabled = false;
    AutofillCreditCardEnabled = false;
    PaymentMethodQueryEnabled = false;
  };

  chromePolicyJson = pkgs.writeText "com.google.Chrome.policy.json" (builtins.toJSON chromePolicies);
in
{
  # macOS Chrome reads managed browser policies from Managed Preferences.
  system.activationScripts.chromePolicies.text = ''
    policy_dir="/Library/Managed Preferences/${username}"
    policy_file="$policy_dir/com.google.Chrome.plist"

    install -d -m 0755 "$policy_dir"
    /usr/bin/plutil -convert xml1 -o "$policy_file" ${chromePolicyJson}
    chown root:wheel "$policy_file"
    chmod 0644 "$policy_file"
  '';
}
