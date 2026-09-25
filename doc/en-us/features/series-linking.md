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
| **Derived series** | A group the app computed from titles and database relations. Nothing about it is stored; it is keyed in memory as `auto:<smallest member id>`. |
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

**Season labels follow the titles (1.6.1).** Ordinals decide the order, but through 1.6.0 the
`season` label itself was never updated, so `葬送的芙莉莲 第二季` still read `Season 1` on the card
and the detail chip. Now, when a record's label is still the default (`Season 1` or empty, ignoring
case and width — `isDefaultSeasonLabel`), it is replaced with `Season N` taken from the first title
that names a season (`seasonLabelFromTitles` over `seriesTitlesOf`; `derivedSeasonLabel`):

- Split-cour markers (`Part 2`, `Cour 2`, `第2クール`) are removed first, so
  `進撃の巨人 The Final Season Part 2` is not read as season 2. An unnumbered final season, a
  season-1 marker, or no marker at all leaves the label alone.
- Only titles count, never the position in a series, because an arc name such as `遊郭編` says
  nothing about which season it is.
- A label the user typed — `S2`, `第二季`, anything but the default — is never replaced.

Where it runs:
- **Stored records** — Home, Manage and the detail page load through
  `AnimeStorage.loadFixingSeasonLabels(seasonLabelFixups)`, which writes the corrected labels with
  `patchSeasonLabels`. Like `patchExternalMeta` it **keeps `modifiedAt`**. Every device on 1.6.1 or
  later derives the same label, so no sync conflict appears, and a newer edit from another device
  simply wins and is corrected again on the next load. `patchSeasonLabels` re-reads the file and
  skips a record whose label is no longer the default.
- **The edit page** — the season field follows the title fields and applied external-metadata
  titles while it still shows the default or the label it derived itself. Typing anything else stops
  it, and it never touches the "Add next season" prefill.

**Edges**, strongest first. An edge joins an auto record to another auto record or to a curated
record; standalone records get none.

| Edge | Strength | Condition |
|---|---|---|
| E1 relation | 3 | One record's `externalMeta.relations` names the other through a same-series relation — `prequel`, `sequel`, `parent`, `sideStory` or `summary` — in either direction. See [Database relations](#database-relations). |
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
computes the same grouping from the same data. Records are indexed by title, base key and database
key in hash maps, so the build is roughly linear in library size.

**Order within a series.** Members with an `order` in that series come first, ascending. The rest
follow by `firstAirDate` (missing sorts last), then season ordinal, then `createdAt`, then `id`.
Reordering writes a dense `order` to every member, so a mixed state arises only when an auto record
joins afterwards; it lands at the end, where the user can move it.

## Suggestions

The manage sheet also offers **suggestions**, which are never automatic links: records outside the
series where some pair of base keys reaches 0.6 under `AnimeSearchService.similarityRaw` **and** 0.5
under the order-aware `orderedSimilarity`, best first, at most eight. They catch pairs a base key
cannot and that would be wrong to link automatically — `Love Live!` against `Love Live! Sunshine!!`,
or arc subtitles such as `鬼灭之刃 游郭篇`.

**Relation suggestions** come first: records a database lists as a `spinOff` or an `alternative` of
this one, or that list this one so, in either direction. They score 1.0, and their row's subtitle
appends *Spin-off* or *Alternative version* to the season label. A spin-off shares a world but is
not the same series, so it is offered and never linked.

## Database relations

Since 1.6.0 (M2), a refresh stores the related works each database lists in
`externalMeta.relations` — see [`../data-formats.md`](../data-formats.md) for the shape and
[`multi-source-search.md`](multi-source-search.md) for where they come from. Titles alone cannot
link a first season recorded under its Japanese title to a sequel recorded under its Chinese one;
the databases know the answer.

**Matching.** A relation's `targetUrl` and a record's pages are reduced to **canonical keys** by
`canonicalDatabaseKey`: `anilist:<id>` for `anilist.co/anime/<id>`, `mal:<id>` for
`myanimelist.net/anime/<id>`, and `bgm:<id>` for `/subject/<id>` on bgm.tv, bangumi.tv or chii.in —
the three bangumi hosts count as one site. A record's keys are those of its `infoUrl` and of every
`externalMeta.ratings[].sourceUrl`. A relation names a record when its key is one of the record's
keys, whatever scheme, host alias or trailing slug either URL uses.

**What each type does.**

| Relation type | Effect |
|---|---|
| `prequel`, `sequel`, `parent`, `sideStory`, `summary` | E1 edge (strength 3), in either direction |
| `spinOff`, `alternative` | Suggestion only, tagged in the manage sheet |
| `other` | Nothing |

A relation only needs to be listed on one side: a sequel that has never been refreshed is still
linked by its prequel's `sequel` relation. Standalone records get no relation edges on either end,
and curated series still never move — a relation edge only attaches auto records, like every other
edge.

**Missing-sequel hint.** When the last member of a record's series (or the record itself, when it
is in no series) lists a `sequel` whose page no record in the library came from, the detail page
shows a card directly above the series card: **Next: <title> (<source>)**, for example
`Next: 葬送のフリーレン 第2期 (AniList)`, with the hint *Listed by the database but not in your
library. Tap to add it.* Tapping it opens the create page through the same `extra` prefill as *Add
next season* (`NextSeasonPrefill.fromRelation`): the relation's title, the next season label, and a
pending link to that last member, written only on save. In a **full** build the create page also
starts the online search with the title straight away, as `autoSearch` does. A **store** build gets
the title pre-filled and no search. Relation data can reach a store build through sync — it is
public metadata inside `externalMeta` — so the hint can appear there too; only the online lookup is
gated on `AppFlavor.isFull`.

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
  A member row and the prev/next buttons **push** the other record's detail page, and the route
  keys each detail page by id. In 1.6.0 they used `context.go`: the first hop replaced the whole
  stack, leaving nothing to go back to, and the second hop reused the same page State, so nothing
  changed on screen.
- **Missing-sequel hint.** A card above the series card, shown whenever
  [a database-listed sequel is missing](#database-relations) — also for a record in no series.
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

## Manage by series

Grouping the Manage list by series — one row per series that expands into its members — was listed
here as a follow-up in 1.6.0 and shipped in 1.6.2. The Manage tab's series view builds the same
`SeriesIndex` over the whole library, so a series there is exactly the series the detail page shows,
curated or derived. See [`home-management-statistics.md`](home-management-statistics.md) and
[`../functions/features/anime/services/manage_grouping.md`](../functions/features/anime/services/manage_grouping.md).

The detail page's Related card (1.6.2) never offers members of the record's own series; see
[`categories-and-recommendations.md`](categories-and-recommendations.md#related-recommendations-on-the-detail-page).

## Tests

`test/series_service_test.dart` covers the grouping over a realistic fixture library (including the
cases that must **not** link automatically, such as `Fate/Zero` and `Fate/stay night`), curated
series never fusing, ties attaching nothing, standalone records, ordering, identical output for
shuffled input, and every `SeriesEditor` operation. `test/relations_test.dart` covers the three
relation mappers, `mergedWith` keeping other sources' relations, JSON preservation of unknown
relation types, canonical keys, E1 grouping, spin-offs staying suggestions, standalone records and
the missing sequel. `test/series_card_ui_test.dart` covers the card in both detail layouts and the
missing-sequel hint; `test/anime_json_test.dart`, `test/bundle_import_test.dart` and
`test/duplicate_service_test.dart` cover the field, the share strip and drop, and the merge.
