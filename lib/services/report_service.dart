import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
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

  Future<pw.Font> _trFont() async {
    final data = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    return pw.Font.ttf(data);
  }

  Future<pw.ThemeData> _pdfTheme() async {
    try {
      final font = await _trFont();
      return pw.ThemeData.withFont(
        base: font,
        bold: font,
        italic: font,
        boldItalic: font,
      );
    } catch (_) {
      return pw.ThemeData.base();
    }
  }

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
    final sheet = excel['Stok'];
    sheet.appendRow([
      TextCellValue('Barkod'),
      TextCellValue('Urun Adi'),
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
    final theme = await _pdfTheme();
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (context) => [
          pw.Text('Stok Listesi Raporu',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Barkod', 'Urun', 'Kategori', 'Stok', 'Birim'],
            data: items
                .map((i) => [
                      i.barcode,
                      i.name,
                      Labels.category(i.category),
                      i.currentStock.toString(),
                      i.unit,
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
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
        '<td>${_esc(Labels.category(i.category))}</td>'
        '<td>${i.currentStock}</td><td>${_esc(i.unit)}</td></tr>',
      );
    }
    return await _saveWord(
      _wordHtml(
        'Stok Listesi Raporu',
        '<table border="1" cellpadding="4" cellspacing="0">'
        '<tr><th>Barkod</th><th>Urun</th><th>Kategori</th><th>Stok</th><th>Birim</th></tr>'
        '$rows</table>',
      ),
      'stok_listesi',
    );
  }

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
    final sheet = excel['Isler'];
    sheet.appendRow([
      TextCellValue('Baslik'),
      TextCellValue('Durum'),
      TextCellValue('Oncelik'),
      TextCellValue('Lokasyon'),
      TextCellValue('Baslangic'),
      TextCellValue('Bitis'),
    ]);
    for (final job in jobs) {
      sheet.appendRow([
        TextCellValue(job.title),
        TextCellValue(Labels.jobStatus(job.status)),
        TextCellValue(Labels.priority(job.priority)),
        TextCellValue(job.location ?? ''),
        TextCellValue(job.startTime?.toString() ?? ''),
        TextCellValue(job.endTime?.toString() ?? ''),
      ]);
    }
    return await _saveExcel(excel, 'is_raporu');
  }

  Future<String> exportJobsPdf() async {
    final jobs = await db.select(db.jobs).get();
    final theme = await _pdfTheme();
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (context) => [
          pw.Text('Is Raporu',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Baslik', 'Durum', 'Oncelik', 'Lokasyon'],
            data: jobs
                .map((j) => [
                      j.title,
                      Labels.jobStatus(j.status),
                      Labels.priority(j.priority),
                      j.location ?? '-',
                    ])
                .toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
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
        '<td>${_esc(Labels.priority(j.priority))}</td>'
        '<td>${_esc(j.location ?? "-")}</td></tr>',
      );
    }
    return await _saveWord(
      _wordHtml(
        'Is Raporu',
        '<table border="1" cellpadding="4" cellspacing="0">'
        '<tr><th>Baslik</th><th>Durum</th><th>Oncelik</th><th>Lokasyon</th></tr>'
        '$rows</table>',
      ),
      'is_raporu',
    );
  }

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
    final sheet = excel['Bakim'];
    sheet.appendRow([
      TextCellValue('Bakim Adi'),
      TextCellValue('Periyot (Gun)'),
      TextCellValue('Son Yapilma'),
      TextCellValue('Sonraki Tarih'),
      TextCellValue('Durum'),
    ]);
    final now = DateTime.now();
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final diff = plan.nextDueDate!.difference(now).inDays;
        if (diff < 0) {
          durum = 'Gecikmis';
        } else if (diff <= 7) {
          durum = 'Yaklasiyor';
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
    final theme = await _pdfTheme();
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (context) => [
          pw.Text('Planli Bakim Raporu',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Bakim', 'Periyot', 'Sonraki', 'Durum'],
            data: plans.map((plan) {
              String durum = 'Normal';
              if (plan.nextDueDate != null) {
                final diff = plan.nextDueDate!.difference(now).inDays;
                if (diff < 0) {
                  durum = 'Gecikmis';
                } else if (diff <= 7) {
                  durum = 'Yaklasiyor';
                }
              }
              return [
                plan.title,
                '${plan.intervalDays} gun',
                plan.nextDueDate?.toString().substring(0, 10) ?? '-',
                durum,
              ];
            }).toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
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
          durum = 'Gecikmis';
        } else if (diff <= 7) {
          durum = 'Yaklasiyor';
        }
      }
      rows.writeln(
        '<tr><td>${_esc(plan.title)}</td><td>${plan.intervalDays}</td>'
        '<td>${plan.nextDueDate?.toString().substring(0, 10) ?? "-"}</td>'
        '<td>$durum</td></tr>',
      );
    }
    return await _saveWord(
      _wordHtml(
        'Planli Bakim Raporu',
        '<table border="1" cellpadding="4" cellspacing="0">'
        '<tr><th>Bakim</th><th>Periyot</th><th>Sonraki</th><th>Durum</th></tr>'
        '$rows</table>',
      ),
      'bakim_raporu',
    );
  }

  String _esc(String s) => s
      .replaceAll('&', '&')
      .replaceAll('<', '<')
      .replaceAll('>', '>')
      .replaceAll('"', '"');

  String _wordHtml(String title, String body) {
    return '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
xmlns:w="urn:schemas-microsoft-com:office:word"
xmlns="http://www.w3.org/TR/REC-html40">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<title>$title</title>
<style>
body{font-family:Arial,'Segoe UI',sans-serif}
table{border-collapse:collapse;width:100%}
th,td{border:1px solid #333;padding:6px}
th{background:#e8eef1}
</style>
</head>
<body>
<h1>$title</h1>
$body
</body>
</html>''';
  }

  Future<String> _saveExcel(Excel excel, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    await File(path).writeAsBytes(excel.encode()!, flush: true);
    return path;
  }

  Future<String> _savePdf(pw.Document pdf, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(await pdf.save(), flush: true);
    return path;
  }

  Future<String> _saveWord(String html, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.doc';
    final bom = [0xEF, 0xBB, 0xBF];
    await File(path).writeAsBytes([...bom, ...utf8.encode(html)], flush: true);
    return path;
  }

  Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}
