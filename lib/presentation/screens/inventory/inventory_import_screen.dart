import 'dart:io';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/inventory_service.dart';

class InventoryImportScreen extends ConsumerStatefulWidget {
  const InventoryImportScreen({super.key});

  @override
  ConsumerState<InventoryImportScreen> createState() =>
      _InventoryImportScreenState();
}

class _InventoryImportScreenState extends ConsumerState<InventoryImportScreen> {
  bool _busy = false;
  String? _result;

  Future<void> _downloadTemplate() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final excel = Excel.createExcel();
      final sheet = excel['StokSablon'];
      sheet.appendRow([
        TextCellValue('Barkod'),
        TextCellValue('Urun Adi'),
        TextCellValue('Kategori'),
        TextCellValue('Birim'),
        TextCellValue('Ambalaj'),
        TextCellValue('1 Amb Miktar'),
        TextCellValue('Renk'),
        TextCellValue('Min Stok'),
        TextCellValue('Mevcut Stok'),
      ]);
      final samples = [
        ['8690000000001', 'Interthane 990', 'BOYA', 'Lt', '5 Lt', '5', 'Beyaz', '2', '10'],
        ['8690000000002', 'Interthane 990', 'BOYA', 'Lt', '20 Lt', '20', 'Storm Grey', '1', '4'],
        ['8690000000003', 'Cop torbasi buyuk', 'KABIN', 'Adet', '50 li', '50', '', '100', '200'],
        ['8690000000004', 'Detarjan 5L', 'KABIN', 'Lt', '5 Lt', '5', '', '5', '15'],
        ['8690000000005', 'Supurge', 'KABIN', 'Adet', '1', '1', '', '2', '6'],
        ['8690000000006', 'Faras', 'KABIN', 'Adet', '1', '1', '', '2', '4'],
        ['8690000000007', 'Is eldiveni', 'KKD', 'Adet', '12 li', '12', '', '12', '36'],
        ['8690000000008', 'Koruyucu gozluk', 'KKD', 'Adet', '1', '1', '', '5', '10'],
        ['8690000000009', 'Raspa disc 125mm', 'RASPA', 'Adet', '10 lu', '10', '', '20', '50'],
        ['8690000000010', 'Matkap', 'EL_ALETI', 'Adet', '1', '1', '', '1', '2'],
        ['8690000000011', 'Pirinc', 'KUMANYA', 'Kg', '25 Kg', '25', '', '50', '100'],
      ];
      for (final r in samples) {
        sheet.appendRow(r.map((e) => TextCellValue(e)).toList());
      }
      final info = excel['Aciklama'];
      info.appendRow([TextCellValue('Kategori kodlari')]);
      for (final c in ['BOYA', 'KUMANYA', 'KABIN', 'RASPA', 'EL_ALETI', 'KKD', 'DIGER']) {
        info.appendRow([TextCellValue(c)]);
      }
      info.appendRow([TextCellValue('')]);
      info.appendRow([
        TextCellValue('Ayni barkod varsa urun guncellenir. Bos barkod satirlari atlanir.')
      ]);

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/DeckAsist_Stok_Sablon_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final bytes = excel.encode();
      if (bytes == null) throw Exception('Sablon olusturulamadi');
      await File(path).writeAsBytes(bytes, flush: true);
      await OpenFilex.open(path);
      setState(() => _result = 'Sablon kaydedildi ve acildi:\n$path');
    } catch (e) {
      setState(() => _result = 'Hata: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _importExcel() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (pick == null || pick.files.isEmpty) {
        setState(() {
          _busy = false;
          _result = 'Dosya secilmedi';
        });
        return;
      }
      final file = pick.files.first;
      List<int>? bytes = file.bytes;
      if (bytes == null && file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes == null) throw Exception('Dosya okunamadi');

      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      final rows = <List<String>>[];
      for (final row in sheet.rows) {
        rows.add(
          row.map((c) {
            if (c == null) return '';
            final v = c.value;
            if (v == null) return '';
            return v.toString().trim();
          }).toList(),
        );
      }

      final service = InventoryService(ref.read(databaseProvider));
      final res = await service.importFromExcelRows(rows);
      ref.invalidate(inventoryProvider);

      final errText = res.errors.isEmpty
          ? ''
          : '\nHatalar:\n${res.errors.take(8).join('\n')}';
      setState(() {
        _result =
            'Import tamamlandi\nEklenen: ${res.added}\nGuncellenen: ${res.updated}\nAtlanan: ${res.skipped}$errText';
      });
    } catch (e) {
      setState(() => _result = 'Import hatasi: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toplu Stok Import')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            '1) Ornek listeyi indirin\n'
            '2) Barkod, urun adi, kategori vb. doldurun\n'
            '3) Ayni dosyayi ice aktarin',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kategoriler: BOYA, KUMANYA, KABIN, RASPA, EL_ALETI, KKD, DIGER',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _busy ? null : _downloadTemplate,
            icon: const Icon(Icons.download),
            label: const Text('Ornek Excel sablonunu indir'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _importExcel,
            icon: const Icon(Icons.upload_file),
            label: const Text('Excel dosyasini ice aktar'),
          ),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_result != null) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.deepSea.withOpacity(0.15)),
              ),
              child: Text(_result!, style: const TextStyle(height: 1.35)),
            ),
          ],
        ],
      ),
    );
  }
}
