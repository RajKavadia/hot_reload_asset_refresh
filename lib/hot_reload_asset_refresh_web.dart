import 'package:flutter_web_plugins/flutter_web_plugins.dart';

import 'src/auto_binding.dart';

/// Web entry point that the Flutter tool registers automatically when this
/// package is a dependency.
///
/// The generated web plugin registrant runs this before the app's `main`.
class HotReloadAssetRefreshWebPlugin {
  /// Registers the asset refresh behavior.
  static void registerWith(Registrar registrar) {
    HotReloadAssetRefreshPlugin.registerWith();
  }
}
