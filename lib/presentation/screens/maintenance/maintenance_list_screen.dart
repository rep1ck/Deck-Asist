import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/maintenance_service.dart';
import 'create_maintenance_plan_screen.dart';

class MaintenanceListScreen extends ConsumerWidget {
  const MaintenanceListScreen({super.key});

  Color _statusColor(DateTime? nextDue) {
    if (nextDue == null) return Colors.grey;
    final days = nextDue.difference(DateTime.now()).inDays;
    if (days < 0) return Colors.red;
    if (days <= 7) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(maintenancePlansProvider);
    final currentUser = ref.watch(currentUserProvider)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planlı Bakımlar'),
        actions: [
          if (['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(currentUser.role))
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateMaintenancePlanScreen(),
                  ),
                ).then((_) => ref.invalidate(maintenancePlansProvider));
              },
            ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('Henüz bakım planı yok'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              final color = _statusColor(plan.nextDueDate);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: color, radius: 8),
                  title: Text(plan.title),
                  subtitle: Text(
                    'Sonraki: ${plan.nextDueDate?.toString().substring(0, 10) ?? "-"} | ${plan.intervalDays} gün',
                  ),
                  trailing: ['ROOT', 'MASTER', 'SECOND', 'REIS']
                          .contains(currentUser.role)
                      ? IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          tooltip: 'Tamamla',
                          onPressed: () async {
                            final service =
                                MaintenanceService(ref.read(databaseProvider));
                            await service.completeMaintenance(
                              planId: plan.id,
                              doneById: currentUser.id,
                            );
                            ref.invalidate(maintenancePlansProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Bakım tamamlandı')),
                              );
                            }
                          },
                        )
                      : null,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}
