import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint('tz init: $e');
    }

    try {
      // ic_launcher yoksa varsayilan android ikonu kullan
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _plugin.initialize(
        const InitializationSettings(android: android),
      );
      try {
        await _plugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('notification permission: $e');
      }
      _ready = true;
    } catch (e, st) {
      debugPrint('NotificationService.init failed: $e\n$st');
      _ready = false;
    }
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'deck_asist_channel',
        'Deck Asist Bildirimleri',
        channelDescription: 'Is ve bakim bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
      );
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('notification show: $e');
    }
  }

  static Future<void> jobAssigned({
    required int jobId,
    required String title,
    required String toName,
  }) async {
    await show(
      id: jobId,
      title: 'Yeni Is Atandi',
      body: '$toName kisisine "$title" isi atandi.',
    );
  }

  static Future<void> jobStarted({
    required int jobId,
    required String title,
  }) async {
    await show(
      id: jobId + 1000,
      title: 'Is Baslatildi',
      body: '"$title" isine baslandi.',
    );
  }

  static Future<void> jobCompleted({
    required int jobId,
    required String title,
    required String byName,
  }) async {
    await show(
      id: jobId + 2000,
      title: 'Is Tamamlandi',
      body: '"$title" isi $byName tarafindan tamamlandi.',
    );
  }

  static Future<void> jobApproved({
    required int jobId,
    required String title,
  }) async {
    await show(
      id: jobId + 3000,
      title: 'Is Onaylandi',
      body: '"$title" isi onaylandi.',
    );
  }

  static Future<void> maintenanceDue({
    required int planId,
    required String title,
    required int daysLeft,
  }) async {
    final body = daysLeft < 0
        ? '"$title" bakimi ${-daysLeft} gundur gecikti!'
        : '"$title" bakimi $daysLeft gun icinde yapilmali.';
    await show(
      id: planId + 5000,
      title: 'Bakim Hatirlatmasi',
      body: body,
    );
  }

  static Future<void> maintenanceCompleted({
    required int planId,
    required String title,
  }) async {
    await show(
      id: planId + 6000,
      title: 'Bakim Tamamlandi',
      body: '"$title" bakimi tamamlandi.',
    );
  }
}
