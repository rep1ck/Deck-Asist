import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/maintenance_service.dart';

class CreateMaintenancePlanScreen extends ConsumerStatefulWidget {
  const CreateMaintenancePlanScreen({super.key});

  @override
  ConsumerState<CreateMaintenancePlanScreen> createState() =>
      _CreateMaintenancePlanScreenState();
}

class _CreateMaintenancePlanScreenState
    extends ConsumerState<CreateMaintenancePlanScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _intervalController = TextEditingController(text: '30');
  bool _isLoading = false;

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final interval = int.tryParse(_intervalController.text);
    if (title.isEmpty || interval == null || interval <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Başlık ve geçerli periyot girin')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final service = MaintenanceService(ref.read(databaseProvider));
    final user = ref.read(currentUserProvider)!;

    await service.createPlan(
      title: title,
      description: _descriptionController.text.trim(),
      intervalDays: interval,
      createdById: user.id,
    );

    setState(() => _isLoading = false);
    ref.invalidate(maintenancePlansProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan oluşturuldu')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _intervalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Bakım Planı')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Bakım Adı *',
                hintText: 'Örn: Kreyn Teli Yağlama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _intervalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Periyot (Gün) *',
                hintText: '30, 90, 180, 365',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Planı Oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}
