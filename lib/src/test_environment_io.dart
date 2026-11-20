import 'dart:io';

/// Whether the current process is a `flutter test` run.
bool get isFlutterTest => Platform.environment['FLUTTER_TEST'] == 'true';
