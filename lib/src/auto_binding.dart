import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cache_refresh.dart';
import 'log.dart';
import 'test_environment.dart'
    if (dart.library.io) 'test_environment_io.dart';
import 'web_asset_refresh.dart'
    if (dart.library.js_interop) 'web_asset_refresh_web.dart' as web;

/// Entry point that the Flutter tool registers automatically when this package
/// is a dependency.
///
/// Nothing in the app has to import or call this; the generated Dart plugin
/// registrant invokes [registerWith] at startup. In debug builds it installs an
/// [WidgetsFlutterBinding] subclass that clears the asset caches when the tool
/// reports changed assets during a hot reload. On the web it also re-fetches
/// those assets so the browser's HTTP cache does not serve stale bytes.
///
/// Activation is disabled in release builds, under `flutter test`, and for
/// `flutter test integration_test`. To disable it as well for an app with a
/// custom binding, run with `--dart-define=HOT_RELOAD_ASSET_REFRESH=false`.
class HotReloadAssetRefreshPlugin {
  /// Registers the asset refresh behavior. Called by the Flutter tool.
  static void registerWith() {
    assetLog(
      'registerWith: kDebugMode=$kDebugMode isFlutterTest=$isFlutterTest '
      'isIntegrationTest=$_isIntegrationTest enabled=$_enabled '
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
    if (!_enabled) {
      assetLog('registerWith: skip (HOT_RELOAD_ASSET_REFRESH=false)');
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
    assetLog(
      'performReassemble: begin changedAssets=${_changedAssets.length} '
      'assets=${_changedAssets.toList()}',
    );
    if (_changedAssets.isNotEmpty) {
      final List<String> changed = _changedAssets.toList(growable: false);
      _changedAssets.clear();
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
      clearAssetCaches();
    } else {
      assetLog('performReassemble: no changed assets recorded');
    }
    await super.performReassemble();
    sw.stop();
    assetLog('performReassemble: complete in ${sw.elapsedMilliseconds}ms');
  }
}
