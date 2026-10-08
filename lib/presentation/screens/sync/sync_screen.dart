import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../services/sync_service.dart';
import '../../../services/archive_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

class SyncScreen extends ConsumerStatefulWidget {
  const SyncScreen({super.key});

  @override
  ConsumerState<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends ConsumerState<SyncScreen> {
  String _status = 'Ağ taranıyor...';
  bool _isSyncing = false;
  List<String> _peers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _discoverAndSync());
  }

  Future<void> _discoverAndSync() async {
    final service = ref.read(syncServiceProvider);
    setState(() {
      _isSyncing = true;
      _status = 'Aynı ağdaki Deck Asist cihazları aranıyor...';
    });

    final peers = await service.discoverPeers();
    if (mounted) setState(() => _peers = peers);

    final result = await service.syncWithDiscoveredPeers();
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _status = result.message;
    });

    if (result.success) _invalidateData();
  }



  Future<void> _weeklyArchive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('14 günlük arşiv uyarısı'),
        content: const Text(
          '14 günden eski tamamlanmış / onaylanmış işlerin fotoğraf ve yorumları '
          'zip dosyasına alınır ve uygulamadan SİLİNİR.

'
          'İş kaydında yalnızca başlık, durum, başlangıç ve bitiş bilgisi kalır.

'
          'Bu işlem geri alınamaz. Devam edilsin mi?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Anladım, arşivle'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() {
      _isSyncing = true;
      _status = 'Arşiv oluşturuluyor...';
    });
    final archive = ArchiveService(ref.read(databaseProvider));
    final result = await archive.archiveCompletedJobs(olderThanDays: 14);
    if (!mounted) return;
    setState(() {
      _isSyncing = false;
      _status = result.message;
    });
    if (result.zipPath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
      }
      return;
    }
    final share = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arşiv hazır'),
        content: Text(result.message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'open'), child: const Text('Dosyayı aç')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, 'email'),
            icon: const Icon(Icons.email),
            label: const Text('E-posta ile paylaş'),
          ),
        ],
      ),
    );
    if (share == 'open') {
      await OpenFilex.open(result.zipPath!);
    } else if (share == 'email') {
      await Share.shareXFiles(
        [XFile(result.zipPath!)],
        subject: 'Deck Asist haftalık arşiv',
        text: 'Deck Asist 14 günlük fotoğraf ve yorum arşivi ektedir.

rep1ck & BY',
      );
    }
    ref.invalidate(jobsProvider);
  }

  void _invalidateData() {
    ref.invalidate(usersProvider);
    ref.invalidate(jobsProvider);
    ref.invalidate(inventoryProvider);
    ref.invalidate(maintenancePlansProvider);
  }

  @override
  Widget build(BuildContext context) {
    final service = ref.watch(syncServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('LAN Senkronizasyon')),
      body: RefreshIndicator(
        onRefresh: _discoverAndSync,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.wifi, size: 28),
                      SizedBox(width: 10),
                      Expanded(child: Text('Otomatik LAN senkronizasyonu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    ]),
                    const SizedBox(height: 12),
                    const Text('Aynı Wi-Fi ağına bağlı çalışan Deck Asist cihazları birbirini otomatik bulur. İnternet veya merkezi sunucu gerekmez.'),
                    const SizedBox(height: 12),
                    FutureBuilder<String>(
                      future: service.deviceId,
                      builder: (_, snapshot) => Text('Bu cihaz: ${snapshot.data ?? '...'}', style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSyncing ? null : _discoverAndSync,
              icon: _isSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Senkronize ediliyor...' : 'Şimdi Senkronize Et'),
            ),
            const SizedBox(height: 20),
            Text('Durum', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(_status),
            const SizedBox(height: 20),
            Text('Bulunan cihazlar (${_peers.length})', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_peers.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Henüz başka Deck Asist cihazı bulunamadı. Diğer cihazda da uygulamanın açık olduğundan ve aynı Wi-Fi ağında olduğundan emin olun.')))
            else
              ..._peers.map((peer) => ListTile(leading: const Icon(Icons.devices), title: Text(peer))),
            const SizedBox(height: 16),
            const Text('Senkronizasyon kapsamı: kullanıcılar, işler, atamalar, fotoğraf kayıtları, stoklar, stok hareketleri, bakım planları ve bakım kayıtları. Değişen kayıtlar güncelleme zamanı ile birleştirilir.'),
          ],
        ),
      ),
    );
  }
}
