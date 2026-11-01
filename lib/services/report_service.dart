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
import '../core/utils/ship_settings.dart';

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

  List<Job> _filterJobs(
    List<Job> jobs, {
    DateTime? from,
    DateTime? to,
    bool onlyCompleted = false,
  }) {
    var list = jobs;
    if (onlyCompleted) {
      list = list
          .where((j) => j.status == 'COMPLETED' || j.status == 'APPROVED')
          .toList();
    }
    if (from != null) {
      final f = DateTime(from.year, from.month, from.day);
      list = list.where((j) {
        final t = j.endTime ?? j.startTime ?? j.createdAt;
        return !t.isBefore(f);
      }).toList();
    }
    if (to != null) {
      final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
      list = list.where((j) {
        final t = j.endTime ?? j.startTime ?? j.createdAt;
        return !t.isAfter(end);
      }).toList();
    }
    return list;
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
      TextCellValue('Urun'),
      TextCellValue('Kategori'),
      TextCellValue('Birim'),
      TextCellValue('Stok'),
      TextCellValue('Min'),
      TextCellValue('Renk'),
    ]);
    for (final i in items) {
      sheet.appendRow([
        TextCellValue(i.barcode),
        TextCellValue(i.name),
        TextCellValue(Labels.category(i.category)),
        TextCellValue(i.unit),
        TextCellValue(i.currentStock.toString()),
        TextCellValue(i.minStock.toString()),
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
            style:
                pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
          headerStyle:
              pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
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
      _wordHtml(
          'Stok Raporu',
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

  Future<String> exportJobsExcel({
    DateTime? from,
    DateTime? to,
    bool onlyCompleted = false,
  }) async {
    var jobs = _filterJobs(await db.select(db.jobs).get(),
        from: from, to: to, onlyCompleted: onlyCompleted);
    final excel = Excel.createExcel();
    final sheet = excel['Isler'];
    sheet.appendRow([
      TextCellValue('Baslik'),
      TextCellValue('Kategori'),
      TextCellValue('Durum'),
      TextCellValue('Oncelik'),
      TextCellValue('Lokasyon'),
      TextCellValue('Baslangic'),
      TextCellValue('Bitis'),
      TextCellValue('Aciklama'),
      TextCellValue('Hava'),
      TextCellValue('Yorumlar'),
    ]);
    for (final j in jobs) {
      final comments = await (db.select(db.jobComments)
            ..where((t) => t.jobId.equals(j.id)))
          .get();
      final commentText = comments.map((c) => c.comment).join(' | ');
      sheet.appendRow([
        TextCellValue(j.title),
        TextCellValue(Labels.jobCategory(j.jobCategory)),
        TextCellValue(Labels.jobStatus(j.status)),
        TextCellValue(Labels.priority(j.priority)),
        TextCellValue(j.location ?? ''),
        TextCellValue(
            j.startTime != null ? j.startTime.toString().substring(0, 16) : ''),
        TextCellValue(
            j.endTime != null ? j.endTime.toString().substring(0, 16) : ''),
        TextCellValue(j.description ?? ''),
        TextCellValue(j.weatherNote ?? ''),
        TextCellValue(commentText),
      ]);
    }
    return await _saveExcel(excel, 'is_raporu');
  }

  Future<String> exportJobsPdf({
    DateTime? from,
    DateTime? to,
    bool onlyCompleted = false,
  }) async {
    final jobs = _filterJobs(await db.select(db.jobs).get(),
        from: from, to: to, onlyCompleted: onlyCompleted);
    final ship = await ShipSettings.shipName();
    final sign = await ShipSettings.signatureBlock();
    final reportNo = await ShipSettings.nextReportNo();
    final theme = await _pdfTheme();
    final pdf = pw.Document(theme: theme);

    if (jobs.isEmpty) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (_) => pw.Center(child: pw.Text('Kayitli is yok.')),
      ));
      return await _savePdf(pdf, 'is_raporu_A4');
    }

    for (final job in jobs) {
      final allPhotos = await (db.select(db.jobPhotos)
            ..where((t) => t.jobId.equals(job.id)))
          .get();
      final before =
          allPhotos.where((p) => p.photoPhase == 'BEFORE').take(6).toList();
      final after =
          allPhotos.where((p) => p.photoPhase == 'AFTER').take(6).toList();
      final general = allPhotos
          .where((p) => p.photoPhase != 'BEFORE' && p.photoPhase != 'AFTER')
          .take(6)
          .toList();
      final comments = await (db.select(db.jobComments)
            ..where((t) => t.jobId.equals(job.id)))
          .get();

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 22, 24, 22),
        theme: theme,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('$ship — Guverte Is Raporu',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(reportNo, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
              pw.Text(
                  'Tarih: ${DateTime.now().toString().substring(0, 16)}',
                  style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 1),
              pw.Text(job.title,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(
                'Durum: ${Labels.jobStatus(job.status)}  |  '
                'Oncelik: ${Labels.priority(job.priority)}  |  '
                'Kategori: ${Labels.jobCategory(job.jobCategory)}',
                style: const pw.TextStyle(fontSize: 8),
              ),
              if (job.location != null && job.location!.isNotEmpty)
                pw.Text('Lokasyon: ${job.location}',
                    style: const pw.TextStyle(fontSize: 8)),
              if (job.weatherNote != null && job.weatherNote!.isNotEmpty)
                pw.Text('Hava / deniz: ${job.weatherNote}',
                    style: const pw.TextStyle(fontSize: 8)),
              pw.SizedBox(height: 4),
              pw.Text(
                'Is baslangic: ${job.startTime != null ? job.startTime.toString().substring(0, 16) : "-"}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Is oncesi fotograflar',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              _photoBlock(before.isNotEmpty ? before : general),
              pw.SizedBox(height: 6),
              pw.Text(
                'Is bitis: ${job.endTime != null ? job.endTime.toString().substring(0, 16) : "-"}',
                style: const pw.TextStyle(fontSize: 9),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Aciklama / is kapsami',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                ),
                child: pw.Text(
                  (job.description != null && job.description!.isNotEmpty)
                      ? job.description!
                      : '-',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              if (comments.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text('Yorumlar',
                    style: pw.TextStyle(
                        fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ...comments.map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 4, top: 1),
                      child: pw.Text(
                          '• ${c.comment}  (${c.createdAt.toString().substring(0, 16)})',
                          style: const pw.TextStyle(fontSize: 8)),
                    )),
              ],
              pw.SizedBox(height: 6),
              pw.Text('Is sonrasi / bitmis hali',
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              _photoBlock(after),
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(sign,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold),
                        textAlign: pw.TextAlign.right),
                    pw.SizedBox(height: 18),
                    pw.Text('________________',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Imza', style: const pw.TextStyle(fontSize: 7)),
                  ],
                ),
              ),
            ],
          );
        },
      ));
    }
    return await _savePdf(pdf, 'is_raporu_A4');
  }

  pw.Widget _photoBlock(List<JobPhoto> photos) {
    final list = photos.take(6).toList();
    if (list.isEmpty) {
      return pw.Text('Fotograf yok',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600));
    }
    final cells = <pw.Widget>[];
    for (final ph in list) {
      final imgs = _pdfImageWidgets(ph.photoPath, maxW: 155, maxH: 95);
      cells.add(pw.Container(
        width: 158,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            ...imgs,
            if (ph.description != null && ph.description!.isNotEmpty)
              pw.Text(ph.description!,
                  style: const pw.TextStyle(fontSize: 7), maxLines: 2),
          ],
        ),
      ));
    }
    return pw.Wrap(spacing: 6, runSpacing: 6, children: cells);
  }

  Future<String> exportJobsWord({
    DateTime? from,
    DateTime? to,
    bool onlyCompleted = false,
  }) async {
    final jobs = _filterJobs(await db.select(db.jobs).get(),
        from: from, to: to, onlyCompleted: onlyCompleted);
    final ship = await ShipSettings.shipName();
    final sign = await ShipSettings.signatureBlock();
    final reportNo = await ShipSettings.nextReportNo();
    final buf = StringBuffer();

    if (jobs.isEmpty) {
      buf.writeln('<p>Kayitli is yok.</p>');
    }

    for (final job in jobs) {
      final allPhotos = await (db.select(db.jobPhotos)
            ..where((t) => t.jobId.equals(job.id)))
          .get();
      final before =
          allPhotos.where((p) => p.photoPhase == 'BEFORE').take(6).toList();
      final after =
          allPhotos.where((p) => p.photoPhase == 'AFTER').take(6).toList();
      final general = allPhotos
          .where((p) => p.photoPhase != 'BEFORE' && p.photoPhase != 'AFTER')
          .take(6)
          .toList();
      final comments = await (db.select(db.jobComments)
            ..where((t) => t.jobId.equals(job.id)))
          .get();

      buf.writeln('<div style="page-break-after:always">');
      buf.writeln('<h1>${_esc(ship)} — Guverte Is Raporu</h1>');
      buf.writeln('<p><small>Rapor No: ${_esc(reportNo)}</small></p>');
      buf.writeln('<h2>${_esc(job.title)}</h2>');
      buf.writeln(
        '<p><b>Durum:</b> ${_esc(Labels.jobStatus(job.status))} | '
        '<b>Oncelik:</b> ${_esc(Labels.priority(job.priority))} | '
        '<b>Kategori:</b> ${_esc(Labels.jobCategory(job.jobCategory))}<br/>'
        '<b>Lokasyon:</b> ${_esc(job.location ?? "-")}<br/>'
        '<b>Hava/deniz:</b> ${_esc(job.weatherNote ?? "-")}<br/>'
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
        if (ph.description != null && ph.description!.isNotEmpty) {
          buf.writeln('<p><small>${_esc(ph.description!)}</small></p>');
        }
      }
      buf.writeln('<h3>Aciklama / is kapsami</h3>');
      buf.writeln('<p>${_esc(job.description ?? "-")}</p>');
      if (comments.isNotEmpty) {
        buf.writeln('<h3>Yorumlar</h3><ul>');
        for (final c in comments) {
          buf.writeln(
              '<li>${_esc(c.comment)} <small>(${c.createdAt.toString().substring(0, 16)})</small></li>');
        }
        buf.writeln('</ul>');
      }
      buf.writeln('<h3>Is sonrasi / bitmis hali</h3>');
      for (final ph in after) {
        final b64 = _imageFileToBase64(ph.photoPath);
        if (b64 != null) {
          buf.writeln(
              '<img src="data:image/jpeg;base64,$b64" width="220" style="margin:4px"/>');
        }
        if (ph.description != null && ph.description!.isNotEmpty) {
          buf.writeln('<p><small>${_esc(ph.description!)}</small></p>');
        }
      }
      buf.writeln(
          '<p style="text-align:right;margin-top:36px"><b>${_esc(sign).replaceAll('\n', '<br/>')}</b><br/>________________</p>');
      buf.writeln('</div>');
    }
    return await _saveWord(
      _wordHtml('$ship Guverte Is Raporu', buf.toString()),
      'is_raporu_A4',
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
      TextCellValue('Bakim'),
      TextCellValue('Periyot'),
      TextCellValue('Sonraki'),
      TextCellValue('Durum'),
    ]);
    final now = DateTime.now();
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final d = plan.nextDueDate!.difference(now).inDays;
        if (d < 0) {
          durum = 'Gecikmis';
        } else if (d <= 7) {
          durum = 'Yaklasiyor';
        }
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
    final sign = await ShipSettings.signatureBlock();
    final pdf = pw.Document(theme: theme);
    final widgets = <pw.Widget>[
      pw.Text('Planli Bakim Raporu',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
    ];
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final d = plan.nextDueDate!.difference(now).inDays;
        if (d < 0) {
          durum = 'Gecikmis';
        } else if (d <= 7) {
          durum = 'Yaklasiyor';
        }
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
            pw.Text('Periyot: ${plan.intervalDays} gun | Durum: $durum',
                style: const pw.TextStyle(fontSize: 9)),
            if (plan.description != null && plan.description!.isNotEmpty)
              pw.Text(plan.description!,
                  style: const pw.TextStyle(fontSize: 8)),
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
      widgets
          .add(pw.Text('Plan yok.', style: const pw.TextStyle(fontSize: 11)));
    }
    widgets.add(pw.SizedBox(height: 16));
    widgets.add(pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text(sign,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    ));
    pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4, theme: theme, build: (_) => widgets));
    return await _savePdf(pdf, 'bakim_raporu_resimli');
  }

  Future<String> exportMaintenanceWord() async {
    final plans = await db.select(db.maintenancePlans).get();
    final now = DateTime.now();
    final sign = await ShipSettings.signatureBlock();
    final buf = StringBuffer();
    for (final plan in plans) {
      String durum = 'Normal';
      if (plan.nextDueDate != null) {
        final d = plan.nextDueDate!.difference(now).inDays;
        if (d < 0) {
          durum = 'Gecikmis';
        } else if (d <= 7) {
          durum = 'Yaklasiyor';
        }
      }
      buf.writeln('<h2>${_esc(plan.title)}</h2>');
      buf.writeln('<p>Periyot: ${plan.intervalDays} gun | Durum: $durum</p>');
      if (plan.description != null) {
        buf.writeln('<p>${_esc(plan.description!)}</p>');
      }
      final records = await (db.select(db.maintenanceRecords)
            ..where((t) => t.planId.equals(plan.id)))
          .get();
      for (final rec in records) {
        buf.writeln(
            '<p>• ${_esc(rec.doneDate.toString().substring(0, 16))}'
            '${rec.notes != null ? " — ${_esc(rec.notes!)}" : ""}</p>');
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
        '<p style="text-align:right"><b>${_esc(sign).replaceAll('\n', '<br/>')}</b></p>');
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
<body>$body</body></html>''';

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
