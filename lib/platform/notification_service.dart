import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Abstract interface for notification scheduling and permission handling.
abstract class NotificationService {
  Future<void> initialize();
  Future<bool> requestPermission();
  Future<bool> hasPermission();
  Future<void> scheduleStreakReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    DateTime? testNow,
  });
  Future<void> cancelStreakReminder();
  Future<bool> isReminderScheduled();
}

/// Fake implementation of [NotificationService] for unit testing and deterministic checks.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({
    this.initialHasPermission = true,
  }) : _permissionGranted = initialHasPermission;

  final bool initialHasPermission;
  bool _permissionGranted;
  bool _isScheduled = false;
  int? scheduledHour;
  int? scheduledMinute;
  String? scheduledTitle;
  String? scheduledBody;
  int scheduleCallCount = 0;
  int cancelCallCount = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async {
    _permissionGranted = true;
    return _permissionGranted;
  }

  void setPermission(bool granted) {
    _permissionGranted = granted;
  }

  @override
  Future<bool> hasPermission() async => _permissionGranted;

  @override
  Future<void> scheduleStreakReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    DateTime? testNow,
  }) async {
    scheduleCallCount++;
    if (!_permissionGranted) {
      _isScheduled = false;
      return;
    }
    _isScheduled = true;
    scheduledHour = hour;
    scheduledMinute = minute;
    scheduledTitle = title;
    scheduledBody = body;
  }

  @override
  Future<void> cancelStreakReminder() async {
    cancelCallCount++;
    _isScheduled = false;
    scheduledHour = null;
    scheduledMinute = null;
    scheduledTitle = null;
    scheduledBody = null;
  }

  @override
  Future<bool> isReminderScheduled() async => _isScheduled;
}

/// Production implementation of [NotificationService] using flutter_local_notifications.
class LocalNotificationService implements NotificationService {
  LocalNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const int streakReminderNotificationId = 1001;
  static const String channelId = 'arrowz_streak_reminders';
  static const String channelName = 'Streak Reminders';
  static const String channelDesc =
      'Gentle daily evening reminder to continue your puzzle streak.';

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (e) {
      debugPrint(
          'Notice: Timezone initialization error or already initialized: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    try {
      await _plugin.initialize(settings: initSettings);
      _initialized = true;
    } catch (e) {
      debugPrint('Warning: LocalNotificationService failed to initialize: $e');
    }
  }

  @override
  Future<bool> requestPermission() async {
    await initialize();
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    }
    return true;
  }

  @override
  Future<bool> hasPermission() async {
    await initialize();
    if (kIsWeb) return false;

    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final areEnabled = await androidPlugin.areNotificationsEnabled();
        return areEnabled ?? false;
      }
    }
    return true;
  }

  @override
  Future<void> scheduleStreakReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    DateTime? testNow,
  }) async {
    await initialize();

    final hasPerm = await hasPermission();
    if (!hasPerm) {
      debugPrint('Notification permission not granted, skipping schedule.');
      return;
    }

    // Cancel any previous reminder first to ensure idempotency and avoid duplicates
    await cancelStreakReminder();

    try {
      final now = testNow ?? DateTime.now();

      // Determine local timezone location or fallback to UTC if not found
      tz.Location location;
      try {
        location = tz.local;
      } catch (_) {
        location = tz.UTC;
      }

      var scheduledTzDate = tz.TZDateTime(
        location,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // If scheduled time for today has already passed, schedule for tomorrow
      if (scheduledTzDate.isBefore(now)) {
        scheduledTzDate = scheduledTzDate.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      // We explicitly prefer AndroidScheduleMode.inexact as instructed by the specification.
      // Inexact scheduling respects Android battery optimization and does not require SCHEDULE_EXACT_ALARM.
      await _plugin.zonedSchedule(
        id: streakReminderNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduledTzDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexact,
      );
    } catch (e) {
      debugPrint('Warning: Failed to schedule local notification: $e');
    }
  }

  @override
  Future<void> cancelStreakReminder() async {
    await initialize();
    try {
      await _plugin.cancel(id: streakReminderNotificationId);
    } catch (e) {
      debugPrint('Warning: Failed to cancel local notification: $e');
    }
  }

  @override
  Future<bool> isReminderScheduled() async {
    await initialize();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.any((req) => req.id == streakReminderNotificationId);
    } catch (e) {
      return false;
    }
  }
}

/// Riverpod provider for NotificationService.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return LocalNotificationService();
});
