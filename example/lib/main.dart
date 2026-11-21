import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

/// Minimal demo: edit [assets/images.jpg] or [assets/abc.json] and hot reload.
///
/// The example depends on [hot_reload_asset_refresh] via `path: ../` but does
/// not import it; the plugin registers itself in debug builds.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'hot_reload_asset_refresh example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AssetHotReloadDemo(),
    );
  }
}

class AssetHotReloadDemo extends StatefulWidget {
  const AssetHotReloadDemo({super.key});

  @override
  State<AssetHotReloadDemo> createState() => _AssetHotReloadDemoState();
}

class _AssetHotReloadDemoState extends State<AssetHotReloadDemo> {
  late Future<String> _jsonFuture;

  @override
  void initState() {
    super.initState();
    _jsonFuture = rootBundle.loadString('assets/abc.json');
  }

  @override
  void reassemble() {
    super.reassemble();
    setState(() {
      _jsonFuture = rootBundle.loadString('assets/abc.json');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset hot reload demo'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Change assets/images.jpg or assets/abc.json on disk, then hot '
              'reload (r). State below should update without a full restart.',
            ),
            const SizedBox(height: 24),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/image-5.jpg',
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('assets/abc.json', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            FutureBuilder<String>(
              future: _jsonFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const Text('Loading…');
                }
                return SelectableText(snapshot.data!);
              },
            ),
          ],
        ),
      ),
    );
  }
}