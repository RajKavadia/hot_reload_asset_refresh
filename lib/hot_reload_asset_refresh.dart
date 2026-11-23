/// Refreshes changed assets on Flutter hot reload.
///
/// On web, adding this package as a dependency is enough: its web plugin
/// registers itself at startup and clears the asset caches when the Flutter
/// tool reports changed assets.
///
/// On Android, iOS, Linux, macOS, and Windows the app installs the binding
/// itself, as the first statement of `main()`:
///
/// ```dart
/// void main() {
///   AssetRefreshBinding.ensureInitialized();
///   runApp(const MyApp());
/// }
/// ```
///
/// [AssetRefresh] is also available for explicit, subtree-scoped refreshes.
library;

export 'src/asset_refresh.dart';
export 'src/auto_binding.dart' show AssetRefreshBinding;
export 'src/cache_refresh.dart' show clearAssetCaches;
