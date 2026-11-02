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
    final jobsAsync = ref.watch(visibleJobsProvider);
    final user = ref.watch(currentUserProvider)!;
    final canCreate =
        ['ROOT', 'MASTER', 'SECOND', 'REIS'].contains(user.role);

    return Scaffold(
      appBar: AppBar(
        title: Text(user.role == 'PERSONEL' ? 'İşlerim' : 'İşler'),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateJobScreen()),
                );
                ref.invalidate(visibleJobsProvider);
                ref.invalidate(jobsProvider);
                ref.invalidate(openJobsProvider);
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: jobsAsync.when(
        data: (jobs) {
          if (jobs.isEmpty) {
            return const Center(child: Text('İş bulunamadı'));
          }
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, i) {
              final j = jobs[i];
              return ListTile(
                title: Text(j.title),
                subtitle: Text(
                  '${Labels.jobStatus(j.status)} · ${Labels.priority(j.priority)}'
                  '${j.jobCategory.isNotEmpty ? " · ${j.jobCategory}" : ""}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JobDetailScreen(jobId: j.id),
                    ),
                  );
                  ref.invalidate(visibleJobsProvider);
                  ref.invalidate(openJobsProvider);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
