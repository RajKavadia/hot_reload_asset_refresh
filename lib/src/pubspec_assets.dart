import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Every entry under `flutter.assets` in a pubspec (files and directories).
List<String> flutterAssetEntries(String pubspecContents) {
  return _parseFlutterAssetEntries(pubspecContents);
}

/// Directory paths to watch: declared directories plus parents of file entries.
List<String> assetWatchDirectoryPaths(String pubspecContents) {
  final directories = <String>{};
  for (final entry in flutterAssetEntries(pubspecContents)) {
    if (entry.endsWith('/')) {
      directories.add(entry);
    } else {
      final parent = _parentAssetDirectory(entry);
      if (parent.isNotEmpty) {
        directories.add(parent);
      }
    }
  }
  final sorted = directories.toList()..sort();
  return sorted;
}

/// Whether [assetPath] is already bundled via a directory entry in the pubspec.
bool assetPathCoveredByDirectoryEntry(
  String assetPath,
  Iterable<String> directoryEntries,
) {
  final normalized = assetPath.replaceAll('\\', '/');
  for (final dir in directoryEntries) {
    final withSlash = dir.endsWith('/') ? dir : '$dir/';
    if (normalized.startsWith(withSlash)) {
      return true;
    }
  }
  return false;
}

/// Result of applying a filesystem add/remove to [flutter.assets].
enum PubspecAssetApplyKind {
  /// Rewrote the pubspec (added or removed a file entry).
  updated,

  /// The path is covered by a directory entry; only a pubspec touch is needed.
  touchOnly,

  /// No pubspec edit required (already listed, or not listed on delete).
  unchanged,
}

/// Describes how [applyAssetFilesystemChange] would update a pubspec.
class PubspecAssetApplyResult {
  /// Creates a result with an optional rewritten [contents] value.
  const PubspecAssetApplyResult({
    required this.kind,
    this.contents,
  });

  /// What kind of pubspec change is required.
  final PubspecAssetApplyKind kind;

  /// New pubspec text when [kind] is [PubspecAssetApplyKind.updated].
  final String? contents;
}

/// Updates [pubspecContents] when a file is added to or removed from disk.
PubspecAssetApplyResult applyAssetFilesystemChange({
  required String pubspecContents,
  required String assetPath,
  required bool added,
}) {
  final entry = assetPath.replaceAll('\\', '/');
  if (entry.isEmpty || entry.endsWith('/')) {
    return const PubspecAssetApplyResult(kind: PubspecAssetApplyKind.unchanged);
  }

  final directoryEntries =
      flutterAssetEntries(pubspecContents).where((e) => e.endsWith('/'));
  if (assetPathCoveredByDirectoryEntry(entry, directoryEntries)) {
    return const PubspecAssetApplyResult(kind: PubspecAssetApplyKind.touchOnly);
  }

  final listed = pubspecListsAsset(pubspecContents, entry);
  if (added) {
    if (listed) {
      return const PubspecAssetApplyResult(kind: PubspecAssetApplyKind.unchanged);
    }
    return PubspecAssetApplyResult(
      kind: PubspecAssetApplyKind.updated,
      contents: addPubspecAssetEntry(pubspecContents, entry),
    );
  }

  if (!listed) {
    return const PubspecAssetApplyResult(kind: PubspecAssetApplyKind.unchanged);
  }
  return PubspecAssetApplyResult(
    kind: PubspecAssetApplyKind.updated,
    contents: removePubspecAssetEntry(pubspecContents, entry),
  );
}

/// Whether [assetPath] appears as a file entry under `flutter.assets`.
bool pubspecListsAsset(String pubspecContents, String assetPath) {
  final normalized = assetPath.replaceAll('\\', '/');
  return flutterAssetEntries(pubspecContents).contains(normalized);
}

/// Adds [assetPath] to the `flutter.assets` list when it is not already present.
String addPubspecAssetEntry(String pubspecContents, String assetPath) {
  final entry = assetPath.replaceAll('\\', '/');
  if (pubspecListsAsset(pubspecContents, entry)) {
    return pubspecContents;
  }

  final lines = const LineSplitter().convert(pubspecContents);
  final insert = _findAssetListInsertIndex(lines);
  if (insert == null) {
    return pubspecContents;
  }

  final indent = insert.itemIndent;
  final newLine = '${' ' * indent}- $entry';
  final updated = List<String>.from(lines)..insert(insert.lineIndex, newLine);
  return '${updated.join('\n')}\n';
}

/// Removes [assetPath] from the `flutter.assets` list when present.
String removePubspecAssetEntry(String pubspecContents, String assetPath) {
  final entry = assetPath.replaceAll('\\', '/');
  final lines = const LineSplitter().convert(pubspecContents);
  final updated = <String>[];

  var inFlutterSection = false;
  var inAssetsSection = false;
  var flutterIndent = 0;

  for (final rawLine in lines) {
    final line = _stripComment(rawLine);
    final trimmed = line.trim();
    final indent = line.length - line.trimLeft().length;

    if (trimmed == 'flutter:') {
      inFlutterSection = true;
      inAssetsSection = false;
      flutterIndent = indent;
      updated.add(rawLine);
      continue;
    }
    if (!inFlutterSection) {
      updated.add(rawLine);
      continue;
    }

    if (inAssetsSection) {
      if (trimmed.startsWith('-')) {
        final listed = _unquote(trimmed.substring(1).trim());
        if (listed.replaceAll('\\', '/') == entry) {
          continue;
        }
        updated.add(rawLine);
        continue;
      }
      inAssetsSection = false;
    }

    if (indent <= flutterIndent) {
      inFlutterSection = false;
      updated.add(rawLine);
      continue;
    }

    if (trimmed == 'assets:') {
      inAssetsSection = true;
      updated.add(rawLine);
      continue;
    }

    updated.add(rawLine);
  }

  final text = updated.join('\n');
  return text.endsWith('\n') ? text : '$text\n';
}

/// Project-root-relative asset path using forward slashes.
String normalizeAssetPath(String projectRoot, String absolutePath) {
  final root = Directory(projectRoot).absolute.path;
  final abs = File(absolutePath).absolute.path;
  var relative = p.relative(abs, from: root);
  relative = p.normalize(relative);
  return relative.replaceAll('\\', '/');
}

class _AssetListInsert {
  const _AssetListInsert({
    required this.lineIndex,
    required this.itemIndent,
  });

  final int lineIndex;
  final int itemIndent;
}

_AssetListInsert? _findAssetListInsertIndex(List<String> lines) {
  var inFlutterSection = false;
  var inAssetsSection = false;
  var flutterIndent = 0;
  var assetsKeyLineIndex = -1;
  var assetsKeyIndent = 0;
  var lastItemLineIndex = -1;
  var itemIndent = 0;

  for (var i = 0; i < lines.length; i++) {
    final rawLine = lines[i];
    final line = _stripComment(rawLine);
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final indent = line.length - line.trimLeft().length;

    if (trimmed == 'flutter:') {
      inFlutterSection = true;
      inAssetsSection = false;
      flutterIndent = indent;
      continue;
    }
    if (!inFlutterSection) {
      continue;
    }

    if (inAssetsSection) {
      if (trimmed.startsWith('-')) {
        lastItemLineIndex = i;
        itemIndent = indent;
        continue;
      }
      if (lastItemLineIndex >= 0) {
        return _AssetListInsert(
          lineIndex: lastItemLineIndex + 1,
          itemIndent: itemIndent,
        );
      }
      break;
    }

    if (indent <= flutterIndent) {
      inFlutterSection = false;
      continue;
    }

    if (trimmed == 'assets:') {
      inAssetsSection = true;
      assetsKeyLineIndex = i;
      assetsKeyIndent = indent;
    }
  }

  if (lastItemLineIndex >= 0) {
    return _AssetListInsert(
      lineIndex: lastItemLineIndex + 1,
      itemIndent: itemIndent,
    );
  }
  if (assetsKeyLineIndex >= 0) {
    return _AssetListInsert(
      lineIndex: assetsKeyLineIndex + 1,
      itemIndent: assetsKeyIndent + 2,
    );
  }
  return null;
}

String _parentAssetDirectory(String fileEntry) {
  final normalized = fileEntry.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash <= 0) {
    return '';
  }
  return normalized.substring(0, slash + 1);
}

List<String> _parseFlutterAssetEntries(String pubspecContents) {
  final entries = <String>[];
  var inFlutterSection = false;
  var inAssetsSection = false;
  var flutterIndent = 0;

  for (final rawLine in const LineSplitter().convert(pubspecContents)) {
    final line = _stripComment(rawLine);
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final indent = line.length - line.trimLeft().length;

    if (trimmed == 'flutter:') {
      inFlutterSection = true;
      inAssetsSection = false;
      flutterIndent = indent;
      continue;
    }
    if (!inFlutterSection) {
      continue;
    }

    if (inAssetsSection) {
      if (trimmed.startsWith('-')) {
        entries.add(_unquote(trimmed.substring(1).trim()));
        continue;
      }
      inAssetsSection = false;
    }

    if (indent <= flutterIndent) {
      inFlutterSection = false;
      continue;
    }

    if (trimmed == 'assets:') {
      inAssetsSection = true;
    }
  }

  return entries;
}

String _stripComment(String line) {
  final commentIndex = line.indexOf('#');
  return commentIndex == -1 ? line : line.substring(0, commentIndex);
}

String _unquote(String value) {
  if (value.length >= 2) {
    final first = value[0];
    final last = value[value.length - 1];
    if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
      return value.substring(1, value.length - 1);
    }
  }
  return value;
}