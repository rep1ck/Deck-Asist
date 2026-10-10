import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import '../core/utils/sync_identity.dart';

class InventoryService {
  final AppDatabase db;
  InventoryService(this.db);

  Future<InventoryItem?> findByBarcode(String barcode) async {
    return await (db.select(db.inventoryItems)
          ..where((t) => t.barcode.equals(barcode.trim())))
        .getSingleOrNull();
  }

  Future<void> addMovement({
    required int itemId,
    required String movementType,
    required double quantity,
    required int userId,
    String? note,
  }) async {
    await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
          syncId: Value(SyncIdentity.newId()),
          itemId: itemId,
          movementType: movementType,
          quantity: quantity,
          userId: userId,
          note: Value(note),
        ));

    final item = await (db.select(db.inventoryItems)
          ..where((t) => t.id.equals(itemId)))
        .getSingle();

    double newStock = item.currentStock;
    if (movementType == 'GIRIS') {
      newStock += quantity;
    } else if (movementType == 'CIKIS') {
      newStock -= quantity;
    } else if (movementType == 'SAYIM' || movementType == 'DUZELTME') {
      newStock = quantity;
    }
    if (newStock < 0) newStock = 0;

    await (db.update(db.inventoryItems)..where((t) => t.id.equals(itemId)))
        .write(InventoryItemsCompanion(
      currentStock: Value(newStock),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<int> createItem({
    required String barcode,
    required String name,
    String? color,
    String category = 'BOYA',
    String unit = 'Adet',
    String? packSize,
    double unitsPerPack = 1,
    double minStock = 0,
  }) async {
    return await db.into(db.inventoryItems).insert(
          InventoryItemsCompanion.insert(
            syncId: Value(SyncIdentity.newId()),
            barcode: barcode.trim(),
            name: name,
            color: Value(color),
            category: category,
            unit: Value(unit),
            packSize: Value(packSize),
            unitsPerPack: Value(unitsPerPack <= 0 ? 1 : unitsPerPack),
            minStock: Value(minStock),
          ),
        );
  }

  Future<bool> updateItem({
    required int itemId,
    required String barcode,
    required String name,
    String? color,
    String? category,
    String? unit,
    String? packSize,
    double? unitsPerPack,
    double? minStock,
  }) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty || name.trim().isEmpty) return false;

    final conflict = await (db.select(db.inventoryItems)
          ..where((t) => t.barcode.equals(trimmed) & t.id.equals(itemId).not()))
        .getSingleOrNull();
    if (conflict != null) return false;

    await (db.update(db.inventoryItems)..where((t) => t.id.equals(itemId)))
        .write(InventoryItemsCompanion(
      barcode: Value(trimmed),
      name: Value(name.trim()),
      color: Value(color),
      category: category != null ? Value(category) : const Value.absent(),
      unit: unit != null ? Value(unit) : const Value.absent(),
      packSize: Value(packSize),
      unitsPerPack: unitsPerPack != null
          ? Value(unitsPerPack <= 0 ? 1 : unitsPerPack)
          : const Value.absent(),
      minStock: minStock != null ? Value(minStock) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));
    return true;
  }

  Future<({int added, int updated, int skipped, List<String> errors})>
      importFromExcelRows(List<List<String>> rows) async {
    int added = 0, updated = 0, skipped = 0;
    final errors = <String>[];
    if (rows.isEmpty) {
      return (added: 0, updated: 0, skipped: 0, errors: ['Bos dosya']);
    }

    var start = 0;
    final h0 = rows.first.isNotEmpty ? rows.first[0].toLowerCase().trim() : '';
    if (h0.contains('barkod') || h0.contains('barcode')) {
      start = 1;
    }

    for (var i = start; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty) continue;
      final barcode = row[0].trim();
      if (barcode.isEmpty) {
        skipped++;
        continue;
      }
      try {
        final name = row.length > 1 ? row[1].trim() : '';
        if (name.isEmpty) {
          errors.add('Satir ${i + 1}: urun adi bos ($barcode)');
          skipped++;
          continue;
        }
        String category =
            row.length > 2 ? row[2].trim().toUpperCase() : 'DIGER';
        const catMap = {
          'BOYA': 'BOYA',
          'KUMANYA': 'KUMANYA',
          'KABIN': 'KABIN',
          'KABIN MALZEMELERI': 'KABIN',
          'RASPA': 'RASPA',
          'EL_ALETI': 'EL_ALETI',
          'EL ALETI': 'EL_ALETI',
          'ELEKTRIKLI': 'EL_ALETI',
          'KKD': 'KKD',
          'DIGER': 'DIGER',
        };
        category = catMap[category] ?? 'DIGER';

        final unit = row.length > 3 && row[3].trim().isNotEmpty
            ? row[3].trim()
            : 'Adet';
        final packSize =
            row.length > 4 && row[4].trim().isNotEmpty ? row[4].trim() : null;
        final unitsPerPack = row.length > 5
            ? (double.tryParse(row[5].replaceAll(',', '.')) ?? 1.0)
            : 1.0;
        final color =
            row.length > 6 && row[6].trim().isNotEmpty ? row[6].trim() : null;
        final minStock = row.length > 7
            ? (double.tryParse(row[7].replaceAll(',', '.')) ?? 0.0)
            : 0.0;
        final stock = row.length > 8
            ? (double.tryParse(row[8].replaceAll(',', '.')) ?? 0.0)
            : 0.0;

        final existing = await findByBarcode(barcode);
        if (existing != null) {
          await updateItem(
            itemId: existing.id,
            barcode: barcode,
            name: name,
            color: color,
            category: category,
            unit: unit,
            packSize: packSize,
            unitsPerPack: unitsPerPack,
            minStock: minStock,
          );
          if (stock > 0) {
            await (db.update(db.inventoryItems)
                  ..where((t) => t.id.equals(existing.id)))
                .write(InventoryItemsCompanion(
              currentStock: Value(stock),
              updatedAt: Value(DateTime.now()),
            ));
          }
          updated++;
        } else {
          final id = await createItem(
            barcode: barcode,
            name: name,
            color: color,
            category: category,
            unit: unit,
            packSize: packSize,
            unitsPerPack: unitsPerPack,
            minStock: minStock,
          );
          if (stock > 0) {
            await (db.update(db.inventoryItems)..where((t) => t.id.equals(id)))
                .write(InventoryItemsCompanion(
              currentStock: Value(stock),
              updatedAt: Value(DateTime.now()),
            ));
          }
          added++;
        }
      } catch (e) {
        errors.add('Satir ${i + 1}: $e');
        skipped++;
      }
    }
    return (added: added, updated: updated, skipped: skipped, errors: errors);
  }
}
