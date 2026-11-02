import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bildirim basarisiz olsa bile uygulama acilsin
  try {
    await NotificationService.init();
  } catch (e, st) {
    debugPrint('NotificationService.init hata: $e\n$st');
  }

  AppDatabase? db;
  try {
    db = AppDatabase();
  } catch (e, st) {
    debugPrint('AppDatabase acilis hata: $e\n$st');
    runApp(_BootErrorApp('Veritabani acilamadi: $e'));
    return;
  }

  final sync = SyncService(db);

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        syncServiceProvider.overrideWithValue(sync),
      ],
      child: DeckMasterApp(sync: sync),
    ),
  );
}

class DeckMasterApp extends ConsumerStatefulWidget {
  final SyncService sync;
  const DeckMasterApp({super.key, required this.sync});

  @override
  ConsumerState<DeckMasterApp> createState() => _DeckMasterAppState();
}

class _DeckMasterAppState extends ConsumerState<DeckMasterApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // LAN senkronu UI acildiktan sonra baslasin (acilisi engellemesin)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await widget.sync.start();
      } catch (e, st) {
        debugPrint('SyncService.start hata: $e\n$st');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.sync.syncWithDiscoveredPeers());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deck Asist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}

class _BootErrorApp extends StatelessWidget {
  final String message;
  const _BootErrorApp(this.message);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Deck Asist baslatilamadi.\n\n$message',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
