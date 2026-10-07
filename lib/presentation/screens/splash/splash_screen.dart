import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final db = ref.read(databaseProvider);
      await db.customSelect('SELECT 1').get();
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final currentUser = ref.read(currentUserProvider);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            currentUser == null ? const LoginScreen() : const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_boat, size: 80, color: Colors.blueGrey),
            SizedBox(height: 24),
            Text(
              'Deck Asist',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
