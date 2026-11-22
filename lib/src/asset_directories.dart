import 'pubspec_assets.dart';

/// Returns the directory entries declared under `flutter.assets` in a pubspec.
///
/// Only directory entries are returned (paths ending in `/`), because they are
/// the ones whose contents can change without editing the pubspec. Individual
/// file entries are already covered by a pubspec edit.
///
/// Used by the `watch_assets` development script.
List<String> assetDirectoryEntries(String pubspecContents) {
  return flutterAssetEntries(pubspecContents)
      .where((entry) => entry.endsWith('/'))
      .toList();
}