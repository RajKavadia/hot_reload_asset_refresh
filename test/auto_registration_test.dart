import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';
import 'package:hot_reload_asset_refresh/src/auto_binding.dart'
    show HotReloadAssetRefreshPlugin;

void main() {
  testWidgets('registerWith leaves the test binding in place', (tester) async {
    final before = WidgetsBinding.instance;

    HotReloadAssetRefreshPlugin.registerWith();
    HotReloadAssetRefreshPlugin.registerWith();

    expect(identical(WidgetsBinding.instance, before), isTrue);
  });

  testWidgets('ensureInitialized keeps an existing binding', (tester) async {
    final before = WidgetsBinding.instance;

    final WidgetsBinding result = AssetRefreshBinding.ensureInitialized();

    expect(identical(result, before), isTrue);
    expect(identical(WidgetsBinding.instance, before), isTrue);
  });

  testWidgets('ensureInitialized is idempotent', (tester) async {
    final before = WidgetsBinding.instance;

    AssetRefreshBinding.ensureInitialized();
    AssetRefreshBinding.ensureInitialized();

    expect(identical(WidgetsBinding.instance, before), isTrue);
  });
}
