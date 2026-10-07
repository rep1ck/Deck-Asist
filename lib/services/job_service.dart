import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import 'notification_service.dart';

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
          title: title,
          description: Value(description),
          location: Value(location),
          priority: Value(priority),
          createdBy: createdById,
        ));

    for (final userId in assignedUserIds) {
      await db.into(db.jobAssignments).insert(JobAssignmentsCompanion.insert(
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

  Future<void> addPhoto({
    required int jobId,
    required String photoPath,
    required int uploadedById,
    String? description,
  }) async {
    await db.into(db.jobPhotos).insert(JobPhotosCompanion.insert(
          jobId: jobId,
          photoPath: photoPath,
          uploadedBy: uploadedById,
          description: Value(description),
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
      ),
    );
  }
}
