import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../data/database/app_database.dart';
import 'notification_service.dart';
import '../core/utils/sync_identity.dart';

class JobService {
  final AppDatabase db;
  JobService(this.db);

  Future<int> createJob({
    required String title,
    String? description,
    String? location,
    String priority = 'NORMAL',
    required int createdById,
    List<int> assignedUserIds = const [],
  }) async {
    final jobId = await db.into(db.jobs).insert(JobsCompanion.insert(
          syncId: Value(SyncIdentity.newId()),
          title: title,
          description: Value(description),
          location: Value(location),
          priority: Value(priority),
          createdBy: createdById,
        ));

    for (final userId in assignedUserIds) {
      await db.into(db.jobAssignments).insert(JobAssignmentsCompanion.insert(
            syncId: Value(SyncIdentity.newId()),
            jobId: jobId,
            userId: userId,
          ));

      final user = await (db.select(db.users)..where((u) => u.id.equals(userId)))
          .getSingleOrNull();
      if (user != null) {
        await NotificationService.jobAssigned(
          jobId: jobId,
          title: title,
          toName: user.fullName,
        );
      }
    }
    return jobId;
  }

  Future<void> updateStatus({
    required int jobId,
    required String newStatus,
    DateTime? startTime,
    DateTime? endTime,
    String? completedByName,
  }) async {
    final job =
        await (db.select(db.jobs)..where((j) => j.id.equals(jobId))).getSingle();

    await (db.update(db.jobs)..where((j) => j.id.equals(jobId))).write(
      JobsCompanion(
        status: Value(newStatus),
        startTime: startTime != null ? Value(startTime) : const Value.absent(),
        endTime: endTime != null ? Value(endTime) : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (newStatus == 'IN_PROGRESS') {
      await NotificationService.jobStarted(jobId: jobId, title: job.title);
    }
    if (newStatus == 'COMPLETED') {
      await NotificationService.jobCompleted(
        jobId: jobId,
        title: job.title,
        byName: completedByName ?? 'Kullanıcı',
      );
    }
    if (newStatus == 'APPROVED') {
      await NotificationService.jobApproved(jobId: jobId, title: job.title);
    }
  }

  /// Fotoğrafı kalıcı kaydeder; boyut küçültülür (görüntü bozulmadan ~JPEG 65, max 1280px).
  Future<String> _persistPhoto(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photoDir = Directory(p.join(dir.path, 'job_photos'));
    if (!await photoDir.exists()) await photoDir.create(recursive: true);
    final dest = p.join(
      photoDir.path,
      '${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    try {
      final bytes = await File(sourcePath).readAsBytes();
      // image package ile yeniden boyutlandır + sıkıştır
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        var out = decoded;
        const maxSide = 1280;
        if (out.width > maxSide || out.height > maxSide) {
          out = img.copyResize(
            out,
            width: out.width >= out.height ? maxSide : null,
            height: out.height > out.width ? maxSide : null,
          );
        }
        final jpg = img.encodeJpg(out, quality: 65);
        await File(dest).writeAsBytes(jpg, flush: true);
        return dest;
      }
    } catch (_) {}
    await File(sourcePath).copy(dest);
    return dest;
  }

  Future<void> addPhoto({
    required int jobId,
    required String photoPath,
    required int uploadedById,
    String? description,
  }) async {
    final permanentPath = await _persistPhoto(photoPath);
    await db.into(db.jobPhotos).insert(JobPhotosCompanion.insert(
          syncId: Value(SyncIdentity.newId()),
          jobId: jobId,
          photoPath: permanentPath,
          uploadedBy: uploadedById,
          description: Value(description),
          approvalStatus: const Value('APPROVED'),
        ));
  }

  Future<void> approvePhoto({
    required int photoId,
    required int approvedById,
    required bool isApproved,
  }) async {
    await (db.update(db.jobPhotos)..where((p) => p.id.equals(photoId))).write(
      JobPhotosCompanion(
        approvedBy: Value(approvedById),
        approvalStatus: Value(isApproved ? 'APPROVED' : 'REJECTED'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> addComment({
    required int jobId,
    required int userId,
    required String comment,
  }) async {
    final text = comment.trim();
    if (text.isEmpty) return;
    await db.into(db.jobComments).insert(JobCommentsCompanion.insert(
          syncId: Value(SyncIdentity.newId()),
          jobId: jobId,
          userId: userId,
          comment: text,
        ));
  }

  Future<List<JobComment>> getComments(int jobId) async {
    return await (db.select(db.jobComments)
          ..where((c) => c.jobId.equals(jobId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }
}
