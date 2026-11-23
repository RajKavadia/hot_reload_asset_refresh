import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hot_reload_asset_refresh/hot_reload_asset_refresh.dart';

void main() {
  // REQUIRED on Android/iOS: install the cache-clearing binding BEFORE runApp.
  // The plugin registrant runs before main() when initialLifecycleState is not
  // yet available, so we must install it here. Without this, asset caches are
  // never cleared on hot reload for native platforms (Android/iOS).
  // To see detailed logs: run with `flutter run -dart-define=HOT_RELOAD_ASSET_REFRESH_VERBOSE=true`
  AssetRefreshBinding.ensureInitialized();
  runApp(const MyApp());
}

/// Minimal demo: edit [assets/images.jpg] or [assets/abc.json] and hot reload.
///
/// The example depends on [hot_reload_asset_refresh] via `path: ../`.
/// [AssetRefreshBinding.ensureInitialized] installs the cache-clearing binding;
/// it must run before [runApp].
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
      appBar: AppBar(title: const Text('Asset hot reload demo')),
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
                  'assets/images.jpg',
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'assets/abc.json',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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