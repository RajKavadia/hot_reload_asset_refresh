import 'package:flutter/foundation.dart';

const String _logPrefix = '[hot_reload_asset_refresh]';

/// Enables fingerprint and header diagnostics (for example on web).
///
/// Pass at run time:
/// `flutter run --dart-define=HOT_RELOAD_ASSET_REFRESH_VERBOSE=true`
const bool assetRefreshVerboseLogging = bool.fromEnvironment(
  'HOT_RELOAD_ASSET_REFRESH_VERBOSE',
);

/// Prints a debug log line for the package.
///
/// Always enabled in debug/profile builds so the user can diagnose hot-reload
/// issues from the console. No-op in release.
void assetLog(String message) {
  if (kDebugMode) {
    debugPrint('$_logPrefix $message');
  }
}

/// Prints detailed diagnostics when [assetRefreshVerboseLogging] is true.
void assetLogVerbose(String message) {
  if (kDebugMode && assetRefreshVerboseLogging) {
    debugPrint('$_logPrefix $message');
  }
}
