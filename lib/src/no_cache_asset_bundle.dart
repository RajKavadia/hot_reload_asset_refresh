import 'package:flutter/services.dart';

/// AssetBundle wrapper that appends a cache-busting query parameter to every asset URL.
///
/// This wrapper delegates to an inner [AssetBundle] and adds a cache-busting
/// query parameter (`?_cb=<timestamp>`) to every asset key. This ensures the
/// browser never serves a cached response.
///
/// Usage:
/// ```dart
/// final bundle = NoCacheAssetBundle(rootBundle);
/// final bytes = await bundle.load('assets/image.jpg');
/// ```
///
/// Or wrap the entire app:
/// ```dart
/// runApp(DefaultAssetBundle(
///   bundle: NoCacheAssetBundle(rootBundle),
///   child: MyApp(),
/// ));
/// ```
class NoCacheAssetBundle extends AssetBundle {
  final AssetBundle _delegate;
  final String _buster = DateTime.now().millisecondsSinceEpoch.toString();

  /// Creates a cache-busting wrapper around [delegate].
  NoCacheAssetBundle(AssetBundle delegate) : _delegate = delegate;

  String _bust(String key) => key.contains('?') ? '$key&_cb=$_buster' : '$key?_cb=$_buster';

  @override
  Future<ByteData> load(String key) => _delegate.load(_bust(key));

  @override
  Future<String> loadString(String key, {bool cache = true}) => _delegate.loadString(_bust(key), cache: cache);

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String) parser) =>
      _delegate.loadStructuredData(_bust(key), parser);

  @override
  void clear() => _delegate.clear();

  @override
  void evict(String key) => _delegate.evict(key);
}

/// Wraps the given [AssetBundle] with a cache-busting wrapper if [enabled] is true.
///
/// By default, [enabled] is true unless the user passes
/// `--dart-define=HOT_RELOAD_ASSET_REFRESH_NO_CACHE=false`.
AssetBundle maybeWrapNoCache(AssetBundle bundle) {
  const bool enabled = bool.fromEnvironment('HOT_RELOAD_ASSET_REFRESH_NO_CACHE', defaultValue: true);
  if (enabled) {
    return NoCacheAssetBundle(bundle);
  }
  return bundle;
}