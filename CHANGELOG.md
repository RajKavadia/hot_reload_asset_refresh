## 0.1.0

* Clear `ImageCache` and `rootBundle` on every debug hot reload reassemble, not
  only when the tool calls `evict`, so stale caches are less likely when the
  tool omits eviction.
* Add `watch_assets` options: `--pubspec`, `--dry-run`, and `--verbose`; longer
  debounce when many files change at once.
* Add verbose logging via
  `--dart-define=HOT_RELOAD_ASSET_REFRESH_VERBOSE=true` (web fetch diagnostics).
* Fix corrupted `homepage` field in `pubspec.yaml`.
* Polish the example app (directory-based assets, focused hot-reload demo).

## 0.0.1

* Auto-activate with no app code changes: the package is a Flutter plugin that
  installs a `WidgetsFlutterBinding` subclass in debug builds and clears the
  image and asset bundle caches when the tool reports changed assets. Supports
  Android, iOS, Linux, macOS, Windows, and web.
* Add `AssetRefresh`, an optional widget for explicit, subtree-scoped refreshes.
* Add a `watch_assets` development script that touches `pubspec.yaml` when files
  are added or removed, so the next hot reload rebuilds the asset bundle.