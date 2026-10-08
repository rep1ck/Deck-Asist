import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../../../services/job_service.dart';

class JobDetailScreen extends ConsumerStatefulWidget {
  final int jobId;
  const JobDetailScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends ConsumerState<JobDetailScreen> {
  final _picker = ImagePicker();
  final _commentController = TextEditingController();
  bool _savingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _changeStatus(String newStatus) async {
    final service = JobService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;
    final now = DateTime.now();

    await service.updateStatus(
      jobId: widget.jobId,
      newStatus: newStatus,
      startTime: newStatus == 'IN_PROGRESS' ? now : null,
      endTime:
          (newStatus == 'COMPLETED' || newStatus == 'APPROVED') ? now : null,
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

    final image = await _picker.pickImage(source: source, imageQuality: 60, maxWidth: 1280, maxHeight: 1280);
    if (image == null) return;

    String? note;
    if (mounted) {
      note = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final c = TextEditingController();
          return AlertDialog(
            title: const Text('Fotoğraf notu (isteğe bağlı)'),
            content: TextField(
              controller: c,
              decoration: const InputDecoration(
                hintText: 'Kısa açıklama...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Atla'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
    }

    final service = JobService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;
    await service.addPhoto(
      jobId: widget.jobId,
      photoPath: image.path,
      uploadedById: user.id,
      description: (note != null && note.isNotEmpty) ? note : null,
    );
    ref.invalidate(jobPhotosProvider(widget.jobId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf eklendi')),
      );
      setState(() {});
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingComment = true);
    final service = JobService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;
    await service.addComment(
      jobId: widget.jobId,
      userId: user.id,
      comment: text,
    );
    _commentController.clear();
    setState(() => _savingComment = false);
    ref.invalidate(jobCommentsProvider(widget.jobId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum eklendi')),
      );
    }
  }

  void _openPhoto(String path) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        child: InteractiveViewer(
          child: Image.file(
            File(path),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Fotoğraf yüklenemedi'),
            ),
          ),
        ),
      ),
    );
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
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  Chip(
                    label: Text(Labels.jobStatus(job.status)),
                    backgroundColor: _statusColor(job.status).withOpacity(0.2),
                  ),
                  Chip(label: Text('Öncelik: ${Labels.priority(job.priority)}')),
                ],
              ),
              if (job.location != null) ...[
                const SizedBox(height: 4),
                Text('Lokasyon: ${job.location}'),
              ],
              if (job.description != null && job.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(job.description!),
              ],
              if (job.startTime != null)
                Text('Başlangıç: ${_fmt(job.startTime!)}'),
              if (job.endTime != null) Text('Bitiş: ${_fmt(job.endTime!)}'),
              const Divider(height: 32),
              const Text('Durum İşlemleri',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  if (job.status == 'PENDING')
                    ElevatedButton.icon(
                      onPressed: () => _changeStatus('IN_PROGRESS'),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('İşe Başla'),
                    ),
                  if (job.status == 'IN_PROGRESS')
                    ElevatedButton.icon(
                      onPressed: () => _changeStatus('COMPLETED'),
                      icon: const Icon(Icons.check),
                      label: const Text('Tamamla'),
                    ),
                  if (job.status == 'COMPLETED' &&
                      ['ROOT', 'MASTER', 'SECOND', 'REIS']
                          .contains(currentUser.role))
                    ElevatedButton.icon(
                      onPressed: () => _changeStatus('APPROVED'),
                      icon: const Icon(Icons.verified),
                      label: const Text('Onayla'),
                    ),
                ],
              ),
              const Divider(height: 32),
              // —— Fotoğraflar ——
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fotoğraflar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addPhoto,
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Ekle'),
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
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Henüz fotoğraf yok. Kamera veya galeriden ekleyin.'),
                        );
                      }
                      return SizedBox(
                        height: 140,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: photos.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final ph = photos[i];
                            final file = File(ph.photoPath);
                            return GestureDetector(
                              onTap: () {
                                if (file.existsSync()) {
                                  _openPhoto(ph.photoPath);
                                }
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: file.existsSync()
                                    ? Image.file(
                                        file,
                                        width: 140,
                                        height: 140,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        width: 140,
                                        height: 140,
                                        color: Colors.grey.shade300,
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image),
                                      ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('Hata: $e'),
                  );
                },
              ),
              const Divider(height: 32),
              // —— Yorumlar ——
              const Text('Yorumlar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Consumer(
                builder: (context, ref, _) {
                  final commentsAsync =
                      ref.watch(jobCommentsProvider(widget.jobId));
                  final usersAsync = ref.watch(usersProvider);
                  return commentsAsync.when(
                    data: (comments) {
                      if (comments.isEmpty) {
                        return const Text('Henüz yorum yok.');
                      }
                      final users = usersAsync.valueOrNull ?? [];
                      String nameOf(int id) {
                        final u = users.where((x) => x.id == id);
                        return u.isEmpty ? 'Kullanıcı #$id' : u.first.fullName;
                      }
                      return Column(
                        children: comments.map((c) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(c.comment),
                              subtitle: Text(
                                '${nameOf(c.userId)} • ${_fmt(c.createdAt)}',
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('$e'),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Yorum yaz...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _savingComment ? null : _addComment,
                    icon: _savingComment
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'PENDING':
        return Colors.orange;
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'COMPLETED':
        return Colors.green;
      case 'APPROVED':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  static String _fmt(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
