import 'dart:typed_data';

/// Stable label for byte identity in expectations.
String assetFingerprint(Uint8List bytes) {
  final head = bytes.length > 6 ? bytes.sublist(0, 6) : bytes;
  final hex = head.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return 'len=${bytes.length}:$hex';
}