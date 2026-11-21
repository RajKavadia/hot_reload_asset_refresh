import 'package:integration_test/integration_test.dart';

import '../test/web/asset_lifecycle_shared.dart';

/// `flutter drive` entry target (same cases as [test/web/asset_lifecycle_web_test.dart]).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  runAssetLifecycleWebTests();
}