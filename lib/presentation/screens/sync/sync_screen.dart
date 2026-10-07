import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/sync_service.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  final _serverUrlController =
      TextEditingController(text: 'http://192.168.1.100:8080');
  String _status = 'Hazır';
  bool _isSyncing = false;

  Future<void> _sync() async {
    final url = _serverUrlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isSyncing = true;
      _status = 'Senkronize ediliyor...';
    });

    final service = SyncService(ref.read(databaseProvider));
    final result = await service.syncWithServer(url);

    setState(() {
      _isSyncing = false;
      _status = result.success
          ? 'Tamamlandı\nKullanıcı: ${result.usersMerged}, İş: ${result.jobsMerged}, Stok: ${result.inventoryMerged}'
          : result.message;
    });

    if (result.success) {
      ref.invalidate(jobsProvider);
      ref.invalidate(inventoryProvider);
      ref.invalidate(maintenancePlansProvider);
      ref.invalidate(usersProvider);
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LAN Senkronizasyon')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aynı Wi-Fi / LAN ağındaki sunucu adresini girin.\nİnternet gerekmez.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'Sunucu URL',
                hintText: 'http://192.168.x.x:8080',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(_isSyncing ? 'Senkronize ediliyor...' : 'Senkronize Et'),
                onPressed: _isSyncing ? null : _sync,
              ),
            ),
            const SizedBox(height: 24),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
