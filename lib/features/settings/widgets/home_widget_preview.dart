import 'package:flutter/material.dart';
import 'package:myapps_widget/myapps_widget.dart' show PlacedWidgetSize;
import 'package:myapps_widget_ui/myapps_widget_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/home_widget_service.dart';
import '../../../shared/utils/calendar_preferences.dart';
import '../../anime/services/anime_storage.dart';

/// Which home-screen widget a [HomeWidgetPreview] draws.
enum HomeWidgetPreviewKind {
  /// The large "Up next" widget (`UpNextWidgetProvider`, 2×2 by default).
  large,

  /// The strip (`UpNextStripWidgetProvider`, 2×1 by default).
  strip,
}

/// What a [HomeWidgetPreview] draws from: the evaluated library state and
/// every placed widget instance's size.
typedef HomeWidgetPreviewData = (
  HomeWidgetPreviewState,
  List<PlacedWidgetSize>,
);

/// Live preview of one home-screen widget for its text-size setting (1.9.4;
/// one widget per preview since 1.9.7).
///
/// It draws the large "Up next" widget or the strip from a snapshot of the
/// real library, built by [HomeWidgetService.buildSnapshot], with the same text
/// sizes as the Android layouts times [textScale]. On Android the card lays
/// out at the size the launcher gives the first placed instance of that widget
/// ([HomeWidgetService.placedSizes]); with none placed, and on iOS, it uses a
/// 3×2 or 3×1 cell size ([defaultSize]). The card is then drawn at
/// [displayScale] and shrinks further only to fit the page. It approximates
/// the native widgets in app colors; it is not a pixel copy of either
/// platform, and a launcher that draws widgets scaled still looks smaller on
/// the home screen.
class HomeWidgetPreview extends StatelessWidget {
  /// Purpose: Create a home widget preview.
  /// Inputs: `data` — from [load], shared by the previews on one page;
  /// `kind` — which widget to draw; `textScale` — that widget's text size
  /// multiplier.
  /// Returns: A new `HomeWidgetPreview` instance.
  /// Side effects: None.
  /// Notes: None.
  const HomeWidgetPreview({
    super.key,
    required this.data,
    required this.kind,
    required this.textScale,
  });

  final Future<HomeWidgetPreviewData> data;
  final HomeWidgetPreviewKind kind;
  final double textScale;

  /// Width and height of one launcher cell in the default sizes, in dp:
  /// half of the shared 2×2 preview side.
  static const double cell = WidgetPreviewSurface.smallSide / 2;

  /// Factor the card is drawn at on the Settings page (1.9.7). At 1.0 the
  /// card looked larger than the widget does on most home screens.
  static const double displayScale = 0.75;

  /// Purpose: Return the size a preview uses when no instance is placed.
  /// Inputs: `kind`.
  /// Returns: 3×2 cells for the large widget, 3×1 for the strip, in dp.
  /// Side effects: None.
  /// Notes: The strip keeps the shared strip height rather than a full cell.
  static Size defaultSize(HomeWidgetPreviewKind kind) => switch (kind) {
    HomeWidgetPreviewKind.large => const Size(3 * cell, 2 * cell),
    HomeWidgetPreviewKind.strip => const Size(
      3 * cell,
      WidgetPreviewSurface.stripHeight,
    ),
  };

  /// Purpose: Build the preview data from the stored library, with the
  /// placed widgets' sizes.
  /// Inputs: None.
  /// Returns: The evaluated state and every placed instance's size.
  /// Side effects: Reads `anime_data.json` and `storage_config.json`, and
  /// asks the launcher for placed widget sizes on Android.
  /// Notes: Labels are resolved later from the widget's own localizations.
  /// The widget settings page calls it once per visit.
  static Future<HomeWidgetPreviewData> load() async {
    final data = await AnimeStorage.load();
    final basis = await AnimeStorage.getHomeCalendarTimeBasis() == 'local'
        ? HomeCalendarTimeBasis.local
        : HomeCalendarTimeBasis.jst;
    final now = DateTime.now().toUtc();
    final snapshot = HomeWidgetService.buildSnapshot(
      data.animeList,
      nowUtc: now,
      basis: basis,
      labels: const {},
    );
    return (
      HomeWidgetPreviewState.evaluate(snapshot, now),
      await HomeWidgetService.placedSizes(),
    );
  }

  /// Purpose: Build the widget subtree for the current state.
  /// Inputs: `context`.
  /// Returns: The card at its placed size (portrait or landscape by the
  /// current orientation) or [defaultSize], drawn at [displayScale] and
  /// scaled down further to fit the page width, centered.
  /// Side effects: None.
  /// Notes: Keeps the space of the default size until the data has loaded.
  /// With several placed instances of the widget, the first one is shown.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeWidgetPreviewData>(
      future: data,
      builder: (context, snapshot) {
        final loaded = snapshot.data;
        if (loaded == null) {
          return SizedBox(height: defaultSize(kind).height * displayScale);
        }
        final (state, placed) = loaded;
        final provider = switch (kind) {
          HomeWidgetPreviewKind.large => HomeWidgetService.smallProvider,
          HomeWidgetPreviewKind.strip => HomeWidgetService.stripProvider,
        };
        final instance = placed
            .where((s) => s.provider == provider)
            .firstOrNull;
        final landscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final size = instance == null
            ? defaultSize(kind)
            : (landscape ? instance.landscape : instance.portrait);
        final Widget card = switch (kind) {
          HomeWidgetPreviewKind.large => _SmallWidgetCard(
            state: state,
            scale: textScale,
            size: size,
            placedMinHeight: instance?.minHeight,
          ),
          HomeWidgetPreviewKind.strip => _StripWidgetCard(
            state: state,
            scale: textScale,
            size: size,
          ),
        };
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: size.width * displayScale,
              height: size.height * displayScale,
              child: FittedBox(child: card),
            ),
          ),
        );
      },
    );
  }
}

/// One widget state for the preview: the Dart mirror of the native
/// `UpNextState` evaluation at the instant the snapshot was built.
class HomeWidgetPreviewState {
  /// Purpose: Create a preview state.
  /// Inputs: Every field.
  /// Returns: A new `HomeWidgetPreviewState`.
  /// Side effects: None.
  /// Notes: None.
  const HomeWidgetPreviewState({
    required this.toWatch,
    required this.queue,
    required this.todayCount,
    required this.nextUp,
  });

  final int toWatch;

  /// Earliest unwatched aired episode per anime, oldest first.
  final List<Map<String, dynamic>> queue;
  final int todayCount;

  /// First unwatched episode airing after now, if any.
  final Map<String, dynamic>? nextUp;

  /// Purpose: Evaluate a freshly built snapshot.
  /// Inputs: `snapshot` — the envelope map from
  /// [HomeWidgetService.buildSnapshot]; `nowUtc` — the instant it was built for.
  /// Returns: `HomeWidgetPreviewState`.
  /// Side effects: None.
  /// Notes: Reads MyAnime's fields from the envelope's `payload`. Because the
  /// snapshot is fresh, no episode aired after `generatedAt`, so `toWatch`
  /// is simply `airedUnwatched`.
  factory HomeWidgetPreviewState.evaluate(
    Map<String, dynamic> snapshot,
    DateTime nowUtc,
  ) {
    final now = nowUtc.millisecondsSinceEpoch;
    final payload = snapshot['payload'] as Map<String, dynamic>;
    final episodes = (payload['episodes'] as List).cast<Map<String, dynamic>>();
    final jst = payload['timeZone'] == 'Asia/Tokyo';
    DateTime day(int ms) {
      final utc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      final t = jst ? utc.add(const Duration(hours: 9)) : utc.toLocal();
      return DateTime(t.year, t.month, t.day);
    }

    final today = day(now);
    final seen = <String>{};
    return HomeWidgetPreviewState(
      toWatch: payload['airedUnwatched'] as int,
      queue: [
        for (final e in episodes)
          if (e['w'] != true && (e['at'] as int) <= now && seen.add(e['id'])) e,
      ],
      todayCount: episodes.where((e) => day(e['at'] as int) == today).length,
      nextUp: episodes
          .where((e) => e['w'] != true && (e['at'] as int) > now)
          .firstOrNull,
    );
  }
}

/// Purpose: Format an air time like the native widgets.
/// Inputs: `ms` — epoch milliseconds; `context` for the locale.
/// Returns: "HH:mm", with a short weekday when it is not today.
/// Side effects: None.
/// Notes: Uses device-local time; the preview does not need the JST basis.
String _airTime(BuildContext context, int ms) {
  final at = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final time = MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(at), alwaysUse24HourFormat: true);
  if (at.year == now.year && at.month == now.month && at.day == now.day) {
    return time;
  }
  final weekday = MaterialLocalizations.of(
    context,
  ).narrowWeekdays[at.weekday % 7];
  return '$weekday $time';
}

/// Preview of the large "Up next" widget.
class _SmallWidgetCard extends StatelessWidget {
  /// Purpose: Create the large widget preview.
  /// Inputs: `state`, `scale`; `size` — the card size in dp;
  /// `placedMinHeight` — the placed instance's `OPTION_APPWIDGET_MIN_HEIGHT`,
  /// or null when none is placed.
  /// Returns: A new `_SmallWidgetCard`.
  /// Side effects: None.
  /// Notes: None.
  const _SmallWidgetCard({
    required this.state,
    required this.scale,
    required this.size,
    this.placedMinHeight,
  });

  /// Mirrors `UpNextWidgetProvider.TWO_ROW_MIN_HEIGHT_DP`.
  static const _twoRowMinHeight = 150.0;

  final HomeWidgetPreviewState state;
  final double scale;
  final Size size;
  final double? placedMinHeight;

  /// Purpose: Build the widget subtree for the current state.
  /// Inputs: `context`.
  /// Returns: Header, count block and queue rows, sized like
  /// `widget_up_next.xml` times [scale].
  /// Side effects: None.
  /// Notes: With a placed Android instance, the row count follows
  /// `UpNextWidgetProvider.render` (two rows when its minimum height reaches
  /// 150 dp × [scale]); otherwise the same rule against the default
  /// 2-cell height.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    double sp(double base) => base * scale;
    final h = placedMinHeight ?? size.height;
    final rowCount = h == 0 || h >= _twoRowMinHeight * scale ? 2 : 1;
    final rows = state.queue.isNotEmpty
        ? [
            for (final e in state.queue.take(rowCount))
              (e['t'] as String, l10n.widgetEpisode('${e['e']}')),
          ]
        : [
            if (state.nextUp case final next?)
              (
                next['t'] as String,
                '${l10n.widgetEpisode('${next['e']}')} · '
                    '${_airTime(context, next['at'] as int)}',
              ),
          ];
    final caughtUp = state.toWatch == 0;

    return WidgetPreviewSurface(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'MyAnime',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: sp(12),
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${l10n.widgetToday} ${state.todayCount}',
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: sp(11),
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caughtUp ? l10n.widgetCaughtUp : '${state.toWatch}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: sp(caughtUp ? 20 : 36),
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caughtUp
                ? (state.nextUp == null
                      ? l10n.widgetNoUpdatesToday
                      : l10n.widgetNext)
                : '${l10n.widgetToWatch} · '
                      '${l10n.widgetSeriesCount('${state.queue.length}')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: sp(12), color: scheme.onSurfaceVariant),
          ),
          const Spacer(),
          for (final (i, (title, meta)) in rows.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: sp(13),
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    meta,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: sp(12),
                      fontWeight: FontWeight.w500,
                      color: scheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Preview of the strip widget.
class _StripWidgetCard extends StatelessWidget {
  /// Purpose: Create the strip preview.
  /// Inputs: `state`, `scale`; `size` — the card size in dp.
  /// Returns: A new `_StripWidgetCard`.
  /// Side effects: None.
  /// Notes: None.
  const _StripWidgetCard({
    required this.state,
    required this.scale,
    required this.size,
  });

  final HomeWidgetPreviewState state;
  final double scale;
  final Size size;

  /// Purpose: Build the widget subtree for the current state.
  /// Inputs: `context`.
  /// Returns: Count tile plus two lines, sized like
  /// `widget_up_next_strip.xml` times [scale].
  /// Side effects: None.
  /// Notes: Same line choice as `UpNextStripWidgetProvider.render`.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    double sp(double base) => base * scale;
    final today = '${l10n.widgetToday} ${state.todayCount}';
    final first = state.queue.firstOrNull;
    final next = state.nextUp;
    final (line1, line2) = first != null
        ? (
            first['t'] as String,
            '${l10n.widgetEpisode('${first['e']}')} · $today',
          )
        : next != null
        ? (
            l10n.widgetCaughtUp,
            '${l10n.widgetNext} ${_airTime(context, next['at'] as int)} · '
                '${next['t']}',
          )
        : (l10n.widgetCaughtUp, l10n.widgetNoUpdatesToday);

    return WidgetPreviewSurface(
      width: size.width,
      height: size.height,
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              state.toWatch > 0 ? '${state.toWatch}' : '✓',
              maxLines: 1,
              style: TextStyle(
                fontSize: sp(18),
                fontWeight: FontWeight.w500,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: sp(14),
                    fontWeight: FontWeight.w500,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  line2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: sp(12),
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
