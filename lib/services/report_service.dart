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
          base: font, bold: font, italic: font, boldItalic: font);
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
      TextCellValue('Barkod'), TextCellValue('Urun'), TextCellValue('Kategori'),
      TextCellValue('Birim'), TextCellValue('Stok'), TextCellValue('Renk'),
    ]);
    for (final i in items) {
      sheet.appendRow([
        TextCellValue(i.barcode), TextCellValue(i.name),
        TextCellValue(Labels.category(i.category)),
        TextCellValue(i.unit),
        TextCellValue(i.currentStock.toString()),
        TextCellValue(i.color ?? ''),
      ]);
    }
    return await _saveExcel(excel, 'stok_raporu');
  }

  Future<String> exportInventoryPdf() async {
    final items = await db.select(db.inventoryItems).get();
    final theme = await _pdfTheme();
    final pdf = pw.Document(theme: theme);
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      build: (_) => [
        pw.Text('Stok Raporu',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table.fromTextArray(
          headers: ['Barkod', 'Urun', 'Kategori', 'Stok'],
          data: items
              .map((i) => [
                    i.barcode,
                    i.name,
                    Labels.category(i.category),
                    '${i.currentStock} ${i.unit}',
                  ])
              .toList(),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ));
    return await _savePdf(pdf, 'stok_raporu');
  }

  Future<String> exportInventoryWord() async {
    final items = await db.select(db.inventoryItems).get();
    final rows = StringBuffer();
    for (final i in items) {
      rows.writeln(
          '<tr><td>${_esc(i.barcode)}</td><td>${_esc(i.name)}</td>'
          '<td>${_esc(Labels.category(i.category))}</td>'
          '<td>${i.currentStock} ${_esc(i.unit)}</td></tr>');
    }
    return await _saveWord(
      _wordHtml('Stok Raporu',
          '<table border="1" cellpadding="4"><tr><th>Barkod</th><th>Urun</th><th>Kategori</th><th>Stok</th></tr>$rows</table>'),
      'stok_raporu',
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
      TextCellValue('Baslik'), TextCellValue('Durum'), TextCellValue('Oncelik'),
      TextCellValue('Lokasyon'), TextCellValue('Baslangic'), TextCellValue('Bitis'),
    ]);
    for (final j in jobs) {
      sheet.appendRow([
        TextCellValue(j.title),
        TextCellValue(Labels.jobStatus(j.status)),
        TextCellValue(Labels.priority(j.priority)),
        TextCellValue(j.location ?? ''),
        TextCellValue(j.startTime?.toString() ?? ''),
        TextCellValue(j.endTime?.toString() ?? ''),
      ]);
    }
    return await _saveExcel(excel, 'is_raporu');
  }

  Future<String> exportJobsPdf() async {
    final jobs = await db.select(db.jobs).get();
    final theme = await _pdfTheme();
    final pdf = pw.Document(theme: theme);

    if (jobs.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (_) => pw.Center(child: pw.Text('Kayitli is yok.')),
      ));
      return await _savePdf(pdf, 'is_raporu_resimli');
    }

    for (final job in jobs) {
      final allPhotos = await (db.select(db.jobPhotos)
            ..where((t) => t.jobId.equals(job.id)))
          .get();
      final before = allPhotos
          .where((p) => p.photoPhase == 'BEFORE')
          .take(6)
          .toList();
      final after = allPhotos
          .where((p) => p.photoPhase == 'AFTER')
          .take(6)
          .toList();
      final general = allPhotos
          .where((p) => p.photoPhase != 'BEFORE' && p.photoPhase != 'AFTER')
          .take(6)
          .toList();
      final comments = await (db.select(db.jobComments)
            ..where((t) => t.jobId.equals(job.id)))
          .get();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('M/V Zeynep C - Guverte Is Raporu',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  'Tarih: ${DateTime.now().toString().substring(0, 16)}',
                  style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              pw.Text(job.title,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                'Durum: ${Labels.jobStatus(job.status)}  |  '
                'Oncelik: ${Labels.priority(job.priority)}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (job.location != null && job.location!.isNotEmpty)
                pw.Text('Lokasyon: ${job.location}',
                    style: const pw.TextStyle(fontSize: 9)),
              pw.SizedBox(height: 6),
              pw.Text(
                'Is baslangic: ${job.startTime != null ? job.startTime.toString().substring(0, 16) : "-"}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Is oncesi fotograflar (max 6)',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _photoRow(before.isNotEmpty ? before : general),
              pw.SizedBox(height: 8),
              pw.Text(
                'Is bitis: ${job.endTime != null ? job.endTime.toString().substring(0, 16) : "-"}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Aciklama / is kapsami',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text(
                (job.description != null && job.description!.isNotEmpty)
                    ? job.description!
                    : '-',
                style: const pw.TextStyle(fontSize: 9),
              ),
              if (comments.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                ...comments.take(5).map((c) => pw.Text('• ${c.comment}',
                    style: const pw.TextStyle(fontSize: 8))),
              ],
              pw.SizedBox(height: 8),
              pw.Text('Is sonrasi / bitmis hali (max 6)',
                  style: pw.TextStyle(
                      fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              _photoRow(after),
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('M/V Zeynep C Master',
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 20),
                    pw.Text('________________',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Imza', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ),
            ],
          );
        },
      ));
    }
    return await _savePdf(pdf, 'is_raporu_resimli');
  }

  pw.Widget _photoRow(List<JobPhoto> photos) {
    final list = photos.take(6).toList();
    if (list.isEmpty) {
      return pw.Text('Fotograf yok',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600));
    }
    final cells = <pw.Widget>[];
    for (final ph in list) {
      cells.addAll(_pdfImageWidgets(ph.photoPath, maxW: 160, maxH: 110));
    }
    return pw.Wrap(spacing: 6, runSpacing: 6, children: cells);
  }

  Future<String> exportJobsWord() async {
    final jobs = await db.select(db.jobs).get();
    final buf = StringBuffer();
    for (final job in jobs) {
      final allPhotos = await (db.select(db.jobPhotos)
            ..where((t) => t.jobId.equals(job.id)))
          .get();
      final before = allPhotos
          .where((p) => p.photoPhase == 'BEFORE')
          .take(6)
          .toList();
      final after =
          allPhotos.where((p) => p.photoPhase == 'AFTER').take(6).toList();
      final general = allPhotos
          .where((p) => p.photoPhase != 'BEFORE' && p.photoPhase != 'AFTER')
          .take(6)
          .toList();

      buf.writeln('<h1>M/V Zeynep C - Guverte Is Raporu</h1>');
      buf.writeln('<h2>${_esc(job.title)}</h2>');
      buf.writeln(
        '<p><b>Durum:</b> ${_esc(Labels.jobStatus(job.status))} | '
        '<b>Oncelik:</b> ${_esc(Labels.priority(job.priority))}<br/>'
        '<b>Lokasyon:</b> ${_esc(job.location ?? "-")}<br/>'
        '<b>Baslangic:</b> ${job.startTime != null ? job.startTime.toString().substring(0, 16) : "-"}<br/>'
        '<b>Bitis:</b> ${job.endTime != null ? job.endTime.toString().substring(0, 16) : "-"}</p>',
      );
      buf.writeln('<h3>Is oncesi fotograflar</h3>');
      for (final ph in (before.isNotEmpty ? before : general)) {
        final b64 = _imageFileToBase64(ph.photoPath);
        if (b64 != null) {
          buf.writeln(
              '<img src="data:image/jpeg;base64,$b64" width="220" style="margin:4px"/>');
        }
      }
      buf.writeln('<h3>Aciklama / is kapsami</h3>');
      buf.writeln('<p>${_esc(job.description ?? "-")}</p>');
      buf.writeln('<h3>Is sonrasi / bitmis hali</h3>');
      for (final ph in after) {
        final b64 = _imageFileToBase64(ph.photoPath);
        if (b64 != null) {
          buf.writeln(
              '<img src="data:image/jpeg;base64,$b64" width="220" style="margin:4px"/>');
        }
      }
      buf.writeln(
          '<p style="text-align:right;margin-top:40px"><b>M/V Zeynep C Master</b><br/>________________</p>');
      buf.writeln('<div style="page-break-after:always"></div>');
    }
    return await _saveWord(
      _wordHtml('M/V Zeynep C Guverte Is Raporu', buf.toString()),
      'is_raporu_resimli',
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
      TextCellValue('Bakim'), TextCellValue('Periyot'),
      TextCellValue('Sonraki'), TextCellValue('Durum'),
    ]);
    final now = DateTime.now();
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final d = plan.nextDueDate!.difference(now).inDays;
        if (d < 0) durum = 'Gecikmis';
        else if (d <= 7) durum = 'Yaklasiyor';
      }
      sheet.appendRow([
        TextCellValue(plan.title),
        IntCellValue(plan.intervalDays),
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
    final widgets = <pw.Widget>[
      pw.Text('Planli Bakim Raporu (Resimli)',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
    ];
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final d = plan.nextDueDate!.difference(now).inDays;
        if (d < 0) durum = 'Gecikmis';
        else if (d <= 7) durum = 'Yaklasiyor';
      }
      final records = await (db.select(db.maintenanceRecords)
            ..where((t) => t.planId.equals(plan.id)))
          .get();
      widgets.add(pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600, width: 0.5)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(plan.title,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Periyot: ${plan.intervalDays} gun | Durum: $durum',
                style: const pw.TextStyle(fontSize: 9)),
            for (final rec in records.take(4)) ...[
              pw.Text(
                  '• ${rec.doneDate.toString().substring(0, 16)}'
                  '${rec.notes != null ? " — ${rec.notes}" : ""}',
                  style: const pw.TextStyle(fontSize: 8)),
              if (rec.photoPath != null && rec.photoPath!.isNotEmpty)
                pw.Wrap(
                    children: _pdfImageWidgets(rec.photoPath!,
                        maxW: 140, maxH: 100)),
            ],
          ],
        ),
      ));
    }
    if (plans.isEmpty) {
      widgets.add(pw.Text('Plan yok.', style: const pw.TextStyle(fontSize: 11)));
    }
    widgets.add(pw.SizedBox(height: 16));
    widgets.add(pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('M/V Zeynep C Master',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
    ));
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4, theme: theme, build: (_) => widgets));
    return await _savePdf(pdf, 'bakim_raporu_resimli');
  }

  Future<String> exportMaintenanceWord() async {
    final plans = await db.select(db.maintenancePlans).get();
    final now = DateTime.now();
    final buf = StringBuffer();
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final d = plan.nextDueDate!.difference(now).inDays;
        if (d < 0) durum = 'Gecikmis';
        else if (d <= 7) durum = 'Yaklasiyor';
      }
      buf.writeln('<h2>${_esc(plan.title)}</h2>');
      buf.writeln('<p>Periyot: ${plan.intervalDays} gun | Durum: $durum</p>');
      final records = await (db.select(db.maintenanceRecords)
            ..where((t) => t.planId.equals(plan.id)))
          .get();
      for (final rec in records) {
        buf.writeln(
            '<p>• ${_esc(rec.doneDate.toString().substring(0, 16))}</p>');
        if (rec.photoPath != null) {
          final b64 = _imageFileToBase64(rec.photoPath!);
          if (b64 != null) {
            buf.writeln(
                '<img src="data:image/jpeg;base64,$b64" width="220"/>');
          }
        }
      }
    }
    buf.writeln(
        '<p style="text-align:right"><b>M/V Zeynep C Master</b></p>');
    return await _saveWord(
        _wordHtml('Planli Bakim Raporu', buf.toString()), 'bakim_raporu_resimli');
  }

  List<pw.Widget> _pdfImageWidgets(String path,
      {double maxW = 160, double maxH = 120}) {
    try {
      final f = File(path);
      if (!f.existsSync()) return [];
      final image = pw.MemoryImage(f.readAsBytesSync());
      return [
        pw.Container(
            width: maxW,
            height: maxH,
            child: pw.Image(image, fit: pw.BoxFit.contain)),
      ];
    } catch (_) {
      return [
        pw.Text('(foto yok)',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey))
      ];
    }
  }

  String? _imageFileToBase64(String path) {
    try {
      final f = File(path);
      if (!f.existsSync()) return null;
      return base64Encode(f.readAsBytesSync());
    } catch (_) {
      return null;
    }
  }

  String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String _wordHtml(String title, String body) => '''
<html xmlns:o="urn:schemas-microsoft-com:office:office"
xmlns:w="urn:schemas-microsoft-com:office:word">
<head><meta charset="utf-8"><title>$title</title></head>
<body><h1>$title</h1>$body</body></html>''';

  Future<String> _saveExcel(Excel excel, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Excel olusturulamadi');
    await File(path).writeAsBytes(bytes, flush: true);
    await OpenFilex.open(path);
    return path;
  }

  Future<String> _savePdf(pw.Document pdf, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await File(path).writeAsBytes(await pdf.save(), flush: true);
    await OpenFilex.open(path);
    return path;
  }

  Future<String> _saveWord(String html, String name) async {
    final dir = await getApplicationDocumentsDirectory();
    final path =
        '${dir.path}/${name}_${DateTime.now().millisecondsSinceEpoch}.doc';
    await File(path).writeAsString(html, flush: true);
    await OpenFilex.open(path);
    return path;
  }
}
