import 'dart:convert';

import 'package:crypto/crypto.dart';
import '../data/database/app_database.dart';

/// Authentication for Deck Asist LAN sync.
///
/// Requests are authenticated with HMAC-SHA256 and contain a timestamp and
/// nonce so captured requests cannot simply be replayed.
class SyncSecurity {
  static const Duration maxClockSkew = Duration(minutes: 2);
  final List<int> _key;
  final Map<String, DateTime> _seen = <String, DateTime>{};

  SyncSecurity._(this._key);

  static Future<SyncSecurity> fromDatabase(AppDatabase db) async {
    final users = await db.select(db.users).get();
    final hashes = users
        .where((u) => u.isActive == 1)
        .map((u) => u.passwordHash)
        .where((h) => h.isNotEmpty)
        .toList()
      ..sort();
    final seed = hashes.isEmpty ? 'deck-asist-no-users' : hashes.join('|');
    final key = sha256.convert(utf8.encode('deck-asist-lan-v5:$seed')).bytes;
    return SyncSecurity._(key);
  }

  Map<String, String> sign(String method, String path, String body) {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    final nonce = _randomNonce(timestamp);
    final canonical = _canonical(timestamp, nonce, method, path, body);
    final signature = Hmac(sha256, _key)
        .convert(utf8.encode(canonical))
        .toString();
    return <String, String>{
      'X-Deck-Timestamp': timestamp,
      'X-Deck-Nonce': nonce,
      'X-Deck-Signature': signature,
    };
  }

  bool verify({
    required String method,
    required String path,
    required String body,
    required String? timestamp,
    required String? nonce,
    required String? signature,
  }) {
    if (timestamp == null || nonce == null || signature == null) return false;
    final millis = int.tryParse(timestamp);
    if (millis == null || nonce.length < 16) return false;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if ((now - millis).abs() > maxClockSkew.inMilliseconds) return false;
    _purge();
    if (_seen.containsKey(nonce)) return false;

    final canonical = _canonical(timestamp, nonce, method, path, body);
    final expected = Hmac(sha256, _key)
        .convert(utf8.encode(canonical))
        .toString();
    if (!_constantTimeEquals(expected, signature)) return false;
    _seen[nonce] = DateTime.now().toUtc();
    return true;
  }

  String _canonical(String timestamp, String nonce, String method,
      String path, String body) {
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    return '$timestamp\n$nonce\n${method.toUpperCase()}\n$path\n$bodyHash';
  }

  String _randomNonce(String seed) {
    final digest = sha256.convert(utf8.encode(
      '$seed:${DateTime.now().microsecondsSinceEpoch}:${_seen.length}',
    ));
    return digest.toString();
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  void _purge() {
    final cutoff = DateTime.now().toUtc().subtract(maxClockSkew);
    _seen.removeWhere((_, value) => value.isBefore(cutoff));
  }
}
