import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart';
import 'sync_security.dart';
import 'sync_security.dart';

class SyncResult {
  final bool success;
  final String message;
  final int merged;
  final int conflicts;
  final int peers;

  const SyncResult({
    required this.success,
    required this.message,
    this.merged = 0,
    this.conflicts = 0,
    this.peers = 0,
  });
}

/// Automatic, offline-first LAN synchronization.
///
/// Every running Deck Asist instance exposes an HTTP endpoint and advertises
/// itself over UDP. There is no central server and no internet dependency.
/// Records have a stable syncId. Mutable records use last-write-wins based on
/// updatedAt; immutable history records are de-duplicated by syncId.
class SyncService {
  static const int httpPort = 8787;
  static const int discoveryPort = 8788;
  static const String protocol = 'deck-asist-v5';

  final AppDatabase db;
  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  Timer? _advertiseTimer;
  Timer? _autoSyncTimer;
  String? _deviceId;
  bool _syncing = false;
  final Map<String, String> _knownPeers = {};
  SyncSecurity? _security;
  SyncSecurity? _security;

  SyncService(this.db);

  Future<String> get deviceId async => _deviceId ??= await _loadDeviceId();

  Future<void> start() async {
    if (_server != null) return;
    await db.ensureSyncIds();
    _deviceId = await _loadDeviceId();
    _security = await SyncSecurity.fromDatabase(db);
    _security = await SyncSecurity.fromDatabase(db);

    _server = await HttpServer.bind(InternetAddress.anyIPv4, httpPort, shared: true);
    _server!.listen(_handleRequest, onError: (_) {});

    _discoverySocket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    _discoverySocket!.broadcastEnabled = true;
    _discoverySocket!.listen(_handleDiscovery);

    await _broadcastPresence();
    _advertiseTimer = Timer.periodic(const Duration(seconds: 15), (_) => _broadcastPresence());
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) => syncWithDiscoveredPeers());
  }

  Future<void> stop() async {
    _advertiseTimer?.cancel();
    _autoSyncTimer?.cancel();
    _advertiseTimer = null;
    _autoSyncTimer = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    await _server?.close(force: true);
    _server = null;
  }

  Future<List<String>> discoverPeers({Duration wait = const Duration(seconds: 2)}) async {
    final socket = _discoverySocket;
    if (socket == null) return const [];
    final self = await deviceId;

    socket.send(
      utf8.encode(jsonEncode({'protocol': protocol, 'type': 'discover', 'deviceId': self})),
      InternetAddress('255.255.255.255'),
      discoveryPort,
    );
    await Future<void>.delayed(wait);

    return _knownPeers.entries
        .where((e) => e.key != self)
        .map((e) => e.value)
        .toSet()
        .toList()
      ..sort();
  }

  void _handleDiscovery(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final socket = _discoverySocket;
    if (socket == null) return;
    final datagram = socket.receive();
    if (datagram == null) return;

    try {
      final data = jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      if (data['protocol'] != protocol) return;
      final id = data['deviceId'] as String?;
      if (id == null || id == _deviceId || _server == null) return;

      _knownPeers[id] = 'http://${datagram.address.address}:$httpPort';
      if (data['type'] == 'discover') {
        socket.send(
          utf8.encode(jsonEncode({'protocol': protocol, 'type': 'presence', 'deviceId': _deviceId})),
          datagram.address,
          discoveryPort,
        );
      }
    } catch (_) {}
  }

  Future<void> _broadcastPresence() async {
    final socket = _discoverySocket;
    if (socket == null) return;
    socket.send(
      utf8.encode(jsonEncode({'protocol': protocol, 'type': 'presence', 'deviceId': await deviceId})),
      InternetAddress('255.255.255.255'),
      discoveryPort,
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/health') {
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode({'protocol': protocol, 'deviceId': await deviceId}));
      } else if (request.method == 'POST' && request.uri.path == '/sync') {
        final body = await utf8.decoder.bind(request).join();
        final security = _security ??= await SyncSecurity.fromDatabase(db);
        final ok = security.verify(
          method: request.method,
          path: request.uri.path,
          body: body,
          timestamp: request.headers.value('X-Deck-Timestamp'),
          nonce: request.headers.value('X-Deck-Nonce'),
          signature: request.headers.value('X-Deck-Signature'),
        );
        if (!ok) {
          request.response.statusCode = HttpStatus.unauthorized;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({'error': 'Unauthorized sync request'}));
        } else {
          final incoming = jsonDecode(body) as Map<String, dynamic>;
          await _mergeSnapshot(incoming);
          request.response.headers.contentType = ContentType.json;
          request.response.statusCode = HttpStatus.ok;
          request.response.write(jsonEncode({
            'protocol': protocol,
            'deviceId': await deviceId,
            'snapshot': await _snapshot(),
          }));
        }
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'error': 'Not found'}));
      }
    } catch (e) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'error': e.toString()}));
    } finally {
      await request.response.close();
    }
  }

  Future<SyncResult> syncWithDiscoveredPeers() async {
    if (_syncing) return const SyncResult(success: true, message: 'Senkronizasyon zaten Ã§alÄ±ÅŸÄ±yor.');
    _syncing = true;
    try {
      await start();
      final peers = await discoverPeers();
      if (peers.isEmpty) {
        return const SyncResult(success: true, message: 'AynÄ± aÄŸda baÅŸka Deck Asist cihazÄ± bulunamadÄ±.');
      }

      var merged = 0;
      var failed = 0;
      for (final peer in peers) {
        final result = await _syncPeer(peer);
        if (result.success) {
          merged += result.merged;
        } else {
          failed++;
        }
      }
      return SyncResult(
        success: failed == 0,
        message: failed == 0
            ? '$merged kayÄ±t senkronize edildi. ${peers.length} cihaz bulundu.'
            : '${peers.length - failed}/${peers.length} cihaz senkronize edildi.',
        merged: merged,
        peers: peers.length,
      );
    } finally {
      _syncing = false;
    }
  }

  Future<SyncResult> syncWithServer(String serverUrl) async {
    try {
      await start();
      return await _syncPeer(serverUrl.replaceAll(RegExp(r'/$'), ''));
    } catch (e) {
      return SyncResult(success: false, message: 'Senkronizasyon hatasÄ±: $e');
    }
  }

  Future<SyncResult> _syncPeer(String baseUrl) async {
    try {
      final body = jsonEncode(await _snapshot());
      final security = _security ??= await SyncSecurity.fromDatabase(db);
      final headers = <String, String>{
        'content-type': 'application/json',
        ...security.sign('POST', '/sync', body),
      };
      final response = await http
          .post(Uri.parse('$baseUrl/sync'), headers: headers, body: body)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != HttpStatus.ok) {
        return SyncResult(success: false, message: 'Cihaz yanÄ±t vermedi (${response.statusCode}).');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['protocol'] != protocol) {
        return const SyncResult(success: false, message: 'Uyumsuz Deck Asist sÃ¼rÃ¼mÃ¼.');
      }
      final remote = Map<String, dynamic>.from(data['snapshot'] as Map);
      final result = await _mergeSnapshot(remote);
      await _logSync(baseUrl, true);
      return SyncResult(
        success: true,
        message: 'Senkronizasyon tamamlandÄ±.',
        merged: result['merged'] ?? 0,
        conflicts: result['conflicts'] ?? 0,
      );
    } catch (e) {
      await _logSync(baseUrl, false);
      return SyncResult(success: false, message: 'BaÄŸlantÄ± hatasÄ±: $e');
    }
  }

  Future<Map<String, dynamic>> _snapshot() async {
    await db.ensureSyncIds();
    final users = await db.select(db.users).get();
    final jobs = await db.select(db.jobs).get();
    final assignments = await db.select(db.jobAssignments).get();
    final photos = await db.select(db.jobPhotos).get();
    final comments = await db.select(db.jobComments).get();
    final inventory = await db.select(db.inventoryItems).get();
    final movements = await db.select(db.stockMovements).get();
    final plans = await db.select(db.maintenancePlans).get();
    final records = await db.select(db.maintenanceRecords).get();

    final userById = {for (final x in users) x.id: x.syncId};
    final jobById = {for (final x in jobs) x.id: x.syncId};
    final inventoryById = {for (final x in inventory) x.id: x.syncId};
    final planById = {for (final x in plans) x.id: x.syncId};

    return {
      'protocol': protocol,
      'deviceId': await deviceId,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'users': users.map((x) => {
            'syncId': x.syncId, 'username': x.username, 'passwordHash': x.passwordHash, 'fullName': x.fullName,
            'role': x.role, 'isActive': x.isActive, 'canManageUsers': x.canManageUsers, 'createdAt': x.createdAt.toUtc().toIso8601String(),
            'lastLogin': x.lastLogin?.toUtc().toIso8601String(), 'updatedAt': x.updatedAt.toUtc().toIso8601String(),
          }).toList(),
      'jobs': jobs.map((x) => {
            'syncId': x.syncId, 'title': x.title, 'description': x.description, 'location': x.location, 'priority': x.priority,
            'status': x.status, 'createdBySyncId': userById[x.createdBy], 'createdAt': x.createdAt.toUtc().toIso8601String(),
            'startTime': x.startTime?.toUtc().toIso8601String(), 'endTime': x.endTime?.toUtc().toIso8601String(), 'updatedAt': x.updatedAt.toUtc().toIso8601String(),
          }).toList(),
      'jobAssignments': assignments.map((x) => {
            'syncId': x.syncId, 'jobSyncId': jobById[x.jobId], 'userSyncId': userById[x.userId], 'assignedAt': x.assignedAt.toUtc().toIso8601String(),
          }).toList(),
      'jobPhotos': await Future.wait(photos.map((x) async {
            String? b64;
            var size = 0;
            try {
              final f = File(x.photoPath);
              if (await f.exists()) {
                final bytes = await f.readAsBytes();
                size = bytes.length;
                // Inline up to 8 MiB. The path itself is never sent because it is local to one device.
                if (bytes.length <= 8 * 1024 * 1024) b64 = base64Encode(bytes);
              }
            } catch (_) {}
            return {
              'syncId': x.syncId,
              'jobSyncId': jobById[x.jobId],
              'photoBase64': b64,
              'photoSize': size,
              'uploadedBySyncId': userById[x.uploadedBy],
              'approvedBySyncId': x.approvedBy == null ? null : userById[x.approvedBy!],
              'approvalStatus': x.approvalStatus,
              'description': x.description,
              'createdAt': x.createdAt.toUtc().toIso8601String(),
              'updatedAt': x.updatedAt.toUtc().toIso8601String(),
            };
          })),
      'jobComments': comments.map((x) => {
            'syncId': x.syncId,
            'jobSyncId': jobById[x.jobId],
            'userSyncId': userById[x.userId],
            'comment': x.comment,
            'createdAt': x.createdAt.toUtc().toIso8601String(),
          }).toList(),
      'inventoryItems': inventory.map((x) => {
            'syncId': x.syncId, 'barcode': x.barcode, 'name': x.name, 'color': x.color, 'brand': x.brand, 'category': x.category,
            'unit': x.unit, 'packSize': x.packSize, 'currentStock': x.currentStock, 'minStock': x.minStock,
            'createdAt': x.createdAt.toUtc().toIso8601String(), 'updatedAt': x.updatedAt.toUtc().toIso8601String(),
          }).toList(),
      'stockMovements': movements.map((x) => {
            'syncId': x.syncId, 'itemSyncId': inventoryById[x.itemId], 'movementType': x.movementType, 'quantity': x.quantity,
            'userSyncId': userById[x.userId], 'note': x.note, 'movementDate': x.movementDate.toUtc().toIso8601String(), 'createdAt': x.createdAt.toUtc().toIso8601String(),
          }).toList(),
      'maintenancePlans': plans.map((x) => {
            'syncId': x.syncId, 'title': x.title, 'description': x.description, 'intervalDays': x.intervalDays, 'lastDoneDate': x.lastDoneDate?.toUtc().toIso8601String(),
            'nextDueDate': x.nextDueDate?.toUtc().toIso8601String(), 'responsibleRole': x.responsibleRole, 'isActive': x.isActive,
            'createdBySyncId': userById[x.createdBy], 'createdAt': x.createdAt.toUtc().toIso8601String(), 'updatedAt': x.updatedAt.toUtc().toIso8601String(),
          }).toList(),
      'maintenanceRecords': records.map((x) => {
            'syncId': x.syncId, 'planSyncId': planById[x.planId], 'doneBySyncId': userById[x.doneBy], 'doneDate': x.doneDate.toUtc().toIso8601String(),
            'usedMaterials': x.usedMaterials, 'notes': x.notes, 'photoPath': x.photoPath, 'createdAt': x.createdAt.toUtc().toIso8601String(),
          }).toList(),
    };
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  Future<Map<String, int>> _mergeSnapshot(Map<String, dynamic> incoming) async {
    if (incoming['protocol'] != protocol) throw StateError('Uyumsuz protokol');
    await db.ensureSyncIds();
    var merged = 0;
    var conflicts = 0;
    final users = <String, int>{};
    final jobs = <String, int>{};
    final inventory = <String, int>{};
    final plans = <String, int>{};

    for (final r in _list(incoming['users'])) {
      final result = await _mergeUser(r);
      users[r['syncId'] as String] = result.id;
      merged += result.changed ? 1 : 0;
      conflicts += result.conflict ? 1 : 0;
    }
    for (final r in _list(incoming['jobs'])) {
      final result = await _mergeJob(r, users);
      jobs[r['syncId'] as String] = result.id;
      merged += result.changed ? 1 : 0;
      conflicts += result.conflict ? 1 : 0;
    }
    for (final r in _list(incoming['inventoryItems'])) {
      final result = await _mergeInventory(r);
      inventory[r['syncId'] as String] = result.id;
      merged += result.changed ? 1 : 0;
      conflicts += result.conflict ? 1 : 0;
    }
    for (final r in _list(incoming['maintenancePlans'])) {
      final result = await _mergePlan(r, users);
      plans[r['syncId'] as String] = result.id;
      merged += result.changed ? 1 : 0;
      conflicts += result.conflict ? 1 : 0;
    }
    for (final r in _list(incoming['jobAssignments'])) {
      if (jobs[r['jobSyncId']] != null && users[r['userSyncId']] != null && await _mergeAssignment(r, jobs, users)) merged++;
    }
    for (final r in _list(incoming['jobPhotos'])) {
      if (jobs[r['jobSyncId']] != null && users[r['uploadedBySyncId']] != null && await _mergePhoto(r, jobs, users)) merged++;
    }
    for (final r in _list(incoming['jobComments'])) {
      if (jobs[r['jobSyncId']] != null && users[r['userSyncId']] != null && await _mergeComment(r, jobs, users)) merged++;
    }
    for (final r in _list(incoming['stockMovements'])) {
      if (inventory[r['itemSyncId']] != null && users[r['userSyncId']] != null && await _mergeMovement(r, inventory, users)) merged++;
    }
    for (final r in _list(incoming['maintenanceRecords'])) {
      if (plans[r['planSyncId']] != null && users[r['doneBySyncId']] != null && await _mergeRecord(r, plans, users)) merged++;
    }
    return {'merged': merged, 'conflicts': conflicts};
  }

  Future<_MergeOutcome> _mergeUser(Map<String, dynamic> r) async {
    final sid = r['syncId'] as String;
    final remoteUpdated = DateTime.parse(r['updatedAt']);
    var local = await (db.select(db.users)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    local ??= await (db.select(db.users)..where((t) => t.username.equals(r['username'] as String))).getSingleOrNull();
    if (local == null) {
      final id = await db.into(db.users).insert(UsersCompanion.insert(
        syncId: Value(sid), username: r['username'], passwordHash: r['passwordHash'], fullName: r['fullName'], role: r['role'],
        isActive: Value(r['isActive']), canManageUsers: Value(r['canManageUsers']), createdAt: Value(DateTime.parse(r['createdAt'])),
        lastLogin: Value(r['lastLogin'] == null ? null : DateTime.parse(r['lastLogin'])), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.users)..where((t) => t.id.equals(local!.id))).write(UsersCompanion(
        username: Value(r['username']), passwordHash: Value(r['passwordHash']), fullName: Value(r['fullName']), role: Value(r['role']),
        isActive: Value(r['isActive']), canManageUsers: Value(r['canManageUsers']), lastLogin: Value(r['lastLogin'] == null ? null : DateTime.parse(r['lastLogin'])), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(local!.id, true, false);
    }
    return _MergeOutcome(local!.id, false, remoteUpdated != local.updatedAt);
  }

  Future<_MergeOutcome> _mergeJob(Map<String, dynamic> r, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final createdBy = users[r['createdBySyncId']];
    if (createdBy == null) throw StateError('Ä°ÅŸ iÃ§in kullanÄ±cÄ± bulunamadÄ±');
    final remoteUpdated = DateTime.parse(r['updatedAt']);
    final local = await (db.select(db.jobs)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local == null) {
      final id = await db.into(db.jobs).insert(JobsCompanion.insert(
        syncId: Value(sid), title: r['title'], description: Value(r['description']), location: Value(r['location']), priority: Value(r['priority']), status: Value(r['status']),
        createdBy: createdBy, startTime: Value(_date(r['startTime'])), endTime: Value(_date(r['endTime'])), createdAt: Value(DateTime.parse(r['createdAt'])), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.jobs)..where((t) => t.id.equals(local!.id))).write(JobsCompanion(
        title: Value(r['title']), description: Value(r['description']), location: Value(r['location']), priority: Value(r['priority']), status: Value(r['status']),
        createdBy: Value(createdBy), startTime: Value(_date(r['startTime'])), endTime: Value(_date(r['endTime'])), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(local!.id, true, false);
    }
    return _MergeOutcome(local!.id, false, false);
  }

  Future<_MergeOutcome> _mergeInventory(Map<String, dynamic> r) async {
    final sid = r['syncId'] as String;
    final remoteUpdated = DateTime.parse(r['updatedAt']);
    var local = await (db.select(db.inventoryItems)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    local ??= await (db.select(db.inventoryItems)..where((t) => t.barcode.equals(r['barcode'] as String))).getSingleOrNull();
    if (local == null) {
      final id = await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
        syncId: Value(sid), barcode: r['barcode'], name: r['name'], color: Value(r['color']), brand: Value(r['brand']), category: r['category'], unit: Value(r['unit']),
        packSize: Value(r['packSize']), minStock: Value((r['minStock'] as num).toDouble()), createdAt: Value(DateTime.parse(r['createdAt'])), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.inventoryItems)..where((t) => t.id.equals(local!.id))).write(InventoryItemsCompanion(
        barcode: Value(r['barcode']), name: Value(r['name']), color: Value(r['color']), brand: Value(r['brand']), category: Value(r['category']), unit: Value(r['unit']),
        packSize: Value(r['packSize']), minStock: Value((r['minStock'] as num).toDouble()), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(local!.id, true, false);
    }
    return _MergeOutcome(local!.id, false, false);
  }

  Future<_MergeOutcome> _mergePlan(Map<String, dynamic> r, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final createdBy = users[r['createdBySyncId']];
    if (createdBy == null) throw StateError('BakÄ±m planÄ± iÃ§in kullanÄ±cÄ± bulunamadÄ±');
    final remoteUpdated = DateTime.parse(r['updatedAt']);
    final local = await (db.select(db.maintenancePlans)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local == null) {
      final id = await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
        syncId: Value(sid), title: r['title'], description: Value(r['description']), intervalDays: r['intervalDays'], lastDoneDate: Value(_date(r['lastDoneDate'])), nextDueDate: Value(_date(r['nextDueDate'])),
        responsibleRole: Value(r['responsibleRole']), isActive: Value(r['isActive']), createdBy: createdBy, createdAt: Value(DateTime.parse(r['createdAt'])), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.maintenancePlans)..where((t) => t.id.equals(local!.id))).write(MaintenancePlansCompanion(
        title: Value(r['title']), description: Value(r['description']), intervalDays: Value(r['intervalDays']), lastDoneDate: Value(_date(r['lastDoneDate'])), nextDueDate: Value(_date(r['nextDueDate'])),
        responsibleRole: Value(r['responsibleRole']), isActive: Value(r['isActive']), createdBy: Value(createdBy), updatedAt: Value(remoteUpdated),
      ));
      return _MergeOutcome(local!.id, true, false);
    }
    return _MergeOutcome(local!.id, false, false);
  }

  Future<bool> _mergeAssignment(Map<String, dynamic> r, Map<String, int> jobs, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final local = await (db.select(db.jobAssignments)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    await db.into(db.jobAssignments).insert(JobAssignmentsCompanion.insert(
      syncId: Value(sid), jobId: jobs[r['jobSyncId']]!, userId: users[r['userSyncId']]!, assignedAt: Value(DateTime.parse(r['assignedAt'])),
    ));
    return true;
  }

  Future<String> _savePhotoBytes(String syncId, String? b64, String fallbackPath) async {
    if (b64 == null || b64.isEmpty) return fallbackPath;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final photoDir = Directory(p.join(dir.path, 'synced_photos'));
      if (!await photoDir.exists()) await photoDir.create(recursive: true);
      final out = File(p.join(photoDir.path, '$syncId.jpg'));
      await out.writeAsBytes(base64Decode(b64), flush: true);
      return out.path;
    } catch (_) {
      return fallbackPath;
    }
  }

  Future<bool> _mergePhoto(Map<String, dynamic> r, Map<String, int> jobs, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final remoteUpdated = DateTime.parse(r['updatedAt']);
    final local = await (db.select(db.jobPhotos)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    final approvedBy = r['approvedBySyncId'] == null ? null : users[r['approvedBySyncId']];
    final jobId = jobs[r['jobSyncId']];
    final uploader = users[r['uploadedBySyncId']];
    if (jobId == null || uploader == null) return false;
    final path = await _savePhotoBytes(sid, r['photoBase64'] as String?, r['photoPath'] as String? ?? '');
    if (local == null) {
      await db.into(db.jobPhotos).insert(JobPhotosCompanion.insert(
        syncId: Value(sid),
        jobId: jobId,
        photoPath: path,
        uploadedBy: uploader,
        approvedBy: Value(approvedBy),
        approvalStatus: Value(r['approvalStatus'] as String? ?? 'PENDING'),
        description: Value(r['description'] as String?),
        createdAt: Value(DateTime.parse(r['createdAt'] as String)),
        updatedAt: Value(remoteUpdated),
      ));
      return true;
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.jobPhotos)..where((t) => t.id.equals(local!.id))).write(JobPhotosCompanion(
        jobId: Value(jobId),
        photoPath: Value(path),
        uploadedBy: Value(uploader),
        approvedBy: Value(approvedBy),
        approvalStatus: Value(r['approvalStatus'] as String? ?? local.approvalStatus),
        description: Value(r['description'] as String?),
        updatedAt: Value(remoteUpdated),
      ));
      return true;
    }
    return false;
  }

  Future<bool> _mergeMovement(Map<String, dynamic> r, Map<String, int> inventory, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final local = await (db.select(db.stockMovements)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    final itemId = inventory[r['itemSyncId']];
    final userId = users[r['userSyncId']];
    if (itemId == null || userId == null) return false;
    await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
      syncId: Value(sid), itemId: itemId, movementType: r['movementType'],
      quantity: (r['quantity'] as num).toDouble(), userId: userId,
      note: Value(r['note']), movementDate: Value(DateTime.parse(r['movementDate'])),
      createdAt: Value(DateTime.parse(r['createdAt'])),
    ));
    await _recalculateStock(itemId);
    return true;
  }

  Future<void> _recalculateStock(int itemId) async {
    final movements = await (db.select(db.stockMovements)..where((t) => t.itemId.equals(itemId))).get();
    movements.sort((a, b) {
      final d = a.movementDate.compareTo(b.movementDate);
      if (d != 0) return d;
      final c = a.createdAt.compareTo(b.createdAt);
      if (c != 0) return c;
      return (a.syncId ?? '').compareTo(b.syncId ?? '');
    });
    var stock = 0.0;
    for (final m in movements) {
      if (m.movementType == 'GIRIS') stock += m.quantity;
      if (m.movementType == 'CIKIS') stock -= m.quantity;
      if (m.movementType == 'SAYIM' || m.movementType == 'DUZELTME') stock = m.quantity;
      if (stock < 0) stock = 0;
    }
    await (db.update(db.inventoryItems)..where((t) => t.id.equals(itemId)))
        .write(InventoryItemsCompanion(currentStock: Value(stock)));
  }

  Future<bool> _mergeRecord(Map<String, dynamic> r, Map<String, int> plans, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final local = await (db.select(db.maintenanceRecords)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    await db.into(db.maintenanceRecords).insert(MaintenanceRecordsCompanion.insert(
      syncId: Value(sid), planId: plans[r['planSyncId']]!, doneBy: users[r['doneBySyncId']]!, doneDate: DateTime.parse(r['doneDate']),
      usedMaterials: Value(r['usedMaterials']), notes: Value(r['notes']), photoPath: Value(r['photoPath']), createdAt: Value(DateTime.parse(r['createdAt'])),
    ));
    return true;
  }

  DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value as String);

  Future<String> _loadDeviceId() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'deck_device_id.txt'));
    if (await file.exists()) return (await file.readAsString()).trim();
    final r = Random.secure();
    final id = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await file.writeAsString(id, flush: true);
    return id;
  }

  Future<void> _logSync(String peer, bool success) async {
    await db.into(db.syncLogs).insert(SyncLogsCompanion.insert(
      deviceId: peer, recordId: 0, action: 'LAN_SYNC', synced: Value(success ? 1 : 0),
    ));
  }
}

class _MergeOutcome {
  final int id;
  final bool changed;
  final bool conflict;
  const _MergeOutcome(this.id, this.changed, this.conflict);
}


