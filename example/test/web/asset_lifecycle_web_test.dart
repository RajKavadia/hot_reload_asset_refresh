@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'asset_lifecycle_shared.dart';

/// Primary web test runner (real Chrome via `flutter test --platform chrome`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  runAssetLifecycleWebTests();
}