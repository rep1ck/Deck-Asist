import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../data/database/app_database.dart';

class ReportService {
  final AppDatabase db;
  ReportService(this.db);

  Future<String> exportInventoryExcel() async {
    final items = await db.select(db.inventoryItems).get();
    final excel = Excel.createExcel();
    final sheet = excel['Stok Listesi'];

    sheet.appendRow([
      TextCellValue('Barkod'),
      TextCellValue('Ürün Adı'),
      TextCellValue('Renk'),
      TextCellValue('Kategori'),
      TextCellValue('Ambalaj'),
      TextCellValue('Mevcut Stok'),
      TextCellValue('Birim'),
      TextCellValue('Min Stok'),
    ]);

    for (final item in items) {
      sheet.appendRow([
        TextCellValue(item.barcode),
        TextCellValue(item.name),
        TextCellValue(item.color ?? ''),
        TextCellValue(item.category),
        TextCellValue(item.packSize ?? ''),
        DoubleCellValue(item.currentStock),
        TextCellValue(item.unit),
        DoubleCellValue(item.minStock),
      ]);
    }
    return await _saveExcel(excel, 'stok_listesi');
  }

  Future<String> exportJobsExcel() async {
    final jobs = await db.select(db.jobs).get();
    final excel = Excel.createExcel();
    final sheet = excel['İş Raporu'];

    sheet.appendRow([
      TextCellValue('Başlık'),
      TextCellValue('Durum'),
      TextCellValue('Öncelik'),
      TextCellValue('Lokasyon'),
      TextCellValue('Başlangıç'),
      TextCellValue('Bitiş'),
      TextCellValue('Oluşturma'),
    ]);

    for (final job in jobs) {
      sheet.appendRow([
        TextCellValue(job.title),
        TextCellValue(job.status),
        TextCellValue(job.priority),
        TextCellValue(job.location ?? ''),
        TextCellValue(job.startTime?.toString() ?? ''),
        TextCellValue(job.endTime?.toString() ?? ''),
        TextCellValue(job.createdAt.toString()),
      ]);
    }
    return await _saveExcel(excel, 'is_raporu');
  }

  Future<String> exportMaintenanceExcel() async {
    final plans = await db.select(db.maintenancePlans).get();
    final excel = Excel.createExcel();
    final sheet = excel['Planlı Bakım'];

    sheet.appendRow([
      TextCellValue('Bakım Adı'),
      TextCellValue('Periyot (Gün)'),
      TextCellValue('Son Yapılma'),
      TextCellValue('Sonraki Tarih'),
      TextCellValue('Durum'),
    ]);

    final now = DateTime.now();
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final diff = plan.nextDueDate!.difference(now).inDays;
        if (diff < 0) {
          durum = 'Gecikmiş';
        } else if (diff <= 7) {
          durum = 'Yaklaşıyor';
        }
      }
      sheet.appendRow([
        TextCellValue(plan.title),
        IntCellValue(plan.intervalDays),
        TextCellValue(plan.lastDoneDate?.toString().substring(0, 10) ?? '-'),
        TextCellValue(plan.nextDueDate?.toString().substring(0, 10) ?? '-'),
        TextCellValue(durum),
      ]);
    }
    return await _saveExcel(excel, 'bakim_raporu');
  }

  Future<String> exportInventoryPdf() async {
    final items = await db.select(db.inventoryItems).get();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Stok Listesi Raporu')),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Barkod', 'Ürün', 'Renk', 'Stok', 'Birim'],
            data: items
                .map((i) => [
                      i.barcode,
                      i.name,
                      i.color ?? '-',
                      i.currentStock.toString(),
                      i.unit,
                    ])
                .toList(),
          ),
        ],
      ),
    );
    return await _savePdf(pdf, 'stok_listesi');
  }

  Future<String> _saveExcel(Excel excel, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    await file.writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String> _savePdf(pw.Document pdf, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return path;
  }

  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}
