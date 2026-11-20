import 'dart:convert';

/// Returns the directory entries declared under `flutter.assets` in a pubspec.
///
/// Only directory entries are returned (paths ending in `/`), because they are
/// the ones whose contents can change without editing the pubspec. Individual
/// file entries are already covered by a pubspec edit.
///
/// Used by the `watch_assets` development script.
List<String> assetDirectoryEntries(String pubspecContents) {
  final directories = <String>[];
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
        final entry = _unquote(trimmed.substring(1).trim());
        if (entry.endsWith('/')) {
          directories.add(entry);
        }
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

  return directories;
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
