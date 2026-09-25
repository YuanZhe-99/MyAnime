import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/services/manage_grouping.dart';

final _t = DateTime.utc(2024, 1, 1);
const _frieren = '44444444-4444-4444-8444-444444444444';

/// Purpose: Build a fixture record.
/// Inputs: see parameters.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper. `order` puts the record in the curated fixture
/// series.
Anime rec(
  String id,
  String title, {
  DateTime? aired,
  DateTime? modified,
  int? order,
}) => Anime(
  id: id,
  title: title,
  firstAirDate: aired,
  seriesLink: order == null
      ? null
      : AnimeSeriesLink(seriesId: _frieren, order: order),
  createdAt: _t,
  modifiedAt: modified ?? _t,
);

List<String> labels(List<ManageSeriesGroup> g) => [for (final x in g) x.label];

void main() {
  final s1 = rec('f1', '葬送的芙莉莲', aired: DateTime(2023, 9, 29), order: 1);
  final s2 = rec(
    'f2',
    '葬送的芙莉莲 第二季',
    aired: DateTime(2026, 1, 16),
    modified: DateTime.utc(2024, 3, 1),
    order: 2,
  );
  final solo = rec('solo', 'Bocchi the Rock!', aired: DateTime(2022, 10, 9));
  final undated = rec('undated', 'Akira');
  final library = [solo, s2, undated, s1];

  test('a series is one group in series order, others are single rows', () {
    final g = groupForSeriesView(
      library,
      keep: (_) => true,
      sort: ManageSeriesSort.latest,
    );
    expect(g, hasLength(3));
    final series = g.firstWhere((x) => x.isGroup);
    expect(series.label, '葬送的芙莉莲');
    expect(series.members.map((m) => m.id), ['f1', 'f2']);
    expect(series.key, startsWith('series:'));
    expect(g.where((x) => !x.isGroup).map((x) => x.key), [
      'id:solo',
      'id:undated',
    ]);
  });

  test('newest premiere first puts undated rows last', () {
    final g = groupForSeriesView(
      library,
      keep: (_) => true,
      sort: ManageSeriesSort.latest,
    );
    expect(labels(g), ['葬送的芙莉莲', 'Bocchi the Rock!', 'Akira']);
  });

  test('title and recently edited sorts', () {
    expect(
      labels(
        groupForSeriesView(
          library,
          keep: (_) => true,
          sort: ManageSeriesSort.title,
        ),
      ),
      ['Akira', 'Bocchi the Rock!', '葬送的芙莉莲'],
    );
    expect(
      labels(
        groupForSeriesView(
          library,
          keep: (_) => true,
          sort: ManageSeriesSort.modified,
        ),
      ).first,
      '葬送的芙莉莲',
    );
  });

  test('filters narrow members but never regroup', () {
    final g = groupForSeriesView(
      library,
      keep: (a) => a.id != 'f1' && a.id != 'undated',
      sort: ManageSeriesSort.title,
    );
    // The series still exists over the whole library; with one visible
    // member it becomes a single row for that member.
    expect(g.map((x) => x.key), ['id:solo', 'id:f2']);
    expect(g.every((x) => !x.isGroup), isTrue);
  });

  test('stored strings parse with safe defaults', () {
    expect(parseManageViewMode('series'), ManageViewMode.series);
    expect(parseManageViewMode(null), ManageViewMode.quarter);
    expect(parseManageViewMode('grid'), ManageViewMode.quarter);
    expect(parseManageSeriesSort('title'), ManageSeriesSort.title);
    expect(parseManageSeriesSort('modified'), ManageSeriesSort.modified);
    expect(parseManageSeriesSort('???'), ManageSeriesSort.latest);
  });
}
