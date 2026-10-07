import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/report_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider)!;
    final canExport = ['ROOT', 'MASTER', 'SECOND', 'REIS', 'INSPECTOR']
        .contains(user.role);

    if (!canExport) {
      return const Scaffold(
        body: Center(child: Text('Rapor alma yetkiniz yok')),
      );
    }

    final reportService = ReportService(ref.watch(databaseProvider));

    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportTile(
            title: 'Stok Listesi (Excel)',
            icon: Icons.table_chart,
            onTap: () async {
              final path = await reportService.exportInventoryExcel();
              await reportService.openFile(path);
            },
          ),
          _ReportTile(
            title: 'Stok Listesi (PDF)',
            icon: Icons.picture_as_pdf,
            onTap: () async {
              final path = await reportService.exportInventoryPdf();
              await reportService.openFile(path);
            },
          ),
          _ReportTile(
            title: 'İş Raporu (Excel)',
            icon: Icons.work,
            onTap: () async {
              final path = await reportService.exportJobsExcel();
              await reportService.openFile(path);
            },
          ),
          _ReportTile(
            title: 'Planlı Bakım (Excel)',
            icon: Icons.build,
            onTap: () async {
              final path = await reportService.exportMaintenanceExcel();
              await reportService.openFile(path);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        trailing: const Icon(Icons.download),
        onTap: onTap,
      ),
    );
  }
}
