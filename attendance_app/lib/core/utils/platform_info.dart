import 'package:flutter/foundation.dart';

/// Where the app is running, for the few features that depend on it.
class PlatformInfo {
  const PlatformInfo._();

  /// The device has real GPS for punching: the phone apps and phone browsers.
  /// Desktop and laptop browsers get their location from Wi-Fi or IP, which
  /// is rarely inside the 100 m accuracy a punch needs.
  static bool get canPunch =>
      !kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// A browser (where fake-GPS apps can't be detected, unlike the phone app).
  static bool get isBrowser => kIsWeb;
}
