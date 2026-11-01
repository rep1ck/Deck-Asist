import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import '../services/auth_service.dart';
import '../services/job_service.dart';
import '../services/inventory_service.dart';
import '../services/maintenance_service.dart';
import '../services/sync_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) => AppDatabase());

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(databaseProvider));
});

final jobServiceProvider = Provider<JobService>((ref) {
  return JobService(ref.watch(databaseProvider));
});

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.watch(databaseProvider));
});

final maintenanceServiceProvider = Provider<MaintenanceService>((ref) {
  return MaintenanceService(ref.watch(databaseProvider));
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(databaseProvider));
});

final currentUserProvider = StateProvider<User?>((ref) => null);

final usersProvider = FutureProvider.autoDispose<List<User>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await db.select(db.users).get();
});

final jobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.jobs)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
});

final visibleJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final db = ref.watch(databaseProvider);
  final user = ref.watch(currentUserProvider);
  final all = await (db.select(db.jobs)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
  if (user == null) return all;
  if (user.role != 'PERSONEL') return all;
  final assigns = await (db.select(db.jobAssignments)
        ..where((a) => a.userId.equals(user.id)))
      .get();
  final ids = assigns.map((a) => a.jobId).toSet();
  return all.where((j) => ids.contains(j.id)).toList();
});

final inventoryProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.inventoryItems)
        ..orderBy([(t) => OrderingTerm.asc(t.name)]))
      .get();
});

final lowStockProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final items = await ref.watch(inventoryProvider.future);
  return items
      .where((i) => i.minStock > 0 && i.currentStock < i.minStock)
      .toList();
});

final maintenancePlansProvider =
    FutureProvider.autoDispose<List<MaintenancePlan>>((ref) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.maintenancePlans)
        ..where((t) => t.isActive.equals(1))
        ..orderBy([(t) => OrderingTerm.asc(t.nextDueDate)]))
      .get();
});

final overdueMaintenanceProvider =
    FutureProvider.autoDispose<List<MaintenancePlan>>((ref) async {
  final plans = await ref.watch(maintenancePlansProvider.future);
  final now = DateTime.now();
  return plans
      .where((p) => p.nextDueDate != null && p.nextDueDate!.isBefore(now))
      .toList();
});

final openJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final jobs = await ref.watch(visibleJobsProvider.future);
  return jobs
      .where((j) =>
          j.status == 'PENDING' ||
          j.status == 'ASSIGNED' ||
          j.status == 'IN_PROGRESS')
      .toList();
});

final jobPhotosProvider =
    FutureProvider.autoDispose.family<List<JobPhoto>, int>((ref, jobId) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.jobPhotos)
        ..where((p) => p.jobId.equals(jobId))
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .get();
});

final stockMovementsProvider = FutureProvider.autoDispose
    .family<List<StockMovement>, int>((ref, itemId) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.stockMovements)
        ..where((t) => t.itemId.equals(itemId))
        ..orderBy([(t) => OrderingTerm.desc(t.movementDate)]))
      .get();
});

final jobCommentsProvider =
    FutureProvider.autoDispose.family<List<JobComment>, int>((ref, jobId) async {
  final db = ref.watch(databaseProvider);
  return await (db.select(db.jobComments)
        ..where((c) => c.jobId.equals(jobId))
        ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
      .get();
});
