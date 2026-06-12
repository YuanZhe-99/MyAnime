import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';

/// Daily reminder notification service.
///
/// On Android/iOS: uses flutter_local_notifications' zonedSchedule() to
/// schedule per-day one-shot notifications at the OS level for the next
/// [_scheduledDays] days, with the body computed from current anime data and
/// days without anything to watch skipped. Schedules are refreshed on app
/// launch, on reminder-settings change, and after anime data saves, so they
/// fire even when the app process is killed or the device is rebooted.
///
/// On Desktop (Windows/macOS/Linux): uses Timer.periodic + local_notifier
/// with `lastReminderDate` deduplication.
class ReminderService {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `ReminderService._` instance.
  /// Side effects: Implementation-dependent.
  /// Notes: Implementations should preserve this contract.
  ReminderService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  /// Notification channel / ID constants.
  static const _channelId = 'my_anime_reminder';
  static const _channelName = 'Anime Reminder';
  static const _scheduledNotificationId = 100;

  /// Number of upcoming days covered by OS-level scheduled notifications.
  static const _scheduledDays = 7;

  static bool _isDesktop = false;
  static bool _isMobile = false;
  static Timer? _timer;
  static Timer? _rescheduleDebounce;

  /// Purpose: Resolve the current l10n instance from saved locale or platform default.
  /// Inputs: None.
  /// Returns: `Future<AppLocalizations>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Resolve the current l10n instance from saved locale or platform default.
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

  /// Purpose: Initialize the notification plugin.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Initialize the notification plugin.
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

    // Initialize timezone database for zonedSchedule. Resolve the IANA zone
    // id from the OS (flutter_timezone); `DateTime.now().timeZoneName` is an
    // abbreviation like "JST"/"CST" that the tz database cannot look up and
    // an offset-only fallback may pick a zone with different DST rules.
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      final offset = DateTime.now().timeZoneOffset;
      final locations = tz.timeZoneDatabase.locations.values.where(
        (l) => l.currentTimeZone.offset == offset.inMilliseconds,
      );
      if (locations.isNotEmpty) {
        tz.setLocalLocation(locations.first);
      }
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

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
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }

    // Request notification permission on iOS.
    if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  /// Purpose: Schedule per-day OS notifications for the next [_scheduledDays] days.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels and re-creates scheduled notifications; reads config and anime data.
  /// Notes: Internal helper used within this file only. Each day's body is computed
  /// from current anime data; days with nothing airing and nothing unwatched are
  /// skipped so no empty reminder fires. The OS delivers these even when the app
  /// is killed. Schedules are refreshed on launch, settings change, and data saves.
  static Future<void> _scheduleMobileNotification() async {
    if (!_isMobile) return;

    final config = await AnimeStorage.readConfig();
    final enabled = config['reminderEnabled'] as bool? ?? false;

    // Clear all previously scheduled per-day notifications.
    for (var i = 0; i < _scheduledDays; i++) {
      await _plugin.cancel(_scheduledNotificationId + i);
    }
    if (!enabled) return;

    final timeStr = config['reminderTime'] as String? ?? '18:00';
    final parts = timeStr.split(':');
    final rHour = int.parse(parts[0]);
    final rMinute = int.parse(parts[1]);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();

    final l10n = await _getL10n();
    final data = await AnimeStorage.load();

    final now = tz.TZDateTime.now(tz.local);
    for (var offset = 0; offset < _scheduledDays; offset++) {
      final day = now.add(Duration(days: offset));
      final fireAt = tz.TZDateTime(
        tz.local,
        day.year,
        day.month,
        day.day,
        rHour,
        rMinute,
      );
      if (!fireAt.isAfter(now)) continue;

      final body = _buildReminderBody(data, l10n, fireAt);
      if (body == null) continue; // nothing to watch that day

      await _plugin.zonedSchedule(
        _scheduledNotificationId + offset,
        'MyAnime!!!!!',
        body,
        fireAt,
        const NotificationDetails(android: androidDetails, iOS: darwinDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  /// Purpose: Build the reminder body for the given local fire time, or null when empty.
  /// Inputs: `data` current anime data, `l10n`, `atLocal` local notification fire time.
  /// Returns: `String?` — localized body, or null when nothing airs and nothing is unwatched.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Airing counts use the JST
  /// calendar date of the fire moment; unwatched counts include episodes that will
  /// have aired by that moment based on current data.
  static String? _buildReminderBody(
    AnimeData data,
    AppLocalizations l10n,
    DateTime atLocal,
  ) {
    // Convert the local fire time to the JST wall clock used by airing logic.
    final utc = atLocal.toUtc();
    final jstNow = DateTime(
      utc.year,
      utc.month,
      utc.day,
      utc.hour + 9,
      utc.minute,
      utc.second,
    );
    final jstDate = DateTime(jstNow.year, jstNow.month, jstNow.day);

    final airingAnimeIds = <String>{};
    var airingEpisodeCount = 0;
    final unwatchedAnimeIds = <String>{};
    var unwatchedEpisodeCount = 0;

    for (final anime in data.animeList) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final calDate = anime.getEpisodeCalendarDate(ep);
        if (calDate != null && calDate == jstDate) {
          airingAnimeIds.add(anime.id);
          airingEpisodeCount++;
        }

        final s = anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
        if (s == EpisodeStatus.unwatched) {
          final airDate = anime.getEpisodeAirDate(ep);
          if (airDate != null && !airDate.isAfter(jstNow)) {
            unwatchedAnimeIds.add(anime.id);
            unwatchedEpisodeCount++;
          }
        }
      }
    }

    if (airingEpisodeCount == 0 && unwatchedEpisodeCount == 0) return null;

    final lines = <String>[];
    if (airingEpisodeCount > 0) {
      lines.add(
        l10n.reminderAiringToday(airingAnimeIds.length, airingEpisodeCount),
      );
    }
    if (unwatchedEpisodeCount > 0) {
      lines.add(
        l10n.reminderUnwatched(unwatchedAnimeIds.length, unwatchedEpisodeCount),
      );
    }
    return lines.join(' · ');
  }

  /// Purpose: Start periodic reminder checks.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Start periodic reminder checks. On Android/iOS: schedules content-aware
  /// per-day OS notifications via zonedSchedule (no in-app duplicate is shown).
  /// On desktop: uses Timer.periodic (every 60 seconds). Safe to call multiple times.
  static void startPeriodicCheck() {
    if (!kIsWeb && _isMobile) {
      _scheduleMobileNotification();
      return;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkAndNotify();
    });
    // Also check immediately.
    checkAndNotify();
  }

  /// Purpose: Refresh OS-level scheduled reminders after anime data changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Debounce-reschedules the per-day mobile notifications.
  /// Notes: Called from storage saves so scheduled bodies track current data;
  /// no-op on desktop where the periodic check reads fresh data each minute.
  static void notifyDataChanged() {
    if (kIsWeb || !_isMobile) return;
    _rescheduleDebounce?.cancel();
    _rescheduleDebounce = Timer(const Duration(seconds: 5), () {
      _scheduleMobileNotification();
    });
  }

  /// Purpose: Check due reminder conditions and show the daily schedule summary.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Desktop-only in-process path; mobile is covered by OS-scheduled
  /// notifications so this never double-notifies there. Counts both anime titles
  /// and episode totals for today's airing and aired unwatched work.
  static Future<void> checkAndNotify() async {
    if (!_isDesktop) return;
    try {
      final config = await AnimeStorage.readConfig();
      final enabled = config['reminderEnabled'] as bool? ?? false;
      if (!enabled) return;

      final timeStr = config['reminderTime'] as String? ?? '18:00';
      final parts = timeStr.split(':');
      final rHour = int.parse(parts[0]);
      final rMinute = int.parse(parts[1]);

      final now = DateTime.now(); // local timezone
      final reminderToday = DateTime(
        now.year,
        now.month,
        now.day,
        rHour,
        rMinute,
      );

      // Not yet time.
      if (now.isBefore(reminderToday)) return;

      // Already notified today.
      final lastDate = config['lastReminderDate'] as String?;
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      if (lastDate == todayStr) return;

      // Compute the notification body for the current moment.
      final data = await AnimeStorage.load();
      final l10n = await _getL10n();
      final body = _buildReminderBody(data, l10n, now);
      if (body == null) return;

      await _show('MyAnime!!!!!', body);

      // Record today's date.
      config['lastReminderDate'] = todayStr;
      await AnimeStorage.writeConfig(config);
    } catch (e) {
      debugPrint('ReminderService error: $e');
    }
  }

  static int _showCounter = 0;

  /// Purpose: Provide the internal show helper for this file.
  /// Inputs: `title`, `body`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static Future<void> _show(String title, String body) async {
    if (_isDesktop) {
      final notification = LocalNotification(title: title, body: body);
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
      const NotificationDetails(android: androidDetails, iOS: darwinDetails),
    );
  }
}
