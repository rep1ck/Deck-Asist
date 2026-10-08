import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../auth/login_screen.dart';
import '../inventory/inventory_list_screen.dart';
import '../jobs/job_list_screen.dart';
import '../maintenance/maintenance_list_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/user_management_screen.dart';
import '../sync/sync_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = user.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deck Asist'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(
              child: Text(
                '${user.fullName} • ${Labels.role(user.role)}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Çıkış',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text('Oturumu kapatmak istiyor musunuz?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hayır'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Evet'),
                    ),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                ref.read(currentUserProvider.notifier).state = null;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: [
          _MenuCard(
            title: 'İşler',
            icon: Icons.work,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JobListScreen()),
            ),
          ),
          _MenuCard(
            title: 'Stok / Boya',
            icon: Icons.inventory_2,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryListScreen()),
            ),
          ),
          _MenuCard(
            title: 'Planlı Bakım',
            icon: Icons.build,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MaintenanceListScreen()),
            ),
          ),
          if (['ROOT', 'MASTER', 'SECOND', 'REIS', 'INSPECTOR'].contains(role))
            _MenuCard(
              title: 'Raporlar',
              icon: Icons.assessment,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportsScreen()),
              ),
            ),
          if (['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(role))
            _MenuCard(
              title: 'Kullanıcı Yönetimi',
              icon: Icons.people,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              ),
            ),
          if (['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(role))
            _MenuCard(
              title: 'LAN Senkron',
              icon: Icons.sync,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncScreen()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'Deck Asist • Geliştiren: rep1ck & BY',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.black45),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
