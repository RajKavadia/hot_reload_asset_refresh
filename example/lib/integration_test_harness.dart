import 'dart:convert';
import 'dart:typed_data';

import 'package:example/integration_test_support/asset_fingerprint.dart';
import 'package:example/integration_test_support/mutable_asset_bundle.dart';
import 'package:example/integration_test_support/test_asset_paths.dart';
import 'package:flutter/material.dart';

/// Keys used by [integration_test/asset_lifecycle_web_test.dart].
abstract final class AssetProbeKeys {
  static const imageFingerprint = Key('probe_image_fingerprint');
  static const stringValue = Key('probe_string_value');
  static const binaryFingerprint = Key('probe_binary_fingerprint');
  static const jsonVersion = Key('probe_json_version');
  static const optionalStatus = Key('probe_optional_status');
  static const reloadGeneration = Key('probe_reload_generation');
}

/// Web integration harness: all asset types load through [bundle].
class AssetProbeApp extends StatefulWidget {
  const AssetProbeApp({
    super.key,
    required this.bundle,
    required this.generation,
  });

  final MutableAssetBundle bundle;
  final int generation;

  @override
  State<AssetProbeApp> createState() => _AssetProbeAppState();
}

class _AssetProbeAppState extends State<AssetProbeApp> {
  late Future<_ProbeSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _load();
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _snapshot = _load();
    });
  }

  Future<_ProbeSnapshot> _load() {
    return _ProbeSnapshot.load(widget.bundle);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: FutureBuilder<_ProbeSnapshot>(
            future: _snapshot,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }
              if (!snapshot.hasData) {
                return const Text('Loading…', key: Key('probe_loading'));
              }
              final data = snapshot.data!;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'generation=${widget.generation}',
                      key: AssetProbeKeys.reloadGeneration,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.imageFingerprint,
                      key: AssetProbeKeys.imageFingerprint,
                    ),
                    const SizedBox(height: 8),
                    if (data.imageBytes != null)
                      Image.memory(
                        data.imageBytes!,
                        width: 48,
                        height: 48,
                        key: const Key('probe_image_widget'),
                      ),
                    const SizedBox(height: 8),
                    Text(data.stringValue, key: AssetProbeKeys.stringValue),
                    const SizedBox(height: 8),
                    Text(
                      data.binaryFingerprint,
                      key: AssetProbeKeys.binaryFingerprint,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'json.version=${data.jsonVersion}',
                      key: AssetProbeKeys.jsonVersion,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data.optionalStatus,
                      key: AssetProbeKeys.optionalStatus,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProbeSnapshot {
  const _ProbeSnapshot({
    required this.imageFingerprint,
    required this.imageBytes,
    required this.stringValue,
    required this.binaryFingerprint,
    required this.jsonVersion,
    required this.optionalStatus,
  });

  final String imageFingerprint;
  final Uint8List? imageBytes;
  final String stringValue;
  final String binaryFingerprint;
  final int jsonVersion;
  final String optionalStatus;

  static Future<_ProbeSnapshot> load(MutableAssetBundle bundle) async {
    final imageBytes =
        (await bundle.load(TestAssetPaths.image)).buffer.asUint8List();
    final stringValue = await bundle.loadString(TestAssetPaths.string);
    final binaryBytes =
        (await bundle.load(TestAssetPaths.binary)).buffer.asUint8List();
    final jsonMap = await bundle.loadStructuredData<Map<String, Object?>>(
      TestAssetPaths.json,
      (value) async => jsonDecode(value) as Map<String, Object?>,
    );
    final version = (jsonMap['version'] as num?)?.toInt() ?? -1;

    String optionalStatus;
    if (bundle.containsKey(TestAssetPaths.optional)) {
      optionalStatus =
          'present:${await bundle.loadString(TestAssetPaths.optional)}';
    } else {
      optionalStatus = 'missing';
    }

    return _ProbeSnapshot(
      imageFingerprint: assetFingerprint(imageBytes),
      imageBytes: imageBytes,
      stringValue: stringValue,
      binaryFingerprint: assetFingerprint(binaryBytes),
      jsonVersion: version,
      optionalStatus: optionalStatus,
    );
  }
}