import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cache_refresh.dart';
import 'log.dart';
import 'test_environment.dart' if (dart.library.io) 'test_environment_io.dart';
import 'web_asset_refresh.dart'
    if (dart.library.js_interop) 'web_asset_refresh_web.dart'
    as web;

/// Flutter plugin entry point.
///
/// The Flutter tool invokes [registerWith] before the app's `main`. On web that
/// is early enough to install [AssetRefreshBinding]; on native platforms it is
/// not, so [registerWith] only logs a hint and the app installs the binding
/// itself with [AssetRefreshBinding.ensureInitialized].
class HotReloadAssetRefreshPlugin {
  /// Registers the asset refresh behavior.
  ///
  /// Called automatically by the Flutter tool; apps do not call this directly.
  static void registerWith() {
    if (!kIsWeb) {
      // The plugin registrant runs before `main()`, when
      // `platformDispatcher.initialLifecycleState` is still unset. Building any
      // `BindingBase` there throws `LateInitializationError` *after*
      // `BindingBase._debugInitializedType` has been assigned, which leaves the
      // isolate half-initialized: `_debugInitializedType != null` but
      // `WidgetsBinding._instance == null`. The next `runApp()` then fails with
      // "Binding is already initialized to ..." and the app never starts.
      // There is no public way to reset that state, so never create a binding
      // from this callback.
      assetLog(
        'registerWith: no-op on native platforms. Call '
        'AssetRefreshBinding.ensureInitialized() first in main().',
      );
      return;
    }

    if (!kDebugMode) {
      assetLog('registerWith: skip (not debug)');
      return;
    }
    if (isFlutterTest || _isIntegrationTest) {
      assetLog('registerWith: skip (test environment)');
      return;
    }
    if (BindingBase.debugBindingType() != null) {
      assetLog(
        'registerWith: skip (binding already initialized: '
        '${BindingBase.debugBindingType()})',
      );
      return;
    }

    AssetRefreshBinding();
    assetLog(
      'registerWith: installed AssetRefreshBinding '
      'bindingType=${BindingBase.debugBindingType()}',
    );
  }
}

// `flutter test integration_test` sets this define so results are collected
// by the tool instead of the native test framework. Create no binding in that
// case: the integration test binding must be the only one.
const bool _isIntegrationTest =
    bool.fromEnvironment(
      'INTEGRATION_TEST_SHOULD_REPORT_RESULTS_TO_NATIVE',
      defaultValue: true,
    ) ==
    false;

/// A [WidgetsFlutterBinding] that clears the asset caches on every hot reload.
///
/// Install it as the first statement of `main()`:
///
/// ```dart
/// void main() {
///   AssetRefreshBinding.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
///
/// On web the package's plugin registrant installs this binding before `main`,
/// so calling [ensureInitialized] there is a no-op.
class AssetRefreshBinding extends WidgetsFlutterBinding {
  /// Installs [AssetRefreshBinding] as the app's binding, or returns the
  /// binding that is already installed.
  ///
  /// Must run before any other binding is created. Calling it later is safe but
  /// leaves the app with its original binding, so asset caches are only
  /// refreshed when the subtree is wrapped with `AssetRefresh`.
  static WidgetsBinding ensureInitialized() {
    if (!kDebugMode || isFlutterTest || _isIntegrationTest) {
      // Release, profile, and test runs keep the default binding.
      return WidgetsFlutterBinding.ensureInitialized();
    }

    if (BindingBase.debugBindingType() == null) {
      assetLog('ensureInitialized: installing AssetRefreshBinding');
      return AssetRefreshBinding();
    }

    final WidgetsBinding binding = WidgetsBinding.instance;
    if (binding is AssetRefreshBinding) {
      assetLog('ensureInitialized: AssetRefreshBinding already installed');
      return binding;
    }

    assetLog(
      'ensureInitialized: a different binding '
      '(${BindingBase.debugBindingType()}) is already installed, so automatic '
      'asset refresh is inactive. Call AssetRefreshBinding.ensureInitialized() '
      'before any other binding is created, or wrap the app with AssetRefresh.',
    );
    return binding;
  }

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
