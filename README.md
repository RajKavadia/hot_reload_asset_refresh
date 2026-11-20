# hot_reload_asset_refresh

Refreshes changed assets on Flutter hot reload. **No widget wrapping and no app
code changes**: add the dependency, and the package's Flutter plugin registers
itself at startup in debug builds.

Works on Android, iOS, Linux, macOS, Windows, and web.

## Getting started

Add the dependency and run `flutter pub get`:

```yaml
dependencies:
  hot_reload_asset_refresh: ^0.0.1
```

That is the whole setup. Nothing in the app imports or calls the package.

In debug builds the plugin installs a `WidgetsFlutterBinding` subclass before
`main`. When the Flutter tool reports changed assets during a hot reload, the
binding clears `ImageCache` and `rootBundle` before the widget tree reassembles,
so images and string assets are re-read from disk instead of coming from the
stale caches.

Edit an image or other asset and save. The next hot reload picks it up.

## How it works

- The package declares a Dart plugin (`dartPluginClass` on native platforms and
  a web plugin entry point). Flutter generates a plugin registrant that calls it
  at startup. On web the generated web plugin registrant runs it before `main`.
- Hot reload reassembles the widget tree, and `WidgetsBinding.performReassemble`
  is overridden to clear the caches right before the tree re-resolves its
  `ImageProvider`s.
- Automatic registration is skipped in release builds, under `flutter test`, and
  under `flutter test integration_test`, so test bindings are never replaced.

### Opting out

Apps with a custom binding, or integration tests run through `flutter drive`,
can disable automatic registration:

```sh
flutter run --dart-define=HOT_RELOAD_ASSET_REFRESH=false
```

If you still want a refresh in that case, use the optional widget below.

## Optional widget

`AssetRefresh` refreshes only its subtree. It is useful when automatic
registration is disabled or when you want the refresh scoped explicitly:

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

It reads the directory entries from `flutter.assets` in `pubspec.yaml` (you can
also pass directories explicitly, for example
`dart run hot_reload_asset_refresh:watch_assets assets/ assets/icons/`). When a
file is added or deleted in one of those directories, it touches `pubspec.yaml`,
so the next hot reload rebuilds the asset bundle and regenerates the manifest.
Hot reload after the change as usual (`r`, or let the IDE reload on the next
save).

Web works the same way, but the browser may need a refresh before it requests
the rebuilt manifest.

## Platform notes

- This package is a Flutter plugin. On Windows, building any app with plugins
  requires symlink support, which means enabling Developer Mode
  (`start ms-settings:developers`). Web and the other platforms do not need
  this.
- Adding the package does not modify `main.dart`, the widget tree, or any other
  app source.
- Fonts are loaded by the engine and are not reloaded.
- Assets loaded through a custom `AssetBundle` and assets served from the
  browser's HTTP cache may still be stale.
