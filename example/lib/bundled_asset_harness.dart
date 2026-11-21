import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class BundledAssetProbeKeys {
  static const jsonName = Key('bundled_json_name');
  static const imagePresent = Key('bundled_image_present');
  static const reloadLabel = Key('bundled_reload_label');
}

class BundledAssetProbeApp extends StatefulWidget {
  const BundledAssetProbeApp({super.key, required this.reloadLabel});

  final String reloadLabel;

  @override
  State<BundledAssetProbeApp> createState() => _BundledAssetProbeAppState();
}

class _BundledAssetProbeAppState extends State<BundledAssetProbeApp> {
  late Future<String> _nameFuture;

  @override
  void initState() {
    super.initState();
    _nameFuture = _readName();
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _nameFuture = _readName();
    });
  }

  Future<String> _readName() async {
    final raw = await rootBundle.loadString('assets/abc.json');
    final match = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(raw);
    return match?.group(1) ?? raw;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Text(widget.reloadLabel, key: BundledAssetProbeKeys.reloadLabel),
              const SizedBox(height: 8),
              Image.asset(
                'assets/images.jpg',
                width: 64,
                height: 64,
                key: BundledAssetProbeKeys.imagePresent,
              ),
              FutureBuilder<String>(
                future: _nameFuture,
                builder: (context, snapshot) {
                  final value = snapshot.data ?? 'loading';
                  return Text(value, key: BundledAssetProbeKeys.jsonName);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}