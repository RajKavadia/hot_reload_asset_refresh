import 'package:example/integration_test_harness.dart';
import 'package:example/integration_test_support/mutable_asset_bundle.dart';
import 'package:example/integration_test_support/test_asset_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';
import 'package:hot_reload_asset_refresh/src/web_asset_refresh.dart'
    if (dart.library.js_interop) 'package:hot_reload_asset_refresh/src/web_asset_refresh_web.dart';

void integrationStep(int number, String message) {
  debugPrint('[web-integration step $number] $message');
}

Widget buildProbeApp({
  required MutableAssetBundle bundle,
  required int generation,
}) {
  return DefaultAssetBundle(
    bundle: bundle,
    child: AssetRefresh(
      child: AssetProbeApp(bundle: bundle, generation: generation),
    ),
  );
}

Future<void> pumpProbeApp(
  WidgetTester tester, {
  required MutableAssetBundle bundle,
  required int generation,
}) async {
  await tester.pumpWidget(buildProbeApp(bundle: bundle, generation: generation));
  await tester.pumpAndSettle();
}

Future<void> runWebHotReload({
  required WidgetTester tester,
  required MutableAssetBundle bundle,
  required List<String> changedAssetKeys,
}) async {
  integrationStep(1, 'Apply asset mutations (simulate Flutter tool sync).');

  integrationStep(
    2,
    'Evict changed keys (tool → binding.evict) for: $changedAssetKeys.',
  );
  for (final key in changedAssetKeys) {
    bundle.evict(key);
  }

  integrationStep(3, 'Clear ImageCache and rootBundle (package refresh).');
  AssetRefresh.refresh();
  bundle.clear();

  integrationStep(
    4,
    'Web: fetch changed assets with cache: no-store before reassemble.',
  );
  await tester.runAsync(() => refreshChangedAssetsOnWeb(changedAssetKeys));

  integrationStep(5, 'Hot reload: reassemble widget tree.');
  await tester.binding.reassembleApplication();
  await tester.pump();
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

Future<void> runWebHotRestart({
  required WidgetTester tester,
  required MutableAssetBundle bundle,
  required int generation,
}) async {
  integrationStep(1, 'Hot restart: dispose prior tree.');
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();

  integrationStep(2, 'Hot restart: mount fresh app (generation=$generation).');
  await pumpProbeApp(tester, bundle: bundle, generation: generation);

  integrationStep(3, 'Hot restart: caches cleared like a fresh debug session.');
  AssetRefresh.refresh();
  bundle.clear();
  await tester.pumpAndSettle(const Duration(seconds: 1));
}

Future<void> expectProbeV1(WidgetTester tester) async {
  expect(find.byKey(AssetProbeKeys.imageFingerprint), findsOneWidget);
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.imageFingerprint)).data,
    TestAssetExpectations.imageV1(),
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.stringValue)).data,
    'hello-v1',
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.binaryFingerprint)).data,
    TestAssetExpectations.binaryV1(),
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.jsonVersion)).data,
    'json.version=1',
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
    'missing',
  );
}

Future<void> expectProbeV2(WidgetTester tester) async {
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.imageFingerprint)).data,
    TestAssetExpectations.imageV2(),
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.stringValue)).data,
    'hello-v2',
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.binaryFingerprint)).data,
    TestAssetExpectations.binaryV2(),
  );
  expect(
    tester.widget<Text>(find.byKey(AssetProbeKeys.jsonVersion)).data,
    'json.version=2',
  );
}