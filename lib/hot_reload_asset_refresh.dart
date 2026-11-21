/// Refreshes changed assets on Flutter hot reload.
///
/// Adding this package as a dependency is enough: its Dart plugin registers
/// itself at startup and clears the asset caches when the Flutter tool reports
/// changed assets. No widget wrapping and no changes to the app's source are
/// required.
///
/// [AssetRefresh] is also available for explicit, subtree-scoped refreshes.
library;

export 'src/asset_refresh.dart';
export 'src/cache_refresh.dart' show clearAssetCaches;
