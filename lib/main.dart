import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'data/database/app_database.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final db = AppDatabase();
  final sync = SyncService(db);
  try {
    await sync.start();
  } catch (_) {
    // The app remains usable even if the LAN listener cannot be opened.
  }
  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      syncServiceProvider.overrideWithValue(sync),
    ],
    child: const DeckMasterApp(),
  ));
}

class DeckMasterApp extends ConsumerStatefulWidget {
  const DeckMasterApp({super.key});

  @override
  ConsumerState<DeckMasterApp> createState() => _DeckMasterAppState();
}

class _DeckMasterAppState extends ConsumerState<DeckMasterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncServiceProvider).syncWithDiscoveredPeers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deck Asist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
