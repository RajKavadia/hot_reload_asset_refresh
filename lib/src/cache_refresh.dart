import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Clears the caches that hold decoded images and bundle assets.
///
/// Image widgets resolve their providers again during hot reload, so clearing
/// the caches here makes them decode the updated files.
void clearAssetCaches() {
  PaintingBinding.instance.imageCache
    ..clear()
    ..clearLiveImages();
  rootBundle.clear();
}
