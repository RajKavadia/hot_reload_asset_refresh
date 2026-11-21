import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// In-memory bundle for web integration tests.
class MutableAssetBundle extends AssetBundle {
  MutableAssetBundle([Map<String, Uint8List>? seed]) {
    if (seed != null) {
      _assets.addAll(seed);
    }
  }

  final Map<String, Uint8List> _assets = <String, Uint8List>{};

  bool containsKey(String key) => _assets.containsKey(key);

  void put(String key, Uint8List bytes) {
    _assets[key] = Uint8List.fromList(bytes);
  }

  void remove(String key) {
    _assets.remove(key);
  }

  @override
  Future<ByteData> load(String key) async {
    final bytes = _assets[key];
    if (bytes == null) {
      throw FlutterError('Unable to load asset "$key".');
    }
    return ByteData.sublistView(bytes);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final data = await load(key);
    return utf8.decode(data.buffer.asUint8List());
  }

  @override
  void evict(String key) {}

  @override
  void clear() {}
}