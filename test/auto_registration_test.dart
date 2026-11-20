import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/src/auto_binding.dart';

void main() {
  testWidgets('registerWith leaves the test binding in place', (
    tester,
  ) async {
    final before = WidgetsBinding.instance;

    HotReloadAssetRefreshPlugin.registerWith();
    HotReloadAssetRefreshPlugin.registerWith();

    expect(identical(WidgetsBinding.instance, before), isTrue);
  });
}
