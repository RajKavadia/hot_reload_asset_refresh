## 0.2.0

* **Breaking (native only):** install the binding yourself with
  `AssetRefreshBinding.ensureInitialized()` as the first statement of `main()`.
  The plugin registrant runs before `main()`, when
  `PlatformDispatcher.initialLifecycleState` is not yet available; constructing
  a `BindingBase` there threw `LateInitializationError` after
  `_debugInitializedType` was assigned, leaving the isolate half-initialized so
  that `runApp()` failed with `Binding is already initialized to
  _AssetRefreshBinding`. The registrant now only logs a hint on native
  platforms.
* Web is unchanged: the web plugin still installs the binding before `main`.
* `AssetRefreshBinding` is now public and `ensureInitialized()` is idempotent;
  it keeps an already-installed binding instead of replacing it, and keeps the
  default binding in release builds and under `flutter test` /
  `flutter test integration_test`.
* Registration guards now check `BindingBase.debugBindingType()` instead of
  probing `WidgetsBinding.instance`, so a half-initialized binding is no longer
  reported as "not initialized".

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