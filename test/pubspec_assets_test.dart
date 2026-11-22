import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/src/pubspec_assets.dart';

const _fileListPubspec = '''
name: example
flutter:
  assets:
    - assets/images.jpg
    - assets/icons/logo.png
''';

const _directoryPubspec = '''
name: example
flutter:
  assets:
    - assets/
''';

void main() {
  test('assetWatchDirectoryPaths includes parents of file entries', () {
    expect(
      assetWatchDirectoryPaths(_fileListPubspec),
      ['assets/', 'assets/icons/'],
    );
    expect(assetWatchDirectoryPaths(_directoryPubspec), ['assets/']);
  });

  test('addPubspecAssetEntry appends under flutter.assets', () {
    final updated = addPubspecAssetEntry(_fileListPubspec, 'assets/abc.json');
    expect(updated, contains('- assets/abc.json'));
    expect(flutterAssetEntries(updated), contains('assets/abc.json'));
  });

  test('removePubspecAssetEntry drops a listed file', () {
    final updated =
        removePubspecAssetEntry(_fileListPubspec, 'assets/images.jpg');
    expect(updated, isNot(contains('assets/images.jpg')));
    expect(flutterAssetEntries(updated), ['assets/icons/logo.png']);
  });

  test('applyAssetFilesystemChange updates file lists but touches directories', () {
    final add = applyAssetFilesystemChange(
      pubspecContents: _fileListPubspec,
      assetPath: 'assets/abc.json',
      added: true,
    );
    expect(add.kind, PubspecAssetApplyKind.updated);
    expect(add.contents, contains('assets/abc.json'));

    final remove = applyAssetFilesystemChange(
      pubspecContents: _fileListPubspec,
      assetPath: 'assets/images.jpg',
      added: false,
    );
    expect(remove.kind, PubspecAssetApplyKind.updated);
    expect(remove.contents, isNot(contains('assets/images.jpg')));

    final touch = applyAssetFilesystemChange(
      pubspecContents: _directoryPubspec,
      assetPath: 'assets/new.png',
      added: true,
    );
    expect(touch.kind, PubspecAssetApplyKind.touchOnly);
  });
}