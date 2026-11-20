import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cache_refresh.dart';
import 'test_environment.dart'
    if (dart.library.io) 'test_environment_io.dart';

/// Entry point that the Flutter tool registers automatically when this package
/// is a dependency.
///
/// Nothing in the app has to import or call this; the generated Dart plugin
/// registrant invokes [registerWith] at startup. In debug builds it installs an
/// [WidgetsFlutterBinding] subclass that clears the asset caches when the tool
/// reports changed assets during a hot reload.
///
/// Activation is disabled in release builds, under `flutter test`, and for
/// `flutter test integration_test`. To disable it as well for an app with a
/// custom binding, run with `--dart-define=HOT_RELOAD_ASSET_REFRESH=false`.
class HotReloadAssetRefreshPlugin {
  /// Registers the asset refresh behavior. Called by the Flutter tool.
  static void registerWith() {
    if (!kDebugMode) {
      return;
    }
    if (isFlutterTest || _isIntegrationTest) {
      return;
    }
    if (!_enabled) {
      return;
    }
    if (_bindingAlreadyInitialized) {
      return;
    }
    _AssetRefreshBinding();
  }

  static const bool _enabled = bool.fromEnvironment(
    'HOT_RELOAD_ASSET_REFRESH',
    defaultValue: true,
  );

  // `flutter test integration_test` sets this define so results are collected
  // by the tool instead of the native test framework. Create no binding in that
  // case: the integration test binding must be the only one.
  static const bool _isIntegrationTest =
      bool.fromEnvironment(
        'INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE',
        defaultValue: true,
      ) ==
      false;

  static bool get _bindingAlreadyInitialized {
    try {
      WidgetsBinding.instance;
      return true;
    } on FlutterError {
      return false;
    }
  }
}

class _AssetRefreshBinding extends WidgetsFlutterBinding {
  bool _assetChanged = false;

  @override
  void evict(String asset) {
    super.evict(asset);
    _assetChanged = true;
  }

  @override
  Future<void> performReassemble() {
    if (_assetChanged) {
      _assetChanged = false;
      clearAssetCaches();
    }
    return super.performReassemble();
  }
}
