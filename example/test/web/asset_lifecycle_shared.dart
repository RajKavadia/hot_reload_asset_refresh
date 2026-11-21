import 'package:example/bundled_asset_harness.dart';
import 'package:example/integration_test_harness.dart';
import 'package:example/integration_test_support/mutable_asset_bundle.dart';
import 'package:example/integration_test_support/test_asset_bytes.dart';
import 'package:example/integration_test_support/test_asset_paths.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';
import 'package:hot_reload_asset_refresh/src/web_asset_refresh.dart'
    if (dart.library.js_interop) 'package:hot_reload_asset_refresh/src/web_asset_refresh_web.dart';

import 'web_reload_protocol.dart';

/// Web-only asset lifecycle tests (shared by browser unit tests and drive target).
void runAssetLifecycleWebTests() {
  if (!kIsWeb) {
    test(
      'Web-only integration tests',
      () {},
      skip: 'Run on a Web platform (Chrome).',
    );
    return;
  }

  group('Web integration — in-memory assets (image, string, binary, JSON)', () {
    late MutableAssetBundle bundle;

    setUp(() {
      bundle = createSeedBundleV1();
    });

    group('Hot reload', () {
      testWidgets('change: image → string → binary → structured JSON', (
        tester,
      ) async {
        integrationStep(0, 'Baseline: mount harness with v1 assets.');
        await pumpProbeApp(tester, bundle: bundle, generation: 1);
        await expectProbeV1(tester);

        integrationStep(0, 'Mutate all asset types to v2 (tool sync).');
        applyAssetChangeV2(bundle);

        await runWebHotReload(
          tester: tester,
          bundle: bundle,
          changedAssetKeys: [
            TestAssetPaths.image,
            TestAssetPaths.string,
            TestAssetPaths.binary,
            TestAssetPaths.json,
          ],
        );

        await expectProbeV2(tester);
        expect(find.byKey(const Key('probe_image_widget')), findsOneWidget);
      });

      testWidgets('add: optional string asset appears after reload', (
        tester,
      ) async {
        await pumpProbeApp(tester, bundle: bundle, generation: 1);
        expect(
          tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
          'missing',
        );

        applyOptionalAssetAddition(bundle);

        await runWebHotReload(
          tester: tester,
          bundle: bundle,
          changedAssetKeys: [TestAssetPaths.optional],
        );

        expect(
          tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
          'present:added-on-hot-reload',
        );
      });

      testWidgets('delete: optional asset removed after reload', (
        tester,
      ) async {
        applyOptionalAssetAddition(bundle);
        await pumpProbeApp(tester, bundle: bundle, generation: 1);
        expect(
          tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
          contains('present:'),
        );

        removeOptionalAsset(bundle);

        await runWebHotReload(
          tester: tester,
          bundle: bundle,
          changedAssetKeys: [TestAssetPaths.optional],
        );

        expect(
          tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
          'missing',
        );
      });
    });

    group('Hot restart', () {
      testWidgets('change: full remount shows v2 bytes', (tester) async {
        await pumpProbeApp(tester, bundle: bundle, generation: 1);
        await expectProbeV1(tester);

        applyAssetChangeV2(bundle);

        await runWebHotRestart(tester: tester, bundle: bundle, generation: 2);
        await expectProbeV2(tester);
      });

      testWidgets('add: optional asset after restart', (tester) async {
        await pumpProbeApp(tester, bundle: bundle, generation: 1);
        applyOptionalAssetAddition(bundle);
        await runWebHotRestart(tester: tester, bundle: bundle, generation: 2);
        expect(
          tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
          'present:added-on-hot-reload',
        );
      });

      testWidgets('delete: optional asset gone after restart', (tester) async {
        applyOptionalAssetAddition(bundle);
        await pumpProbeApp(tester, bundle: bundle, generation: 1);
        removeOptionalAsset(bundle);
        await runWebHotRestart(tester: tester, bundle: bundle, generation: 2);
        expect(
          tester.widget<Text>(find.byKey(AssetProbeKeys.optionalStatus)).data,
          'missing',
        );
      });
    });
  });

  group('Web integration — bundled example assets (image + JSON string)', () {
    const bundledImage = 'assets/images.jpg';
    const bundledJson = 'assets/abc.json';

    testWidgets('hot reload: image and string still load after cache refresh', (
      tester,
    ) async {
      integrationStep(1, 'Mount app using declared pubspec assets.');
      await tester.pumpWidget(
        const AssetRefresh(
          child: BundledAssetProbeApp(reloadLabel: 'bundled-hot-reload'),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(BundledAssetProbeKeys.imagePresent), findsOneWidget);
      expect(find.byKey(BundledAssetProbeKeys.jsonName), findsOneWidget);
      final nameBefore =
          tester.widget<Text>(find.byKey(BundledAssetProbeKeys.jsonName)).data;
      expect(nameBefore, isNotEmpty);
      expect(nameBefore, isNot('loading'));

      integrationStep(2, 'Evict bundled paths (tool-reported changes).');
      rootBundle.evict(bundledImage);
      rootBundle.evict(bundledJson);

      integrationStep(3, 'Package cache clear + web no-store fetch.');
      await tester.runAsync(() async {
        AssetRefresh.refresh();
        await refreshChangedAssetsOnWeb([bundledImage, bundledJson]);
      });

      integrationStep(4, 'Hot reload reassemble.');
      await tester.binding.reassembleApplication();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(BundledAssetProbeKeys.imagePresent), findsOneWidget);
      final nameAfter =
          tester.widget<Text>(find.byKey(BundledAssetProbeKeys.jsonName)).data;
      expect(nameAfter, nameBefore);
    });

    testWidgets('hot restart: image and string reload from bundle', (
      tester,
    ) async {
      await tester.pumpWidget(
        const AssetRefresh(
          child: BundledAssetProbeApp(reloadLabel: 'bundled-hot-restart-1'),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));
      final nameV1 =
          tester.widget<Text>(find.byKey(BundledAssetProbeKeys.jsonName)).data;

      integrationStep(1, 'Hot restart with fresh widget tree.');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        const AssetRefresh(
          child: BundledAssetProbeApp(reloadLabel: 'bundled-hot-restart-2'),
        ),
      );
      AssetRefresh.refresh();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      expect(find.byKey(BundledAssetProbeKeys.imagePresent), findsOneWidget);
      final nameV2 =
          tester.widget<Text>(find.byKey(BundledAssetProbeKeys.jsonName)).data;
      expect(nameV2, nameV1);
      expect(
        tester.widget<Text>(find.byKey(BundledAssetProbeKeys.reloadLabel)).data,
        'bundled-hot-restart-2',
      );
    });
  });
}