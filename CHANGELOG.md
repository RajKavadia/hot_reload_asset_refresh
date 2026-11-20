## 0.0.1

* Auto-activate with no app code changes: the package is a Flutter plugin that
  installs a `WidgetsFlutterBinding` subclass in debug builds and clears the
  image and asset bundle caches when the tool reports changed assets. Supports
  Android, iOS, Linux, macOS, Windows, and web.
* Add `AssetRefresh`, an optional widget for explicit, subtree-scoped refreshes.
* Add a `watch_assets` development script that touches `pubspec.yaml` when files
  are added or removed, so the next hot reload rebuilds the asset bundle.
