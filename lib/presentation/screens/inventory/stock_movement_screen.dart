import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../../../data/database/app_database.dart';
import '../../../services/inventory_service.dart';
import 'barcode_scan_screen.dart';

class StockMovementScreen extends ConsumerStatefulWidget {
  final InventoryItem item;
  final String initialMovementType;

  const StockMovementScreen({
    super.key,
    required this.item,
    this.initialMovementType = 'SAYIM',
  });

  @override
  ConsumerState<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  final _quantityController = TextEditingController();
  late String _movementType;
  bool _inputAsPacks = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _movementType = widget.initialMovementType;
  }

  double get _upp {
    final v = widget.item.unitsPerPack;
    return v <= 0 ? 1 : v;
  }

  Future<void> _save({bool scanNext = false}) async {
    final raw =
        double.tryParse(_quantityController.text.replaceAll(',', '.'));
    if (raw == null || raw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gecerli bir miktar girin')),
      );
      return;
    }

    final quantityInUnit = _inputAsPacks ? raw * _upp : raw;

    setState(() => _isLoading = true);
    final service = InventoryService(ref.read(databaseProvider));
    final currentUser = ref.read(currentUserProvider)!;

    final note = _inputAsPacks
        ? 'Ambalaj: $raw x $_upp ${widget.item.unit} = $quantityInUnit ${widget.item.unit}'
        : null;

    await service.addMovement(
      itemId: widget.item.id,
      movementType: _movementType,
      quantity: quantityInUnit,
      userId: currentUser.id,
      note: note,
    );

    setState(() => _isLoading = false);
    ref.invalidate(inventoryProvider);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Kaydedildi: ${quantityInUnit.toStringAsFixed(2)} ${widget.item.unit}',
        ),
      ),
    );

    if (scanNext) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BarcodeScanScreen(
            defaultMovementType: _movementType,
            title: _movementType == 'SAYIM'
                ? 'Barkod ile Sayim'
                : 'Barkod Okut',
          ),
        ),
      );
    } else {
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
    final preview = double.tryParse(
          _quantityController.text.replaceAll(',', '.'),
        ) ??
        0;
    final converted = _inputAsPacks ? preview * _upp : preview;

    return Scaffold(
      appBar: AppBar(
        title: Text(_movementType == 'SAYIM' ? 'Sayim / Duzeltme' : 'Stok Hareketi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'Baska urun okut',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BarcodeScanScreen(
                    defaultMovementType: _movementType,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Kategori: ${Labels.category(item.category)}'),
          if (item.color != null && item.color!.isNotEmpty)
            Text('Renk/Kod: ${item.color}'),
          Text(
              'Ambalaj: ${item.packSize ?? "-"} (1 ambalaj = $_upp ${item.unit})'),
          Text(
            'Mevcut stok: ${item.currentStock} ${item.unit}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Barkod: ${item.barcode}'),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _movementType,
            decoration: const InputDecoration(
              labelText: 'Islem tipi',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'SAYIM', child: Text('Sayim (mevcut = girilen)')),
              DropdownMenuItem(
                  value: 'DUZELTME', child: Text('Duzeltme (mevcut = girilen)')),
              DropdownMenuItem(
                  value: 'GIRIS', child: Text('Giris (stok ekle)')),
              DropdownMenuItem(
                  value: 'CIKIS', child: Text('Cikis (kullanim)')),
            ],
            onChanged: (v) => setState(() => _movementType = v!),
          ),
          const SizedBox(height: 16),
          const Text('Giris sekli',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: true,
                label: const Text('Ambalaj adedi'),
                icon: const Icon(Icons.inventory_2, size: 18),
              ),
              ButtonSegment(
                value: false,
                label: Text('${item.unit} miktari'),
                icon: const Icon(Icons.straighten, size: 18),
              ),
            ],
            selected: {_inputAsPacks},
            onSelectionChanged: (s) =>
                setState(() => _inputAsPacks = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _quantityController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _inputAsPacks
                  ? 'Ambalaj adedi'
                  : 'Miktar (${item.unit})',
              border: const OutlineInputBorder(),
              helperText: preview > 0
                  ? 'Stoka yazilacak: ${converted.toStringAsFixed(2)} ${item.unit}'
                  : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _save(scanNext: false),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Kaydet'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : () => _save(scanNext: true),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Kaydet ve sonraki barkodu okut'),
            ),
          ),
        ],
      ),
    );
  }
}
