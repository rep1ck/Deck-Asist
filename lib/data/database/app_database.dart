import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/password_utils.dart';
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Users,
  Jobs,
  JobAssignments,
  JobPhotos,
  JobComments,
  InventoryItems,
  StockMovements,
  MaintenancePlans,
  MaintenanceRecords,
  Devices,
  SyncLogs,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedRootUser();
          await _seedCrewUsers();
          // DEMO boya listesi otomatik yuklenmez
          await ensureSyncIds();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.addColumn(users, users.syncId);
            await m.addColumn(users, users.updatedAt);
            await m.addColumn(jobs, jobs.syncId);
            await m.addColumn(jobAssignments, jobAssignments.syncId);
            await m.addColumn(jobPhotos, jobPhotos.syncId);
            await m.addColumn(jobPhotos, jobPhotos.updatedAt);
            await m.addColumn(inventoryItems, inventoryItems.syncId);
            await m.addColumn(stockMovements, stockMovements.syncId);
            await m.addColumn(maintenancePlans, maintenancePlans.syncId);
            await m.addColumn(maintenancePlans, maintenancePlans.updatedAt);
            await m.addColumn(maintenanceRecords, maintenanceRecords.syncId);
            await ensureSyncIds();
          }
          if (from < 3) {
            await m.createTable(jobComments);
          }
          if (from < 4) {
            await m.addColumn(inventoryItems, inventoryItems.unitsPerPack);
          }
          if (from < 5) {
            await _seedCrewUsers();
          }
          if (from < 6) {
            await m.addColumn(jobPhotos, jobPhotos.photoPhase);
          }
          if (from < 7) {
            await m.addColumn(jobs, jobs.jobCategory);
            await m.addColumn(jobs, jobs.weatherNote);
          }
        },
      );

  Future<void> _seedCrewUsers() async {
    Future<void> ensure({
      required String username,
      required String password,
      required String fullName,
      required String role,
      int canManageUsers = 0,
    }) async {
      final existing = await (select(users)
            ..where((u) => u.username.equals(username)))
          .getSingleOrNull();
      if (existing != null) return;
      await into(users).insert(
        UsersCompanion.insert(
          syncId: Value('seed-' + username),
          username: username,
          passwordHash: PasswordUtils.hash(password),
          fullName: fullName,
          role: role,
          isActive: const Value(1),
          canManageUsers: Value(canManageUsers),
        ),
      );
    }

    await ensure(
      username: 'master@zeynepc.arkas',
      password: '654321',
      fullName: 'Suvari / Master',
      role: 'MASTER',
      canManageUsers: 1,
    );
    await ensure(
      username: 'chief@zeynepc.arkas',
      password: '654321',
      fullName: '2. Kaptan',
      role: 'SECOND',
      canManageUsers: 1,
    );
    await ensure(
      username: 'bosun@zeynepc.arkas',
      password: '123456',
      fullName: 'Guverte Reisi',
      role: 'REIS',
      canManageUsers: 1,
    );
    await ensure(
      username: 'ab1@zeynepc.arkas',
      password: '123456',
      fullName: 'Fenerci',
      role: 'PERSONEL',
    );
    await ensure(
      username: 'ab2@zeynepc.arkas',
      password: '123456',
      fullName: 'Usta Gemici',
      role: 'PERSONEL',
    );
  }

  Future<void> _seedRootUser() async {
    final existing = await (select(users)
          ..where((u) => u.username.equals('root@zeynepc.arkas')))
        .getSingleOrNull();

    if (existing == null) {
      await into(users).insert(
        UsersCompanion.insert(
          syncId: Value('seed-root-user'),
          username: 'root@zeynepc.arkas',
          passwordHash: PasswordUtils.hash('zeynepcroot'),
          fullName: 'Sistem Yoneticisi',
          role: 'ROOT',
          isActive: const Value(1),
          canManageUsers: const Value(1),
        ),
      );
    }
  }

  Future<void> ensureSyncIds() async {
    final seed = await _deviceNamespace();
    Future<String> make(String table, int id) async => '$seed:$table:$id';

    final usersRows = await select(users).get();
    for (final r in usersRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(users)..where((t) => t.id.equals(r.id))).write(
            UsersCompanion(
                syncId: Value(await make('users', r.id)),
                updatedAt: Value(r.updatedAt)));
      }
    }
    final jobsRows = await select(jobs).get();
    for (final r in jobsRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(jobs)..where((t) => t.id.equals(r.id))).write(
            JobsCompanion(syncId: Value(await make('jobs', r.id))));
      }
    }
    final assignmentRows = await select(jobAssignments).get();
    for (final r in assignmentRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(jobAssignments)..where((t) => t.id.equals(r.id))).write(
            JobAssignmentsCompanion(
                syncId: Value(await make('assignments', r.id))));
      }
    }
    final photoRows = await select(jobPhotos).get();
    for (final r in photoRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(jobPhotos)..where((t) => t.id.equals(r.id))).write(
            JobPhotosCompanion(syncId: Value(await make('photos', r.id))));
      }
    }
    final commentRows = await select(jobComments).get();
    for (final r in commentRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(jobComments)..where((t) => t.id.equals(r.id))).write(
            JobCommentsCompanion(
                syncId: Value(await make('comments', r.id))));
      }
    }
    final inventoryRows = await select(inventoryItems).get();
    for (final r in inventoryRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(inventoryItems)..where((t) => t.id.equals(r.id))).write(
            InventoryItemsCompanion(
                syncId: Value(await make('inventory', r.id))));
      }
    }
    final movementRows = await select(stockMovements).get();
    for (final r in movementRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(stockMovements)..where((t) => t.id.equals(r.id))).write(
            StockMovementsCompanion(
                syncId: Value(await make('movements', r.id))));
      }
    }
    final planRows = await select(maintenancePlans).get();
    for (final r in planRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(maintenancePlans)..where((t) => t.id.equals(r.id))).write(
            MaintenancePlansCompanion(
                syncId: Value(await make('plans', r.id))));
      }
    }
    final recordRows = await select(maintenanceRecords).get();
    for (final r in recordRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(maintenanceRecords)..where((t) => t.id.equals(r.id)))
            .write(MaintenanceRecordsCompanion(
                syncId: Value(await make('records', r.id))));
      }
    }
  }

  Future<String> _deviceNamespace() async {
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path, 'deck_sync_namespace.txt'));
    if (await file.exists()) return (await file.readAsString()).trim();
    final r = Random.secure();
    final id = List.generate(
            12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    await file.writeAsString(id, flush: true);
    return id;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'deck_master.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
