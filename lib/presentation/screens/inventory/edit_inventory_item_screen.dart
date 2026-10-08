import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../../../data/database/app_database.dart';
import '../../../services/inventory_service.dart';

class EditInventoryItemScreen extends ConsumerStatefulWidget {
  final InventoryItem item;
  const EditInventoryItemScreen({super.key, required this.item});

  @override
  ConsumerState<EditInventoryItemScreen> createState() =>
      _EditInventoryItemScreenState();
}

class _EditInventoryItemScreenState
    extends ConsumerState<EditInventoryItemScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _packCtrl;
  late final TextEditingController _minStockCtrl;
  late String _category;
  late String _unit;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final i = widget.item;
    _nameCtrl = TextEditingController(text: i.name);
    _barcodeCtrl = TextEditingController(text: i.barcode);
    _colorCtrl = TextEditingController(text: i.color ?? '');
    _packCtrl = TextEditingController(text: i.packSize ?? '');
    _minStockCtrl = TextEditingController(text: i.minStock.toString());
    _category = i.category;
    _unit = i.unit;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _colorCtrl.dispose();
    _packCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final service = InventoryService(ref.read(databaseProvider));
    final ok = await service.updateItem(
      itemId: widget.item.id,
      barcode: _barcodeCtrl.text,
      name: _nameCtrl.text,
      color: _colorCtrl.text.trim().isEmpty ? null : _colorCtrl.text.trim(),
      category: _category,
      unit: _unit,
      packSize: _packCtrl.text.trim().isEmpty ? null : _packCtrl.text.trim(),
      minStock: double.tryParse(_minStockCtrl.text.replaceAll(',', '.')),
    );
    setState(() => _saving = false);
    ref.invalidate(inventoryProvider);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün güncellendi')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Güncellenemedi (barkod başka üründe olabilir)'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ürünü Düzenle')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: 'Ürün Adı *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _barcodeCtrl,
            decoration: const InputDecoration(
              labelText: 'Barkod *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _colorCtrl,
            decoration: const InputDecoration(
              labelText: 'Renk / Renk Kodu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _packCtrl,
            decoration: const InputDecoration(
              labelText: 'Ambalaj (5 Lt, 20 Lt...)',
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
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _unit,
            decoration: const InputDecoration(
              labelText: 'Birim',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Lt', child: Text('Lt')),
              DropdownMenuItem(value: 'Kg', child: Text('Kg')),
              DropdownMenuItem(value: 'Adet', child: Text('Adet')),
              DropdownMenuItem(value: 'Kutu', child: Text('Kutu')),
            ],
            onChanged: (v) => setState(() => _unit = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minStockCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Minimum Stok',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Mevcut stok: ${widget.item.currentStock} ${widget.item.unit}'
            ' • ${Labels.category(widget.item.category)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Kaydet'),
            ),
          ),
        ],
      ),
    );
  }
}
