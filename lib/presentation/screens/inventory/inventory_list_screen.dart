import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import 'barcode_scan_screen.dart';
import 'stock_movement_screen.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryProvider);

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
              );
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
              final isLow = item.currentStock <= item.minStock && item.minStock > 0;
              return Card(
                color: isLow ? Colors.red.shade50 : null,
                child: ListTile(
                  title: Text('${item.name} ${item.color ?? ''}'),
                  subtitle: Text(
                    'Stok: ${item.currentStock} ${item.unit} | ${item.packSize ?? ""} | ${item.barcode}',
                  ),
                  trailing: isLow
                      ? const Icon(Icons.warning, color: Colors.red)
                      : Text(
                          '${item.currentStock}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StockMovementScreen(item: item),
                      ),
                    );
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
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Barkod Okut'),
      ),
    );
  }
}
