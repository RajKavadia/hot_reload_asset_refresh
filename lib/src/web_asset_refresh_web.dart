import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'log.dart';

/// Refreshes the browser cache for assets changed by a hot reload.
///
/// Flutter evicts its own caches, but on the web the engine loads asset bytes
/// with `fetch()`, which the browser may answer from its HTTP cache. Fetching
/// each changed asset again with `cache: 'no-store'` forces a network round trip
/// and ensures the browser never serves a cached copy, so an
/// overwritten image shows its new bytes.
Future<void> refreshChangedAssetsOnWeb(Iterable<String> assets) async {
  final List<String> list = assets.toList(growable: false);
  assetLog('refreshChangedAssetsOnWeb(web): ${list.length} assets $list');
  final List<Future<void>> requests = <Future<void>>[
    for (final String asset in list) _reload(asset),
  ];
  if (requests.isNotEmpty) {
    await Future.wait(requests);
    assetLog('refreshChangedAssetsOnWeb(web): all requests complete');
  }
}

Future<void> _reload(String asset) async {
  final Stopwatch sw = Stopwatch()..start();
  final String url = ui_web.assetManager.getAssetUrl(asset);
  assetLogVerbose('reload: asset=$asset url=$url');
  try {
    await _fetchAsset(asset, url).timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        assetLog('reload: TIMEOUT after ${sw.elapsedMilliseconds}ms url=$url');
      },
    );
  } catch (e, st) {
    assetLog('reload: ERROR asset=$asset url=$url error=$e\n$st');
  } finally {
    sw.stop();
    assetLogVerbose('reload: done asset=$asset elapsed=${sw.elapsedMilliseconds}ms');
  }
}

Future<void> _fetchAsset(String asset, String url) async {
  try {
    final JSObject init = <String, Object?>{'cache': 'no-store'}.jsify() as JSObject;
    assetLogVerbose('fetch(no-store): url=$url');
    final _Response response = _Response._(
      await _fetch(url, init).toDart as JSObject,
    );
    final int status = response.status;
    final bool ok = response.ok;
    final String contentType = _header(response, 'content-type');
    final String cacheControl = _header(response, 'cache-control');
    final String etag = _header(response, 'etag');
    assetLogVerbose(
      'fetch(no-store): url=$url status=$status ok=$ok '
      'content-type=$contentType cache-control=$cacheControl etag=$etag',
    );
    final Uint8List bytes = await _readBytes(response);
    final String fp = _fingerprint(bytes);
    assetLogVerbose(
      'fetch(no-store): url=$url bytes=${bytes.length} fingerprint=$fp',
    );

    // Diagnostic: verify the browser's default cache now serves the same bytes.
    try {
      final _Response verify = _Response._(
        await _fetch(url).toDart as JSObject,
      );
      final Uint8List vbytes = await _readBytes(verify);
      final String vfp = _fingerprint(vbytes);
      final bool same = fp == vfp;
      assetLogVerbose(
        'fetch(default-after-no-store): url=$url status=${verify.status} '
        'bytes=${vbytes.length} fingerprint=$vfp sameAsReload=$same',
      );
      if (!same) {
        assetLogVerbose(
          'fetch(default-after-no-store): MISMATCH url=$url '
          'no-store=$fp default=$vfp',
        );
      }
    } catch (e, st) {
      assetLogVerbose('fetch(default-after-no-store): ERROR url=$url $e\n$st');
    }
  } catch (e, st) {
    assetLog('fetch(no-store): ERROR url=$url error=$e\n$st');
  }
}

Future<Uint8List> _readBytes(_Response response) async {
  final JSAny? buffer = await response.arrayBuffer().toDart;
  if (buffer == null) return Uint8List(0);
  return (buffer as JSArrayBuffer).toDart.asUint8List();
}

String _header(_Response response, String name) {
  try {
    final JSAny? headers = response.headers;
    if (headers == null) return '<no-headers>';
    final JSAny? value = (headers as JSObject).callMethod<JSAny?>(
      'get'.toJS,
      name.toJS,
    );
    return value?.dartify()?.toString() ?? '<null>';
  } catch (e) {
    return '<header-error:$e>';
  }
}

String _fingerprint(Uint8List bytes) {
  final int n = bytes.length;
  final int head = n < 8 ? n : 8;
  final StringBuffer sb = StringBuffer('len=$n head=');
  for (int i = 0; i < head; i++) {
    sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  if (n > 8) {
    sb.write(' tail=');
    final int start = n - 8 < 0 ? 0 : n - 8;
    for (int i = start; i < n; i++) {
      sb.write(bytes[i].toRadixString(16).padLeft(2, '0'));
    }
  }
  // Simple rolling checksum for quick compare.
  int sum = 0;
  for (int i = 0; i < n; i++) {
    sum = (sum + bytes[i]) & 0xFFFFFFFF;
  }
  sb.write(' sum=${sum.toRadixString(16)}');
  return sb.toString();
}

@JS('fetch')
external JSPromise<JSAny?> _fetch(String url, [JSAny? init]);

@JS()
extension type _Response._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> arrayBuffer();
  external int get status;
  external bool get ok;
  external JSAny? get headers;
}
