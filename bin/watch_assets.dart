// Watches asset directories and forces the Flutter tool to rebuild its asset
// bundle when files are added or removed.
//
// Flutter's hot reload notices a newer modification time on existing files, but
// it never notices deletions: the running manifest keeps listing the deleted
// asset and the dev file system keeps the old file. Touching `pubspec.yaml`
// makes the tool's `needsBuild()` return true on the next hot reload, which
// regenerates `AssetManifest.bin` and syncs it.
//
// Usage (from the Flutter project root):
//
//     dart run hot_reload_asset_refresh:watch_assets
//     dart run hot_reload_asset_refresh:watch_assets assets/ assets/icons/
//
// Without arguments the directories are read from `flutter.assets` in
// `pubspec.yaml`. Only directory entries are watched, matching Flutter: files
// in subdirectories are only bundled when each subdirectory is declared.

import 'dart:async';
import 'dart:io';

import 'package:hot_reload_asset_refresh/src/asset_directories.dart';

const _tool = 'watch_assets';

Future<void> main(List<String> arguments) async {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    stderr.writeln(
      '$_tool: run this from the Flutter project root (no pubspec.yaml here).',
    );
    exitCode = 64;
    return;
  }

  final requested = arguments.isEmpty
      ? assetDirectoryEntries(pubspec.readAsStringSync())
      : arguments;

  final directories = <Directory>[];
  for (final path in requested) {
    final directory = Directory(path);
    if (directory.existsSync()) {
      directories.add(directory);
    } else {
      stderr.writeln('$_tool: skipping missing directory "$path".');
    }
  }

  if (directories.isEmpty) {
    stderr.writeln('$_tool: no asset directories to watch.');
    stderr.writeln(
      'Pass them as arguments, for example: '
      'dart run hot_reload_asset_refresh:watch_assets assets/ assets/icons/',
    );
    exitCode = 64;
    return;
  }

  for (final directory in directories) {
    try {
      directory.watch().listen(
        (event) => _handleEvent(event, pubspec),
        onError: (Object error) {
          stderr.writeln('$_tool: error watching ${directory.path}: $error');
        },
      );
    } on FileSystemException catch (error) {
      stderr.writeln('$_tool: cannot watch ${directory.path}: ${error.message}');
    }
  }

  stdout.writeln(
    '$_tool: watching ${directories.map((d) => d.path).join(', ')}',
  );
  stdout.writeln(
    '$_tool: additions and deletions touch pubspec.yaml so the next hot '
    'reload rebuilds the asset bundle.',
  );
  await stdout.flush();
}

Timer? _pendingTouch;

void _handleEvent(FileSystemEvent event, File pubspec) {
  final change = switch (event) {
    FileSystemCreateEvent() => 'added',
    FileSystemDeleteEvent() => 'removed',
    _ => null,
  };
  if (change == null) {
    return;
  }

  _pendingTouch?.cancel();
  _pendingTouch = Timer(const Duration(milliseconds: 100), () async {
    try {
      pubspec.setLastModifiedSync(DateTime.now());
      stdout.writeln(
        '$_tool: $change ${event.path}; pubspec.yaml touched - '
        'hot reload to rebuild the asset bundle.',
      );
      await stdout.flush();
    } on FileSystemException catch (error) {
      stderr.writeln('$_tool: cannot touch pubspec.yaml: ${error.message}');
    }
  });
}
