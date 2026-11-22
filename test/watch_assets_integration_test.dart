import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs the real `watch_assets` script against a temporary Flutter project and
/// checks that it touches `pubspec.yaml` when assets are added or deleted.
void main() {
  late Directory project;
  late File pubspec;

  setUp(() {
    project = Directory.systemTemp.createTempSync('watch_assets_integration');
    Directory('${project.path}/assets/icons').createSync(recursive: true);
    pubspec = File('${project.path}/pubspec.yaml')
      ..writeAsStringSync('''
name: watch_assets_integration
flutter:
  assets:
    - assets/
    - assets/icons/
''');
  });

  tearDown(() {
    if (project.existsSync()) {
      project.deleteSync(recursive: true);
    }
  });

  test(
    'touches pubspec.yaml when an asset is added and removed',
    () async {
      final process = await Process.start(
        _dartExecutable(),
        [File('bin/watch_assets.dart').absolute.path],
        workingDirectory: project.path,
      );
      addTearDown(() async {
        process.kill();
        await process.exitCode.timeout(
          const Duration(seconds: 10),
          onTimeout: () => -1,
        );
      });

      final lines = <String>[];
      final ready = Completer<void>();
      final added = Completer<void>();
      final removed = Completer<void>();
      final stdoutLines = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      stdoutLines.listen((line) {
        lines.add(line);
        if (!ready.isCompleted && line.contains('watching assets/')) {
          ready.complete();
        }
        if (!added.isCompleted && line.contains('added ')) {
          added.complete();
        }
        if (!removed.isCompleted && line.contains('removed ')) {
          removed.complete();
        }
      });
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(lines.add);

      await ready.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => fail('watcher did not start. Output:\n${lines.join('\n')}'),
      );

      final beforeCreate = pubspec.lastModifiedSync();
      final asset = File('${project.path}/assets/new.png')
        ..writeAsStringSync('asset');
      await added.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('no touch after adding a file. Output:\n${lines.join('\n')}'),
      );
      final afterCreate = pubspec.lastModifiedSync();
      expect(afterCreate.isAfter(beforeCreate), isTrue);

      asset.deleteSync();
      await removed.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('no touch after deleting a file. Output:\n${lines.join('\n')}'),
      );
      final afterDelete = pubspec.lastModifiedSync();
      expect(afterDelete.isAfter(afterCreate), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test(
    'updates pubspec asset list when entries list individual files',
    () async {
      pubspec.writeAsStringSync('''
name: watch_assets_integration
flutter:
  assets:
    - assets/existing.png
''');

      final process = await Process.start(
        _dartExecutable(),
        [File('bin/watch_assets.dart').absolute.path],
        workingDirectory: project.path,
      );
      addTearDown(() async {
        process.kill();
        await process.exitCode.timeout(
          const Duration(seconds: 10),
          onTimeout: () => -1,
        );
      });

      final lines = <String>[];
      final ready = Completer<void>();
      final added = Completer<void>();
      final removed = Completer<void>();
      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        lines.add(line);
        if (!ready.isCompleted && line.contains('watching assets/')) {
          ready.complete();
        }
        if (!added.isCompleted && line.contains('updated') && line.contains('added')) {
          added.complete();
        }
        if (!removed.isCompleted &&
            line.contains('updated') &&
            line.contains('removed')) {
          removed.complete();
        }
      });
      process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(lines.add);

      await ready.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => fail('watcher did not start. Output:\n${lines.join('\n')}'),
      );

      final asset = File('${project.path}/assets/new.json')
        ..writeAsStringSync('{}');
      await added.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => fail('no pubspec update after add. Output:\n${lines.join('\n')}'),
      );
      expect(
        pubspec.readAsStringSync(),
        contains('- assets/new.json'),
      );

      asset.deleteSync();
      await removed.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            fail('no pubspec update after delete. Output:\n${lines.join('\n')}'),
      );
      expect(pubspec.readAsStringSync(), isNot(contains('assets/new.json')));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

String _dartExecutable() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final executable = File(
      '$flutterRoot/bin/cache/dart-sdk/bin/dart${Platform.isWindows ? '.exe' : ''}',
    );
    if (executable.existsSync()) {
      return executable.path;
    }
  }
  return 'dart';
}
