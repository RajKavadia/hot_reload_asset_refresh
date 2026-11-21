import 'dart:io';

import 'asset_directories.dart';

/// Options for the `watch_assets` development script.
class WatchAssetsOptions {
  /// Creates watch options for the `watch_assets` CLI.
  const WatchAssetsOptions({
    required this.pubspec,
    required this.directoryPaths,
    this.dryRun = false,
    this.verbose = false,
  });

  /// Pubspec file that `watch_assets` touches to trigger a bundle rebuild.
  final File pubspec;

  /// Explicit directory paths to watch; may be empty to read from [pubspec].
  final List<String> directoryPaths;

  /// When true, log touches without modifying [pubspec].
  final bool dryRun;

  /// When true, log all filesystem events under watched directories.
  final bool verbose;

  /// Reads declared directories from [pubspec] when [directoryPaths] is empty.
  List<String> resolveDirectoryPaths() {
    if (directoryPaths.isNotEmpty) {
      return directoryPaths;
    }
    return assetDirectoryEntries(pubspec.readAsStringSync());
  }
}

/// Parses CLI arguments for `watch_assets`.
///
/// Returns `null` when a usage error should be reported (unknown flag, etc.).
WatchAssetsOptions? parseWatchAssetsArguments(
  List<String> arguments, {
  String defaultPubspecPath = 'pubspec.yaml',
}) {
  var pubspecPath = defaultPubspecPath;
  var dryRun = false;
  var verbose = false;
  final directoryPaths = <String>[];

  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--dry-run') {
      dryRun = true;
      continue;
    }
    if (arg == '--verbose') {
      verbose = true;
      continue;
    }
    if (arg == '--pubspec') {
      if (i + 1 >= arguments.length) {
        return null;
      }
      pubspecPath = arguments[++i];
      continue;
    }
    if (arg.startsWith('--pubspec=')) {
      pubspecPath = arg.substring('--pubspec='.length);
      if (pubspecPath.isEmpty) {
        return null;
      }
      continue;
    }
    if (arg.startsWith('-')) {
      return null;
    }
    directoryPaths.add(arg);
  }

  return WatchAssetsOptions(
    pubspec: File(pubspecPath),
    directoryPaths: directoryPaths,
    dryRun: dryRun,
    verbose: verbose,
  );
}