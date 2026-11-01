import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/report_service.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime? _from;
  DateTime? _to;
  bool _onlyDone = true;
  bool _busy = false;

  Future<void> _pickFrom() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now().subtract(const Duration(days: 7)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _from = d);
  }

  Future<void> _pickTo() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d != null) setState(() => _to = d);
  }

  Future<void> _run(Future<String> Function() fn) async {
    setState(() => _busy = true);
    try {
      final path = await fn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapor hazir')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final service = ReportService(db);

    String fmt(DateTime? d) =>
        d == null ? 'Sec' : '${d.day}.${d.month}.${d.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Raporlar')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Is raporu tarih araligi',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickFrom,
                  child: Text('Baslangic: ${fmt(_from)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _pickTo,
                  child: Text('Bitis: ${fmt(_to)}'),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sadece tamamlanan / onayli isler'),
            value: _onlyDone,
            onChanged: (v) => setState(() => _onlyDone = v),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Is raporu PDF (A4, resimli)'),
            subtitle: const Text('Oncelikli format'),
            onTap: _busy
                ? null
                : () => _run(() => service.exportJobsPdf(
                      from: _from,
                      to: _to,
                      onlyCompleted: _onlyDone,
                    )),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Is raporu Word'),
            onTap: _busy
                ? null
                : () => _run(() => service.exportJobsWord(
                      from: _from,
                      to: _to,
                      onlyCompleted: _onlyDone,
                    )),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart),
            title: const Text('Is listesi Excel'),
            onTap: _busy ? null : () => _run(() => service.exportJobsExcel()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Stok Excel'),
            onTap:
                _busy ? null : () => _run(() => service.exportInventoryExcel()),
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Stok PDF'),
            onTap: _busy
                ? null
                : () => _run(() => service.exportInventory(ReportFormat.pdf)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.build),
            title: const Text('Bakim PDF (resimli)'),
            onTap:
                _busy ? null : () => _run(() => service.exportMaintenancePdf()),
          ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
