import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';

ImageCache get imageCache => PaintingBinding.instance.imageCache;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void addPendingImage(String key) {
    imageCache.putIfAbsent(
      key,
      () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
    );
  }

  setUp(() {
    imageCache
      ..clear()
      ..clearLiveImages();
  });

  test('refresh empties the image cache', () {
    addPendingImage('asset-key');
    expect(imageCache.pendingImageCount, 1);

    AssetRefresh.refresh();

    expect(imageCache.pendingImageCount, 0);
  });

  testWidgets('reassembly refreshes assets and rebuilds the child', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AssetRefresh(child: SizedBox(key: ValueKey('child'))),
    );
    addPendingImage('asset-key');
    expect(imageCache.pendingImageCount, 1);

    // This is what the framework calls on the tree during a hot reload.
    // ignore: invalid_use_of_protected_member
    tester.element(find.byType(AssetRefresh)).reassemble();
    await tester.pump();

    expect(imageCache.pendingImageCount, 0);
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
  });
}
