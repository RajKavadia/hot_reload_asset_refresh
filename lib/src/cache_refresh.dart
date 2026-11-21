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
  cache
    ..clear()
    ..clearLiveImages();
  rootBundle.clear();
  assetLog(
    'clearAssetCaches: done imageCache pending=${cache.pendingImageCount} '
    'live=${cache.liveImageCount} currentSize=${cache.currentSize}',
  );
}
