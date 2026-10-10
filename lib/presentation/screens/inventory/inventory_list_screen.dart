import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import 'barcode_scan_screen.dart';
import 'edit_inventory_item_screen.dart';
import 'stock_movement_screen.dart';

class InventoryListScreen extends ConsumerWidget {
  final String? categoryFilter;
  final String title;

  const InventoryListScreen({
    super.key,
    this.categoryFilter,
    this.title = 'Stok Listesi',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final user = ref.watch(currentUserProvider)!;
    final canEdit = ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(user.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
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
          final filtered = categoryFilter == null
              ? items
              : items.where((i) => i.category == categoryFilter).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                categoryFilter == null
                    ? 'Stok kaydi yok'
                    : '${Labels.category(categoryFilter!)} kategorisinde urun yok',
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
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
                      IconButton(
                        icon: const Icon(Icons.swap_vert),
                        tooltip: 'Stok hareketi',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StockMovementScreen(item: item),
                            ),
                          ).then((_) => ref.invalidate(inventoryProvider));
                        },
                      ),
                      if (canEdit)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Duzenle',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    EditInventoryItemScreen(item: item),
                              ),
                            ).then((_) => ref.invalidate(inventoryProvider));
                          },
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}
