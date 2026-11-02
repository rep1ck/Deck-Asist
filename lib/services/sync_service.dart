import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/database/app_database.dart';
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
  SyncService(this.db);

  Future<String> get deviceId async => _deviceId ??= await _loadDeviceId();

  Future<void> start() async {
    if (_server != null) return;
    await db.ensureSyncIds();
    _deviceId = await _loadDeviceId();
    _security = await SyncSecurity.load();
    try {
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
      _advertiseTimer =
          Timer.periodic(const Duration(seconds: 8), (_) => _broadcastPresence());
      _autoSyncTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (!_syncing) await syncWithDiscoveredPeers();
      });
    } catch (e) {
      await stop();
      rethrow;
    }
  }

  Future<void> stop() async {
    _advertiseTimer?.cancel();
    _autoSyncTimer?.cancel();
    _advertiseTimer = null;
    _autoSyncTimer = null;
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _discoverySocket?.close();
    _discoverySocket = null;
  }

  Future<String> _loadDeviceId() async {
    final dir = await getApplicationDocumentsDirectory();
    final f = File(p.join(dir.path, 'deck_device_id.txt'));
    if (await f.exists()) return (await f.readAsString()).trim();
    final id = List.generate(16, (_) => Random.secure().nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await f.writeAsString(id, flush: true);
    return id;
  }

  Future<void> _broadcastPresence() async {
    final sock = _discoverySocket;
    if (sock == null) return;
    final msg = jsonEncode({
      'protocol': protocol,
      'deviceId': await deviceId,
      'httpPort': httpPort,
    });
    try {
      sock.send(utf8.encode(msg), InternetAddress('255.255.255.255'), discoveryPort);
    } catch (_) {}
  }

  void _handleDiscovery(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _discoverySocket?.receive();
    if (dg == null) return;
    try {
      final map = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
      if (map['protocol'] != protocol) return;
      final id = map['deviceId'] as String?;
      final port = map['httpPort'] as int? ?? httpPort;
      if (id == null || id == _deviceId) return;
      _knownPeers[id] = 'http://${dg.address.address}:$port';
    } catch (_) {}
  }

  Future<void> _handleRequest(HttpRequest req) async {
    try {
      final body = await utf8.decoder.bind(req).join();
      final security = _security ??= await SyncSecurity.load();
      final ok = security.verify(
        method: req.method,
        path: req.uri.path,
        body: body,
        timestamp: req.headers.value('X-Deck-Timestamp'),
        nonce: req.headers.value('X-Deck-Nonce'),
        signature: req.headers.value('X-Deck-Signature'),
      );
      if (!ok) {
        req.response.statusCode = 401;
        req.response.write('unauthorized');
        await req.response.close();
        return;
      }
      if (req.method == 'POST' && req.uri.path == '/sync') {
        final incoming = jsonDecode(body) as Map<String, dynamic>;
        final result = await _mergeSnapshot(incoming);
        final reply = jsonEncode({
          'ok': true,
          'merged': result['merged'],
          'conflicts': result['conflicts'],
          'snapshot': await _snapshot(),
        });
        req.response.headers.contentType = ContentType.json;
        req.response.write(reply);
      } else if (req.method == 'GET' && req.uri.path == '/ping') {
        req.response.write(jsonEncode({'ok': true, 'deviceId': await deviceId}));
      } else {
        req.response.statusCode = 404;
      }
    } catch (e) {
      req.response.statusCode = 500;
      req.response.write('$e');
    }
    await req.response.close();
  }

  Future<List<String>> discoverPeers() async {
    if (_server == null) {
      try {
        await start();
      } catch (_) {}
    }
    await _broadcastPresence();
    await Future.delayed(const Duration(milliseconds: 600));
    return _knownPeers.values.toList();
  }

  Future<SyncResult> syncWithDiscoveredPeers() async {
    if (_syncing) {
      return const SyncResult(success: false, message: 'Senkron zaten sürüyor');
    }
    _syncing = true;
    var merged = 0;
    var conflicts = 0;
    var peers = 0;
    try {
      if (_server == null) {
        try {
          await start();
        } catch (e) {
          return SyncResult(success: false, message: 'LAN servis başlatılamadı: $e');
        }
      }
      await _broadcastPresence();
      await Future.delayed(const Duration(milliseconds: 400));
      final security = _security ??= await SyncSecurity.load();
      final body = jsonEncode(await _snapshot());
      for (final entry in _knownPeers.entries) {
        try {
          final headers = security.sign('POST', '/sync', body);
          final res = await http
              .post(
                Uri.parse('${entry.value}/sync'),
                headers: {'Content-Type': 'application/json', ...headers},
                body: body,
              )
              .timeout(const Duration(seconds: 25));
          if (res.statusCode != 200) continue;
          peers++;
          final remote = jsonDecode(res.body) as Map<String, dynamic>;
          final result = await _mergeSnapshot(
              remote['snapshot'] as Map<String, dynamic>? ?? {});
          merged += result['merged'] as int;
          conflicts += result['conflicts'] as int;
        } catch (_) {}
      }
      return SyncResult(
        success: true,
        message: peers == 0
            ? 'Aynı ağda başka Deck Asist cihazı bulunamadı'
            : '$peers eş ile senkron: $merged kayıt birleşti',
        merged: merged,
        conflicts: conflicts,
        peers: peers,
      );
    } catch (e) {
      return SyncResult(success: false, message: 'Senkron hatası: $e');
    } finally {
      _syncing = false;
    }
  }

  Future<Map<String, dynamic>> _snapshot() async {
    final users = await db.select(db.users).get();
    final jobs = await db.select(db.jobs).get();
    final assignments = await db.select(db.jobAssignments).get();
    final photos = await db.select(db.jobPhotos).get();
    final comments = await db.select(db.jobComments).get();
    final inventory = await db.select(db.inventoryItems).get();
    final movements = await db.select(db.stockMovements).get();
    final plans = await db.select(db.maintenancePlans).get();
    final records = await db.select(db.maintenanceRecords).get();

    final userById = {for (final u in users) u.id: u.syncId};
    final jobById = {for (final j in jobs) j.id: j.syncId};
    final invById = {for (final i in inventory) i.id: i.syncId};
    final planById = {for (final p in plans) p.id: p.syncId};

    return {
      'protocol': protocol,
      'deviceId': await deviceId,
      'sentAt': DateTime.now().toUtc().toIso8601String(),
      'users': users
          .map((x) => {
                'syncId': x.syncId,
                'username': x.username,
                'passwordHash': x.passwordHash,
                'fullName': x.fullName,
                'role': x.role,
                'isActive': x.isActive,
                'canManageUsers': x.canManageUsers,
                'createdAt': x.createdAt.toUtc().toIso8601String(),
                'lastLogin': x.lastLogin?.toUtc().toIso8601String(),
                'updatedAt': x.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'jobs': jobs
          .map((x) => {
                'syncId': x.syncId,
                'title': x.title,
                'description': x.description,
                'location': x.location,
                'jobCategory': x.jobCategory,
                'weatherNote': x.weatherNote,
                'priority': x.priority,
                'status': x.status,
                'createdBySyncId': userById[x.createdBy],
                'createdAt': x.createdAt.toUtc().toIso8601String(),
                'startTime': x.startTime?.toUtc().toIso8601String(),
                'endTime': x.endTime?.toUtc().toIso8601String(),
                'updatedAt': x.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'jobAssignments': assignments
          .map((x) => {
                'syncId': x.syncId,
                'jobSyncId': jobById[x.jobId],
                'userSyncId': userById[x.userId],
                'assignedAt': x.assignedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'jobPhotos': await Future.wait(photos.map((x) async {
        String? b64;
        var size = 0;
        try {
          final f = File(x.photoPath);
          if (await f.exists()) {
            final bytes = await f.readAsBytes();
            size = bytes.length;
            if (bytes.length <= 8 * 1024 * 1024) b64 = base64Encode(bytes);
          }
        } catch (_) {}
        return {
          'syncId': x.syncId,
          'jobSyncId': jobById[x.jobId],
          'photoPhase': x.photoPhase,
          'photoBase64': b64,
          'photoSize': size,
          'uploadedBySyncId': userById[x.uploadedBy],
          'approvedBySyncId': x.approvedBy == null ? null : userById[x.approvedBy],
          'approvalStatus': x.approvalStatus,
          'description': x.description,
          'createdAt': x.createdAt.toUtc().toIso8601String(),
          'updatedAt': x.updatedAt.toUtc().toIso8601String(),
        };
      })),
      'jobComments': comments
          .map((x) => {
                'syncId': x.syncId,
                'jobSyncId': jobById[x.jobId],
                'userSyncId': userById[x.userId],
                'comment': x.comment,
                'createdAt': x.createdAt.toUtc().toIso8601String(),
              })
          .toList(),
      'inventoryItems': inventory
          .map((x) => {
                'syncId': x.syncId,
                'barcode': x.barcode,
                'name': x.name,
                'color': x.color,
                'brand': x.brand,
                'category': x.category,
                'unit': x.unit,
                'packSize': x.packSize,
                'unitsPerPack': x.unitsPerPack,
                'currentStock': x.currentStock,
                'minStock': x.minStock,
                'createdAt': x.createdAt.toUtc().toIso8601String(),
                'updatedAt': x.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'stockMovements': movements
          .map((x) => {
                'syncId': x.syncId,
                'itemSyncId': invById[x.itemId],
                'movementType': x.movementType,
                'quantity': x.quantity,
                'userSyncId': userById[x.userId],
                'note': x.note,
                'movementDate': x.movementDate.toUtc().toIso8601String(),
                'createdAt': x.createdAt.toUtc().toIso8601String(),
              })
          .toList(),
      'maintenancePlans': plans
          .map((x) => {
                'syncId': x.syncId,
                'title': x.title,
                'description': x.description,
                'intervalDays': x.intervalDays,
                'lastDoneDate': x.lastDoneDate?.toUtc().toIso8601String(),
                'nextDueDate': x.nextDueDate?.toUtc().toIso8601String(),
                'responsibleRole': x.responsibleRole,
                'isActive': x.isActive,
                'createdBySyncId': userById[x.createdBy],
                'createdAt': x.createdAt.toUtc().toIso8601String(),
                'updatedAt': x.updatedAt.toUtc().toIso8601String(),
              })
          .toList(),
      'maintenanceRecords': records
          .map((x) => {
                'syncId': x.syncId,
                'planSyncId': planById[x.planId],
                'doneBySyncId': userById[x.doneBy],
                'doneDate': x.doneDate.toUtc().toIso8601String(),
                'usedMaterials': x.usedMaterials,
                'notes': x.notes,
                'photoPath': x.photoPath,
                'createdAt': x.createdAt.toUtc().toIso8601String(),
              })
          .toList(),
    };
  }

  Future<Map<String, int>> _mergeSnapshot(Map<String, dynamic> incoming) async {
    var merged = 0;
    var conflicts = 0;
    final users = <String, int>{};
    final jobs = <String, int>{};
    final inventory = <String, int>{};
    final plans = <String, int>{};

    List<Map<String, dynamic>> listOf(dynamic v) {
      if (v is! List) return [];
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    for (final r in listOf(incoming['users'])) {
      final o = await _mergeUser(r);
      if (r['syncId'] != null) users[r['syncId'] as String] = o.id;
      if (o.merged) merged++;
      if (o.conflict) conflicts++;
    }
    for (final r in listOf(incoming['jobs'])) {
      final o = await _mergeJob(r, users);
      if (r['syncId'] != null) jobs[r['syncId'] as String] = o.id;
      if (o.merged) merged++;
      if (o.conflict) conflicts++;
    }
    for (final r in listOf(incoming['inventoryItems'])) {
      final o = await _mergeInventory(r);
      if (r['syncId'] != null) inventory[r['syncId'] as String] = o.id;
      if (o.merged) merged++;
      if (o.conflict) conflicts++;
    }
    for (final r in listOf(incoming['maintenancePlans'])) {
      final o = await _mergePlan(r, users);
      if (r['syncId'] != null) plans[r['syncId'] as String] = o.id;
      if (o.merged) merged++;
      if (o.conflict) conflicts++;
    }
    for (final r in listOf(incoming['jobAssignments'])) {
      if (jobs[r['jobSyncId']] != null && users[r['userSyncId']] != null) {
        if (await _mergeAssignment(r, jobs, users)) merged++;
      }
    }
    for (final r in listOf(incoming['jobPhotos'])) {
      if (jobs[r['jobSyncId']] != null && users[r['uploadedBySyncId']] != null) {
        if (await _mergePhoto(r, jobs, users)) merged++;
      }
    }
    for (final r in listOf(incoming['jobComments'])) {
      if (jobs[r['jobSyncId']] != null && users[r['userSyncId']] != null) {
        if (await _mergeComment(r, jobs, users)) merged++;
      }
    }
    for (final r in listOf(incoming['stockMovements'])) {
      if (inventory[r['itemSyncId']] != null && users[r['userSyncId']] != null) {
        if (await _mergeMovement(r, inventory, users)) merged++;
      }
    }
    for (final r in listOf(incoming['maintenanceRecords'])) {
      if (plans[r['planSyncId']] != null && users[r['doneBySyncId']] != null) {
        if (await _mergeRecord(r, plans, users)) merged++;
      }
    }
    return {'merged': merged, 'conflicts': conflicts};
  }

  Future<_MergeOutcome> _mergeUser(Map<String, dynamic> r) async {
    final sid = r['syncId'] as String;
    final remoteUpdated = DateTime.parse(r['updatedAt'] as String);
    var local = await (db.select(db.users)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    local ??= await (db.select(db.users)..where((t) => t.username.equals(r['username'] as String))).getSingleOrNull();
    final remoteHash = r['passwordHash'] as String?;
    final lastLogin =
        r['lastLogin'] == null ? null : DateTime.parse(r['lastLogin'] as String);
    if (local == null) {
      final hasHash = remoteHash != null && remoteHash.isNotEmpty;
      final id = await db.into(db.users).insert(UsersCompanion.insert(
            syncId: Value(sid),
            username: r['username'] as String,
            passwordHash: hasHash
                ? remoteHash!
                : sha256.convert(utf8.encode('deck-asist-disabled:$sid')).toString(),
            fullName: r['fullName'] as String,
            role: r['role'] as String,
            isActive: Value(hasHash ? (r['isActive'] as num).toInt() : 0),
            canManageUsers: Value((r['canManageUsers'] as num).toInt()),
            createdAt: Value(DateTime.parse(r['createdAt'] as String)),
            lastLogin: Value(lastLogin),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.users)..where((t) => t.id.equals(local!.id))).write(UsersCompanion(
            username: Value(r['username'] as String),
            passwordHash: remoteHash != null && remoteHash.isNotEmpty
                ? Value(remoteHash)
                : const Value.absent(),
            fullName: Value(r['fullName'] as String),
            role: Value(r['role'] as String),
            isActive: Value((r['isActive'] as num).toInt()),
            canManageUsers: Value((r['canManageUsers'] as num).toInt()),
            lastLogin: Value(lastLogin),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(local.id, true, false);
    }
    return _MergeOutcome(local.id, false, remoteUpdated != local.updatedAt);
  }

  Future<_MergeOutcome> _mergeJob(Map<String, dynamic> r, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final createdBy = users[r['createdBySyncId']];
    if (createdBy == null) return const _MergeOutcome(-1, false, false);
    final remoteUpdated = DateTime.parse(r['updatedAt'] as String);
    final local = await (db.select(db.jobs)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local == null) {
      final id = await db.into(db.jobs).insert(JobsCompanion.insert(
            syncId: Value(sid),
            title: r['title'] as String,
            description: Value(r['description'] as String?),
            location: Value(r['location'] as String?),
            jobCategory: Value((r['jobCategory'] as String?) ?? 'GENEL'),
            weatherNote: Value(r['weatherNote'] as String?),
            priority: Value((r['priority'] as String?) ?? 'NORMAL'),
            status: Value((r['status'] as String?) ?? 'PENDING'),
            createdBy: createdBy,
            startTime: Value(_date(r['startTime'])),
            endTime: Value(_date(r['endTime'])),
            createdAt: Value(DateTime.parse(r['createdAt'] as String)),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.jobs)..where((t) => t.id.equals(local.id))).write(JobsCompanion(
            title: Value(r['title'] as String),
            description: Value(r['description'] as String?),
            location: Value(r['location'] as String?),
            jobCategory: Value((r['jobCategory'] as String?) ?? local.jobCategory),
            weatherNote: Value(r['weatherNote'] as String?),
            priority: Value(r['priority'] as String? ?? local.priority),
            status: Value(r['status'] as String? ?? local.status),
            startTime: Value(_date(r['startTime'])),
            endTime: Value(_date(r['endTime'])),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(local.id, true, false);
    }
    return _MergeOutcome(local.id, false, false);
  }

  Future<_MergeOutcome> _mergeInventory(Map<String, dynamic> r) async {
    final sid = r['syncId'] as String;
    final remoteUpdated = DateTime.parse(r['updatedAt'] as String);
    var local = await (db.select(db.inventoryItems)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    local ??= await (db.select(db.inventoryItems)
          ..where((t) => t.barcode.equals(r['barcode'] as String)))
        .getSingleOrNull();
    final brand = (r['brand'] as String?) ?? 'Akzo Nobel / International';
    if (local == null) {
      final id = await db.into(db.inventoryItems).insert(InventoryItemsCompanion.insert(
            syncId: Value(sid),
            barcode: r['barcode'] as String,
            name: r['name'] as String,
            color: Value(r['color'] as String?),
            brand: Value(brand),
            category: r['category'] as String,
            unit: Value((r['unit'] as String?) ?? 'Lt'),
            packSize: Value(r['packSize'] as String?),
            unitsPerPack: Value((r['unitsPerPack'] as num?)?.toDouble() ?? 1.0),
            minStock: Value((r['minStock'] as num?)?.toDouble() ?? 0),
            createdAt: Value(DateTime.parse(r['createdAt'] as String)),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.inventoryItems)..where((t) => t.id.equals(local!.id))).write(InventoryItemsCompanion(
            barcode: Value(r['barcode'] as String),
            name: Value(r['name'] as String),
            color: Value(r['color'] as String?),
            brand: Value(brand),
            category: Value(r['category'] as String),
            unit: Value(r['unit'] as String? ?? local.unit),
            packSize: Value(r['packSize'] as String?),
            unitsPerPack: Value((r['unitsPerPack'] as num?)?.toDouble() ?? local.unitsPerPack),
            minStock: Value((r['minStock'] as num?)?.toDouble() ?? local.minStock),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(local.id, true, false);
    }
    return _MergeOutcome(local.id, false, false);
  }

  Future<_MergeOutcome> _mergePlan(Map<String, dynamic> r, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final createdBy = users[r['createdBySyncId']];
    if (createdBy == null) return const _MergeOutcome(-1, false, false);
    final remoteUpdated = DateTime.parse(r['updatedAt'] as String);
    final local =
        await (db.select(db.maintenancePlans)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local == null) {
      final id = await db.into(db.maintenancePlans).insert(MaintenancePlansCompanion.insert(
            syncId: Value(sid),
            title: r['title'] as String,
            description: Value(r['description'] as String?),
            intervalDays: (r['intervalDays'] as num).toInt(),
            lastDoneDate: Value(_date(r['lastDoneDate'])),
            nextDueDate: Value(_date(r['nextDueDate'])),
            responsibleRole: Value(r['responsibleRole'] as String?),
            isActive: Value((r['isActive'] as num?)?.toInt() ?? 1),
            createdBy: createdBy,
            createdAt: Value(DateTime.parse(r['createdAt'] as String)),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(id, true, false);
    }
    if (remoteUpdated.isAfter(local.updatedAt)) {
      await (db.update(db.maintenancePlans)..where((t) => t.id.equals(local.id))).write(MaintenancePlansCompanion(
            title: Value(r['title'] as String),
            description: Value(r['description'] as String?),
            intervalDays: Value((r['intervalDays'] as num).toInt()),
            lastDoneDate: Value(_date(r['lastDoneDate'])),
            nextDueDate: Value(_date(r['nextDueDate'])),
            responsibleRole: Value(r['responsibleRole'] as String?),
            isActive: Value((r['isActive'] as num?)?.toInt() ?? 1),
            updatedAt: Value(remoteUpdated),
          ));
      return _MergeOutcome(local.id, true, false);
    }
    return _MergeOutcome(local.id, false, false);
  }

  Future<bool> _mergeAssignment(
      Map<String, dynamic> r, Map<String, int> jobs, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final local =
        await (db.select(db.jobAssignments)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    await db.into(db.jobAssignments).insert(JobAssignmentsCompanion.insert(
          syncId: Value(sid),
          jobId: jobs[r['jobSyncId']]!,
          userId: users[r['userSyncId']]!,
          assignedAt: Value(DateTime.parse(r['assignedAt'] as String)),
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

  Future<bool> _mergePhoto(
      Map<String, dynamic> r, Map<String, int> jobs, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final remoteUpdated = DateTime.parse(r['updatedAt'] as String);
    final local =
        await (db.select(db.jobPhotos)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    final approvedBy =
        r['approvedBySyncId'] == null ? null : users[r['approvedBySyncId']];
    final jobId = jobs[r['jobSyncId']];
    final uploader = users[r['uploadedBySyncId']];
    if (jobId == null || uploader == null) return false;
    final b64 = r['photoBase64'] as String?;
    final phase = (r['photoPhase'] as String?) ?? 'GENERAL';

    if (local == null) {
      final path = await _savePhotoBytes(sid, b64, '');
      await db.into(db.jobPhotos).insert(JobPhotosCompanion.insert(
            syncId: Value(sid),
            jobId: jobId,
            photoPath: path,
            photoPhase: Value(phase),
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
      final path = await _savePhotoBytes(sid, b64, local.photoPath);
      await (db.update(db.jobPhotos)..where((t) => t.id.equals(local.id))).write(JobPhotosCompanion(
            jobId: Value(jobId),
            photoPath: Value(path.isEmpty ? local.photoPath : path),
            photoPhase: Value(phase),
            uploadedBy: Value(uploader),
            approvedBy: Value(approvedBy),
            approvalStatus: Value(r['approvalStatus'] as String? ?? local.approvalStatus),
            description: Value(r['description'] as String?),
            updatedAt: Value(remoteUpdated),
          ));
      return true;
    }
    if (b64 != null &&
        b64.isNotEmpty &&
        (local.photoPath.isEmpty || !(await File(local.photoPath).exists()))) {
      final path = await _savePhotoBytes(sid, b64, local.photoPath);
      if (path.isNotEmpty) {
        await (db.update(db.jobPhotos)..where((t) => t.id.equals(local.id))).write(
              JobPhotosCompanion(photoPath: Value(path)),
            );
        return true;
      }
    }
    return false;
  }

  Future<bool> _mergeComment(
      Map<String, dynamic> r, Map<String, int> jobs, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final jobId = jobs[r['jobSyncId']];
    final userId = users[r['userSyncId']];
    if (jobId == null || userId == null) return false;
    final local =
        await (db.select(db.jobComments)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    await db.into(db.jobComments).insert(JobCommentsCompanion.insert(
          syncId: Value(sid),
          jobId: jobId,
          userId: userId,
          comment: r['comment'] as String,
          createdAt: Value(DateTime.parse(r['createdAt'] as String)),
        ));
    return true;
  }

  Future<bool> _mergeMovement(
      Map<String, dynamic> r, Map<String, int> inventory, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final itemId = inventory[r['itemSyncId']];
    final userId = users[r['userSyncId']];
    if (itemId == null || userId == null) return false;
    final local =
        await (db.select(db.stockMovements)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    await db.into(db.stockMovements).insert(StockMovementsCompanion.insert(
          syncId: Value(sid),
          itemId: itemId,
          movementType: r['movementType'] as String,
          quantity: (r['quantity'] as num).toDouble(),
          userId: userId,
          note: Value(r['note'] as String?),
          movementDate: Value(DateTime.parse(r['movementDate'] as String)),
          createdAt: Value(DateTime.parse(r['createdAt'] as String)),
        ));
    return true;
  }

  Future<bool> _mergeRecord(
      Map<String, dynamic> r, Map<String, int> plans, Map<String, int> users) async {
    final sid = r['syncId'] as String;
    final planId = plans[r['planSyncId']];
    final doneBy = users[r['doneBySyncId']];
    if (planId == null || doneBy == null) return false;
    final local =
        await (db.select(db.maintenanceRecords)..where((t) => t.syncId.equals(sid))).getSingleOrNull();
    if (local != null) return false;
    await db.into(db.maintenanceRecords).insert(MaintenanceRecordsCompanion.insert(
          syncId: Value(sid),
          planId: planId,
          doneBy: doneBy,
          doneDate: DateTime.parse(r['doneDate'] as String),
          usedMaterials: Value(r['usedMaterials'] as String?),
          notes: Value(r['notes'] as String?),
          photoPath: Value(r['photoPath'] as String?),
          createdAt: Value(DateTime.parse(r['createdAt'] as String)),
        ));
    return true;
  }

  DateTime? _date(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v as String);
  }
}

class _MergeOutcome {
  final int id;
  final bool merged;
  final bool conflict;
  const _MergeOutcome(this.id, this.merged, this.conflict);
}
