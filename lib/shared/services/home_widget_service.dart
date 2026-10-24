import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';
import '../utils/calendar_preferences.dart';
import 'auto_sync_service.dart';

/// Feeds the Android and iOS home-screen widgets ("Up next" 2×2 and the
/// compact 2×1 strip / lock-screen rectangle) with a precomputed snapshot.
///
/// The snapshot is one JSON string handed to the native side over
/// [_channel], which stores it (the `MyAnimeWidget` shared preferences on
/// Android, the `group.com.yuanzhe.myAnime` App Group `UserDefaults` on iOS)
/// and redraws the widgets. The native widgets only render it; the format is
/// documented in `doc/en-us/features/home-screen-widgets.md`.
class HomeWidgetService {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  HomeWidgetService._();

  /// Native bridge: `MainActivity.kt` on Android, `AppDelegate.swift` on iOS.
  static const _channel = MethodChannel('com.yuanzhe.my_anime/home_widget');

  /// Snapshot format version; bump only with a matching native change.
  static const formatVersion = 1;

  /// How far ahead upcoming episodes are included, so the widgets keep
  /// moving episodes from "upcoming" to "to watch" without the app running.
  static const lookahead = Duration(days: 8);

  /// Cap on episode entries, keeping the shared store small.
  static const maxEpisodes = 80;

  /// Smallest and largest widget text scale the settings slider offers.
  static const minTextScale = 0.9;
  static const maxTextScale = 1.5;

  static Timer? _debounce;

  /// Purpose: Clamp a widget text scale to the supported range.
  /// Inputs: `scale`.
  /// Returns: The scale within [minTextScale]..[maxTextScale], rounded to
  /// one decimal; 1.0 for a non-finite value.
  /// Side effects: None.
  /// Notes: Rounding keeps slider steps exact when stored and compared.
  static double clampTextScale(double scale) {
    if (!scale.isFinite) return 1.0;
    final clamped = scale.clamp(minTextScale, maxTextScale).toDouble();
    return (clamped * 10).roundToDouble() / 10;
  }

  /// Purpose: Whether this platform has home-screen widgets.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Android and iOS only; every public entry point no-ops elsewhere.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Purpose: Configure the widget store and push the first snapshot.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Subscribes to sync/restore reloads and refreshes the widgets.
  /// Notes: Call once from `main()`; safe on unsupported platforms.
  static Future<void> init() async {
    if (!isSupported) return;
    AutoSyncService.instance.addOnLocalDataChanged(notifyDataChanged);
    unawaited(refresh());
  }

  /// Purpose: Schedule a debounced widget refresh after data or settings change.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Starts a 2-second timer that calls [refresh].
  /// Notes: Called from library saves, sync/restore reloads, app resume, and
  /// the locale, calendar-time-basis and widget-text-size settings.
  static void notifyDataChanged() {
    if (!isSupported) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(refresh()));
  }

  /// Purpose: Rebuild the snapshot from the stored library and redraw the widgets.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `anime_data.json` and `storage_config.json`, writes
  /// the shared widget store, and asks the OS to redraw every widget.
  /// Notes: Failures are logged and swallowed; a stale widget is harmless.
  static Future<void> refresh() async {
    if (!isSupported) return;
    try {
      final data = await AnimeStorage.load();
      final basis = await AnimeStorage.getHomeCalendarTimeBasis() == 'local'
          ? HomeCalendarTimeBasis.local
          : HomeCalendarTimeBasis.jst;
      final l10n = await _l10n();
      final snapshot = buildSnapshot(
        data.animeList,
        nowUtc: DateTime.now().toUtc(),
        basis: basis,
        labels: labelsFor(l10n),
        textScale: clampTextScale(await AnimeStorage.getWidgetTextScale()),
      );
      await _channel.invokeMethod<void>('update', {
        'snapshot': jsonEncode(snapshot),
      });
    } catch (e) {
      debugPrint('HomeWidgetService: refresh failed: $e');
    }
  }

  /// Purpose: Collect the localized strings the native widgets display.
  /// Inputs: `l10n`.
  /// Returns: `Map<String, String>`; `{n}` in `episode` and `series` is
  /// replaced natively with a number.
  /// Side effects: None.
  /// Notes: Keeps all widget wording in the ARB files instead of native resources.
  static Map<String, String> labelsFor(AppLocalizations l10n) => {
    'appName': 'MyAnime',
    'toWatch': l10n.widgetToWatch,
    'today': l10n.widgetToday,
    'caughtUp': l10n.widgetCaughtUp,
    'noUpdates': l10n.widgetNoUpdatesToday,
    'next': l10n.widgetNext,
    'episode': l10n.widgetEpisode('{n}'),
    'series': l10n.widgetSeriesCount('{n}'),
  };

  /// Purpose: Build the widget snapshot for a library at a given instant.
  /// Inputs: `animeList`; `nowUtc`; `basis` — which calendar day counts as
  /// "today"; `labels` from [labelsFor]; `textScale` — the widget text size
  /// multiplier, written as `textScale`.
  /// Returns: The JSON-ready snapshot map (format version [formatVersion]).
  /// Side effects: None.
  /// Notes: Per anime it keeps the earliest unwatched aired episode (the
  /// "to watch" queue) and every episode airing from the start of today to
  /// [lookahead] ahead, so the native side can recount as time passes:
  /// `toWatch = airedUnwatched + entries with !w and generatedAt < at <= now`.
  /// Episode iteration mirrors the home page's unwatched list.
  static Map<String, dynamic> buildSnapshot(
    List<Anime> animeList, {
    required DateTime nowUtc,
    required HomeCalendarTimeBasis basis,
    required Map<String, String> labels,
    double textScale = 1.0,
  }) {
    final now = nowUtc.toUtc();
    final windowStart = _startOfToday(now, basis);
    final windowEnd = now.add(lookahead);
    var airedUnwatched = 0;
    final queue = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];

    for (final anime in animeList) {
      final lastEp = anime.endEpisode ?? anime.startEpisode;
      var queued = false;
      for (var ep = anime.startEpisode; ep <= lastEp; ep++) {
        final jst = anime.getEpisodeAirDate(ep);
        if (jst == null) continue;
        final at = jstToUtc(jst);
        final status = anime.episodeStatuses[ep] ?? EpisodeStatus.unwatched;
        final unwatched = status == EpisodeStatus.unwatched;
        final aired = !at.isAfter(now);
        if (unwatched && aired) airedUnwatched++;
        final entry = {
          'id': anime.id,
          't': anime.displayTitle,
          'e': ep,
          'at': at.millisecondsSinceEpoch,
          'w': !unwatched,
        };
        if (unwatched && aired && !queued) {
          queued = true;
          queue.add(entry);
        } else if (!at.isBefore(windowStart) && !at.isAfter(windowEnd)) {
          upcoming.add(entry);
        }
      }
    }

    int byAt(Map<String, dynamic> a, Map<String, dynamic> b) =>
        (a['at'] as int).compareTo(b['at'] as int);
    queue.sort(byAt);
    upcoming.sort(byAt);
    final episodes = [...queue, ...upcoming].take(maxEpisodes).toList()
      ..sort(byAt);

    return {
      'v': formatVersion,
      'generatedAt': now.millisecondsSinceEpoch,
      'timeZone': basis == HomeCalendarTimeBasis.jst ? 'Asia/Tokyo' : '',
      'airedUnwatched': airedUnwatched,
      'queueSize': queue.length,
      'episodes': episodes,
      'labels': labels,
      'textScale': clampTextScale(textScale),
    };
  }

  /// Purpose: Convert an anime-model Japan wall-clock time to a UTC instant.
  /// Inputs: `jst` — wall-clock JST, whatever its `isUtc` flag.
  /// Returns: `DateTime` in UTC.
  /// Side effects: None.
  /// Notes: Mirrors `JstTime.toLocal` without the final local conversion.
  static DateTime jstToUtc(DateTime jst) => DateTime.utc(
    jst.year,
    jst.month,
    jst.day,
    jst.hour - 9,
    jst.minute,
    jst.second,
  );

  /// Purpose: Return the UTC instant at which "today" starts for a time basis.
  /// Inputs: `nowUtc`, `basis`.
  /// Returns: `DateTime` in UTC.
  /// Side effects: None.
  /// Notes: JST midnight for [HomeCalendarTimeBasis.jst], device-local midnight otherwise.
  static DateTime _startOfToday(DateTime nowUtc, HomeCalendarTimeBasis basis) {
    if (basis == HomeCalendarTimeBasis.local) {
      final local = nowUtc.toLocal();
      return DateTime(local.year, local.month, local.day).toUtc();
    }
    final jst = nowUtc.add(const Duration(hours: 9));
    return DateTime.utc(
      jst.year,
      jst.month,
      jst.day,
    ).subtract(const Duration(hours: 9));
  }

  /// Purpose: Resolve localizations from the saved locale or the platform default.
  /// Inputs: None.
  /// Returns: `Future<AppLocalizations>`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Same resolution as the reminder service; falls back to English.
  static Future<AppLocalizations> _l10n() async {
    final tag = await AnimeStorage.getLocaleTag();
    var locale = PlatformDispatcher.instance.locale;
    if (tag != null) {
      final parts = tag.split('_');
      locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
