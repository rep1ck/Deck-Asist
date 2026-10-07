import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import 'notification_service.dart';
import '../core/utils/sync_identity.dart';

class MaintenanceService {
  final AppDatabase db;
  MaintenanceService(this.db);

  Future<int> createPlan({
    required String title,
    String? description,
    required int intervalDays,
    DateTime? lastDoneDate,
    String? responsibleRole,
    required int createdById,
  }) async {
    final nextDue = lastDoneDate != null
        ? lastDoneDate.add(Duration(days: intervalDays))
        : DateTime.now().add(Duration(days: intervalDays));

    return await db.into(db.maintenancePlans).insert(
          MaintenancePlansCompanion.insert(
            syncId: Value(SyncIdentity.newId()),
            title: title,
            description: Value(description),
            intervalDays: intervalDays,
            lastDoneDate: Value(lastDoneDate),
            nextDueDate: Value(nextDue),
            responsibleRole: Value(responsibleRole),
            createdBy: createdById,
          ),
        );
  }

  Future<void> completeMaintenance({
    required int planId,
    required int doneById,
    DateTime? doneDate,
    String? usedMaterials,
    String? notes,
    String? photoPath,
  }) async {
    final plan = await (db.select(db.maintenancePlans)
          ..where((t) => t.id.equals(planId)))
        .getSingle();
    final completedDate = doneDate ?? DateTime.now();

    await db.into(db.maintenanceRecords).insert(
          MaintenanceRecordsCompanion.insert(
            syncId: Value(SyncIdentity.newId()),
            planId: planId,
            doneBy: doneById,
            doneDate: completedDate,
            usedMaterials: Value(usedMaterials),
            notes: Value(notes),
            photoPath: Value(photoPath),
          ),
        );

    final nextDue = completedDate.add(Duration(days: plan.intervalDays));

    await (db.update(db.maintenancePlans)..where((t) => t.id.equals(planId)))
        .write(MaintenancePlansCompanion(
      lastDoneDate: Value(completedDate),
      nextDueDate: Value(nextDue),
      updatedAt: Value(DateTime.now()),
    ));

    await NotificationService.maintenanceCompleted(
      planId: planId,
      title: plan.title,
    );
  }

  Future<void> checkAndNotifyDueMaintenances() async {
    final plans = await (db.select(db.maintenancePlans)
          ..where((t) => t.isActive.equals(1)))
        .get();
    final now = DateTime.now();

    for (final plan in plans) {
      if (plan.nextDueDate == null) continue;
      final daysLeft = plan.nextDueDate!.difference(now).inDays;
      if (daysLeft <= 7) {
        await NotificationService.maintenanceDue(
          planId: plan.id,
          title: plan.title,
          daysLeft: daysLeft,
        );
      }
    }
  }
}
