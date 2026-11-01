import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../../../data/database/app_database.dart';
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
  bool _sharing = false;

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
      endTime: (newStatus == 'COMPLETED' || newStatus == 'APPROVED') ? now : null,
      completedByName: user.fullName,
    );
    ref.invalidate(jobsProvider);
    setState(() {});
  }

  Future<void> _addPhoto(String phase) async {
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

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (image == null) return;

    final note = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: Text(phase == 'BEFORE'
              ? 'Is oncesi foto'
              : phase == 'AFTER'
                  ? 'Is sonrasi foto'
                  : 'Foto aciklama'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(hintText: 'Opsiyonel aciklama'),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Iptal')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: const Text('Kaydet')),
          ],
        );
      },
    );
    if (note == null) return;

    final service = JobService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;
    await service.addPhoto(
      jobId: widget.jobId,
      photoPath: image.path,
      uploadedById: user.id,
      photoPhase: phase,
      description: note.isNotEmpty ? note : null,
    );
    ref.invalidate(jobPhotosProvider(widget.jobId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(phase == 'BEFORE'
              ? 'Oncesi foto eklendi'
              : phase == 'AFTER'
                  ? 'Sonrasi foto eklendi'
                  : 'Foto eklendi'),
        ),
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
  }

  /// WhatsApp: is basina SINIRSIZ foto
  Future<void> _shareWhatsApp(Job job, List<JobPhoto> photos) async {
    setState(() => _sharing = true);
    try {
      final before = photos.where((p) => p.photoPhase == 'BEFORE').toList();
      final after = photos.where((p) => p.photoPhase == 'AFTER').toList();
      final general = photos
          .where((p) => p.photoPhase != 'BEFORE' && p.photoPhase != 'AFTER')
          .toList();

      final buf = StringBuffer();
      buf.writeln('*M/V Zeynep C — Guverte Is Raporu*');
      buf.writeln('');
      buf.writeln('*Is:* ${job.title}');
      if (job.location != null && job.location!.isNotEmpty) {
        buf.writeln('*Lokasyon:* ${job.location}');
      }
      buf.writeln('*Durum:* ${Labels.jobStatus(job.status)}');
      buf.writeln('*Oncelik:* ${Labels.priority(job.priority)}');
      if (job.startTime != null) {
        buf.writeln(
            '*Baslangic:* ${job.startTime.toString().substring(0, 16)}');
      }
      if (job.endTime != null) {
        buf.writeln('*Bitis:* ${job.endTime.toString().substring(0, 16)}');
      }
      if (job.description != null && job.description!.isNotEmpty) {
        buf.writeln('');
        buf.writeln('*Is kapsami / aciklama:*');
        buf.writeln(job.description);
      }
      buf.writeln('');
      buf.writeln(
          'Oncesi: ${before.length}  |  Sonrasi: ${after.length}');
      buf.writeln('');
      buf.writeln('_M/V Zeynep C Master_');

      final files = <XFile>[];
      for (final p in [...before, ...after, ...general]) {
        if (File(p.photoPath).existsSync()) {
          files.add(XFile(p.photoPath));
        }
      }

      if (files.isEmpty) {
        await Share.share(buf.toString(), subject: 'M/V Zeynep C Is Raporu');
      } else {
        await Share.shareXFiles(
          files,
          text: buf.toString(),
          subject: 'M/V Zeynep C — ${job.title}',
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
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
              child: Text('Fotograf yuklenemedi'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _photoGrid(List<JobPhoto> list, String emptyLabel) {
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(emptyLabel,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: list.map((ph) {
        return GestureDetector(
          onTap: () => _openPhoto(ph.photoPath),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(ph.photoPath),
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 96,
                height: 96,
                color: Colors.grey.shade300,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final currentUser = ref.watch(currentUserProvider)!;

    return FutureBuilder<Job?>(
      future: (db.select(db.jobs)..where((j) => j.id.equals(widget.jobId)))
          .getSingleOrNull(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final job = snap.data!;
        final photosAsync = ref.watch(jobPhotosProvider(widget.jobId));
        final commentsAsync = ref.watch(jobCommentsProvider(widget.jobId));
        final photos = photosAsync.valueOrNull ?? [];
        final before = photos.where((p) => p.photoPhase == 'BEFORE').toList();
        final after = photos.where((p) => p.photoPhase == 'AFTER').toList();
        final other = photos
            .where((p) => p.photoPhase != 'BEFORE' && p.photoPhase != 'AFTER')
            .toList();

        final canManage =
            ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(currentUser.role);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Is Detayi'),
            actions: [
              IconButton(
                icon: _sharing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.share),
                tooltip: 'WhatsApp / Paylas',
                onPressed:
                    _sharing ? null : () => _shareWhatsApp(job, photos),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(job.title,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                  'Durum: ${Labels.jobStatus(job.status)}  |  ${Labels.priority(job.priority)}'),
              if (job.location != null) Text('Lokasyon: ${job.location}'),
              if (job.startTime != null)
                Text(
                    'Baslangic: ${job.startTime.toString().substring(0, 16)}'),
              if (job.endTime != null)
                Text('Bitis: ${job.endTime.toString().substring(0, 16)}'),
              if (job.description != null && job.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(job.description!, style: const TextStyle(height: 1.35)),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (job.status == 'PENDING' || job.status == 'ASSIGNED')
                    ElevatedButton(
                      onPressed: () => _changeStatus('IN_PROGRESS'),
                      child: const Text('Ise basla'),
                    ),
                  if (job.status == 'IN_PROGRESS')
                    ElevatedButton(
                      onPressed: () => _changeStatus('COMPLETED'),
                      child: const Text('Tamamla'),
                    ),
                  if (canManage && job.status == 'COMPLETED')
                    ElevatedButton(
                      onPressed: () => _changeStatus('APPROVED'),
                      child: const Text('Onayla'),
                    ),
                ],
              ),
              const Divider(height: 28),
              const Text('Is oncesi fotograflar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _photoGrid(before, 'Henuz oncesi foto yok'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _addPhoto('BEFORE'),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Oncesi foto ekle'),
              ),
              const SizedBox(height: 16),
              const Text('Is sonrasi fotograflar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              _photoGrid(after, 'Henuz sonrasi foto yok'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _addPhoto('AFTER'),
                icon: const Icon(Icons.add_a_photo),
                label: const Text('Sonrasi foto ekle'),
              ),
              if (other.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Diger fotograflar',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                _photoGrid(other, ''),
              ],
              const Divider(height: 28),
              const Text('Yorumlar',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              commentsAsync.when(
                data: (comments) {
                  if (comments.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Yorum yok'),
                    );
                  }
                  return Column(
                    children: comments
                        .map((c) => ListTile(
                              dense: true,
                              title: Text(c.comment),
                              subtitle: Text(
                                  c.createdAt.toString().substring(0, 16)),
                            ))
                        .toList(),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('$e'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Yorum yaz...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _savingComment ? null : _addComment,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed:
                    _sharing ? null : () => _shareWhatsApp(job, photos),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp / Paylasim hazirla'),
              ),
            ],
          ),
        );
      },
    );
  }
}
