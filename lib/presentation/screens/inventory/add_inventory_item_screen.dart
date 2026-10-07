import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/inventory_service.dart';

class AddInventoryItemScreen extends ConsumerStatefulWidget {
  final String initialBarcode;
  const AddInventoryItemScreen({super.key, required this.initialBarcode});

  @override
  ConsumerState<AddInventoryItemScreen> createState() =>
      _AddInventoryItemScreenState();
}

class _AddInventoryItemScreenState
    extends ConsumerState<AddInventoryItemScreen> {
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _packSizeController = TextEditingController();
  String _category = 'BOYA';
  bool _isLoading = false;

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final service = InventoryService(ref.read(databaseProvider));
    await service.createItem(
      barcode: widget.initialBarcode,
      name: _nameController.text.trim(),
      color: _colorController.text.trim().isEmpty
          ? null
          : _colorController.text.trim(),
      category: _category,
      packSize: _packSizeController.text.trim().isEmpty
          ? null
          : _packSizeController.text.trim(),
    );

    setState(() => _isLoading = false);
    ref.invalidate(inventoryProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün eklendi')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _colorController.dispose();
    _packSizeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Ürün Ekle')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text('Barkod: ${widget.initialBarcode}'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ürün Adı *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Renk',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _packSizeController,
              decoration: const InputDecoration(
                labelText: 'Ambalaj (5 Lt, 20 Lt)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'BOYA', child: Text('Boya')),
                DropdownMenuItem(value: 'RASPA', child: Text('Raspa')),
                DropdownMenuItem(value: 'KABIN', child: Text('Kabin')),
                DropdownMenuItem(value: 'DIGER', child: Text('Diğer')),
              ],
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}
