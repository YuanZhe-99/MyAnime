import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';
import '../utils/jst_time.dart';

/// Daily reminder notification service.
///
/// On Android: uses flutter_local_notifications' zonedSchedule() to schedule
/// a daily repeating notification at the OS level. This fires even when the
/// app process is killed or the device is rebooted.
///
/// On iOS: uses Timer.periodic (foreground only; iOS background limits apply).
///
/// On Desktop (Windows/macOS/Linux): uses Timer.periodic + local_notifier.
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Notification channel / ID constants.
  static const _channelId = 'my_anime_reminder';
  static const _channelName = 'Anime Reminder';
  static const _scheduledNotificationId = 100;

  static bool _isDesktop = false;
  static bool _isMobile = false;
  static Timer? _timer;

  /// Resolve the current l10n instance from saved locale or platform default.
  static Future<AppLocalizations> _getL10n() async {
    final tag = await AnimeStorage.getLocaleTag();
    Locale locale;
    if (tag != null) {
      final parts = tag.split('_');
      locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    } else {
      locale = PlatformDispatcher.instance.locale;
    }
    return lookupAppLocalizations(locale);
  }

  /// Initialize the notification plugin.
  static Future<void> init() async {
    if (kIsWeb) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _isDesktop = true;
      await localNotifier.setup(
        appName: 'MyAnime!!!!!',
        shortcutPolicy: ShortcutPolicy.ignore,
      );
      return;
    }

    // Mobile path: Android / iOS
    _isMobile = true;

    // Initialize timezone database for zonedSchedule
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      final locations = tz.timeZoneDatabase.locations.values.where(
        (l) => l.currentTimeZone.offset == offset.inMilliseconds,
      );
      if (locations.isNotEmpty) {
        tz.setLocalLocation(locations.first);
      }
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      ),
    );

    // Request notification permission on Android 13+.
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    // Request notification permission on iOS.
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Schedule or cancel the daily Android notification via zonedSchedule.
  /// The OS delivers this notification even when the app is killed.
  static Future<void> _scheduleMobileNotification() async {
    if (!_isMobile) return;

    final config = await AnimeStorage.readConfig();
    final enabled = config['reminderEnabled'] as bool? ?? false;

    if (!enabled) {
      await _plugin.cancel(_scheduledNotificationId);
      return;
    }

    final timeStr = config['reminderTime'] as String? ?? '18:00';
    final parts = timeStr.split(':');
    final rHour = int.parse(parts[0]);
    final rMinute = int.parse(parts[1]);

    await _plugin.cancel(_scheduledNotificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, rHour, rMinute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    final l10n = await _getL10n();

    await _plugin.zonedSchedule(
      _scheduledNotificationId,
      'MyAnime!!!!!',
      l10n.reminderNotifBody,
      scheduledDate,
      const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Start periodic reminder checks.
  /// On Android/iOS: schedules an OS-level daily notification via zonedSchedule.
  /// On desktop: uses Timer.periodic (every 60 seconds).
  /// Safe to call multiple times.
  static void startPeriodicCheck() {
    if (!kIsWeb && _isMobile) {
      _scheduleMobileNotification();
      // Also check immediately for in-app logic.
      checkAndNotify();
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkAndNotify();
    });
    // Also check immediately.
    checkAndNotify();
  }

  /// Check conditions and show reminder if needed.
  static Future<void> checkAndNotify() async {
    try {
      final config = await AnimeStorage.readConfig();
      final enabled = config['reminderEnabled'] as bool? ?? false;
      if (!enabled) return;

      final timeStr = config['reminderTime'] as String? ?? '18:00';
      final parts = timeStr.split(':');
      final rHour = int.parse(parts[0]);
      final rMinute = int.parse(parts[1]);

      final now = DateTime.now(); // local timezone
      final reminderToday =
          DateTime(now.year, now.month, now.day, rHour, rMinute);

      // Not yet time.
      if (now.isBefore(reminderToday)) return;

      // Already notified today.
      final lastDate = config['lastReminderDate'] as String?;
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (lastDate == todayStr) return;

      // Compute episode counts.
      final data = await AnimeStorage.load();
      final jstToday = JstTime.today();
      final jstNow = JstTime.now();

      int airingToday = 0;
      int unwatchedCount = 0;

      for (final anime in data.animeList) {
        final lastEp = anime.endEpisode ?? anime.startEpisode;
        bool countedUnwatched = false;
        for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
          // Count episodes airing today.
          final calDate = anime.getEpisodeCalendarDate(ep);
          if (calDate != null && calDate == jstToday) {
            airingToday++;
          }
          // Count first unwatched episode per anime.
          if (!countedUnwatched) {
            final s =
                anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
            if (s == EpisodeStatus.unwatched) {
              final airDate = anime.getEpisodeAirDate(ep);
              if (airDate != null && !airDate.isAfter(jstNow)) {
                unwatchedCount++;
              }
              countedUnwatched = true;
            }
          }
        }
      }

      if (airingToday == 0 && unwatchedCount == 0) return;

      // Build notification body.
      final l10n = await _getL10n();
      final lines = <String>[];
      if (airingToday > 0) {
        lines.add(l10n.reminderAiringToday(airingToday));
      }
      if (unwatchedCount > 0) {
        lines.add(l10n.reminderUnwatched(unwatchedCount));
      }

      await _show('MyAnime!!!!!', lines.join(' · '));

      // Record today's date.
      config['lastReminderDate'] = todayStr;
      await AnimeStorage.writeConfig(config);
    } catch (e) {
      debugPrint('ReminderService error: $e');
    }
  }

  static int _showCounter = 0;

  static Future<void> _show(String title, String body) async {
    if (_isDesktop) {
      final notification = LocalNotification(
        title: title,
        body: body,
      );
      notification.show();
      return;
    }

    if (!_isMobile) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );

    const darwinDetails = DarwinNotificationDetails();

    await _plugin.show(
      _showCounter++,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      ),
    );
  }
}
