import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cache_refresh.dart';
import 'log.dart';
import 'test_environment.dart' if (dart.library.io) 'test_environment_io.dart';
import 'web_asset_refresh.dart'
    if (dart.library.js_interop) 'web_asset_refresh_web.dart'
    as web;

/// Flutter plugin entry point for native platforms.
///
/// The Flutter tool invokes [registerWith] when the app starts. In debug mode
/// this installs a binding that clears asset caches on hot reload.
class HotReloadAssetRefreshPlugin {
  /// Registers the asset refresh behavior.
  ///
  /// Called automatically by the Flutter tool; apps do not call this directly.
  static void registerWith() {
    assetLog(
      'registerWith: kDebugMode=$kDebugMode isFlutterTest=$isFlutterTest '
      'isIntegrationTest=$_isIntegrationTest '
      'bindingAlreadyInitialized=$_bindingAlreadyInitialized '
      'bindingType=${_currentBindingType()}',
    );
    if (!kDebugMode) {
      assetLog('registerWith: skip (not debug)');
      return;
    }
    if (isFlutterTest || _isIntegrationTest) {
      assetLog('registerWith: skip (test environment)');
      return;
    }
    if (_bindingAlreadyInitialized) {
      assetLog(
        'registerWith: skip (binding already initialized: '
        '${_currentBindingType()})',
      );
      return;
    }

    _AssetRefreshBinding();
    assetLog(
      'registerWith: installed _AssetRefreshBinding '
      'bindingType=${_currentBindingType()}',
    );
  }

  static String _currentBindingType() {
    try {
      return WidgetsBinding.instance.runtimeType.toString();
    } on FlutterError {
      return '<uninitialized>';
    }
  }

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
  final Set<String> _changedAssets = <String>{};

  @override
  void evict(String asset) {
    assetLog('evict: $asset (pending=${_changedAssets.length + 1})');
    super.evict(asset);
    _changedAssets.add(asset);
  }

  @override
  Future<void> performReassemble() async {
    final Stopwatch sw = Stopwatch()..start();
    final List<String> changed = _changedAssets.toList(growable: false);
    _changedAssets.clear();
    assetLog(
      'performReassemble: begin evictedAssets=${changed.length} '
      'assets=$changed',
    );

    if (changed.isNotEmpty) {
      // The web engine reads asset bytes with `fetch()`, so the browser HTTP
      // cache can still hold the old file. Refresh those entries before the
      // tree reassembles and asks for the assets again.
      assetLog('performReassemble: refreshing ${changed.length} web assets');
      try {
        await web.refreshChangedAssetsOnWeb(changed);
        assetLog(
          'performReassemble: web refresh done in ${sw.elapsedMilliseconds}ms',
        );
      } catch (e, st) {
        assetLog('performReassemble: web refresh error: $e\n$st');
      }
    }

    // Clear on every hot reload so stale entries are not served when the tool
    // did not call [evict] for a changed file.
    clearAssetCaches();

    await super.performReassemble();
    sw.stop();
    assetLog('performReassemble: complete in ${sw.elapsedMilliseconds}ms');
  }
}
