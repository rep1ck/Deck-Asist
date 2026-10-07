import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../data/database/app_database.dart';
import '../../../services/inventory_service.dart';

class StockMovementScreen extends ConsumerStatefulWidget {
  final InventoryItem item;
  const StockMovementScreen({super.key, required this.item});

  @override
  ConsumerState<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  final _quantityController = TextEditingController();
  String _movementType = 'CIKIS';
  bool _isLoading = false;

  Future<void> _save() async {
    final quantity =
        double.tryParse(_quantityController.text.replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçerli bir miktar girin')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final service = InventoryService(ref.read(databaseProvider));
    final currentUser = ref.read(currentUserProvider)!;

    await service.addMovement(
      itemId: widget.item.id,
      movementType: _movementType,
      quantity: quantity,
      userId: currentUser.id,
    );

    setState(() => _isLoading = false);
    ref.invalidate(inventoryProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stok güncellendi')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: const Text('Stok Hareketi')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
            if (item.color != null) Text('Renk: ${item.color}'),
            Text('Ambalaj: ${item.packSize ?? "-"}'),
            Text('Mevcut Stok: ${item.currentStock} ${item.unit}'),
            Text('Barkod: ${item.barcode}'),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              value: _movementType,
              decoration: const InputDecoration(
                labelText: 'İşlem Tipi',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'GIRIS', child: Text('Giriş (Stok Ekle)')),
                DropdownMenuItem(value: 'CIKIS', child: Text('Çıkış (Kullanım)')),
                DropdownMenuItem(value: 'SAYIM', child: Text('Sayım')),
                DropdownMenuItem(value: 'DUZELTME', child: Text('Düzeltme')),
              ],
              onChanged: (v) => setState(() => _movementType = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _quantityController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Miktar (${item.unit})',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
