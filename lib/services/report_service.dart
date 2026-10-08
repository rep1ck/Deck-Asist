import 'dart:io';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../data/database/app_database.dart';
import '../core/utils/labels.dart';

enum ReportFormat { excel, pdf, word }

class ReportService {
  final AppDatabase db;
  ReportService(this.db);

  // ---------- STOK ----------
  Future<String> exportInventory(ReportFormat format) async {
    switch (format) {
      case ReportFormat.excel:
        return exportInventoryExcel();
      case ReportFormat.pdf:
        return exportInventoryPdf();
      case ReportFormat.word:
        return exportInventoryWord();
    }
  }

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
        TextCellValue(Labels.category(item.category)),
        TextCellValue(item.packSize ?? ''),
        DoubleCellValue(item.currentStock),
        TextCellValue(item.unit),
        DoubleCellValue(item.minStock),
      ]);
    }
    return await _saveExcel(excel, 'stok_listesi');
  }

  Future<String> exportInventoryPdf() async {
    final items = await db.select(db.inventoryItems).get();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Stok Listesi Raporu')),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Barkod', 'Ürün', 'Renk', 'Kategori', 'Stok', 'Birim'],
            data: items
                .map((i) => [
                      i.barcode,
                      i.name,
                      i.color ?? '-',
                      Labels.category(i.category),
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

  Future<String> exportInventoryWord() async {
    final items = await db.select(db.inventoryItems).get();
    final rows = StringBuffer();
    for (final i in items) {
      rows.writeln(
        '<tr><td>${_esc(i.barcode)}</td><td>${_esc(i.name)}</td>'
        '<td>${_esc(i.color ?? "-")}</td><td>${_esc(Labels.category(i.category))}</td>'
        '<td>${i.currentStock}</td><td>${_esc(i.unit)}</td></tr>',
      );
    }
    final html = '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><title>Stok Listesi</title></head>
<body>
<h1>Stok Listesi Raporu</h1>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>Barkod</th><th>Ürün</th><th>Renk</th><th>Kategori</th><th>Stok</th><th>Birim</th></tr>
$rows
</table>
</body></html>''';
    return await _saveWord(html, 'stok_listesi');
  }

  // ---------- İŞLER ----------
  Future<String> exportJobs(ReportFormat format) async {
    switch (format) {
      case ReportFormat.excel:
        return exportJobsExcel();
      case ReportFormat.pdf:
        return exportJobsPdf();
      case ReportFormat.word:
        return exportJobsWord();
    }
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
        TextCellValue(Labels.jobStatus(job.status)),
        TextCellValue(Labels.priority(job.priority)),
        TextCellValue(job.location ?? ''),
        TextCellValue(job.startTime?.toString() ?? ''),
        TextCellValue(job.endTime?.toString() ?? ''),
        TextCellValue(job.createdAt.toString()),
      ]);
    }
    return await _saveExcel(excel, 'is_raporu');
  }

  Future<String> exportJobsPdf() async {
    final jobs = await db.select(db.jobs).get();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('İş Raporu')),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Başlık', 'Durum', 'Öncelik', 'Lokasyon'],
            data: jobs
                .map((j) => [
                      j.title,
                      Labels.jobStatus(j.status),
                      Labels.priority(j.priority),
                      j.location ?? '-',
                    ])
                .toList(),
          ),
        ],
      ),
    );
    return await _savePdf(pdf, 'is_raporu');
  }

  Future<String> exportJobsWord() async {
    final jobs = await db.select(db.jobs).get();
    final rows = StringBuffer();
    for (final j in jobs) {
      rows.writeln(
        '<tr><td>${_esc(j.title)}</td><td>${_esc(Labels.jobStatus(j.status))}</td>'
        '<td>${_esc(Labels.priority(j.priority))}</td><td>${_esc(j.location ?? "-")}</td></tr>',
      );
    }
    final html = '''
<html><head><meta charset="utf-8"><title>İş Raporu</title></head>
<body>
<h1>İş Raporu</h1>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>Başlık</th><th>Durum</th><th>Öncelik</th><th>Lokasyon</th></tr>
$rows
</table>
</body></html>''';
    return await _saveWord(html, 'is_raporu');
  }

  // ---------- BAKIM ----------
  Future<String> exportMaintenance(ReportFormat format) async {
    switch (format) {
      case ReportFormat.excel:
        return exportMaintenanceExcel();
      case ReportFormat.pdf:
        return exportMaintenancePdf();
      case ReportFormat.word:
        return exportMaintenanceWord();
    }
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

  Future<String> exportMaintenancePdf() async {
    final plans = await db.select(db.maintenancePlans).get();
    final now = DateTime.now();
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(level: 0, child: pw.Text('Planlı Bakım Raporu')),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Bakım', 'Periyot', 'Sonraki', 'Durum'],
            data: plans.map((plan) {
              String durum = 'Normal';
              if (plan.nextDueDate != null) {
                final diff = plan.nextDueDate!.difference(now).inDays;
                if (diff < 0) {
                  durum = 'Gecikmiş';
                } else if (diff <= 7) {
                  durum = 'Yaklaşıyor';
                }
              }
              return [
                plan.title,
                '${plan.intervalDays} gün',
                plan.nextDueDate?.toString().substring(0, 10) ?? '-',
                durum,
              ];
            }).toList(),
          ),
        ],
      ),
    );
    return await _savePdf(pdf, 'bakim_raporu');
  }

  Future<String> exportMaintenanceWord() async {
    final plans = await db.select(db.maintenancePlans).get();
    final now = DateTime.now();
    final rows = StringBuffer();
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
      rows.writeln(
        '<tr><td>${_esc(plan.title)}</td><td>${plan.intervalDays}</td>'
        '<td>${plan.nextDueDate?.toString().substring(0, 10) ?? "-"}</td>'
        '<td>$durum</td></tr>',
      );
    }
    final html = '''
<html><head><meta charset="utf-8"><title>Planlı Bakım</title></head>
<body>
<h1>Planlı Bakım Raporu</h1>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>Bakım</th><th>Periyot</th><th>Sonraki</th><th>Durum</th></tr>
$rows
</table>
</body></html>''';
    return await _saveWord(html, 'bakim_raporu');
  }

  // ---------- yardımcılar ----------
  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  Future<String> _saveExcel(Excel excel, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await File(path).writeAsBytes(excel.encode()!);
    return path;
  }

  Future<String> _savePdf(pw.Document pdf, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(await pdf.save());
    return path;
  }

  Future<String> _saveWord(String html, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.doc';
    await File(path).writeAsString(html, flush: true);
    return path;
  }

  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}
