import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/home_widget_service.dart';
import '../../../shared/utils/calendar_preferences.dart';
import '../../anime/services/anime_storage.dart';

/// Live preview of the two home-screen widgets for the widget text-size
/// setting (1.9.4).
///
/// It draws the 2×2 "Up next" widget and the 2×1 strip from a snapshot of the
/// real library, built by [HomeWidgetService.buildSnapshot], with the same text
/// sizes as the Android layouts times [textScale]. It approximates the native
/// widgets in app colors; it is not a pixel copy of either platform.
class HomeWidgetPreview extends StatefulWidget {
  /// Purpose: Create a home widget preview.
  /// Inputs: `textScale` — the widget text size multiplier to draw at.
  /// Returns: A new `HomeWidgetPreview` instance.
  /// Side effects: None.
  /// Notes: None.
  const HomeWidgetPreview({super.key, required this.textScale});

  final double textScale;

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<HomeWidgetPreview> createState() => _HomeWidgetPreviewState();
}

class _HomeWidgetPreviewState extends State<HomeWidgetPreview> {
  late final Future<HomeWidgetPreviewState> _state = _load();

  /// Purpose: Build the preview state from the stored library once.
  /// Inputs: None.
  /// Returns: `Future<HomeWidgetPreviewState>`.
  /// Side effects: Reads `anime_data.json` and `storage_config.json`.
  /// Notes: Labels are resolved later from the widget's own localizations.
  Future<HomeWidgetPreviewState> _load() async {
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
    return HomeWidgetPreviewState.evaluate(snapshot, now);
  }

  /// Purpose: Build the widget subtree for the current state.
  /// Inputs: `context`.
  /// Returns: The two preview cards side by side, wrapping on narrow widths.
  /// Side effects: None.
  /// Notes: Shows nothing until the library has loaded.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeWidgetPreviewState>(
      future: _state,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox(height: 172);
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SmallWidgetCard(state: state, scale: widget.textScale),
            _StripWidgetCard(state: state, scale: widget.textScale),
          ],
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
  /// Inputs: `snapshot` from [HomeWidgetService.buildSnapshot]; `nowUtc` — the
  /// instant it was built for.
  /// Returns: `HomeWidgetPreviewState`.
  /// Side effects: None.
  /// Notes: Because the snapshot is fresh, no episode aired after
  /// `generatedAt`, so `toWatch` is simply `airedUnwatched`.
  factory HomeWidgetPreviewState.evaluate(
    Map<String, dynamic> snapshot,
    DateTime nowUtc,
  ) {
    final now = nowUtc.millisecondsSinceEpoch;
    final episodes = (snapshot['episodes'] as List)
        .cast<Map<String, dynamic>>();
    final jst = snapshot['timeZone'] == 'Asia/Tokyo';
    DateTime day(int ms) {
      final utc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      final t = jst ? utc.add(const Duration(hours: 9)) : utc.toLocal();
      return DateTime(t.year, t.month, t.day);
    }

    final today = day(now);
    final seen = <String>{};
    return HomeWidgetPreviewState(
      toWatch: snapshot['airedUnwatched'] as int,
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

/// Shared rounded surface of both preview cards.
class _WidgetSurface extends StatelessWidget {
  /// Purpose: Create a widget surface.
  /// Inputs: `width`, `height`, `padding`, `child`.
  /// Returns: A new `_WidgetSurface`.
  /// Side effects: None.
  /// Notes: Fixed size, like a launcher cell; overflowing text is clipped.
  const _WidgetSurface({
    required this.width,
    required this.height,
    required this.padding,
    required this.child,
  });

  final double width;
  final double height;
  final EdgeInsets padding;
  final Widget child;

  /// Purpose: Build the widget subtree for the current state.
  /// Inputs: `context`.
  /// Returns: The clipped, tinted card.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

/// Preview of the 2×2 "Up next" widget.
class _SmallWidgetCard extends StatelessWidget {
  /// Purpose: Create the 2×2 preview.
  /// Inputs: `state`, `scale`.
  /// Returns: A new `_SmallWidgetCard`.
  /// Side effects: None.
  /// Notes: None.
  const _SmallWidgetCard({required this.state, required this.scale});

  final HomeWidgetPreviewState state;
  final double scale;

  /// Purpose: Build the widget subtree for the current state.
  /// Inputs: `context`.
  /// Returns: Header, count block and queue rows, sized like
  /// `widget_up_next.xml` times [scale].
  /// Side effects: None.
  /// Notes: Two rows at 100–120% text, one above, like a 2×2 cell on most
  /// launchers.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    double sp(double base) => base * scale;
    final rows = state.queue.isNotEmpty
        ? [
            for (final e in state.queue.take(scale > 1.2 ? 1 : 2))
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

    return _WidgetSurface(
      width: 172,
      height: 172,
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

/// Preview of the 2×1 strip widget.
class _StripWidgetCard extends StatelessWidget {
  /// Purpose: Create the strip preview.
  /// Inputs: `state`, `scale`.
  /// Returns: A new `_StripWidgetCard`.
  /// Side effects: None.
  /// Notes: None.
  const _StripWidgetCard({required this.state, required this.scale});

  final HomeWidgetPreviewState state;
  final double scale;

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

    return _WidgetSurface(
      width: 172,
      height: 76,
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
