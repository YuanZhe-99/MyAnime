import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import '../utils/jst_time.dart';

/// Daily reminder notification service.
///
/// At app startup, checks whether the configured reminder time (local
/// timezone) has passed today. If so, and if there are episodes airing
/// today (JST) or unwatched episodes, a local notification is shown.
///
/// Mobile (Android/iOS): flutter_local_notifications
/// Desktop (Windows/macOS/Linux): local_notifier
class ReminderService {
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Notification channel / ID constants.
  static const _channelId = 'my_anime_reminder';
  static const _channelName = 'Anime Reminder';
  static const _notificationId = 1;

  static bool _isDesktop = false;
  static bool _isMobile = false;
  static Timer? _timer;

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

  /// Start periodic reminder checks (every 60 seconds).
  /// Safe to call multiple times — restarts the timer.
  static void startPeriodicCheck() {
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
      final lines = <String>[];
      if (airingToday > 0) {
        lines.add('$airingToday episode(s) airing today');
      }
      if (unwatchedCount > 0) {
        lines.add('$unwatchedCount unwatched episode(s)');
      }

      await _show('MyAnime!!!!!', lines.join(' · '));

      // Record today's date.
      config['lastReminderDate'] = todayStr;
      await AnimeStorage.writeConfig(config);
    } catch (e) {
      debugPrint('ReminderService error: $e');
    }
  }

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
      _notificationId,
      title,
      body,
      const NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      ),
    );
  }
}
