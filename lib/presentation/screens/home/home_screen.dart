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
    final items = <_MenuItem>[
      _MenuItem(
        title: 'Isler',
        subtitle: 'Atama ve takip',
        icon: Icons.work_outline_rounded,
        color: const Color(0xFF3D7A8C),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const JobListScreen()),
        ),
      ),
      _MenuItem(
        title: 'Stok / Sayim',
        subtitle: 'Kategori · barkod',
        icon: Icons.inventory_2_outlined,
        color: const Color(0xFF4A7C59),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StockHubScreen()),
        ),
      ),
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
          subtitle: 'Excel · PDF · Word',
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
          subtitle: 'Yetki yonetimi',
          icon: Icons.people_outline_rounded,
          color: const Color(0xFF6B5B7A),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const UserManagementScreen()),
          ),
        ),
      if (['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(role))
        _MenuItem(
          title: 'LAN Senkron',
          subtitle: 'Ag + arsiv',
          icon: Icons.sync_rounded,
          color: const Color(0xFF2F6F7E),
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
            colors: [
              Color(0xFF1A3A4A),
              Color(0xFF243F4E),
              Color(0xFFE8EEF1),
              Color(0xFFE8EEF1),
            ],
            stops: [0.0, 0.22, 0.22, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 48,
                          height: 48,
                          color: Colors.white24,
                          child: const Icon(Icons.sailing, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            Labels.role(user.role),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Cikis',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Cikis Yap'),
                            content:
                                const Text('Oturumu kapatmak istiyor musunuz?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Hayir'),
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
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: AppColors.mist,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.deepSea.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 1.05,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _AnimatedMenuCard(
                              item: items[index],
                              delayMs: 50 * index,
                            );
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'rep1ck & BY',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _AnimatedMenuCard extends StatefulWidget {
  final _MenuItem item;
  final int delayMs;
  const _AnimatedMenuCard({required this.item, required this.delayMs});

  @override
  State<_AnimatedMenuCard> createState() => _AnimatedMenuCardState();
}

class _AnimatedMenuCardState extends State<_AnimatedMenuCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.white,
          elevation: 2,
          shadowColor: AppColors.deepSea.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
