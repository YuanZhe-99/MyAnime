# Series Linking

Since 1.6.0 the app groups a work's seasons, split cours, films and OVAs into a **series**. The
detail page shows the series as a card, prev/next-season navigation follows the series order, and
the user can correct the grouping. The engine is
[`functions/features/anime/services/series_service.md`](../functions/features/anime/services/series_service.md),
the UI is [`functions/features/anime/views/series_widgets.md`](../functions/features/anime/views/series_widgets.md),
and the stored field is `seriesLink` ([`../data-formats.md`](../data-formats.md)).

Before 1.6.0 the detail page found the "previous" and "next" season as records with an identical
`displayTitle` and a different `season` label, ordered by plain string comparison. `Season 10`
sorted before `Season 2`, a sequel whose title differed at all was never found (`进击的巨人` against
`进击的巨人 第二季`, or a Japanese title on one season and a Chinese one on the next), and nothing
could be corrected.

## Concepts

| Term | Meaning |
|---|---|
| **Series** | An ordered group of records that belong to one work. |
| **Curated series** | Records sharing a `seriesLink.seriesId` created by a user action. Membership is exactly what the user said. |
| **Derived series** | A group the app computed from titles. Nothing about it is stored; it is keyed in memory as `auto:<smallest member id>`. |
| **Auto record** | A record without a `seriesLink`. The app may place it in a derived or a curated series. |
| **Standalone record** | `seriesLink.standalone == true`: the user took it out of every series. It never joins a series, and nothing joins it. |

Curated series are fixed. Automatic grouping never moves a curated record and never merges two
curated series; it can only attach **auto** records to a series.

## The `seriesLink` field

```json
"seriesLink": { "seriesId": "0b5d0c1e-7f59-4f3e-9d5e-2a1c1b9e8f00", "order": 2 }
```

```json
"seriesLink": { "standalone": true }
```

Membership is a shared group id rather than prev/next pointers, so no record references another
record's `id`. Deleting, merging or importing a record cannot leave a dangling pointer, and linking
A to B never requires a second write to B. The object is omitted when empty, so a 1.5.7 library gets
derived series the first time a detail page opens and nothing is written. Field rules and the
travel table are in [`../data-formats.md`](../data-formats.md).

## Automatic grouping

`SeriesIndex.build` groups the whole library whenever the detail page loads. It writes nothing.

**Titles.** A record's titles are `title`, `titleJa`, `externalMeta.titleRomaji`,
`externalMeta.titleEn` and each synonym. Its **base keys** are those titles with season markers
removed (`stripSeasonMarkers`: 第N季 / 第N期, `Season N`, `2nd Season`, `S2`, `Part N`, `Cour N`,
`The Final Season`, 最终季 / 完結編, 続編, a trailing II–IV, after making full-width characters
half-width) and then folded (`AnimeSearchService.foldTitle`). Keys shorter than 2 Han or kana
characters, or 4 Latin letters or digits, are dropped.

**Ordinals.** A record's season ordinal is read from its titles when any title carries one, else
from its `season` label, else it is 1 — titles first, because most users never change the default
`Season 1` label. An unnumbered final-season marker reads as 99 (`finalSeasonOrdinal`), so it sorts
after every numbered season. See [`../functions/shared/utils/season_label.md`](../functions/shared/utils/season_label.md).

**Edges**, strongest first. An edge joins an auto record to another auto record or to a curated
record; standalone records get none.

| Edge | Strength | Condition |
|---|---|---|
| E1 relation | 3 | One record's database relations name the other. **Not active yet:** the kind is defined, but relation metadata arrives with a later milestone (M2) and nothing adds this edge in 1.6.0. |
| E2 legacy | 2 | Identical `displayTitle` and a different trimmed `season` label — the pre-1.6.0 rule, kept so nothing linked before stops being linked. |
| E3 base title | 1 | The two records share a base key, **unless** they look like duplicates rather than seasons: the same season ordinal, and either the same `firstAirDate` day or no `firstAirDate` on one side. Duplicates are [`duplicate-detection.md`](duplicate-detection.md)'s job. |

**Grouping.**

1. Partition the library into curated series (by `seriesId`), standalone records and auto records,
   processing records in `id` order.
2. Union-find over the auto records, using the edges between auto records, gives a set of auto
   components.
3. For each component, keep the strongest edge into each curated series. If exactly one curated
   series holds the strongest edge, the whole component joins it. **On a tie it joins none**, because
   ambiguity must never fuse two user-curated series.
4. Components that joined nothing and have at least two members become derived series.

The result is deterministic: the same records in any order give the same series, so every device
computes the same grouping from the same data. Records are indexed by title and base key in hash
maps, so the build is roughly linear in library size.

**Order within a series.** Members with an `order` in that series come first, ascending. The rest
follow by `firstAirDate` (missing sorts last), then season ordinal, then `createdAt`, then `id`.
Reordering writes a dense `order` to every member, so a mixed state arises only when an auto record
joins afterwards; it lands at the end, where the user can move it.

## Suggestions

The manage sheet also offers **suggestions**, which are never automatic links: records outside the
series where some pair of base keys reaches 0.6 under `AnimeSearchService.similarityRaw` **and** 0.5
under the order-aware `orderedSimilarity`, best first, at most eight. They catch pairs a base key
cannot and that would be wrong to link automatically — `Love Live!` against `Love Live! Sunshine!!`,
or arc subtitles such as `鬼灭之刃 游郭篇`. (Relation-based suggestions arrive with M2.)

## Manual curation

Every action is a pure `SeriesEditor` operation that returns the records to write; the caller
persists them with `AnimeStorage.addOrUpdateAll` — one load, one save, one auto-sync notification.
Every written record gets a fresh UTC `modifiedAt`, because each is a user edit.

- **Materialise on the first edit.** Any manual action on a derived series first gives every current
  member the same new `seriesId`. Nothing is ever materialised without a user action.
- **Link to series…** — in the manage sheet, the user taps a suggestion or searches the library and
  taps a record. The current record takes that record's `seriesId`, materialising its series first
  if it is derived (or starting a new curated series with it if it is in none). A standalone record
  loses `standalone`, and the linked record loses any `order`, so it sorts after the ordered members.
- **Remove from series** — writes `{"standalone": true}`. The remaining members are left alone.
- **Reorder** — drag the members in the manage sheet, then *Save order*: materialise, then write a
  dense `order` (1, 2, 3…) to every member.
- **Let the app decide** — removes `seriesLink` from this record (unknown fields of the old link
  survive). Offered only when the record has a link to remove.
- **Add next season** — opens the create page (`/anime/edit`, `extra: NextSeasonPrefill`) with the
  last member's titles copied, the season label incremented wherever it can be read
  (`Season 1` → `Season 2`, `第一季` → `第二季`, `2nd Season` → `3rd Season`; `Season <n + 1>` when
  the label disagrees with the titles), and a pending link. The link is written only when the new
  record is saved, together with the materialised series, in one `addOrUpdateAll`.

**Auto records may follow a moved record.** Linking only writes the records it names, but the next
build still runs automatic grouping. An auto record with an edge to the record you just moved —
for example another season sharing its base title — may therefore follow it into the new series.
If that is wrong, open that record and use *Remove from series* or link it where it belongs.

## UI

- **Series card.** The detail page's prev/next row became a *Series* card in `_buildDetailChildren`
  — the same place, so in the two-pane layout it lands in the right pane. It appears when the
  record's series has at least two members, lists them in order (position, title, season label,
  watched/total, status icon), highlights the current one, opens a member on tap, and says whether
  the series is *Linked by you* or *Grouped automatically*. Its menu holds *Manage series…*, *Add
  next season*, *Remove from series* and, when applicable, *Let the app decide*. The prev/next
  buttons stay below it, now driven by the series order, in a `Wrap` so they stack on a narrow phone.
- **App-bar link menu.** When the record belongs to no series — including a standalone one — the
  card is absent and a link icon in the app bar offers *Link to series…*, *Add next season* and,
  when the record carries a `seriesLink`, *Let the app decide*.
- **Manage sheet.** A search field, the suggestions, and the members with drag handles. It is a
  bottom sheet on a narrow window and a dialog on a wide one, chosen by `canSplitLayout` — no new
  breakpoint; see [`../adaptive-layout.md`](../adaptive-layout.md).

See [`../functions/features/anime/views/anime_detail_page.md`](../functions/features/anime/views/anime_detail_page.md)
for the detail page's layout.

## Interactions

- **Sync.** `seriesLink` rides the ordinary whole-record merge. Materialising writes several
  records, each an ordinary user edit, so a concurrent edit of one of them on another device becomes
  an ordinary conflict. The conflict dialog adds a series line per side when the two sides'
  `seriesLink` differ, so a conflict about the series alone does not look like two identical
  versions. See [`../sync.md`](../sync.md).
- **Share and import.** `.myanimeitem` export strips `seriesLink`, and import drops it even from a
  hand-written file. See [`share-and-import.md`](share-and-import.md).
- **Duplicate merge.** The primary's `seriesLink` wins, else the first fallback's. Members of a series
  with different season labels are not duplicates. See [`duplicate-detection.md`](duplicate-detection.md).
- **Deleting a record** needs no special handling: the group id lives on the survivors.
- **Local API.** Unchanged; its record projection does not include series data.

## Possible follow-up

Grouping the Manage list by series — one row per series that expands into its members — is not
part of 1.6.0. The index would support it; the list layout does not yet.

## Tests

`test/series_service_test.dart` covers the grouping over a realistic fixture library (including the
cases that must **not** link automatically, such as `Fate/Zero` and `Fate/stay night`), curated
series never fusing, ties attaching nothing, standalone records, ordering, identical output for
shuffled input, and every `SeriesEditor` operation. `test/series_card_ui_test.dart` covers the card
in both detail layouts; `test/anime_json_test.dart`, `test/bundle_import_test.dart` and
`test/duplicate_service_test.dart` cover the field, the share strip and drop, and the merge.
