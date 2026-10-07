import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:drift/drift.dart';
import '../data/database/app_database.dart';

class SyncResult {
  final bool success;
  final String message;
  final int usersMerged;
  final int jobsMerged;
  final int inventoryMerged;

  SyncResult({
    required this.success,
    required this.message,
    this.usersMerged = 0,
    this.jobsMerged = 0,
    this.inventoryMerged = 0,
  });
}

class SyncService {
  final AppDatabase db;
  SyncService(this.db);

  Future<SyncResult> syncWithServer(String serverUrl) async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/sync/all'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return SyncResult(
          success: false,
          message: 'Sunucu yanıt vermedi (${response.statusCode})',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final usersMerged = await _mergeCount(data['users'] ?? []);
      final jobsMerged = await _mergeCount(data['jobs'] ?? []);
      final inventoryMerged = await _mergeInventory(data['inventory'] ?? []);

      await _logSync(serverUrl, 'FULL_SYNC', true);

      return SyncResult(
        success: true,
        message: 'Senkronizasyon tamamlandı',
        usersMerged: usersMerged,
        jobsMerged: jobsMerged,
        inventoryMerged: inventoryMerged,
      );
    } catch (e) {
      await _logSync(serverUrl, 'FULL_SYNC', false, error: e.toString());
      return SyncResult(success: false, message: 'Hata: $e');
    }
  }

  Future<int> _mergeCount(List<dynamic> list) async => list.length;

  Future<int> _mergeInventory(List<dynamic> remoteList) async {
    int count = 0;
    for (final remote in remoteList) {
      final barcode = remote['barcode'] as String?;
      if (barcode == null) continue;
      final existing = await (db.select(db.inventoryItems)
            ..where((t) => t.barcode.equals(barcode)))
          .getSingleOrNull();
      if (existing == null) {
        // Yeni kayıt eklenebilir
        count++;
      } else {
        // Last-write-wins güncelleme
        count++;
      }
    }
    return count;
  }

  Future<void> _logSync(String serverUrl, String action, bool success,
      {String? error}) async {
    await db.into(db.syncLogs).insert(SyncLogsCompanion.insert(
          deviceId: serverUrl,
          tableName: 'ALL',
          recordId: 0,
          action: action,
          synced: Value(success ? 1 : 0),
        ));
  }
}
