import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import 'create_job_screen.dart';
import 'job_detail_screen.dart';

class JobListScreen extends ConsumerWidget {
  const JobListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(jobsProvider);
    final currentUser = ref.watch(currentUserProvider)!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('İşler'),
        actions: [
          if (['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(currentUser.role))
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Yeni İş',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateJobScreen()),
                ).then((_) => ref.invalidate(jobsProvider));
              },
            ),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('Henüz iş yok'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                child: ListTile(
                  title: Text(job.title),
                  subtitle: Text(
                    'Durum: ${Labels.jobStatus(job.status)}'
                    ' | Öncelik: ${Labels.priority(job.priority)}'
                    '${job.location != null ? " | ${job.location}" : ""}',
                  ),
                  trailing: _StatusChip(status: job.status),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(jobId: job.id),
                      ),
                    ).then((_) {
                      ref.invalidate(jobsProvider);
                      ref.invalidate(jobPhotosProvider(job.id));
                      ref.invalidate(jobCommentsProvider(job.id));
                    });
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'PENDING':
        color = Colors.orange;
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        break;
      case 'COMPLETED':
        color = Colors.green;
        break;
      case 'APPROVED':
        color = Colors.teal;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(
        Labels.jobStatus(status),
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }
}
