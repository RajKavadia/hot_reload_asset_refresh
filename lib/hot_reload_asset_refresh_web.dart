import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/auto_binding.dart';
import 'src/log.dart';

/// Web entry point that the Flutter tool registers automatically when this
/// package is a dependency.
///
/// The generated web plugin registrant runs this before the app's `main`.
class HotReloadAssetRefreshWebPlugin {
  /// Registers the asset refresh behavior on the web.
  ///
  /// The [registrar] is provided by Flutter; it is unused because registration
  /// is handled through [HotReloadAssetRefreshPlugin].
  static void registerWith(Registrar registrar) {
    assetLog('HotReloadAssetRefreshWebPlugin.registerWith called');
    HotReloadAssetRefreshPlugin.registerWith();
  }
}
