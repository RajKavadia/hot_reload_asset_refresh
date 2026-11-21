import 'package:flutter/widgets.dart';

import 'cache_refresh.dart';
import 'log.dart';

/// Refreshes cached assets when Flutter hot reloads the app.
///
/// You normally do not need this widget: adding this package as a dependency is
/// enough, because its Dart plugin registers itself at startup and installs a
/// binding that clears the caches. Use this widget only when you want the
/// refresh to be scoped to a subtree, or when you disabled automatic
/// registration (for example because the app has a custom binding).
///
/// Hot reload already resyncs changed asset files and rebuilds the widget tree,
/// but Flutter keeps decoded images in [ImageCache] and decoded strings and
/// structured data in [rootBundle]. Those caches can keep serving the old
/// content. During reassembly this widget empties both caches, before
/// descendant [Image] widgets resolve their providers again.
///
/// Limitations:
/// * This widget only clears Flutter's caches. Whether a new or removed asset
///   reaches the running app is decided by the Flutter tool's asset bundle
///   rebuild. Declare asset directories (for example `assets/`) rather than
///   individual files so new files are picked up; removals need a bundle
///   rebuild (save `pubspec.yaml`) or a restart of `flutter run`. The
///   `watch_assets` script automates that. See the README for details.
/// * Fonts are loaded by the engine and are not reloaded.
/// * Assets loaded through something other than [rootBundle] (for example a
///   custom [AssetBundle] from [DefaultAssetBundle]) and images served from the
///   browser's HTTP cache on the web may still be stale.
class AssetRefresh extends StatefulWidget {
  /// Creates a widget that refreshes the asset caches on hot reload.
  const AssetRefresh({super.key, required this.child});

  /// The widget below this widget in the tree.
  final Widget child;

  /// Empties the image cache and the [rootBundle] cache.
  ///
  /// This is called automatically on hot reload. Call it manually when assets
  /// are reloaded through another mechanism.
  static void refresh() => clearAssetCaches();

  @override
  State<AssetRefresh> createState() => _AssetRefreshState();
}

class _AssetRefreshState extends State<AssetRefresh> {
  @override
  void reassemble() {
    assetLog('AssetRefresh widget reassemble');
    // The framework calls this before reassembling descendants, so images are
    // re-resolved against the emptied cache instead of reusing stale entries.
    AssetRefresh.refresh();
    super.reassemble();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
