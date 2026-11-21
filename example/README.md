# Example

Demonstrates `hot_reload_asset_refresh` with no imports in app code.

```sh
flutter run
```

1. Change `assets/images.jpg` or `assets/abc.json` on disk.
2. Hot reload (`r`). The image and JSON text should update.

For add/remove of files under `assets/`, run from the package root:

```sh
dart run hot_reload_asset_refresh:watch_assets
```

(in a second terminal, with `cwd` set to `example/` or pass
`--pubspec=example/pubspec.yaml` from the repo root).

## Web integration tests

Step-by-step hot **reload** and hot **restart** cases (asset change, add, delete;
image, string, binary, JSON; plus bundled `assets/` smoke):

```sh
cd example
flutter test --platform chrome test/web/asset_lifecycle_web_test.dart
```

ChromeDriver (if prompted):

```sh
chromedriver --port=4444
```

Driver-based CI:

```sh
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/asset_lifecycle_web_test.dart \
  -d chrome
```

In-memory mutations in the harness simulate the Flutter tool syncing new asset
bytes before reload; bundled tests use real `assets/images.jpg` and
`assets/abc.json` with `refreshChangedAssetsOnWeb`.