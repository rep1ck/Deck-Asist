import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/labels.dart';
import '../auth/login_screen.dart';
import '../inventory/stock_hub_screen.dart';
import '../jobs/job_list_screen.dart';
import '../maintenance/maintenance_list_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/user_management_screen.dart';
import '../settings/ship_settings_screen.dart';
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
    final isPersonel = role == 'PERSONEL';
    final openJobs = ref.watch(openJobsProvider);
    final lowStock = ref.watch(lowStockProvider);
    final overdue = ref.watch(overdueMaintenanceProvider);

    final items = <_MenuItem>[
      _MenuItem(
        title: isPersonel ? 'Is lerim' : 'Isler',
        subtitle: isPersonel ? 'Atanan isler' : 'Atama ve takip',
        icon: Icons.work_outline_rounded,
        color: const Color(0xFF3D7A8C),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JobListScreen()),
        ),
      ),
      _MenuItem(
        title: isPersonel ? 'Sayim' : 'Stok / Sayim',
        subtitle: isPersonel ? 'Barkod sayim' : 'Kategori · barkod',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF4A7C59),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StockHubScreen()),
        ),
      ),
      if (!isPersonel)
        _MenuItem(
          title: 'Planli Bakim',
          subtitle: 'Hatirlatmalar',
          icon: Icons.build_outlined,
          color: const Color(0xFF8B6B3D),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MaintenanceListScreen()),
          ),
        ),
      if (['ROOT', 'MASTER', 'SECOND', 'REIS', 'INSPECTOR'].contains(role))
        _MenuItem(
          title: 'Raporlar',
          subtitle: 'PDF · tarih araligi',
          icon: Icons.assessment_outlined,
          color: const Color(0xFF5C6B8A),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsScreen()),
          ),
        ),
      if (['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(role))
        _MenuItem(
          title: 'Kullanicilar',
          subtitle: 'Rol ve sifre',
          icon: Icons.people_outline,
          color: const Color(0xFF6B5B7A),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserManagementScreen()),
          ),
        ),
      if (['ROOT', 'MASTER', 'SECOND'].contains(role))
        _MenuItem(
          title: 'Gemi Ayarlari',
          subtitle: 'Isim · imza · kurallar',
          icon: Icons.sailing,
          color: const Color(0xFF2F6F7E),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShipSettingsScreen()),
          ),
        ),
      _MenuItem(
        title: 'LAN Sync',
        subtitle: 'Ayni ag paylasim',
        icon: Icons.sync,
        color: const Color(0xFF5A6F7A),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SyncScreen()),
        ),
      ),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0E2A36), Color(0xFF1A3A4A), Color(0xFFE8EEF1)],
            stops: [0, 0.28, 0.28],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    const Icon(Icons.sailing, color: Colors.white, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deck Asist',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${user.fullName} · ${Labels.role(role)}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white70),
                      onPressed: () {
                        ref.read(currentUserProvider.notifier).state = null;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _DashCard(
                        label: 'Acik is',
                        value: openJobs.when(
                          data: (l) => '${l.length}',
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        color: const Color(0xFF3D7A8C),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashCard(
                        label: 'Geciken bakim',
                        value: overdue.when(
                          data: (l) => '${l.length}',
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        color: const Color(0xFFB85C38),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DashCard(
                        label: 'Dusuk stok',
                        value: lowStock.when(
                          data: (l) => '${l.length}',
                          loading: () => '...',
                          error: (_, __) => '-',
                        ),
                        color: const Color(0xFF8B6B3D),
                      ),
                    ),
                  ],
                ),
              ),
              lowStock.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Material(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.warning_amber,
                            color: Color(0xFFB85C38)),
                        title: Text(
                          'Kritik stok: ${list.take(3).map((e) => e.name).join(", ")}'
                          '${list.length > 3 ? " +" : ""}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const StockHubScreen()),
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8EEF1),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.15,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final m = items[i];
                      return Material(
                        color: Colors.white,
                        elevation: 1.5,
                        shadowColor: AppColors.deepSea.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: m.onTap,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: m.color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(m.icon, color: m.color),
                                ),
                                const Spacer(),
                                Text(m.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                                Text(m.subtitle,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600)),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'rep1ck ve BY',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _DashCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.85), fontSize: 11)),
        ],
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
