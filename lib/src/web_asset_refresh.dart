import 'log.dart';

/// Refreshes asset bytes cached by the browser.
///
/// Overridden with a web implementation on platforms that support it.
Future<void> refreshChangedAssetsOnWeb(Iterable<String> assets) async {
  final List<String> list = assets.toList(growable: false);
  assetLog(
    'refreshChangedAssetsOnWeb (stub/non-web): ${list.length} assets $list',
  );
}
