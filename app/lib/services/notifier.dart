import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notification channel for new mail. Works from both the foreground
/// app and the background poll isolate.
class Notifier {
  static const _channelId = 'ranse_new_mail';
  static const _channelName = 'New email';
  static const _channelDescription = 'Alerts when new email arrives';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Android 13+ runtime permission. Call once from the UI.
  static Future<void> requestPermission() async {
    await init();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNewMail({
    required int id,
    required String accountEmail,
    required String sender,
    required String subject,
  }) async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.email,
      ),
    );
    await _plugin.show(
      id: id,
      title: sender,
      body: subject.isEmpty ? '(no subject)' : subject,
      notificationDetails: details,
      payload: accountEmail,
    );
  }
}
