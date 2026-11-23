# hot_reload_asset_refresh

Refreshes changed assets on Flutter hot reload. On web there is no app code
change: add the dependency and the web plugin registers itself. On native
platforms the app installs the binding with one line in `main()`.

Works on Android, iOS, Linux, macOS, Windows, and web. Debug hot reload only —
not for release builds or runtime asset updates.

## Getting started

Add the dependency and run `flutter pub get`:

```yaml
dependencies:
  hot_reload_asset_refresh: ^0.2.0
```

On **web** that is the whole setup: the generated web plugin registrant installs
the binding before `main`.

On **Android, iOS, Linux, macOS, and Windows** install the binding as the first
statement of `main()`:

```dart
import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';

void main() {
  AssetRefreshBinding.ensureInitialized();
  runApp(const MyApp());
}
```

It must run before any other binding is created (before
`WidgetsFlutterBinding.ensureInitialized()` and before `runApp`). In debug builds
the binding clears `ImageCache` and `rootBundle` before the widget tree
reassembles, so images and string assets are re-read from disk instead of stale
caches. When the Flutter tool reports specific changed assets, the binding also
records them for a web cache refresh (`fetch` with `cache: 'no-store'`).

> **Why can't the plugin install the binding itself on native platforms?** The
> Dart plugin registrant runs before `main()`, while the engine has not yet
> published `PlatformDispatcher.initialLifecycleState`. Constructing a
> `BindingBase` that early throws `LateInitializationError` halfway through
> initialization, after `BindingBase._debugInitializedType` was already
> assigned. The isolate is then left with a half-initialized binding and the
> app's `runApp()` fails with `Binding is already initialized to ...`. Web does
> not have that constraint, which is why auto-registration still works there.

Edit an image or other asset and save. The next hot reload picks it up on every
platform, including **Flutter web**.

Try the **example** app: `cd example && flutter run` (use `-d chrome` for web).

## Flutter web hot reload

On mobile and desktop, Flutter reads bundled assets from the dev file system.
Hot reload already notices when an **existing** file’s modification time changes,
so updated images and `rootBundle.loadString` results (for example
`assets/abc.json`) can be picked up after the caches are cleared.

Web is different. The engine loads asset bytes with the browser’s `fetch()` API,
and the HTTP cache can keep serving old bytes even after Flutter evicts its own
in-memory caches. A hot reload that only clears `ImageCache` and `rootBundle` is
often not enough: the widget tree reassembles, requests the asset again, and the
browser may still return stale data.

This package addresses that in debug builds on web:

1. **Every hot reload** — Before `performReassemble` runs descendants again, it
   clears `ImageCache` and `rootBundle` so widgets do not reuse decoded images or
   bundle entries from the previous generation.
2. **Changed assets the tool evicts** — When the Flutter tool reports specific
   assets (for example after you saved an edited file), the binding records them
   and, on web only, prefetches each URL through `ui_web.assetManager` with
   `fetch(..., { cache: 'no-store' })` so the browser does not answer from its
   HTTP cache. The next `Image.asset` or `rootBundle` read then sees fresh bytes.

Typical web workflow:

```sh
cd example
flutter run -d chrome
```

1. Change `assets/images.jpg` or `assets/abc.json` on disk and save.
2. Hot reload (`r`). The image and JSON text in the example should update without
   a full restart.

**New or deleted files** still depend on the Flutter tool’s asset bundle (see
[Adding and removing assets](#adding-and-removing-assets)). After the bundle is
rebuilt, hot reload plus this package’s cache clearing and web prefetch apply the
same way.

Web integration tests (asset add/change/delete × hot reload vs restart):

```sh
cd example
flutter test --platform chrome test/web/asset_lifecycle_web_test.dart
```

## How it works

- On web the package declares a web plugin; the generated web plugin registrant
  installs `AssetRefreshBinding` before `main`.
- On native platforms the app calls `AssetRefreshBinding.ensureInitialized()` in
  `main()`. The Dart plugin registrant only logs a hint, because it runs before
  `main()` and cannot create a binding safely (see above).
- Hot reload reassembles the widget tree. `WidgetsBinding.performReassemble` is
  overridden to clear caches every time, then optionally refresh changed asset
  URLs on the web before descendants resolve `ImageProvider`s again.
- In release builds, under `flutter test`, and under
  `flutter test integration_test`, `ensureInitialized` keeps the default
  binding, so test and release bindings are never replaced.

### Verbose logs

Most lines are prefixed with `[hot_reload_asset_refresh]`. For web fetch
fingerprints and header dumps:

```sh
flutter run --dart-define=HOT_RELOAD_ASSET_REFRESH_VERBOSE=true
```

## Optional widget

`AssetRefresh` refreshes only its subtree. It is useful when the app already
created another binding (so `AssetRefreshBinding` was not installed) or when you
want the refresh scoped explicitly:

```dart
import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';

void main() {
  runApp(const AssetRefresh(child: MyApp()));
}
```

To clear the caches manually: `AssetRefresh.refresh();`.

## Adding and removing assets

The caches are not the whole story: the Flutter tool decides which asset files
are part of the running app. Declare directories instead of individual files:

```yaml
flutter:
  assets:
    - assets/
    - assets/icons/   # every subdirectory needs its own entry
```

**Adding a file:** drop it directly into a declared directory and hot reload.
The tool sees the new file, rebuilds the asset bundle, and syncs it (including
`AssetManifest.bin`), so the new asset becomes available.

If you list individual files instead, add the new file to `pubspec.yaml`; saving
the pubspec triggers the same bundle rebuild on the next hot reload.

**Removing a file:** the tool does not notice deletions inside a directory
(it only compares modification times of files that still exist), so the running
manifest keeps listing the removed asset. Force a bundle rebuild by saving
`pubspec.yaml` (a no-op save is enough) and then hot reload, or stop and restart
`flutter run` for a clean dev file system. Deleting an entire declared directory
is detected automatically.

### Automating the rebuild

Instead of saving `pubspec.yaml` by hand, run the bundled watcher in a second
terminal from the project root:

```sh
dart run hot_reload_asset_refresh:watch_assets
```

It discovers paths from `flutter.assets` in `pubspec.yaml` — directory entries
such as `assets/`, plus the parent folder of each listed file (so a pubspec that
only lists `assets/foo.png` still watches `assets/`). You can also pass
directories explicitly.

When a file is added or removed:

- If you declare **directories** (`assets/`), it **touches** `pubspec.yaml` so
  the next hot reload rebuilds the asset bundle and manifest (Flutter does not
  notice deletions inside a directory otherwise).
- If you list **individual files**, it **adds or removes** that path under
  `flutter.assets` and saves the pubspec, which triggers the same bundle rebuild.

Options:

```sh
# Monorepo / package with a non-root pubspec
dart run hot_reload_asset_refresh:watch_assets --pubspec=packages/app/pubspec.yaml

# See what would be touched without modifying the pubspec
dart run hot_reload_asset_refresh:watch_assets --dry-run

# Log raw filesystem events
dart run hot_reload_asset_refresh:watch_assets --verbose

dart run hot_reload_asset_refresh:watch_assets assets/ assets/icons/
```

Hot reload after the change as usual (`r`, or let the IDE reload on the next
save). On web, once the bundle lists the new or removed asset, the debug binding
clears caches and prefetches evicted URLs as described above.

## Platform notes

- This package is a Flutter plugin. On Windows, building any app with plugins
  requires symlink support, which means enabling Developer Mode
  (`start ms-settings:developers`). Web and the other platforms do not need
  this.
- Adding the package does not modify `main.dart` on web. On native platforms add
  `AssetRefreshBinding.ensureInitialized()` as the first line of `main()`; no
  widget wrapping and no other app source changes are needed.
- Fonts are loaded by the engine and are not reloaded.
- Only [rootBundle] is cleared. Assets loaded through a custom [AssetBundle] may
  still be stale unless you clear that bundle or wrap the subtree with
  [AssetRefresh].
- On the web, browser HTTP caching is bypassed for assets the tool evicts during
  hot reload (`cache: 'no-store'` prefetch). Custom loaders or assets loaded
  outside `rootBundle` / `Image.asset` may still need their own refresh logic.