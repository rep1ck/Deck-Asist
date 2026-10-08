import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import 'barcode_scan_screen.dart';
import 'edit_inventory_item_screen.dart';
import 'stock_movement_screen.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final canEdit = ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(user.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok / Boya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Barkod Okut',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
              ).then((_) => ref.invalidate(inventoryProvider));
            },
          ),
        ],
      ),
      body: inventoryAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('Stok kaydı yok'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isLow =
                  item.currentStock <= item.minStock && item.minStock > 0;
              return Card(
                color: isLow ? Colors.red.shade50 : null,
                child: ListTile(
                  title: Text('${item.name} ${item.color ?? ''}'.trim()),
                  subtitle: Text(
                    'Stok: ${item.currentStock} ${item.unit}'
                    ' | ${Labels.category(item.category)}'
                    ' | ${item.packSize ?? "-"}'
                    '\nBarkod: ${item.barcode}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLow)
                        const Icon(Icons.warning, color: Colors.red, size: 20),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'move') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    StockMovementScreen(item: item),
                              ),
                            ).then((_) => ref.invalidate(inventoryProvider));
                          } else if (v == 'edit' && canEdit) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditInventoryItemScreen(item: item),
                              ),
                            ).then((_) => ref.invalidate(inventoryProvider));
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'move',
                            child: Text('Stok hareketi'),
                          ),
                          if (canEdit)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Düzenle'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockMovementScreen(item: item),
                      ),
                    ).then((_) => ref.invalidate(inventoryProvider));
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
          ).then((_) => ref.invalidate(inventoryProvider));
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Barkod Okut'),
      ),
    );
  }
}
