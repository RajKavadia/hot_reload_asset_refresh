import 'package:flutter/foundation.dart';

const String _logPrefix = '[hot_reload_asset_refresh]';

/// Prints a debug log line for the package.
///
/// Always enabled in debug/profile builds so the user can diagnose hot-reload
/// issues from the console. No-op in release.
void assetLog(String message) {
  if (kDebugMode) {
    debugPrint('$_logPrefix $message');
  }
}
