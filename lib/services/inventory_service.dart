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
    String unit = 'Lt',
    String? packSize,
    double minStock = 0,
  }) async {
    return await db.into(db.inventoryItems).insert(
          InventoryItemsCompanion.insert(
            syncId: Value(SyncIdentity.newId()),
            barcode: barcode.trim(),
            name: name,
            color: Value(color),
            category: category,
            unit: unit,
            packSize: Value(packSize),
            minStock: Value(minStock),
          ),
        );
  }
}
