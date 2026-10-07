import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'deck_asist_channel',
      'Deck Asist Bildirimleri',
      channelDescription: 'İş ve bakım bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> jobAssigned({
    required int jobId,
    required String title,
    required String toName,
  }) async {
    await show(
      id: jobId,
      title: 'Yeni İş Atandı',
      body: '$toName kişisine "$title" işi atandı.',
    );
  }

  static Future<void> jobStarted({
    required int jobId,
    required String title,
  }) async {
    await show(
      id: jobId + 1000,
      title: 'İş Başlatıldı',
      body: '"$title" işine başlandı.',
    );
  }

  static Future<void> jobCompleted({
    required int jobId,
    required String title,
    required String byName,
  }) async {
    await show(
      id: jobId + 2000,
      title: 'İş Tamamlandı',
      body: '"$title" işi $byName tarafından tamamlandı.',
    );
  }

  static Future<void> jobApproved({
    required int jobId,
    required String title,
  }) async {
    await show(
      id: jobId + 3000,
      title: 'İş Onaylandı',
      body: '"$title" işi onaylandı.',
    );
  }

  static Future<void> maintenanceDue({
    required int planId,
    required String title,
    required int daysLeft,
  }) async {
    final body = daysLeft < 0
        ? '"$title" bakımı ${-daysLeft} gündür gecikti!'
        : '"$title" bakımı $daysLeft gün içinde yapılmalı.';
    await show(
      id: planId + 5000,
      title: 'Bakım Hatırlatması',
      body: body,
    );
  }

  static Future<void> maintenanceCompleted({
    required int planId,
    required String title,
  }) async {
    await show(
      id: planId + 6000,
      title: 'Bakım Tamamlandı',
      body: '"$title" bakımı tamamlandı.',
    );
  }
}
