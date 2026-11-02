import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/database/app_database.dart';

class ArchiveService {
  final AppDatabase db;
  ArchiveService(this.db);

  Future<ArchiveResult> archiveCompletedJobs({int olderThanDays = 14}) async {
    final cutoff = DateTime.now().subtract(Duration(days: olderThanDays));
    final jobs = await (db.select(db.jobs)
          ..where((j) => j.status.isIn(['COMPLETED', 'APPROVED'])))
        .get();

    final oldJobs = jobs.where((j) {
      final t = j.endTime ?? j.updatedAt;
      return t.isBefore(cutoff);
    }).toList();

    if (oldJobs.isEmpty) {
      return const ArchiveResult(
        success: true,
        message: 'Arsivlenecek eski is yok.',
        archivedJobs: 0,
        deletedPhotos: 0,
        deletedComments: 0,
      );
    }

    final docs = await getApplicationDocumentsDirectory();
    final archiveDir = Directory(p.join(docs.path, 'archives'));
    if (!await archiveDir.exists()) await archiveDir.create(recursive: true);

    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final zipPath = p.join(archiveDir.path, 'deck_archive_$stamp.zip');
    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    var photoCount = 0;
    var commentCount = 0;
    final summary = StringBuffer();
    summary.writeln('Deck Asist Haftalik Arsiv');
    summary.writeln('Tarih: ${DateTime.now()}');
    summary.writeln('Esik: $olderThanDays gunden eski tamamlanmis isler');
    summary.writeln('');

    for (final job in oldJobs) {
      summary.writeln('--- Is #${job.id}: ${job.title}');
      summary.writeln('Durum: ${job.status}');
      summary.writeln('Baslangic: ${job.startTime}');
      summary.writeln('Bitis: ${job.endTime}');
      summary.writeln('Olusturma: ${job.createdAt}');

      final photos = await (db.select(db.jobPhotos)
            ..where((ph) => ph.jobId.equals(job.id)))
          .get();
      for (final ph in photos) {
        final f = File(ph.photoPath);
        if (await f.exists()) {
          final name = 'job_${job.id}/photos/${p.basename(ph.photoPath)}';
          await encoder.addFile(f, name);
          try {
            await f.delete();
          } catch (_) {}
        }
        await (db.delete(db.jobPhotos)..where((t) => t.id.equals(ph.id))).go();
        photoCount++;
        if (ph.description != null && ph.description!.isNotEmpty) {
          summary.writeln('  Foto not: ${ph.description}');
        }
      }

      final comments = await (db.select(db.jobComments)
            ..where((c) => c.jobId.equals(job.id)))
          .get();
      for (final c in comments) {
        summary.writeln('  Yorum (${c.createdAt}): ${c.comment}');
        await (db.delete(db.jobComments)..where((t) => t.id.equals(c.id))).go();
        commentCount++;
      }
      summary.writeln('');
    }

    final tmpSummary = File(p.join(docs.path, 'archive_summary_$stamp.txt'));
    await tmpSummary.writeAsString(summary.toString(), flush: true);
    await encoder.addFile(tmpSummary, 'OZET.txt');
    encoder.close();
    try {
      await tmpSummary.delete();
    } catch (_) {}

    return ArchiveResult(
      success: true,
      message:
          '${oldJobs.length} is arsivlendi. $photoCount fotograf, $commentCount yorum zip\'e alindi ve uygulamadan silindi.',
      archivedJobs: oldJobs.length,
      deletedPhotos: photoCount,
      deletedComments: commentCount,
      zipPath: zipPath,
    );
  }
}

class ArchiveResult {
  final bool success;
  final String message;
  final int archivedJobs;
  final int deletedPhotos;
  final int deletedComments;
  final String? zipPath;

  const ArchiveResult({
    required this.success,
    required this.message,
    this.archivedJobs = 0,
    this.deletedPhotos = 0,
    this.deletedComments = 0,
    this.zipPath,
  });
}
