import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/src/asset_directories.dart';

void main() {
  test('returns only directory entries from flutter.assets', () {
    const pubspec = '''
name: example
flutter:
  uses-material-design: true
  assets:
    - assets/
    - "assets/icons/"
    - assets/logo.png
    - assets/fonts/Inter.ttf  # a file, not a directory
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter.ttf
''';

    expect(assetDirectoryEntries(pubspec), ['assets/', 'assets/icons/']);
  });

  test('ignores assets sections outside the flutter section', () {
    const pubspec = '''
name: example
other_tool:
  assets:
    - ignored/
flutter:
  assets:
    - assets/
''';

    expect(assetDirectoryEntries(pubspec), ['assets/']);
  });

  test('ignores entries after the assets list ends', () {
    const pubspec = '''
flutter:
  assets:
    - assets/
  shaders:
    - shaders/sparkle.frag
  assets_extra:
    - extra/
''';

    expect(assetDirectoryEntries(pubspec), ['assets/']);
  });

  test('returns an empty list without a flutter section', () {
    expect(assetDirectoryEntries('name: example\n'), isEmpty);
    expect(assetDirectoryEntries(''), isEmpty);
  });
}
