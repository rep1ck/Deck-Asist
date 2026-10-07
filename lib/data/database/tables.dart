import 'package:drift/drift.dart';

@DataClassName('User')
class Users extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get passwordHash => text()();
  TextColumn get fullName => text()();
  TextColumn get role => text()(); // ROOT, MASTER, SECOND, REIS, PERSONEL, INSPECTOR
  IntColumn get isActive => integer().withDefault(const Constant(1))();
  IntColumn get canManageUsers => integer().withDefault(const Constant(0))();
  IntColumn get createdBy => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastLogin => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Job')
class Jobs extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get location => text().nullable()();
  TextColumn get priority => text().withDefault(const Constant('NORMAL'))();
  TextColumn get status => text().withDefault(const Constant('PENDING'))();
  IntColumn get createdBy => integer()();
  DateTimeColumn get startTime => dateTime().nullable()();
  DateTimeColumn get endTime => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('JobAssignment')
class JobAssignments extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  IntColumn get jobId => integer()();
  IntColumn get userId => integer()();
  DateTimeColumn get assignedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('JobPhoto')
class JobPhotos extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  IntColumn get jobId => integer()();
  TextColumn get photoPath => text()();
  IntColumn get uploadedBy => integer()();
  IntColumn get approvedBy => integer().nullable()();
  TextColumn get approvalStatus => text().withDefault(const Constant('PENDING'))();
  TextColumn get description => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('InventoryItem')
class InventoryItems extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get barcode => text().unique()();
  TextColumn get name => text()();
  TextColumn get color => text().nullable()();
  TextColumn get brand => text().withDefault(const Constant('Akzo Nobel / International'))();
  TextColumn get category => text()(); // BOYA, RASPA, KABIN, DIGER
  TextColumn get unit => text().withDefault(const Constant('Lt'))();
  TextColumn get packSize => text().nullable()();
  RealColumn get currentStock => real().withDefault(const Constant(0.0))();
  RealColumn get minStock => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('StockMovement')
class StockMovements extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  IntColumn get itemId => integer()();
  TextColumn get movementType => text()(); // GIRIS, CIKIS, SAYIM, DUZELTME
  RealColumn get quantity => real()();
  IntColumn get userId => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get movementDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MaintenancePlan')
class MaintenancePlans extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  IntColumn get intervalDays => integer()();
  DateTimeColumn get lastDoneDate => dateTime().nullable()();
  DateTimeColumn get nextDueDate => dateTime().nullable()();
  TextColumn get responsibleRole => text().nullable()();
  IntColumn get isActive => integer().withDefault(const Constant(1))();
  IntColumn get createdBy => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MaintenanceRecord')
class MaintenanceRecords extends Table {
  TextColumn get syncId => text().nullable()();
  IntColumn get id => integer().autoIncrement()();
  IntColumn get planId => integer()();
  IntColumn get doneBy => integer()();
  DateTimeColumn get doneDate => dateTime()();
  TextColumn get usedMaterials => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Device')
class Devices extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceName => text()();
  IntColumn get userId => integer().nullable()();
  IntColumn get isLocalServer => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSeen => dateTime().nullable()();
}

@DataClassName('SyncLog')
class SyncLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get tableName => text()();
  IntColumn get recordId => integer()();
  TextColumn get action => text()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  IntColumn get synced => integer().withDefault(const Constant(0))();
}
