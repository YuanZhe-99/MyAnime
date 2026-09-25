import '../../../shared/utils/season_label.dart';
import '../models/anime.dart';
import 'series_service.dart';

/// How the Manage tab lays out the library (1.6.2).
enum ManageViewMode {
  /// The swipeable quarter pages, plus "Other" — the default.
  quarter,

  /// One row per series, expanding into its members.
  series,
}

/// How the Manage tab's series view orders its groups (1.6.2).
enum ManageSeriesSort {
  /// The group whose newest member premiered most recently first — the
  /// default.
  latest,

  /// By group label, A to Z.
  title,

  /// The group with the most recently edited member first.
  modified,
}

/// Purpose: Parse a stored Manage view mode.
/// Inputs: `value` — the `storage_config.json` string.
/// Returns: `ManageViewMode` — unknown values fall back to `quarter`.
/// Side effects: None.
/// Notes: None.
ManageViewMode parseManageViewMode(String? value) =>
    value == ManageViewMode.series.name
    ? ManageViewMode.series
    : ManageViewMode.quarter;

/// Purpose: Parse a stored Manage series sort.
/// Inputs: `value` — the `storage_config.json` string.
/// Returns: `ManageSeriesSort` — unknown values fall back to `latest`.
/// Side effects: None.
/// Notes: None.
ManageSeriesSort parseManageSeriesSort(String? value) =>
    ManageSeriesSort.values.where((s) => s.name == value).firstOrNull ??
    ManageSeriesSort.latest;

/// One row of the Manage tab's series view.
class ManageSeriesGroup {
  /// A stable key: the series key, or `id:<anime id>` for a single record.
  final String key;

  /// What the row is called: the first member's title without season
  /// markers, or a single record's own title.
  final String label;

  /// The series, when the row is one with two or more visible members.
  final AnimeSeries? series;

  /// The visible members, in series order.
  final List<Anime> members;

  /// Purpose: Create a group.
  /// Inputs: see fields.
  /// Returns: A new `ManageSeriesGroup`.
  /// Side effects: None.
  /// Notes: None.
  const ManageSeriesGroup({
    required this.key,
    required this.label,
    required this.members,
    this.series,
  });

  /// Purpose: Report whether the row expands into several members.
  /// Inputs: None.
  /// Returns: `bool` — true for two or more members.
  /// Side effects: None.
  /// Notes: None.
  bool get isGroup => members.length >= 2;
}

/// Purpose: Group the library for the Manage tab's series view.
/// Inputs: `all` — the whole library; `keep` — the page's archive and
/// category filters; `sort`.
/// Returns: `List<ManageSeriesGroup>` — every kept record exactly once.
/// Side effects: None.
/// Notes: The series are computed from the **whole** library before the
/// filters apply, so filtering never changes which records belong together.
/// A series with two or more kept members is one group; every other kept
/// record — in no series, standalone, a one-member curated series, or the
/// only kept member of a series — is a group of one. Ties sort by label,
/// then by the first member's id, so the order is deterministic.
List<ManageSeriesGroup> groupForSeriesView(
  List<Anime> all, {
  required bool Function(Anime) keep,
  required ManageSeriesSort sort,
}) {
  final index = SeriesIndex.build(all);
  final seen = <String>{};
  final groups = <ManageSeriesGroup>[];
  for (final a in all) {
    if (!keep(a) || seen.contains(a.id)) continue;
    final series = index.seriesOf(a.id);
    final members = series == null || series.members.length < 2
        ? [a]
        : series.members.where(keep).toList();
    seen.addAll(members.map((m) => m.id));
    if (members.length >= 2) {
      final base = stripSeasonMarkers(members.first.displayTitle).trim();
      groups.add(
        ManageSeriesGroup(
          key: series!.key,
          label: base.isEmpty ? members.first.displayTitle : base,
          series: series,
          members: members,
        ),
      );
    } else {
      groups.add(
        ManageSeriesGroup(
          key: 'id:${members.single.id}',
          label: members.single.displayTitle,
          members: members,
        ),
      );
    }
  }

  DateTime? latestAir(ManageSeriesGroup g) {
    DateTime? best;
    for (final m in g.members) {
      final d = m.firstAirDate;
      if (d != null && (best == null || d.isAfter(best))) best = d;
    }
    return best;
  }

  DateTime lastModified(ManageSeriesGroup g) =>
      g.members.map((m) => m.modifiedAt).reduce((x, y) => x.isAfter(y) ? x : y);

  int byLabel(ManageSeriesGroup x, ManageSeriesGroup y) {
    final c = x.label.toLowerCase().compareTo(y.label.toLowerCase());
    return c != 0 ? c : x.members.first.id.compareTo(y.members.first.id);
  }

  groups.sort((x, y) {
    switch (sort) {
      case ManageSeriesSort.title:
        return byLabel(x, y);
      case ManageSeriesSort.modified:
        final c = lastModified(y).compareTo(lastModified(x));
        return c != 0 ? c : byLabel(x, y);
      case ManageSeriesSort.latest:
        final ax = latestAir(x);
        final ay = latestAir(y);
        if (ax != null && ay != null && ax != ay) return ay.compareTo(ax);
        if (ax == null && ay != null) return 1;
        if (ax != null && ay == null) return -1;
        return byLabel(x, y);
    }
  });
  return groups;
}
