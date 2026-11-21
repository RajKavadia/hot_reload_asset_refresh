import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/src/watch_assets_cli.dart';

void main() {
  test('parseWatchAssetsArguments reads flags and directories', () {
    final options = parseWatchAssetsArguments([
      '--pubspec=custom/pubspec.yaml',
      '--dry-run',
      '--verbose',
      'assets/',
      'assets/icons/',
    ]);
    expect(options, isNotNull);
    expect(options!.pubspec.path, 'custom/pubspec.yaml');
    expect(options.dryRun, isTrue);
    expect(options.verbose, isTrue);
    expect(options.directoryPaths, ['assets/', 'assets/icons/']);
  });

  test('parseWatchAssetsArguments supports --pubspec with separate value', () {
    final options = parseWatchAssetsArguments([
      '--pubspec',
      'packages/app/pubspec.yaml',
    ]);
    expect(options, isNotNull);
    expect(options!.pubspec.path, 'packages/app/pubspec.yaml');
    expect(options.directoryPaths, isEmpty);
  });

  test('parseWatchAssetsArguments returns null for unknown flags', () {
    expect(parseWatchAssetsArguments(['--unknown']), isNull);
  });
}