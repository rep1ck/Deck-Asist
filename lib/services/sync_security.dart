import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// LAN senkronu HMAC kimlik dogrulama.
/// Anahtar cihazlar arasinda paylasilan ag anahtarindan turetilir.
class SyncSecurity {
  static const Duration maxClockSkew = Duration(minutes: 5);
  static const String defaultSecret = 'deck-asist-default-network-key';
  static const String _fileName = 'deck_sync_secret.txt';

  final List<int> _key;
  final Map<String, DateTime> _seen = <String, DateTime>{};
  final Random _rng = Random.secure();

  SyncSecurity._(this._key);

  factory SyncSecurity.fromSecret(String secret) {
    final s = secret.trim().isEmpty ? defaultSecret : secret.trim();
    final key = sha256.convert(utf8.encode('deck-asist-lan-v6:$s')).bytes;
    return SyncSecurity._(key);
  }

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  static Future<String> loadSecret() async {
    try {
      final f = await _file();
      if (await f.exists()) return (await f.readAsString()).trim();
    } catch (_) {}
    return '';
  }

  static Future<void> saveSecret(String secret) async {
    final f = await _file();
    await f.writeAsString(secret.trim(), flush: true);
  }

  static Future<SyncSecurity> load() async =>
      SyncSecurity.fromSecret(await loadSecret());

  Map<String, String> sign(String method, String path, String body) {
    final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch.toString();
    final nonce = _randomNonce();
    final signature = _hmac(_canonical(timestamp, nonce, method, path, body));
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

    final expected = _hmac(_canonical(timestamp, nonce, method, path, body));
    if (!_constantTimeEquals(expected, signature)) return false;
    _seen[nonce] = DateTime.now().toUtc();
    return true;
  }

  String _canonical(String timestamp, String nonce, String method, String path,
      String body) {
    final bodyHash = sha256.convert(utf8.encode(body)).toString();
    return '$timestamp\n$nonce\n${method.toUpperCase()}\n$path\n$bodyHash';
  }

  String _hmac(String canonical) =>
      Hmac(sha256, _key).convert(utf8.encode(canonical)).toString();

  String _randomNonce() {
    final bytes = List<int>.generate(16, (_) => _rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void _purge() {
    final cutoff = DateTime.now().toUtc().subtract(maxClockSkew * 2);
    _seen.removeWhere((_, t) => t.isBefore(cutoff));
  }

  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var r = 0;
    for (var i = 0; i < a.length; i++) {
      r |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return r == 0;
  }
}
