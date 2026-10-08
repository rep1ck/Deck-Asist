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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedRootUser();
          await _seedPaintList();
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
        },
      );

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
          fullName: 'Sistem Yöneticisi',
          role: 'ROOT',
          isActive: const Value(1),
          canManageUsers: const Value(1),
        ),
      );
    }
  }

  Future<void> _seedPaintList() async {
    final existing = await (select(inventoryItems)
          ..where((t) => t.category.equals('BOYA')))
        .get();
    if (existing.isNotEmpty) return;

    final paints = <InventoryItemsCompanion>[
      // Interprime 198
      _paint('DEMO-2001', 'Interprime 198', 'Gri', '5 Lt'),
      _paint('DEMO-2002', 'Interprime 198', 'Gri', '20 Lt'),
      _paint('DEMO-2003', 'Interprime 198', 'Kırmızı Oksit', '5 Lt'),
      _paint('DEMO-2004', 'Interprime 198', 'Kırmızı Oksit', '20 Lt'),
      _paint('DEMO-2005', 'Interprime 198', 'Buff', '5 Lt'),
      // Interbond 201
      _paint('DEMO-2006', 'Interbond 201', 'Gri', '5 Lt'),
      _paint('DEMO-2007', 'Interbond 201', 'Gri', '20 Lt'),
      _paint('DEMO-2008', 'Interbond 201', 'Kırmızı Oksit', '20 Lt'),
      // Intertuf 262
      _paint('DEMO-2009', 'Intertuf 262', 'Gri', '5 Lt'),
      _paint('DEMO-2010', 'Intertuf 262', 'Gri', '20 Lt'),
      _paint('DEMO-2011', 'Intertuf 262', 'Kırmızı Oksit', '5 Lt'),
      _paint('DEMO-2012', 'Intertuf 262', 'Kırmızı Oksit', '20 Lt'),
      // Intergard 263
      _paint('DEMO-2013', 'Intergard 263', 'Gri', '5 Lt'),
      _paint('DEMO-2014', 'Intergard 263', 'Gri', '20 Lt'),
      // Intershield 300
      _paint('DEMO-2015', 'Intershield 300', 'Alüminyum', '5 Lt'),
      _paint('DEMO-2016', 'Intershield 300', 'Alüminyum', '20 Lt'),
      // Intergard 5600
      _paint('DEMO-2017', 'Intergard 5600', 'Gri', '5 Lt'),
      _paint('DEMO-2018', 'Intergard 5600', 'Gri', '20 Lt'),
      // Interlac 665
      _paint('DEMO-2019', 'Interlac 665', 'Beyaz', '5 Lt'),
      _paint('DEMO-2020', 'Interlac 665', 'Beyaz', '20 Lt'),
      _paint('DEMO-2021', 'Interlac 665', 'Off White', '5 Lt'),
      _paint('DEMO-2022', 'Interlac 665', 'Storm Grey', '5 Lt'),
      _paint('DEMO-2023', 'Interlac 665', 'Storm Grey', '20 Lt'),
      _paint('DEMO-2024', 'Interlac 665', 'Haze Grey', '5 Lt'),
      _paint('DEMO-2025', 'Interlac 665', 'Siyah', '5 Lt'),
      _paint('DEMO-2026', 'Interlac 665', 'Signal Red', '5 Lt'),
      _paint('DEMO-2027', 'Interlac 665', 'Ensign Red', '5 Lt'),
      _paint('DEMO-2028', 'Interlac 665', 'Ocean Blue', '5 Lt'),
      _paint('DEMO-2029', 'Interlac 665', 'Signal Blue', '5 Lt'),
      _paint('DEMO-2030', 'Interlac 665', 'Signal Green', '5 Lt'),
      // Interthane 990
      _paint('DEMO-2031', 'Interthane 990', 'Beyaz', '5 Lt'),
      _paint('DEMO-2032', 'Interthane 990', 'Beyaz', '20 Lt'),
      _paint('DEMO-2033', 'Interthane 990', 'Off White', '5 Lt'),
      _paint('DEMO-2034', 'Interthane 990', 'Storm Grey', '5 Lt'),
      _paint('DEMO-2035', 'Interthane 990', 'Storm Grey', '20 Lt'),
      _paint('DEMO-2036', 'Interthane 990', 'Haze Grey', '5 Lt'),
      _paint('DEMO-2037', 'Interthane 990', 'Mid Graphite', '5 Lt'),
      _paint('DEMO-2038', 'Interthane 990', 'Siyah', '5 Lt'),
      _paint('DEMO-2039', 'Interthane 990', 'Signal Red', '5 Lt'),
      _paint('DEMO-2040', 'Interthane 990', 'Ensign Red', '5 Lt'),
      _paint('DEMO-2041', 'Interthane 990', 'Ocean Blue', '5 Lt'),
      _paint('DEMO-2042', 'Interthane 990', 'Signal Blue', '5 Lt'),
      _paint('DEMO-2043', 'Interthane 990', 'Caribbean Blue', '5 Lt'),
      _paint('DEMO-2044', 'Interthane 990', 'Signal Green', '5 Lt'),
      // Intergard 740
      _paint('DEMO-2045', 'Intergard 740', 'Beyaz', '5 Lt'),
      _paint('DEMO-2046', 'Intergard 740', 'Gri', '5 Lt'),
      _paint('DEMO-2047', 'Intergard 740', 'Gri', '20 Lt'),
      _paint('DEMO-2048', 'Intergard 740', 'Siyah', '5 Lt'),
      // Interfine 979
      _paint('DEMO-2049', 'Interfine 979', 'Beyaz', '5 Lt'),
      _paint('DEMO-2050', 'Interfine 979', 'Storm Grey', '5 Lt'),
      _paint('DEMO-2051', 'Interfine 979', 'Siyah', '5 Lt'),
      // Intergard 631 Non-skid
      _paint('DEMO-2052', 'Intergard 631 (Non-skid)', 'Gri', '5 Lt'),
      _paint('DEMO-2053', 'Intergard 631 (Non-skid)', 'Gri', '20 Lt'),
      _paint('DEMO-2054', 'Intergard 631 (Non-skid)', 'Siyah', '5 Lt'),
      _paint('DEMO-2055', 'Intergard 631 (Non-skid)', 'Siyah', '20 Lt'),
      // Interspeed 6400
      _paint('DEMO-2056', 'Interspeed 6400', 'Kırmızı', '5 Lt'),
      _paint('DEMO-2057', 'Interspeed 6400', 'Kırmızı', '20 Lt'),
      _paint('DEMO-2058', 'Interspeed 6400', 'Siyah', '5 Lt'),
      _paint('DEMO-2059', 'Interspeed 6400', 'Siyah', '20 Lt'),
      _paint('DEMO-2060', 'Interspeed 6400', 'Mavi', '5 Lt'),
      _paint('DEMO-2061', 'Interspeed 6400', 'Mavi', '20 Lt'),
      _paint('DEMO-2062', 'Interspeed 6400', 'Navy', '20 Lt'),
      // Interswift 6800HS
      _paint('DEMO-2063', 'Interswift 6800HS', 'Kırmızı', '5 Lt'),
      _paint('DEMO-2064', 'Interswift 6800HS', 'Kırmızı', '20 Lt'),
      _paint('DEMO-2065', 'Interswift 6800HS', 'Siyah', '5 Lt'),
      _paint('DEMO-2066', 'Interswift 6800HS', 'Siyah', '20 Lt'),
      _paint('DEMO-2067', 'Interswift 6800HS', 'Mavi', '20 Lt'),
      // Intersmooth 7460HS SPC
      _paint('DEMO-2068', 'Intersmooth 7460HS SPC', 'Kırmızı', '5 Lt'),
      _paint('DEMO-2069', 'Intersmooth 7460HS SPC', 'Kırmızı', '20 Lt'),
      _paint('DEMO-2070', 'Intersmooth 7460HS SPC', 'Siyah', '5 Lt'),
      _paint('DEMO-2071', 'Intersmooth 7460HS SPC', 'Siyah', '20 Lt'),
      _paint('DEMO-2072', 'Intersmooth 7460HS SPC', 'Mavi', '20 Lt'),
      // Intertherm + Tiner
      _paint('DEMO-2073', 'Intertherm 50', 'Alüminyum', '5 Lt'),
      _paint('DEMO-2074', 'GTA 007', '-', '5 Lt'),
      _paint('DEMO-2075', 'GTA 007', '-', '25 Lt'),
      _paint('DEMO-2076', 'GTA 004', '-', '5 Lt'),
      _paint('DEMO-2077', 'GTA 220', '-', '5 Lt'),
      _paint('DEMO-2078', 'GTA 220', '-', '25 Lt'),
    ];

    await batch((batch) {
      batch.insertAll(inventoryItems, paints);
    });
  }

  Future<void> ensureSyncIds() async {
    final seed = await _deviceNamespace();
    Future<String> make(String table, int id) async => '$seed:$table:$id';

    final usersRows = await select(users).get();
    for (final r in usersRows) {
      if (r.syncId == null || r.syncId!.isEmpty) {
        await (update(users)..where((t) => t.id.equals(r.id))).write(UsersCompanion(syncId: Value(await make('users', r.id)), updatedAt: Value(r.updatedAt)));
      }
    }
    final jobsRows = await select(jobs).get();
    for (final r in jobsRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(jobs)..where((t) => t.id.equals(r.id))).write(JobsCompanion(syncId: Value(await make('jobs', r.id))));
    }
    final assignmentRows = await select(jobAssignments).get();
    for (final r in assignmentRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(jobAssignments)..where((t) => t.id.equals(r.id))).write(JobAssignmentsCompanion(syncId: Value(await make('assignments', r.id))));
    }
    final photoRows = await select(jobPhotos).get();
    for (final r in photoRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(jobPhotos)..where((t) => t.id.equals(r.id))).write(JobPhotosCompanion(syncId: Value(await make('photos', r.id))));
    }
    final commentRows = await select(jobComments).get();
    for (final r in commentRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(jobComments)..where((t) => t.id.equals(r.id))).write(JobCommentsCompanion(syncId: Value(await make('comments', r.id))));
    }
    final inventoryRows = await select(inventoryItems).get();
    for (final r in inventoryRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(inventoryItems)..where((t) => t.id.equals(r.id))).write(InventoryItemsCompanion(syncId: Value(await make('inventory', r.id))));
    }
    final movementRows = await select(stockMovements).get();
    for (final r in movementRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(stockMovements)..where((t) => t.id.equals(r.id))).write(StockMovementsCompanion(syncId: Value(await make('movements', r.id))));
    }
    final planRows = await select(maintenancePlans).get();
    for (final r in planRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(maintenancePlans)..where((t) => t.id.equals(r.id))).write(MaintenancePlansCompanion(syncId: Value(await make('plans', r.id))));
    }
    final recordRows = await select(maintenanceRecords).get();
    for (final r in recordRows) {
      if (r.syncId == null || r.syncId!.isEmpty) await (update(maintenanceRecords)..where((t) => t.id.equals(r.id))).write(MaintenanceRecordsCompanion(syncId: Value(await make('records', r.id))));
    }
  }

  Future<String> _deviceNamespace() async {
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path, 'deck_sync_namespace.txt'));
    if (await file.exists()) return (await file.readAsString()).trim();
    final r = Random.secure();
    final id = List.generate(12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await file.writeAsString(id, flush: true);
    return id;
  }

  InventoryItemsCompanion _paint(
    String barcode,
    String name,
    String color,
    String packSize,
  ) {
    return InventoryItemsCompanion.insert(
      syncId: Value('seed-$barcode'),
      barcode: barcode,
      name: name,
      color: Value(color),
      category: 'BOYA',
      packSize: Value(packSize),
      brand: const Value('Akzo Nobel / International'),
      unit: const Value('Lt'),
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'deck_master.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
