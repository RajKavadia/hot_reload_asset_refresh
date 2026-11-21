# hot_reload_asset_refresh

Refreshes changed assets on Flutter hot reload. **No widget wrapping and no app
code changes**: add the dependency, and the package's Flutter plugin registers
itself at startup in debug builds.

Works on Android, iOS, Linux, macOS, Windows, and web. Debug hot reload only —
not for release builds or runtime asset updates.

## Getting started

Add the dependency and run `flutter pub get`:

```yaml
dependencies:
  hot_reload_asset_refresh: ^0.1.0
```

That is the whole setup. Nothing in the app imports or calls the package.

In debug builds the plugin installs a `WidgetsFlutterBinding` subclass before
`main`. On every hot reload it clears `ImageCache` and `rootBundle` before the
widget tree reassembles, so images and string assets are re-read from disk
instead of stale caches. When the Flutter tool reports specific changed assets,
the binding also records them for a web cache refresh (`fetch` with
`cache: 'no-store'`).

Edit an image or other asset and save. The next hot reload picks it up.

Try the **example** app: `cd example && flutter run`.

Web integration tests (asset add/change/delete × hot reload vs restart):

```sh
cd example
flutter test --platform chrome test/web/asset_lifecycle_web_test.dart
```

## How it works

- The package declares a Dart plugin (`dartPluginClass` on native platforms and
  a web plugin entry point). Flutter generates a plugin registrant that calls it
  at startup. On web the generated web plugin registrant runs it before `main`.
- Hot reload reassembles the widget tree. `WidgetsBinding.performReassemble` is
  overridden to clear caches every time, then optionally refresh changed asset
  URLs on the web before descendants resolve `ImageProvider`s again.
- Automatic registration is skipped in release builds, under `flutter test`, and
  under `flutter test integration_test`, so test bindings are never replaced.

### Verbose logs

Most lines are prefixed with `[hot_reload_asset_refresh]`. For web fetch
fingerprints and header dumps:

```sh
flutter run --dart-define=HOT_RELOAD_ASSET_REFRESH_VERBOSE=true
```

## Optional widget

`AssetRefresh` refreshes only its subtree. It is useful when the app already
has a custom binding (so automatic registration is skipped) or when you want the
refresh scoped explicitly:

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

It reads directory entries from `flutter.assets` in `pubspec.yaml` (you can also
pass directories explicitly). When a file is added or deleted in one of those
directories, it touches `pubspec.yaml`, so the next hot reload rebuilds the
asset bundle and regenerates the manifest.

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
- Only [rootBundle] is cleared. Assets loaded through a custom [AssetBundle] may
  still be stale unless you clear that bundle or wrap the subtree with
  [AssetRefresh].
- On the web, browser HTTP caching is bypassed for assets the tool evicts during
  hot reload; other cache behavior may still apply for custom loaders.