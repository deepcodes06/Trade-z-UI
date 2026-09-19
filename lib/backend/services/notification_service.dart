import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../constants/app_strings.dart';

/// Local notifications + a simple polling engine that watches the user's
/// watchlist and emits a "blow-up" notification when a configured condition
/// is met (e.g. LTP crosses a breakout threshold).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'tradez_blowup';
  static const _channelName = 'TradeZ Blow-up Alerts';

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> showBlowUp(String symbol) async {
    const android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    await _plugin.show(
      symbol.hashCode,
      AppStrings.blowUpTitle,
      '$symbol ${AppStrings.blowUpBody}',
      const NotificationDetails(android: android, iOS: ios),
    );
  }
}
