# lib/features/anime/services/series_service.dart

Series linking (1.6.0): the pure-Dart engine that groups a library into series and computes the
edits a user's curation makes. `SeriesIndex.build` groups the whole library on demand and writes
nothing; `SeriesEditor` turns each curation action into the list of records to write, which the
caller persists with `AnimeStorage.addOrUpdateAll`
([`anime_storage.md`](anime_storage.md#addorupdateall)); `NextSeasonPrefill` carries "Add next
season" to the create page. The stored field is `Anime.seriesLink`
([`../models/anime.md`](../models/anime.md#animeserieslink-new)); the season helpers come from
[`../../../shared/utils/season_label.md`](../../../shared/utils/season_label.md), and title folding
and similarity from [`anime_search_service.md`](anime_search_service.md). The UI on top is
[`../views/series_widgets.md`](../views/series_widgets.md). Concepts, rules and worked behavior are
in [`../../../../features/series-linking.md`](../../../../features/series-linking.md). Tests:
`test/series_service_test.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `SeriesEdgeKind(...)` | enum constructor (`SeriesEdgeKind`) | B | Create an edge kind with its relative `strength` (`relation` 3, `legacy` 2, `baseTitle` 1). |
| `AnimeSeries(...)` | constructor (`AnimeSeries`) | B | Create a series from its key, optional `seriesId` and ordered members; built only by `SeriesIndex.build`. |
| `isCurated` | getter (`AnimeSeries`) | B | Whether the user created this series (`seriesId != null`). |
| `indexOfId` | method (`AnimeSeries`) | B | A member's zero-based position, or `-1`. |
| `previousOf` | method (`AnimeSeries`) | B | The member before a record, or `null`; drives the previous-season button. |
| `nextOf` | method (`AnimeSeries`) | B | The member after a record, or `null`; drives the next-season button. |
| `SeriesSuggestion(...)` | constructor (`SeriesSuggestion`) | B | Create a suggestion: a record and its best base-key similarity. |
| `SeriesIndex._` | constructor (`SeriesIndex`) | B | Internal constructor from precomputed parts; use `SeriesIndex.build`. |
| [`SeriesIndex.build`](#seriesindex-build) | factory constructor | A | Group a whole library into curated and derived series. |
| [`_ordered`](#_ordered) | static method (`SeriesIndex`) | A | Order the members of one series. |
| [`seriesOf`](#seriesof) | method (`SeriesIndex`) | A | Return the series a record belongs to. |
| `animeById` | method (`SeriesIndex`) | B | Look a record up by id. |
| `all` | getter (`SeriesIndex`) | B | Every record the index was built from, in `id` order; the manage sheet searches it. |
| [`suggestionsFor`](#suggestionsfor) | method (`SeriesIndex`) | A | Offer records that may belong in the same series, never linking them. |
| [`seriesTitlesOf`](#seriestitlesof) | top-level function | A | Collect every non-empty title a record is known by. |
| [`seriesBaseKeys`](#seriesbasekeys) | top-level function | A | Compute the base keys two seasons of one work share. |
| [`seriesOrdinalOf`](#seriesordinalof) | top-level function | A | Return the season ordinal the index sorts a record by. |
| [`SeriesEditor(...)`](#serieseditor) | constructor (`SeriesEditor`) | A | Create an editor over an index, with an injectable clock and id generator. |
| `_write` | method (`SeriesEditor`) | B | Return a record with a new (or no) series link, stamped `modifiedAt = now`. |
| [`materialise`](#materialise) | method (`SeriesEditor`) | A | Give every member of a series the same curated `seriesId`. |
| [`link`](#link) | method (`SeriesEditor`) | A | Put a record into the series another record belongs to. |
| [`removeFromSeries`](#removefromseries) | method (`SeriesEditor`) | A | Take a record out of every series (`standalone`). |
| [`letAppDecide`](#letappdecide) | method (`SeriesEditor`) | A | Hand a record back to automatic grouping. |
| [`reorder`](#reorder) | method (`SeriesEditor`) | A | Reorder a series, writing a dense `order` to every member. |
| `NextSeasonPrefill(...)` | constructor (`NextSeasonPrefill`) | B | Create a prefill: copied titles, a season label, and the id to link to on save. |
| [`NextSeasonPrefill.after`](#nextseasonprefill) | factory constructor | A | Build the prefill for the season after a record. |

The `seriesSuggestionMinScore` (`0.6`) and `seriesSuggestionMinOrderedScore` (`0.5`) constants, the
`SeriesEdgeKind` values and the fields of each class carry no `/// Purpose:` comment and are not
indexed as rows.

## Documentation

### `factory SeriesIndex.build(Iterable<Anime> library)` <a id="seriesindex-build"></a>
- **Kind:** factory constructor of `SeriesIndex`
- **Source:** `lib/features/anime/services/series_service.dart` (line 145)
- **Purpose:** Group a whole library into series.
- **Inputs:** `library` — every anime record.
- **Returns:** `SeriesIndex` — every curated series (including one with a single member) and every
  derived series of at least two, sorted by key (`series:<seriesId>` or `auto:<smallest member id>`).
- **Side effects:** None; writes nothing.
- **Algorithm:**
  1. Sort the records by `id`, then precompute each record's base keys
     ([`seriesBaseKeys`](#seriesbasekeys)) and ordinal ([`seriesOrdinalOf`](#seriesordinalof)).
  2. Partition: standalone records are skipped entirely; records with a
     `seriesLink.curatedSeriesId` go into their curated series; everything else is an **auto**
     record.
  3. Index every auto and curated record by trimmed `displayTitle` and by base key in hash maps.
  4. For each auto record, add edges: **legacy** to every record with the identical `displayTitle`
     and a different trimmed `season` label; **base title** to every record sharing a base key,
     unless the pair looks like a duplicate (same ordinal, and either the same `firstAirDate` day
     or no `firstAirDate` on one side). An edge to another auto record unions the two
     (union-find, the smaller root id wins); an edge to a curated record records, per curated
     series, the strongest edge kind seen.
  5. For each auto component, take the strongest edge into each curated series. If exactly one
     curated series holds the top strength, the whole component joins it; on a tie it joins none.
  6. Components that joined nothing and have at least two members become derived series.
  7. Order every series' members with [`_ordered`](#_ordered).
- **Usage:**
  ```dart
  final index = SeriesIndex.build(data.animeList);
  final series = found == null ? null : index.seriesOf(found.id);
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, `_load`; also `anime_edit_page.dart`'s
  `_saveNew`)
- **Notes:** Deterministic — the same records in any order give the same series in the same order,
  so every device computes the same grouping from the same data. Curated series never move and never
  fuse: automatic grouping only attaches auto records, and a tie attaches nothing. The
  `SeriesEdgeKind.relation` edge (strength 3) is defined for M2's database relations but nothing adds
  one yet. The hash-map indexing keeps the build roughly linear in library size.

### `static List<Anime> _ordered(List<Anime> members, String? seriesId, Map<String, int> ordinals)` <a id="_ordered"></a>
- **Kind:** static method of `SeriesIndex`
- **Source:** `lib/features/anime/services/series_service.dart` (line 299)
- **Purpose:** Order the members of one series.
- **Inputs:** `members`; `seriesId` — the curated id, or `null` for a derived series; `ordinals` —
  precomputed season ordinals.
- **Returns:** `List<Anime>` — a sorted copy.
- **Side effects:** None.
- **Algorithm:** Members whose `seriesLink.order` belongs to *this* curated series come first,
  ascending. The rest follow by `firstAirDate` (missing sorts last), then season ordinal, then
  `createdAt`, then `id`.
- **Notes:** A mixed state (some members ordered, some not) arises only when an auto record joins a
  reordered series later; it lands at the end, where the user can move it. `Season 2` sorts before
  `Season 10` because the ordinal is numeric.

### `AnimeSeries? seriesOf(String animeId)` <a id="seriesof"></a>
- **Kind:** method of `SeriesIndex`
- **Source:** `lib/features/anime/services/series_service.dart` (line 342)
- **Purpose:** Return the series a record belongs to.
- **Returns:** `AnimeSeries?` — `null` for a standalone record or one that joined nothing.
- **Side effects:** None.
- **Notes:** A curated series with one member is still returned; the detail page shows a series
  card only when the series has at least two members.

### `List<SeriesSuggestion> suggestionsFor(String animeId, {int limit = 8})` <a id="suggestionsfor"></a>
- **Kind:** method of `SeriesIndex`
- **Source:** `lib/features/anime/services/series_service.dart` (line 367)
- **Purpose:** Offer records that may belong in the same series as `animeId`.
- **Inputs:** `animeId`; `limit` — at most this many results (default 8).
- **Returns:** `List<SeriesSuggestion>` — best score first (ties by `id`), excluding the record's own
  series and the record itself.
- **Side effects:** None.
- **Algorithm:** For every other record, compare every pair of base keys. A pair counts only when
  `AnimeSearchService.orderedSimilarity` reaches `seriesSuggestionMinOrderedScore` (0.5); the
  record's score is the best `similarityRaw` among counted pairs, and it qualifies at
  `seriesSuggestionMinScore` (0.6).
- **Usage:** The manage sheet's *Suggestions* section
  ([`../views/series_widgets.md`](../views/series_widgets.md#seriesmanagesheet)).
- **Notes:** Suggestions are never automatic links. They catch pairs a base key cannot and that
  would be wrong to link automatically — `Love Live!` finds `Love Live! Sunshine!!` this way. The
  order-aware floor stops short Latin keys that merely share letters from being offered.

### `List<String> seriesTitlesOf(Anime anime)` <a id="seriestitlesof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/services/series_service.dart` (line 406)
- **Purpose:** Collect every non-empty title a record is known by.
- **Returns:** `List<String>` — `title`, `titleJa`, `externalMeta.titleRomaji`,
  `externalMeta.titleEn`, then each `externalMeta.synonyms` entry, blanks dropped.
- **Side effects:** None.
- **Usage:** [`seriesBaseKeys`](#seriesbasekeys), [`seriesOrdinalOf`](#seriesordinalof), and the
  manage sheet's library search.

### `Set<String> seriesBaseKeys(Anime anime)` <a id="seriesbasekeys"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/services/series_service.dart` (line 434)
- **Purpose:** Compute the base keys two seasons of one work share.
- **Returns:** `Set<String>` — `AnimeSearchService.foldTitle(stripSeasonMarkers(t))` for every title
  from [`seriesTitlesOf`](#seriestitlesof), keeping keys of at least 2 Han or kana characters or at
  least 4 Latin letters or digits.
- **Side effects:** None.
- **Notes:** The length floor stops a two-letter English title from joining everything else that
  folds to the same two letters. See
  [`stripSeasonMarkers`](../../../shared/utils/season_label.md#stripseasonmarkers).

### `int seriesOrdinalOf(Anime anime)` <a id="seriesordinalof"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/services/series_service.dart` (line 453)
- **Purpose:** Return the season ordinal the series index sorts a record by.
- **Returns:** `int` — the first ordinal any title implies
  ([`titleSeasonOrdinal`](../../../shared/utils/season_label.md#titleseasonordinal)), else the one in
  the `season` label (`seasonOrdinal` after `halfWidthAscii`), else `1`.
- **Side effects:** None.
- **Notes:** Titles come first because most users never change the label from the default
  `Season 1`. An unnumbered final season reads as `finalSeasonOrdinal` (99).

### `SeriesEditor(SeriesIndex index, {DateTime? now, String Function()? newId})` <a id="serieseditor"></a>
- **Kind:** constructor of `SeriesEditor`
- **Source:** `lib/features/anime/services/series_service.dart` (line 479)
- **Purpose:** Create a series editor: pure curation operations over one index.
- **Inputs:** `index`; `now` — defaults to the current time, stored as UTC; `newId` — defaults to a
  lowercase UUID v4.
- **Returns:** A new `SeriesEditor`.
- **Side effects:** None.
- **Usage:**
  ```dart
  final writes = SeriesEditor(index).link(anime, source);
  await AnimeStorage.addOrUpdateAll(writes.isEmpty ? [anime] : writes);
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, `_saveNew`)
- **Notes:** Every operation returns the records to write and writes nothing itself; nothing is
  ever written in the background. Every returned record is stamped `modifiedAt = now` through
  `_write`, so each is an ordinary user edit to sync. `now` and `newId` are injectable for tests.

### `(String, Map<String, Anime>) materialise(AnimeSeries series)` <a id="materialise"></a>
- **Kind:** method of `SeriesEditor`
- **Source:** `lib/features/anime/services/series_service.dart` (line 502)
- **Purpose:** Give every member of a series the same curated `seriesId`.
- **Inputs:** `series`.
- **Returns:** `(String, Map<String, Anime>)` — the series id, and the records that changed keyed by
  id.
- **Side effects:** None.
- **Algorithm:** Use the series' own `seriesId`, or a fresh id for a derived series. Every member not
  already carrying that curated id gets `AnimeSeriesLink(seriesId: sid)`, keeping its link's
  `extraJson`.
- **Notes:** Called only from a user action — [`link`](#link), [`reorder`](#reorder). On a curated
  series it leaves existing members (and their `order`) alone and pins any auto records that had
  been attached to it.

### `List<Anime> link(Anime record, Anime target)` <a id="link"></a>
- **Kind:** method of `SeriesEditor`
- **Source:** `lib/features/anime/services/series_service.dart` (line 526)
- **Purpose:** Put `record` into the series `target` belongs to.
- **Inputs:** `record` — may be a new record not yet in the index; `target`.
- **Returns:** `List<Anime>` — the records to write; empty when `record` and `target` are the same.
- **Side effects:** None.
- **Algorithm:**
  1. If `target` is in a series, [`materialise`](#materialise) it; otherwise start a new curated
     series by writing a fresh id onto `target`.
  2. Write `AnimeSeriesLink(seriesId: sid)` onto `record` (keeping its link's `extraJson`) unless it
     already carries that curated id and was not part of the materialised writes.
- **Usage:** The manage sheet (tap a suggestion or search result) and `_saveNew` on the create page.
- **Notes:** `record` loses `standalone` and any `order`, so it sorts after ordered members until the
  user reorders. Auto records with edges to `record` may follow it into the series on the next
  build — visible behavior, documented in
  [`../../../../features/series-linking.md`](../../../../features/series-linking.md).

### `List<Anime> removeFromSeries(Anime record)` <a id="removefromseries"></a>
- **Kind:** method of `SeriesEditor`
- **Source:** `lib/features/anime/services/series_service.dart` (line 564)
- **Purpose:** Take a record out of every series.
- **Returns:** `List<Anime>` — the one record, now `{"standalone": true}` (its link's `extraJson`
  kept).
- **Side effects:** None.
- **Notes:** The remaining members are left alone. A standalone record gets no edges, so it neither
  joins a series nor attracts other records.

### `List<Anime> letAppDecide(Anime record)` <a id="letappdecide"></a>
- **Kind:** method of `SeriesEditor`
- **Source:** `lib/features/anime/services/series_service.dart` (line 580)
- **Purpose:** Hand a record back to automatic grouping.
- **Returns:** `List<Anime>` — empty when the record had no link; otherwise the record with its
  `seriesLink` removed.
- **Side effects:** None.
- **Notes:** Unknown fields of the old link survive as a field-empty
  `AnimeSeriesLink(extraJson: …)`, so a newer build's data is not lost.

### `List<Anime> reorder(AnimeSeries series, List<String> orderedIds)` <a id="reorder"></a>
- **Kind:** method of `SeriesEditor`
- **Source:** `lib/features/anime/services/series_service.dart` (line 596)
- **Purpose:** Reorder a series.
- **Inputs:** `series`; `orderedIds` — member ids in the new order. Ids that are not members are
  ignored; members left out keep their current relative order after the listed ones.
- **Returns:** `List<Anime>` — every member whose link changed.
- **Side effects:** None.
- **Algorithm:** [`materialise`](#materialise), then write a dense 1-based `order` to every member,
  skipping members that already hold exactly that position in this series.
- **Usage:** The manage sheet's *Save order* button.

### `factory NextSeasonPrefill.after(Anime source)` <a id="nextseasonprefill"></a>
- **Kind:** factory constructor of `NextSeasonPrefill`
- **Source:** `lib/features/anime/services/series_service.dart` (line 653)
- **Purpose:** Build the prefill for the season after `source`.
- **Inputs:** `source` — normally the last member of its series.
- **Returns:** `NextSeasonPrefill` — `source`'s `title` and `titleJa`, the next season label, and
  `linkToAnimeId = source.id`.
- **Side effects:** None.
- **Algorithm:** Compare the title ordinal ([`seriesOrdinalOf`](#seriesordinalof)) with the label's
  own `seasonOrdinal`:
  - after an unnumbered final season (ordinal 99), copy the label unchanged;
  - when they agree, [`nextSeasonLabel`](../../../shared/utils/season_label.md#nextseasonlabel)
    increments the label in its own style (`第一季` → `第二季`), falling back to
    `Season <ordinal + 1>`;
  - otherwise `Season <ordinal + 1>`, since the label is stale (typically the default `Season 1` on
    a record whose title says Season 2).
- **Usage:**
  ```dart
  await context.push('/anime/edit', extra: NextSeasonPrefill.after(last));
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, `_runSeriesAction`)
- **Notes:** The prefill travels as the route's `extra` (see
  [`../../../app/router.md`](../../../app/router.md)); the link it carries is written only when the
  new record is saved ([`../views/anime_edit_page.md`](../views/anime_edit_page.md#_savenew)).
