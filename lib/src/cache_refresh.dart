import 'dart:developer' as dev;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import 'log.dart';

/// Clears the caches that hold decoded images and bundle assets.
///
/// Image widgets resolve their providers again during hot reload, so clearing
/// the caches here makes them decode the updated files.
void clearAssetCaches() {
  final ImageCache cache = PaintingBinding.instance.imageCache;
  assetLog(
    'clearAssetCaches: imageCache pending=${cache.pendingImageCount} '
    'live=${cache.liveImageCount} currentSize=${cache.currentSize} '
    'currentSizeBytes=${cache.currentSizeBytes}',
  );
  // Debug: log cache state before clearing
  dev.log('🔧 clearAssetCaches START: pending=${cache.pendingImageCount} live=${cache.liveImageCount} size=${cache.currentSize} bytes=${cache.currentSizeBytes}', name: 'asset_refresh');
  cache
    ..clear()
    ..clearLiveImages();
  rootBundle.clear();
  // Debug: log cache state after clearing
  dev.log('🔧 clearAssetCaches DONE: pending=${cache.pendingImageCount} live=${cache.liveImageCount} size=${cache.currentSize} bytes=${cache.currentSizeBytes}', name: 'asset_refresh');
  assetLog(
    'clearAssetCaches: done imageCache pending=${cache.pendingImageCount} '
    'live=${cache.liveImageCount} currentSize=${cache.currentSize}',
  );
}
