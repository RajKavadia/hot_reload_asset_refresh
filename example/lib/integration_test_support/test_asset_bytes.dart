import 'dart:convert';
import 'dart:typed_data';

import 'asset_fingerprint.dart';
import 'mutable_asset_bundle.dart';
import 'test_asset_paths.dart';

MutableAssetBundle createSeedBundleV1() {
  return MutableAssetBundle({
    TestAssetPaths.image: TestAssetBytes.pngRedV1,
    TestAssetPaths.string: TestAssetBytes.stringV1,
    TestAssetPaths.binary: TestAssetBytes.binaryV1,
    TestAssetPaths.json: TestAssetBytes.jsonV1,
  });
}

void applyAssetChangeV2(MutableAssetBundle bundle) {
  bundle.put(TestAssetPaths.image, TestAssetBytes.pngGreenV2);
  bundle.put(TestAssetPaths.string, TestAssetBytes.stringV2);
  bundle.put(TestAssetPaths.binary, TestAssetBytes.binaryV2);
  bundle.put(TestAssetPaths.json, TestAssetBytes.jsonV2);
}

void applyOptionalAssetAddition(MutableAssetBundle bundle) {
  bundle.put(TestAssetPaths.optional, TestAssetBytes.optionalV1);
}

void removeOptionalAsset(MutableAssetBundle bundle) {
  bundle.remove(TestAssetPaths.optional);
}

abstract final class TestAssetBytes {
  static final Uint8List pngRedV1 = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
    'hQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  static final Uint8List pngGreenV2 = () {
    final copy = Uint8List.fromList(pngRedV1);
    copy[copy.length ~/ 2] ^= 0xFF;
    return copy;
  }();

  static final Uint8List stringV1 = Uint8List.fromList(utf8.encode('hello-v1'));
  static final Uint8List stringV2 = Uint8List.fromList(utf8.encode('hello-v2'));

  static final Uint8List binaryV1 = Uint8List.fromList([1, 2, 3, 4]);
  static final Uint8List binaryV2 = Uint8List.fromList([9, 8, 7, 6]);

  static final Uint8List jsonV1 =
      Uint8List.fromList(utf8.encode('{"version":1,"kind":"structured"}'));
  static final Uint8List jsonV2 =
      Uint8List.fromList(utf8.encode('{"version":2,"kind":"structured"}'));

  static final Uint8List optionalV1 =
      Uint8List.fromList(utf8.encode('added-on-hot-reload'));
}

abstract final class TestAssetExpectations {
  static String imageV1() => assetFingerprint(TestAssetBytes.pngRedV1);
  static String imageV2() => assetFingerprint(TestAssetBytes.pngGreenV2);
  static String binaryV1() => assetFingerprint(TestAssetBytes.binaryV1);
  static String binaryV2() => assetFingerprint(TestAssetBytes.binaryV2);
}