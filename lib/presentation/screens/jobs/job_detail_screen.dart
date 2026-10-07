import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers.dart';
import '../../../services/job_service.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final int jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _picker = ImagePicker();

  Future<void> _changeStatus(String newStatus) async {
    final service = JobService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;
    final now = DateTime.now();

    await service.updateStatus(
      jobId: widget.jobId,
      newStatus: newStatus,
      startTime: newStatus == 'IN_PROGRESS' ? now : null,
      endTime: (newStatus == 'COMPLETED' || newStatus == 'APPROVED') ? now : null,
      completedByName: user.fullName,
    );
    ref.invalidate(jobsProvider);
    setState(() {});
  }

  Future<void> _addPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    final service = JobService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;
    await service.addPhoto(
      jobId: widget.jobId,
      photoPath: image.path,
      uploadedById: user.id,
    );
    ref.invalidate(jobPhotosProvider(widget.jobId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf eklendi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final currentUser = ref.watch(currentUserProvider)!;

    return FutureBuilder(
      future: (db.select(db.jobs)..where((j) => j.id.equals(widget.jobId)))
          .getSingleOrNull(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final job = snapshot.data;
        if (job == null) {
          return const Scaffold(body: Center(child: Text('İş bulunamadı')));
        }

        return Scaffold(
          appBar: AppBar(title: const Text('İş Detayı')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(job.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Durum: ${job.status}'),
              if (job.location != null) Text('Lokasyon: ${job.location}'),
              if (job.description != null) ...[
                const SizedBox(height: 8),
                Text(job.description!),
              ],
              if (job.startTime != null)
                Text('Başlangıç: ${job.startTime}'),
              if (job.endTime != null) Text('Bitiş: ${job.endTime}'),
              const Divider(height: 32),
              const Text('Durum İşlemleri',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (job.status == 'PENDING')
                    ElevatedButton(
                      onPressed: () => _changeStatus('IN_PROGRESS'),
                      child: const Text('İşe Başla'),
                    ),
                  if (job.status == 'IN_PROGRESS')
                    ElevatedButton(
                      onPressed: () => _changeStatus('COMPLETED'),
                      child: const Text('Tamamla'),
                    ),
                  if (job.status == 'COMPLETED' &&
                      ['ROOT', 'MASTER', 'SECOND', 'REIS']
                          .contains(currentUser.role))
                    ElevatedButton(
                      onPressed: () => _changeStatus('APPROVED'),
                      child: const Text('Onayla'),
                    ),
                ],
              ),
              const Divider(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fotoğraflar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_a_photo),
                    onPressed: _addPhoto,
                  ),
                ],
              ),
              Consumer(
                builder: (context, ref, _) {
                  final photosAsync =
                      ref.watch(jobPhotosProvider(widget.jobId));
                  return photosAsync.when(
                    data: (photos) {
                      if (photos.isEmpty) {
                        return const Text('Henüz fotoğraf yok');
                      }
                      return Text('${photos.length} fotoğraf');
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('$e'),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
