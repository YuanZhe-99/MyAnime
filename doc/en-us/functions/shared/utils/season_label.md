# lib/shared/utils/season_label.dart

Pure string helpers for season labels and titles, shared by the anime1.me lookup
([`../../features/anime/services/anime1_service.md`](../../features/anime/services/anime1_service.md))
and the series index
([`../../features/anime/services/series_service.md`](../../features/anime/services/series_service.md)).
They read a season ordinal out of a title or a `season` label, remove season markers so that two
seasons of one work fold to the same base title, and produce the label of the next season. New in
1.6.0: `seasonOrdinal` and its numeral parser moved here from `Anime1Service`, whose ranking still
uses them. The module imports nothing, so every helper is unit-testable
(`test/anime1_service_test.dart`, `test/series_service_test.dart`). See
[`../../../features/series-linking.md`](../../../features/series-linking.md) for how the series index
uses them.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`halfWidthAscii`](#halfwidthascii) | top-level function | A | Make full-width ASCII letters, digits and spaces half-width. |
| [`seasonOrdinal`](#seasonordinal) | top-level function | A | Read a 第N季 / Season N ordinal out of a title or label. |
| [`parseCjkNumber`](#parsecjknumber) | top-level function | A | Parse a small Chinese or Arabic numeral. |
| `toCjkNumber` | top-level function | B | Write a number from 1 to 99 as a Chinese numeral (the inverse of `parseCjkNumber`). |
| [`titleSeasonOrdinal`](#titleseasonordinal) | top-level function | A | Read the season ordinal a title implies, more permissively than `seasonOrdinal`. |
| [`stripSeasonMarkers`](#stripseasonmarkers) | top-level function | A | Remove season markers from a title, leaving the work's base title. |
| [`nextSeasonLabel`](#nextseasonlabel) | top-level function | A | Produce the season label that follows a given one, in the same numeral style. |
| `_englishSuffix` | top-level function | B | Return the English ordinal suffix (`st`/`nd`/`rd`/`th`) for a number. |

The `finalSeasonOrdinal` constant (`99`) carries no `/// Purpose:` comment and is not indexed as a
row. It is the ordinal an unnumbered "final season" marker (`The Final Season`, 最终季, 完結編)
reads as, so such a season sorts after every numbered season of the same work.

## Documentation

### `String halfWidthAscii(String text)` <a id="halfwidthascii"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/season_label.dart` (line 67)
- **Purpose:** Make full-width ASCII letters, digits and spaces half-width.
- **Inputs:** `text`.
- **Returns:** `String` — the same text with U+FF01–U+FF5E shifted to ASCII and U+3000 made a space.
- **Side effects:** None.
- **Notes:** Titles such as `ゆるキャン△ SEASON２` mix widths. `titleSeasonOrdinal` and
  `stripSeasonMarkers` normalize first, so one pattern covers both widths; `seriesOrdinalOf` does the
  same before reading the `season` label.

### `int? seasonOrdinal(String text)` <a id="seasonordinal"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/season_label.dart` (line 87)
- **Purpose:** Read a season ordinal out of a title or season label — `第二季`, `第2期`, `Season 2`,
  `2nd Season`, `S2`, `Part 2`.
- **Returns:** `int?` — `null` when no ordinal is present.
- **Side effects:** None.
- **Algorithm:** The `第N季` / `第N期` form first, through [`parseCjkNumber`](#parsecjknumber); then
  `Season N`, `Nth Season`, `SN` and `Part N`, in that order.
- **Usage:** `Anime1Service.search` and `rank` read the record's ordinal with it (see
  [`../../features/anime/services/anime1_service.md`](../../features/anime/services/anime1_service.md#rank));
  `seriesOrdinalOf` falls back to it for the `season` label; `NextSeasonPrefill.after` compares it
  with the title ordinal.
- **Notes:** Moved here from `Anime1Service` in 1.6.0 unchanged. `Anime.season` is a free-text label
  ("Season 1"), which is why this reads labels as well as titles. It deliberately does not read bare
  `N期`, English words or the final-season markers — [`titleSeasonOrdinal`](#titleseasonordinal)
  adds those for the series index without changing what the anime1.me ranking sees.

### `int? parseCjkNumber(String s)` <a id="parsecjknumber"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/season_label.dart` (line 103)
- **Purpose:** Parse a small Chinese or Arabic numeral.
- **Inputs:** `s` — `2`, `二`, `十`, `十二`, `二十`, `二十三`.
- **Returns:** `int?` — `null` for anything else.
- **Side effects:** None.
- **Notes:** Covers 1–99, every season number a title carries. It was the private
  `Anime1Service._parseCjkNumber` until 1.6.0; the move also taught it the three-character
  `二十三` form, which the old helper returned `null` for.

### `int? titleSeasonOrdinal(String title)` <a id="titleseasonordinal"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/season_label.dart` (line 150)
- **Purpose:** Read the season ordinal a title implies, more permissively than
  [`seasonOrdinal`](#seasonordinal).
- **Inputs:** `title`.
- **Returns:** `int?` — the ordinal; `finalSeasonOrdinal` (99) for an unnumbered final-season
  marker; `null` when the title carries no season marker.
- **Side effects:** None.
- **Algorithm:** After [`halfWidthAscii`](#halfwidthascii), try in order: `seasonOrdinal`; a bare
  `N期` not preceded by 第 or a digit; `Second Season` … `Sixth Season`; a final-season marker
  (`Final Season`, 最终季 / 最終季, 完结篇 / 完結編 and variants); a trailing Roman numeral II–IV.
- **Usage:** `seriesOrdinalOf` in [`series_service.md`](../../features/anime/services/series_service.md#seriesordinalof)
  reads every title with it before falling back to the label.

### `String stripSeasonMarkers(String title)` <a id="stripseasonmarkers"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/season_label.dart` (line 173)
- **Purpose:** Remove season markers from a title, leaving the work's base title.
- **Inputs:** `title`.
- **Returns:** `String` — trimmed, with the markers removed.
- **Side effects:** None.
- **Algorithm:**
  1. [`halfWidthAscii`](#halfwidthascii).
  2. Replace with a space: 第N季 / 第N期 / 第N部 / 第Nクール (Chinese or Arabic N), bare `N期`,
     `(The) Final Season`, `Season N`, `Nth Season`, `Second Season`-style words, `SN`, `Part N`,
     `Cour N`, 最终季 / 最終季 / 完结篇 / 完結編, and 続編 / 续篇 / 續篇.
  3. Remove a trailing Roman numeral II–IV, then any brackets the removals left empty
     (`()`, `（）`, `[]`, `【】`, `「」`, `『』`, `〔〕`).
  4. Collapse whitespace and trim trailing separators (`:`, `-`, `~`, `・`, `|`, `/` and their
     full-width forms).
- **Usage:** `seriesBaseKeys` folds the result with `AnimeSearchService.foldTitle` to build the base
  keys two seasons of one work share.
- **Notes:** For matching only — the result is folded before comparison and never shown.
  `【我推的孩子】第二季` and `【我推的孩子】` reduce to the same base; `進撃の巨人 The Final Season`
  reduces to `進撃の巨人`.

### `String? nextSeasonLabel(String label)` <a id="nextseasonlabel"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/utils/season_label.dart` (line 192)
- **Purpose:** Produce the season label that follows `label`.
- **Inputs:** `label` — e.g. `Season 1`, `第一季`, `第1期`, `2nd Season`.
- **Returns:** `String?` — the same label with its number incremented in the same numeral style
  (`Season 2`, `第二季`, `第2期`, `3rd Season`), or `null` when no ordinal can be read.
- **Side effects:** None.
- **Algorithm:** The `第N季` / `第N期` form keeps Arabic digits Arabic and Chinese numerals Chinese
  (through `toCjkNumber`); `Nth Season` recomputes the English suffix through `_englishSuffix`;
  otherwise `Season N`, `SN` and `Part N` increment in place. Only the first match is replaced, so
  the rest of the label survives.
- **Usage:** `NextSeasonPrefill.after` in
  [`series_service.md`](../../features/anime/services/series_service.md#nextseasonprefill), which
  prefills "Add next season".
