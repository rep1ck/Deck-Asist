import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/report_service.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  Future<void> _pickAndExport(
    BuildContext context,
    ReportService service,
    String title,
    Future<String> Function(ReportFormat) exportFn,
  ) async {
    final format = await showModalBottomSheet<ReportFormat>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Excel (.xlsx)'),
              onTap: () => Navigator.pop(ctx, ReportFormat.excel),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('PDF (.pdf)'),
              onTap: () => Navigator.pop(ctx, ReportFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Word (.doc)'),
              onTap: () => Navigator.pop(ctx, ReportFormat.word),
            ),
          ],
        ),
      ),
    );
    if (format == null) return;
    try {
      final path = await exportFn(format);
      await service.openFile(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapor oluşturuldu')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

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
          const Text(
            'Bir rapor seçin, ardından Excel / PDF / Word formatını belirleyin.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 12),
          _ReportTile(
            title: 'Stok Listesi',
            subtitle: 'Boya ve malzemeler',
            icon: Icons.inventory_2,
            onTap: () => _pickAndExport(
              context,
              reportService,
              'Stok Listesi – format seçin',
              reportService.exportInventory,
            ),
          ),
          _ReportTile(
            title: 'İş Raporu',
            subtitle: 'Güverte işleri ve durumlar',
            icon: Icons.work,
            onTap: () => _pickAndExport(
              context,
              reportService,
              'İş Raporu – format seçin',
              reportService.exportJobs,
            ),
          ),
          _ReportTile(
            title: 'Planlı Bakım',
            subtitle: 'Bakım planları ve tarihler',
            icon: Icons.build,
            onTap: () => _pickAndExport(
              context,
              reportService,
              'Planlı Bakım – format seçin',
              reportService.exportMaintenance,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
