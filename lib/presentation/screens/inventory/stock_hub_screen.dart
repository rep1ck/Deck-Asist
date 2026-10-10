import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'add_inventory_item_screen.dart';
import 'barcode_scan_screen.dart';
import 'inventory_import_screen.dart';
import 'inventory_list_screen.dart';

class StockHubScreen extends ConsumerWidget {
  const StockHubScreen({super.key});

  static const _categories = [
    _Cat('ALL', 'Tum Stok Listesi', Icons.list_alt, Color(0xFF1A3A4A)),
    _Cat('BOYA', 'Boya', Icons.format_paint, Color(0xFF3D7A8C)),
    _Cat('KUMANYA', 'Kumanya', Icons.restaurant, Color(0xFF8B6B3D)),
    _Cat('KABIN', 'Kabin Malzemeleri', Icons.meeting_room, Color(0xFF4A7C59)),
    _Cat('RASPA', 'Raspa / Boya Yardimci', Icons.handyman, Color(0xFF6B5B7A)),
    _Cat('EL_ALETI', 'Elektrikli / El Aleti', Icons.electrical_services, Color(0xFF5C6B8A)),
    _Cat('KKD', 'KKD (Gozluk, Eldiven)', Icons.health_and_safety, Color(0xFF2F6F7E)),
    _Cat('DIGER', 'Diger', Icons.more_horiz, Color(0xFF5A6F7A)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final canImport =
        ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(user.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok / Sayim'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canImport) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventoryImportScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: const Text('Excel Import'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddInventoryItemScreen(
                            initialBarcode: '',
                          ),
                        ),
                      ).then((_) => ref.invalidate(inventoryProvider));
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Elle giris'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          const Text(
            'Kategori secin',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Sayim ve stok islemleri kategoriye gore yapilir',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ..._categories.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                elevation: 1.5,
                shadowColor: AppColors.deepSea.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InventoryListScreen(
                          categoryFilter: c.code == 'ALL' ? null : c.code,
                          title: c.label,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: c.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(c.icon, color: c.color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            c.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Cat {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.code, this.label, this.icon, this.color);
}
