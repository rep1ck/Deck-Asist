import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/providers.dart';
import '../../../services/inventory_service.dart';
import 'stock_movement_screen.dart';
import 'add_inventory_item_screen.dart';

class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() => _isProcessing = true);

    final service = InventoryService(ref.read(databaseProvider));
    final item = await service.findByBarcode(code);

    if (!mounted) return;

    if (item == null) {
      final shouldAdd = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ürün Bulunamadı'),
          content: Text('Barkod: $code\n\nYeni ürün eklemek ister misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hayır'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Evet'),
            ),
          ],
        ),
      );
      if (shouldAdd == true && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddInventoryItemScreen(initialBarcode: code),
          ),
        );
      }
      setState(() => _isProcessing = false);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StockMovementScreen(item: item)),
    );
    setState(() => _isProcessing = false);
    ref.invalidate(inventoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barkod Okut')),
      body: Stack(
        children: [
          MobileScanner(controller: controller, onDetect: _onDetect),
          if (_isProcessing)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Barkodu kare içine getirin',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
