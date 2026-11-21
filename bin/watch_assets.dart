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
//     dart run hot_reload_asset_refresh:watch_assets --pubspec=packages/app/pubspec.yaml
//     dart run hot_reload_asset_refresh:watch_assets --dry-run --verbose
//
// Without directory arguments the directories are read from `flutter.assets` in
// the pubspec. Only directory entries are watched, matching Flutter: files in
// subdirectories are only bundled when each subdirectory is declared.

import 'dart:async';
import 'dart:io';

import 'package:hot_reload_asset_refresh/src/watch_assets_cli.dart';

const _tool = 'watch_assets';
const _touchDebounce = Duration(milliseconds: 300);

Future<void> main(List<String> arguments) async {
  final options = parseWatchAssetsArguments(arguments);
  if (options == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final pubspec = options.pubspec;
  if (!pubspec.existsSync()) {
    stderr.writeln(
      '$_tool: pubspec not found: ${pubspec.absolute.path}',
    );
    stderr.writeln(
      'Run from the project root or pass --pubspec=path/to/pubspec.yaml.',
    );
    exitCode = 64;
    return;
  }

  final requested = options.resolveDirectoryPaths();

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
      'Pass directories as arguments or declare them under flutter.assets.',
    );
    exitCode = 64;
    return;
  }

  final watcher = _PubspecTouchWatcher(
    pubspec: pubspec,
    dryRun: options.dryRun,
    verbose: options.verbose,
  );

  for (final directory in directories) {
    try {
      directory.watch().listen(
        watcher.handleEvent,
        onError: (Object error) {
          stderr.writeln('$_tool: error watching ${directory.path}: $error');
        },
      );
    } on FileSystemException catch (error) {
      stderr.writeln('$_tool: cannot watch ${directory.path}: ${error.message}');
    }
  }

  stdout.writeln('$_tool: pubspec=${pubspec.path}');
  stdout.writeln(
    '$_tool: watching ${directories.map((d) => d.path).join(', ')}',
  );
  if (options.dryRun) {
    stdout.writeln('$_tool: dry-run mode (pubspec will not be modified).');
  }
  stdout.writeln(
    '$_tool: additions and deletions touch pubspec.yaml so the next hot '
    'reload rebuilds the asset bundle.',
  );
  await stdout.flush();
}

String _eventTypeLabel(FileSystemEvent event) {
  if (event is FileSystemCreateEvent) {
    return 'create';
  }
  if (event is FileSystemModifyEvent) {
    return 'modify';
  }
  if (event is FileSystemDeleteEvent) {
    return 'delete';
  }
  if (event is FileSystemMoveEvent) {
    return 'move';
  }
  return 'other';
}

void _printUsage() {
  stderr.writeln('''
$_tool: watch asset directories and touch pubspec.yaml on add/remove.

Usage:
  dart run hot_reload_asset_refresh:watch_assets [options] [directories...]

Options:
  --pubspec=<path>   Pubspec to touch (default: pubspec.yaml in the cwd)
  --pubspec <path>   Same as --pubspec=<path>
  --dry-run          Log touches without modifying pubspec.yaml
  --verbose          Log every filesystem event (not only touches)

Examples:
  dart run hot_reload_asset_refresh:watch_assets
  dart run hot_reload_asset_refresh:watch_assets assets/ assets/icons/
  dart run hot_reload_asset_refresh:watch_assets --pubspec=packages/app/pubspec.yaml
''');
}

class _PubspecTouchWatcher {
  _PubspecTouchWatcher({
    required this.pubspec,
    required this.dryRun,
    required this.verbose,
  });

  final File pubspec;
  final bool dryRun;
  final bool verbose;
  Timer? _pendingTouch;

  void handleEvent(FileSystemEvent event) {
    if (verbose) {
      stdout.writeln('$_tool: event ${_eventTypeLabel(event)} ${event.path}');
    }

    final change = switch (event) {
      FileSystemCreateEvent() => 'added',
      FileSystemDeleteEvent() => 'removed',
      _ => null,
    };
    if (change == null) {
      return;
    }

    _pendingTouch?.cancel();
    _pendingTouch = Timer(_touchDebounce, () async {
      try {
        if (dryRun) {
          stdout.writeln(
            '$_tool: $change ${event.path}; would touch ${pubspec.path} '
            '(dry-run).',
          );
        } else {
          pubspec.setLastModifiedSync(DateTime.now());
          stdout.writeln(
            '$_tool: $change ${event.path}; pubspec touched - '
            'hot reload to rebuild the asset bundle.',
          );
        }
        await stdout.flush();
      } on FileSystemException catch (error) {
        stderr.writeln(
          '$_tool: cannot touch ${pubspec.path}: ${error.message}',
        );
      }
    });
  }
}