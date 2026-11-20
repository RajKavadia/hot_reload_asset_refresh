/// Whether the current process is a `flutter test` run.
///
/// Overridden with the `dart:io` implementation on platforms that support it.
bool get isFlutterTest => false;
