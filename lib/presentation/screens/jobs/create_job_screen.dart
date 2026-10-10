import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/utils/labels.dart';
import '../../../services/job_service.dart';

class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({super.key});

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  String _priority = 'NORMAL';
  final List<int> _selectedUserIds = [];
  bool _isLoading = false;

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);

    final service = JobService(ref.read(databaseProvider));
    final currentUser = ref.read(currentUserProvider)!;

    await service.createJob(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      location: _locationController.text.trim(),
      priority: _priority,
      createdById: currentUser.id,
      assignedUserIds: _selectedUserIds,
    );

    setState(() => _isLoading = false);
    ref.invalidate(jobsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(usersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Is')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Is Basligi *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Aciklama',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Lokasyon',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Oncelik',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'LOW', child: Text('Dusuk')),
                DropdownMenuItem(value: 'NORMAL', child: Text('Normal')),
                DropdownMenuItem(value: 'HIGH', child: Text('Yuksek')),
                DropdownMenuItem(value: 'URGENT', child: Text('Acil')),
              ],
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 16),
            const Text('Atanacak Personeller',
                style: TextStyle(fontWeight: FontWeight.bold)),
            usersAsync.when(
              data: (users) {
                final assignable = users
                    .where((u) =>
                        u.isActive == 1 &&
                        (u.role == 'PERSONEL' || u.role == 'REIS'))
                    .toList();
                if (assignable.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Atanacak personel yok.\n'
                      'Kullanici Yonetimi\'nden rol=Personel veya Reis kullanici ekleyin.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  );
                }
                return Column(
                  children: assignable.map((user) {
                    final selected = _selectedUserIds.contains(user.id);
                    return CheckboxListTile(
                      title: Text(user.fullName),
                      subtitle: Text(Labels.role(user.role)),
                      value: selected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserIds.add(user.id);
                          } else {
                            _selectedUserIds.remove(user.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, s) => Text('$e'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Isi Olustur'),
            ),
          ],
        ),
      ),
    );
  }
}
