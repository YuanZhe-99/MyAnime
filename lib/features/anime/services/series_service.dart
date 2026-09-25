import 'package:uuid/uuid.dart';

import '../../../shared/utils/season_label.dart';
import '../models/anime.dart';
import 'anime_search_service.dart';

/// Lowest base-key similarity at which another record is offered as a series
/// suggestion. Suggestions are never automatic links.
const double seriesSuggestionMinScore = 0.6;

/// Lowest order-aware similarity a suggestion must also reach, so short Latin
/// keys that merely share letters are not offered.
const double seriesSuggestionMinOrderedScore = 0.5;

/// Why two records were placed in one derived series, strongest first.
enum SeriesEdgeKind {
  /// Database relation data names the other record (M2).
  relation(3),

  /// Identical `displayTitle` and a different season label (the pre-1.6.0
  /// prev/next rule).
  legacy(2),

  /// A shared base title once season markers are removed.
  baseTitle(1);

  /// Relative strength; a larger value beats a smaller one on a tie-break.
  final int strength;

  /// Purpose: Create a series edge kind.
  /// Inputs: `strength`.
  /// Returns: A `SeriesEdgeKind` value.
  /// Side effects: None.
  /// Notes: None.
  const SeriesEdgeKind(this.strength);
}

/// An ordered group of records that belong to one work.
class AnimeSeries {
  /// Stable in-memory key: `series:<seriesId>` for a curated series,
  /// `auto:<smallest member id>` for a derived one.
  final String key;

  /// The shared `seriesLink.seriesId`, or `null` for a derived series.
  final String? seriesId;

  /// Members in series order.
  final List<Anime> members;

  /// Purpose: Create an anime series.
  /// Inputs: `key`, `seriesId`, `members`.
  /// Returns: A new `AnimeSeries`.
  /// Side effects: None.
  /// Notes: Built by [SeriesIndex.build]; not meant to be constructed by
  /// callers.
  const AnimeSeries({
    required this.key,
    required this.seriesId,
    required this.members,
  });

  /// Purpose: Report whether the user created this series.
  /// Inputs: None.
  /// Returns: `bool` — true for a curated series.
  /// Side effects: None.
  /// Notes: None.
  bool get isCurated => seriesId != null;

  /// Purpose: Return a member's zero-based position.
  /// Inputs: `animeId`.
  /// Returns: `int` — `-1` when the record is not a member.
  /// Side effects: None.
  /// Notes: None.
  int indexOfId(String animeId) => members.indexWhere((a) => a.id == animeId);

  /// Purpose: Return the member before `animeId`.
  /// Inputs: `animeId`.
  /// Returns: `Anime?` — `null` for the first member or a non-member.
  /// Side effects: None.
  /// Notes: Drives the detail page's previous-season button.
  Anime? previousOf(String animeId) {
    final i = indexOfId(animeId);
    return i > 0 ? members[i - 1] : null;
  }

  /// Purpose: Return the member after `animeId`.
  /// Inputs: `animeId`.
  /// Returns: `Anime?` — `null` for the last member or a non-member.
  /// Side effects: None.
  /// Notes: Drives the detail page's next-season button.
  Anime? nextOf(String animeId) {
    final i = indexOfId(animeId);
    return i >= 0 && i < members.length - 1 ? members[i + 1] : null;
  }
}

/// A record offered, never applied, as a possible member of another series.
class SeriesSuggestion {
  /// The suggested record.
  final Anime anime;

  /// Best base-key similarity, `0.0..1.0`; 1.0 for a relation suggestion.
  final double score;

  /// The database relation behind the suggestion (a spin-off or an
  /// alternative), or `null` for a title-similarity suggestion.
  final AnimeRelationType? relation;

  /// Purpose: Create a series suggestion.
  /// Inputs: `anime`, `score`, `relation`.
  /// Returns: A new `SeriesSuggestion`.
  /// Side effects: None.
  /// Notes: None.
  const SeriesSuggestion(this.anime, this.score, {this.relation});
}

/// Every series in one library, computed on demand and never persisted.
///
/// The build is deterministic — the same records in any order give the same
/// series in the same order — so every device computes the same grouping from
/// the same data. Curated series are exactly what the user said; automatic
/// grouping only ever attaches records without a `seriesLink` to a series.
class SeriesIndex {
  final Map<String, AnimeSeries> _byAnimeId;
  final Map<String, Anime> _byId;
  final Map<String, Set<String>> _keysById;
  final Map<String, List<Anime>> _dbOwners;

  /// All series, curated and derived, including curated series with a
  /// single member, ordered by key.
  final List<AnimeSeries> series;

  /// Purpose: Create a series index from precomputed parts.
  /// Inputs: `series`, `byAnimeId`, `byId`, `keysById`, `dbOwners`.
  /// Returns: A new `SeriesIndex`.
  /// Side effects: None.
  /// Notes: Internal; use [SeriesIndex.build].
  SeriesIndex._(
    this.series,
    this._byAnimeId,
    this._byId,
    this._keysById,
    this._dbOwners,
  );

  /// Purpose: Group a whole library into series.
  /// Inputs: `library` — every anime record.
  /// Returns: `SeriesIndex`.
  /// Side effects: None; writes nothing.
  /// Notes: Runs union-find over records without a `seriesLink` using the
  /// edges in [SeriesEdgeKind]; a component joins a curated series only when
  /// exactly one curated series holds its strongest edge, and otherwise, with
  /// at least two members, becomes a derived series. Standalone records get
  /// no edges. Records are indexed by title and base key in hash maps, so the
  /// build is roughly linear in the library size.
  factory SeriesIndex.build(Iterable<Anime> library) {
    final records = library.toList()..sort((a, b) => a.id.compareTo(b.id));
    final byId = {for (final a in records) a.id: a};
    final keysById = {for (final a in records) a.id: seriesBaseKeys(a)};
    final ordinals = {for (final a in records) a.id: seriesOrdinalOf(a)};
    // Every record by the database pages it came from, standalone ones
    // included, for relation edges and the missing-sequel hint.
    final dbOwners = <String, List<Anime>>{};
    for (final a in records) {
      for (final k in databaseKeysOf(a)) {
        dbOwners.putIfAbsent(k, () => []).add(a);
      }
    }

    final curated = <String, List<Anime>>{};
    final autos = <Anime>[];
    for (final a in records) {
      final link = a.seriesLink;
      if (link?.standalone == true) continue;
      final sid = link?.curatedSeriesId;
      if (sid != null) {
        curated.putIfAbsent(sid, () => []).add(a);
      } else {
        autos.add(a);
      }
    }
    final curatedIdOf = {
      for (final e in curated.entries)
        for (final a in e.value) a.id: e.key,
    };

    // Index every record that can take part in grouping.
    final byTitle = <String, List<Anime>>{};
    final byKey = <String, List<Anime>>{};
    for (final a in [...autos, for (final l in curated.values) ...l]) {
      final t = a.displayTitle.trim();
      if (t.isNotEmpty) byTitle.putIfAbsent(t, () => []).add(a);
      for (final k in keysById[a.id]!) {
        byKey.putIfAbsent(k, () => []).add(a);
      }
    }

    final parent = {for (final a in autos) a.id: a.id};
    String find(String id) {
      var root = id;
      while (parent[root] != root) {
        root = parent[root]!;
      }
      var cur = id;
      while (parent[cur] != root) {
        final next = parent[cur]!;
        parent[cur] = root;
        cur = next;
      }
      return root;
    }

    void union(String a, String b) {
      final ra = find(a), rb = find(b);
      if (ra == rb) return;
      if (ra.compareTo(rb) < 0) {
        parent[rb] = ra;
      } else {
        parent[ra] = rb;
      }
    }

    // Per auto record: the strongest edge into each curated series.
    final curatedEdges = <String, Map<String, int>>{};
    void addEdge(Anime a, Anime b, SeriesEdgeKind kind) {
      if (a.id == b.id) return;
      final sid = curatedIdOf[b.id];
      if (sid == null) {
        union(a.id, b.id);
      } else {
        final m = curatedEdges.putIfAbsent(a.id, () => {});
        final prev = m[sid] ?? 0;
        if (kind.strength > prev) m[sid] = kind.strength;
      }
    }

    bool looksLikeDuplicate(Anime a, Anime b) {
      if (ordinals[a.id] != ordinals[b.id]) return false;
      final da = a.firstAirDate, db = b.firstAirDate;
      if (da == null || db == null) return true;
      return da.year == db.year && da.month == db.month && da.day == db.day;
    }

    // E1: a same-series relation in either direction. Standalone records
    // are skipped on both ends.
    for (final x in [...autos, for (final l in curated.values) ...l]) {
      for (final r
          in x.externalMeta?.relations ?? const <AnimeExternalRelation>[]) {
        if (!r.type.isSameSeries) continue;
        final k = canonicalDatabaseKey(r.targetUrl);
        if (k == null) continue;
        for (final y in dbOwners[k] ?? const <Anime>[]) {
          if (y.id == x.id || y.seriesLink?.standalone == true) continue;
          if (!curatedIdOf.containsKey(x.id)) {
            addEdge(x, y, SeriesEdgeKind.relation);
          }
          if (!curatedIdOf.containsKey(y.id)) {
            addEdge(y, x, SeriesEdgeKind.relation);
          }
        }
      }
    }

    for (final a in autos) {
      final title = a.displayTitle.trim();
      if (title.isNotEmpty) {
        for (final b in byTitle[title]!) {
          if (b.season.trim() != a.season.trim()) {
            addEdge(a, b, SeriesEdgeKind.legacy);
          }
        }
      }
      for (final k in keysById[a.id]!) {
        for (final b in byKey[k]!) {
          if (b.id != a.id && !looksLikeDuplicate(a, b)) {
            addEdge(a, b, SeriesEdgeKind.baseTitle);
          }
        }
      }
    }

    // Collect components, then attach each to at most one curated series.
    final components = <String, List<Anime>>{};
    for (final a in autos) {
      components.putIfAbsent(find(a.id), () => []).add(a);
    }
    final derived = <List<Anime>>[];
    for (final component in components.values) {
      final best = <String, int>{};
      for (final a in component) {
        for (final e in (curatedEdges[a.id] ?? const <String, int>{}).entries) {
          if (e.value > (best[e.key] ?? 0)) best[e.key] = e.value;
        }
      }
      if (best.isNotEmpty) {
        final top = best.values.reduce((x, y) => x > y ? x : y);
        final winners = [
          for (final e in best.entries)
            if (e.value == top) e.key,
        ];
        if (winners.length == 1) {
          curated[winners.single]!.addAll(component);
          continue;
        }
      }
      if (component.length >= 2) derived.add(component);
    }

    final series = <AnimeSeries>[
      for (final e in curated.entries)
        AnimeSeries(
          key: 'series:${e.key}',
          seriesId: e.key,
          members: _ordered(e.value, e.key, ordinals),
        ),
      for (final members in derived)
        AnimeSeries(
          key: 'auto:${members.first.id}',
          seriesId: null,
          members: _ordered(members, null, ordinals),
        ),
    ]..sort((a, b) => a.key.compareTo(b.key));

    final byAnimeId = {
      for (final s in series)
        for (final a in s.members) a.id: s,
    };
    return SeriesIndex._(series, byAnimeId, byId, keysById, dbOwners);
  }

  /// Purpose: Order the members of one series.
  /// Inputs: `members`, `seriesId` — the curated id, or `null`; `ordinals`.
  /// Returns: `List<Anime>` — members with an explicit `order` in this series
  /// first, ascending, then the rest by `firstAirDate` (missing last), season
  /// ordinal, `createdAt` and `id`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static List<Anime> _ordered(
    List<Anime> members,
    String? seriesId,
    Map<String, int> ordinals,
  ) {
    int? orderOf(Anime a) =>
        seriesId != null && a.seriesLink?.curatedSeriesId == seriesId
        ? a.seriesLink?.order
        : null;

    int derived(Anime a, Anime b) {
      final da = a.firstAirDate, db = b.firstAirDate;
      if (da != null && db != null) {
        final c = da.compareTo(db);
        if (c != 0) return c;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      final c = ordinals[a.id]!.compareTo(ordinals[b.id]!);
      if (c != 0) return c;
      final t = a.createdAt.compareTo(b.createdAt);
      if (t != 0) return t;
      return a.id.compareTo(b.id);
    }

    return [...members]..sort((a, b) {
      final oa = orderOf(a), ob = orderOf(b);
      if (oa != null && ob != null && oa != ob) return oa.compareTo(ob);
      if (oa != null && ob == null) return -1;
      if (oa == null && ob != null) return 1;
      return derived(a, b);
    });
  }

  /// Purpose: Return the series a record belongs to.
  /// Inputs: `animeId`.
  /// Returns: `AnimeSeries?` — `null` for a standalone record or one that
  /// joined nothing.
  /// Side effects: None.
  /// Notes: A curated series with one member is still returned; the UI shows
  /// a series only when it has at least two members.
  AnimeSeries? seriesOf(String animeId) => _byAnimeId[animeId];

  /// Purpose: Look a record up by id.
  /// Inputs: `animeId`.
  /// Returns: `Anime?`.
  /// Side effects: None.
  /// Notes: None.
  Anime? animeById(String animeId) => _byId[animeId];

  /// Purpose: List every record the index was built from.
  /// Inputs: None.
  /// Returns: `Iterable<Anime>` — in `id` order.
  /// Side effects: None.
  /// Notes: Lets the manage sheet search the library without reloading it.
  Iterable<Anime> get all => _byId.values;

  /// Purpose: Offer records that may belong in the same series as `animeId`.
  /// Inputs: `animeId`; `limit`.
  /// Returns: `List<SeriesSuggestion>` — best first, excluding the record's
  /// own series.
  /// Side effects: None.
  /// Notes: A record qualifies when some pair of base keys reaches
  /// [seriesSuggestionMinScore] under `AnimeSearchService.similarityRaw` and
  /// [seriesSuggestionMinOrderedScore] under `orderedSimilarity`. This is how
  /// `Love Live!` finds `Love Live! Sunshine!!` without being linked to it.
  /// Records a database lists as a spin-off or an alternative of this one, in
  /// either direction, come first with score 1.0 and their relation type.
  List<SeriesSuggestion> suggestionsFor(String animeId, {int limit = 8}) {
    final self = _byId[animeId];
    if (self == null) return const [];
    final own = _keysById[animeId] ?? const <String>{};
    final sameSeries = {
      for (final a in seriesOf(animeId)?.members ?? const <Anime>[]) a.id,
      animeId,
    };
    final out = <SeriesSuggestion>[];
    final related = <String, AnimeRelationType>{};
    void relate(Anime to, AnimeRelationType type) {
      if (!sameSeries.contains(to.id)) related.putIfAbsent(to.id, () => type);
    }

    final selfKeys = databaseKeysOf(self);
    for (final r
        in self.externalMeta?.relations ?? const <AnimeExternalRelation>[]) {
      if (r.type != AnimeRelationType.spinOff &&
          r.type != AnimeRelationType.alternative) {
        continue;
      }
      final k = canonicalDatabaseKey(r.targetUrl);
      for (final y in _dbOwners[k] ?? const <Anime>[]) {
        relate(y, r.type);
      }
    }
    for (final y in _byId.values) {
      for (final r
          in y.externalMeta?.relations ?? const <AnimeExternalRelation>[]) {
        if ((r.type == AnimeRelationType.spinOff ||
                r.type == AnimeRelationType.alternative) &&
            selfKeys.contains(canonicalDatabaseKey(r.targetUrl))) {
          relate(y, r.type);
        }
      }
    }
    for (final e in related.entries) {
      out.add(SeriesSuggestion(_byId[e.key]!, 1.0, relation: e.value));
    }

    for (final e in _keysById.entries) {
      if (sameSeries.contains(e.key) || related.containsKey(e.key)) continue;
      var best = 0.0;
      for (final a in own) {
        for (final b in e.value) {
          if (AnimeSearchService.orderedSimilarity(a, b) <
              seriesSuggestionMinOrderedScore) {
            continue;
          }
          final s = AnimeSearchService.similarityRaw(a, b);
          if (s > best) best = s;
        }
      }
      if (best >= seriesSuggestionMinScore) {
        out.add(SeriesSuggestion(_byId[e.key]!, best));
      }
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : a.anime.id.compareTo(b.anime.id);
    });
    return out.length > limit ? out.sublist(0, limit) : out;
  }

  /// Purpose: Find a sequel the databases list that is not in the library.
  /// Inputs: `animeId`.
  /// Returns: `AnimeExternalRelation?` — the first `sequel` relation of the
  /// last member of the record's series (or of the record itself when it is
  /// in none) whose target page no record came from.
  /// Side effects: None.
  /// Notes: Drives the "Next: <title>" hint. The relation data may reach a
  /// store build through sync; only the online lookup behind the hint is
  /// gated on `AppFlavor.isFull`.
  AnimeExternalRelation? missingSequelFor(String animeId) {
    final series = seriesOf(animeId);
    final last = series != null && series.members.length >= 2
        ? series.members.last
        : _byId[animeId];
    if (last == null) return null;
    for (final r
        in last.externalMeta?.relations ?? const <AnimeExternalRelation>[]) {
      if (r.type != AnimeRelationType.sequel) continue;
      final k = canonicalDatabaseKey(r.targetUrl);
      if (k == null || _dbOwners.containsKey(k)) continue;
      return r;
    }
    return null;
  }
}

final _anilistPage = RegExp(r'anilist\.co/anime/(\d+)');
final _malPage = RegExp(r'myanimelist\.net/anime/(\d+)');
final _bangumiPage = RegExp(r'(?:bgm\.tv|bangumi\.tv|chii\.in)/subject/(\d+)');

/// Purpose: Reduce a database page URL to a canonical key.
/// Inputs: `url`.
/// Returns: `String?` — `anilist:<id>`, `mal:<id>` or `bgm:<id>` (bgm.tv,
/// bangumi.tv and chii.in are one site); `null` for anything else.
/// Side effects: None.
/// Notes: Lets a relation's `targetUrl` match a record's `infoUrl` or rating
/// `sourceUrl` whatever host alias or trailing slug either one uses.
String? canonicalDatabaseKey(String? url) {
  if (url == null) return null;
  final a = _anilistPage.firstMatch(url);
  if (a != null) return 'anilist:${a.group(1)}';
  final m = _malPage.firstMatch(url);
  if (m != null) return 'mal:${m.group(1)}';
  final b = _bangumiPage.firstMatch(url);
  if (b != null) return 'bgm:${b.group(1)}';
  return null;
}

/// Purpose: Collect the database pages a record came from.
/// Inputs: `anime`.
/// Returns: `Set<String>` — canonical keys of `infoUrl` and every
/// `externalMeta.ratings[].sourceUrl`.
/// Side effects: None.
/// Notes: What a relation's target is matched against.
Set<String> databaseKeysOf(Anime anime) => {
  for (final url in [
    anime.infoUrl,
    for (final r
        in anime.externalMeta?.ratings ?? const <AnimeExternalRating>[])
      r.sourceUrl,
  ])
    ?canonicalDatabaseKey(url),
};

/// Purpose: Collect every non-empty title a record is known by.
/// Inputs: `anime`.
/// Returns: `List<String>` — `title`, `titleJa`, the romaji and English
/// titles, then each synonym.
/// Side effects: None.
/// Notes: None.
List<String> seriesTitlesOf(Anime anime) {
  final meta = anime.externalMeta;
  return [
    for (final t in [
      anime.title,
      anime.titleJa,
      meta?.titleRomaji,
      meta?.titleEn,
      ...?meta?.synonyms,
    ])
      if (t != null && t.trim().isNotEmpty) t,
  ];
}

final _hanOrKana = RegExp(
  r'[\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}]',
  unicode: true,
);
final _latinOrDigit = RegExp(r'[a-z0-9]');

/// Purpose: Compute the base keys two seasons of one work share.
/// Inputs: `anime`.
/// Returns: `Set<String>` — `AnimeSearchService.foldTitle(stripSeasonMarkers(t))`
/// for every title, keeping keys of at least 2 Han or kana characters or at
/// least 4 Latin letters or digits.
/// Side effects: None.
/// Notes: The length floor stops a two-letter English title from joining
/// everything else that folds to the same two letters.
Set<String> seriesBaseKeys(Anime anime) {
  final out = <String>{};
  for (final t in seriesTitlesOf(anime)) {
    final key = AnimeSearchService.foldTitle(stripSeasonMarkers(t));
    if (key.isEmpty) continue;
    final cjk = _hanOrKana.allMatches(key).length;
    final latin = _latinOrDigit.allMatches(key).length;
    if (cjk >= 2 || latin >= 4) out.add(key);
  }
  return out;
}

/// Purpose: Return the season ordinal the series index sorts a record by.
/// Inputs: `anime`.
/// Returns: `int` — the first ordinal any title implies
/// ([titleSeasonOrdinal]), else the one in the `season` label, else 1.
/// Side effects: None.
/// Notes: Titles come first because most users never change the label from
/// the default `Season 1`.
int seriesOrdinalOf(Anime anime) {
  for (final t in seriesTitlesOf(anime)) {
    final o = titleSeasonOrdinal(t);
    if (o != null) return o;
  }
  return seasonOrdinal(halfWidthAscii(anime.season)) ?? 1;
}

/// Purpose: Work out the season label a record should carry, when its own
/// label is still the default.
/// Inputs: `anime`.
/// Returns: `String?` — `Season N` from the season its titles name
/// ([seasonLabelFromTitles] over [seriesTitlesOf]); `null` when the label was
/// typed by the user, the titles name no season past the first, or the
/// derived label equals the current one.
/// Side effects: None.
/// Notes: Titles only, never the position in a series: an arc name such as
/// `遊郭編` says nothing about which season it is.
String? derivedSeasonLabel(Anime anime) {
  if (!isDefaultSeasonLabel(anime.season)) return null;
  final label = seasonLabelFromTitles(seriesTitlesOf(anime));
  return label == null || label == anime.season ? null : label;
}

/// Purpose: List the records whose default season label should be replaced.
/// Inputs: `records`.
/// Returns: `Map<String, String>` — record id to its new label; empty when
/// nothing needs changing.
/// Side effects: None.
/// Notes: The caller writes these with `AnimeStorage.patchSeasonLabels`, which
/// keeps `modifiedAt` so two devices correcting the same record never make a
/// sync conflict.
Map<String, String> seasonLabelFixups(Iterable<Anime> records) => {
  for (final a in records) a.id: ?derivedSeasonLabel(a),
};

/// Pure series-curation operations. Each returns the records to write; the
/// caller persists them with `AnimeStorage.addOrUpdateAll`, and nothing is
/// written in the background.
class SeriesEditor {
  /// The index the edits are computed against.
  final SeriesIndex index;

  /// UTC timestamp stamped on every written record.
  final DateTime now;

  final String Function() _newId;

  /// Purpose: Create a series editor.
  /// Inputs: `index`; `now` — defaults to the current UTC time; `newId` —
  /// defaults to a lowercase UUID v4.
  /// Returns: A new `SeriesEditor`.
  /// Side effects: None.
  /// Notes: `now` and `newId` are injectable for tests.
  SeriesEditor(this.index, {DateTime? now, String Function()? newId})
    : now = (now ?? DateTime.now()).toUtc(),
      _newId = newId ?? (() => const Uuid().v4());

  /// Purpose: Return a record with a new series link, stamped as a user edit.
  /// Inputs: `anime`, `link` — `null` removes the link.
  /// Returns: `Anime`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Anime _write(Anime anime, AnimeSeriesLink? link) => anime.copyWith(
    seriesLink: link,
    clearSeriesLink: link == null,
    modifiedAt: now,
  );

  /// Purpose: Give every member of a series the same curated `seriesId`.
  /// Inputs: `series`.
  /// Returns: `(String, Map<String, Anime>)` — the series id and the records
  /// that changed, keyed by id.
  /// Side effects: None.
  /// Notes: A derived series gets a new id; a curated one keeps its id and
  /// pins any auto records that were attached to it. Only called from a user
  /// action — nothing is materialised in the background.
  (String, Map<String, Anime>) materialise(AnimeSeries series) {
    final sid = series.seriesId ?? _newId();
    final writes = <String, Anime>{};
    for (final a in series.members) {
      if (a.seriesLink?.curatedSeriesId == sid) continue;
      writes[a.id] = _write(
        a,
        AnimeSeriesLink(
          seriesId: sid,
          extraJson: a.seriesLink?.extraJson ?? const {},
        ),
      );
    }
    return (sid, writes);
  }

  /// Purpose: Put `record` into the series `target` belongs to.
  /// Inputs: `record` — may be a new record not yet in the index; `target`.
  /// Returns: `List<Anime>` — the records to write.
  /// Side effects: None.
  /// Notes: The target's series is materialised first; a target in no series
  /// starts a new curated series with itself. `record` loses `standalone` and
  /// any `order`, so it sorts after ordered members until the user reorders.
  /// Auto records with edges to `record` may follow it on the next build.
  List<Anime> link(Anime record, Anime target) {
    if (record.id == target.id) return const [];
    final targetSeries = index.seriesOf(target.id);
    final String sid;
    final writes = <String, Anime>{};
    if (targetSeries != null) {
      final (id, w) = materialise(targetSeries);
      sid = id;
      writes.addAll(w);
    } else {
      sid = _newId();
      writes[target.id] = _write(
        target,
        AnimeSeriesLink(
          seriesId: sid,
          extraJson: target.seriesLink?.extraJson ?? const {},
        ),
      );
    }
    final current = writes[record.id] ?? record;
    final link = current.seriesLink;
    if (link == null ||
        link.curatedSeriesId != sid ||
        link.standalone ||
        writes.containsKey(record.id)) {
      writes[record.id] = _write(
        current,
        AnimeSeriesLink(seriesId: sid, extraJson: link?.extraJson ?? const {}),
      );
    }
    return writes.values.toList();
  }

  /// Purpose: Take a record out of every series.
  /// Inputs: `record`.
  /// Returns: `List<Anime>` — the one record, now `{"standalone": true}`.
  /// Side effects: None.
  /// Notes: The remaining members are left alone.
  List<Anime> removeFromSeries(Anime record) => [
    _write(
      record,
      AnimeSeriesLink(
        standalone: true,
        extraJson: record.seriesLink?.extraJson ?? const {},
      ),
    ),
  ];

  /// Purpose: Hand a record back to automatic grouping.
  /// Inputs: `record`.
  /// Returns: `List<Anime>` — empty when it already had no link.
  /// Side effects: None.
  /// Notes: Unknown fields of the old link are kept, so a newer build's data
  /// survives.
  List<Anime> letAppDecide(Anime record) {
    final link = record.seriesLink;
    if (link == null) return const [];
    final extra = link.extraJson;
    return [
      _write(record, extra.isEmpty ? null : AnimeSeriesLink(extraJson: extra)),
    ];
  }

  /// Purpose: Reorder a series.
  /// Inputs: `series`; `orderedIds` — member ids in the new order; members
  /// left out keep their current relative order after the listed ones.
  /// Returns: `List<Anime>` — every member whose link changed.
  /// Side effects: None.
  /// Notes: Materialises, then writes a dense 1-based `order` to every
  /// member.
  List<Anime> reorder(AnimeSeries series, List<String> orderedIds) {
    final (sid, writes) = materialise(series);
    final ids = [
      for (final id in orderedIds)
        if (series.indexOfId(id) >= 0) id,
    ];
    for (final a in series.members) {
      if (!ids.contains(a.id)) ids.add(a.id);
    }
    for (var i = 0; i < ids.length; i++) {
      final member = writes[ids[i]] ?? series.members[series.indexOfId(ids[i])];
      final link = member.seriesLink!;
      if (link.order == i + 1 && link.curatedSeriesId == sid) continue;
      writes[member.id] = _write(
        member,
        AnimeSeriesLink(seriesId: sid, order: i + 1, extraJson: link.extraJson),
      );
    }
    return writes.values.toList();
  }
}

/// What "Add next season" hands the create page: copied titles, the next
/// season label and the record the new one is linked to on save.
class NextSeasonPrefill {
  /// Copied `title`.
  final String? title;

  /// Copied `titleJa`.
  final String? titleJa;

  /// The incremented season label.
  final String season;

  /// Id of the record the new one joins when it is saved.
  final String linkToAnimeId;

  /// Whether the create page should start the online search on load (the
  /// missing-sequel hint). Honoured only in full builds.
  final bool autoSearch;

  /// Purpose: Create a next-season prefill.
  /// Inputs: `title`, `titleJa`, `season`, `linkToAnimeId`, `autoSearch`.
  /// Returns: A new `NextSeasonPrefill`.
  /// Side effects: None.
  /// Notes: Passed as the `extra` of `/anime/edit`.
  const NextSeasonPrefill({
    this.title,
    this.titleJa,
    required this.season,
    required this.linkToAnimeId,
    this.autoSearch = false,
  });

  /// Purpose: Build the prefill for the season after `source`.
  /// Inputs: `source` — normally the last member of its series.
  /// Returns: `NextSeasonPrefill`.
  /// Side effects: None.
  /// Notes: The label is incremented wherever [nextSeasonLabel] can read it
  /// and it agrees with the ordinal the titles imply; otherwise it becomes
  /// `Season <ordinal + 1>`. After an unnumbered final season the label is
  /// copied unchanged.
  factory NextSeasonPrefill.after(Anime source) {
    final ordinal = seriesOrdinalOf(source);
    final labelOrdinal = seasonOrdinal(halfWidthAscii(source.season));
    final String label;
    if (ordinal == finalSeasonOrdinal) {
      label = source.season;
    } else if (labelOrdinal == ordinal) {
      label = nextSeasonLabel(source.season) ?? 'Season ${ordinal + 1}';
    } else {
      label = 'Season ${ordinal + 1}';
    }
    return NextSeasonPrefill(
      title: source.title,
      titleJa: source.titleJa,
      season: label,
      linkToAnimeId: source.id,
    );
  }

  /// Purpose: Build the prefill for a sequel the databases list but the
  /// library lacks.
  /// Inputs: `source` — the member the relation came from; `relation`.
  /// Returns: `NextSeasonPrefill` — the relation's title, the next season
  /// label, a link to `source`, and `autoSearch` on.
  /// Side effects: None.
  /// Notes: A store build gets the title pre-filled and no search, because
  /// the create page checks `AppFlavor.isFull` before searching.
  factory NextSeasonPrefill.fromRelation(
    Anime source,
    AnimeExternalRelation relation,
  ) {
    final base = NextSeasonPrefill.after(source);
    return NextSeasonPrefill(
      title: relation.title ?? base.title,
      season: base.season,
      linkToAnimeId: source.id,
      autoSearch: true,
    );
  }
}
