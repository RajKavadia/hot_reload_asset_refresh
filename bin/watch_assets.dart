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
// the pubspec (directory entries and parent folders of listed files). When the
// pubspec lists individual files, additions and removals update that list;
// directory entries still only need a pubspec touch so the bundle rebuilds.

import 'dart:async';
import 'dart:io';

import 'package:hot_reload_asset_refresh/src/pubspec_assets.dart';
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

  final watcher = _PubspecAssetWatcher(
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
    '$_tool: additions and deletions update pubspec.yaml (or touch it when '
    'using directory entries) so the next hot reload rebuilds the asset bundle.',
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

class _PubspecAssetWatcher {
  _PubspecAssetWatcher({
    required this.pubspec,
    required this.dryRun,
    required this.verbose,
  });

  final File pubspec;
  final bool dryRun;
  final bool verbose;
  Timer? _pendingTouch;

  String get _projectRoot => pubspec.parent.path;

  void handleEvent(FileSystemEvent event) {
    if (verbose) {
      stdout.writeln('$_tool: event ${_eventTypeLabel(event)} ${event.path}');
    }

    final added = event is FileSystemCreateEvent;
    final removed = event is FileSystemDeleteEvent;
    if (!added && !removed) {
      return;
    }

    _pendingTouch?.cancel();
    _pendingTouch = Timer(_touchDebounce, () async {
      try {
        await _applyChange(
          eventPath: event.path,
          added: added,
        );
        await stdout.flush();
      } on FileSystemException catch (error) {
        stderr.writeln(
          '$_tool: cannot update ${pubspec.path}: ${error.message}',
        );
      }
    });
  }

  Future<void> _applyChange({
    required String eventPath,
    required bool added,
  }) async {
    final change = added ? 'added' : 'removed';
    if (added && Directory(eventPath).existsSync()) {
      if (verbose) {
        stdout.writeln('$_tool: $change $eventPath; ignoring directory create.');
      }
      return;
    }

    final assetPath = normalizeAssetPath(_projectRoot, eventPath);
    final before = pubspec.readAsStringSync();
    final result = applyAssetFilesystemChange(
      pubspecContents: before,
      assetPath: assetPath,
      added: added,
    );

    if (dryRun) {
      stdout.writeln(
        '$_tool: $change $eventPath ($assetPath); '
        '${_dryRunLabel(result.kind)} ${pubspec.path} (dry-run).',
      );
      return;
    }

    switch (result.kind) {
      case PubspecAssetApplyKind.updated:
        pubspec.writeAsStringSync(result.contents!);
        stdout.writeln(
          '$_tool: $change $assetPath; updated ${pubspec.path} - '
          'hot reload to rebuild the asset bundle.',
        );
      case PubspecAssetApplyKind.touchOnly:
        pubspec.setLastModifiedSync(DateTime.now());
        stdout.writeln(
          '$_tool: $change $assetPath; pubspec touched - '
          'hot reload to rebuild the asset bundle.',
        );
      case PubspecAssetApplyKind.unchanged:
        pubspec.setLastModifiedSync(DateTime.now());
        stdout.writeln(
          '$_tool: $change $assetPath; pubspec touched - '
          'hot reload to rebuild the asset bundle.',
        );
    }
  }

  String _dryRunLabel(PubspecAssetApplyKind kind) {
    return switch (kind) {
      PubspecAssetApplyKind.updated => 'would update',
      PubspecAssetApplyKind.touchOnly => 'would touch',
      PubspecAssetApplyKind.unchanged => 'would touch',
    };
  }
}