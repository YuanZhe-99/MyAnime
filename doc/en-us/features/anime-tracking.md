# Anime Model and Tracking

The core data model is `Anime` in `lib/features/anime/models/anime.dart`. Field-by-field detail
(identity, URLs, schedule, episodes, `AnimeType`, `AnimeRating`, `extraJson`) lives in
[`../data-formats.md`](../data-formats.md) — this page focuses on the tracking/quarter-placement
logic built on top of those fields.

## Quarter placement

Quarter placement uses Japanese anime **cour** conventions (a cour is roughly one 3-month
broadcast season/quarter).

- `startQuarter` derives `(year, quarter)` from `firstAirDate`'s month: Jan–Mar -> Q1, Apr–Jun ->
  Q2, Jul–Sep -> Q3, Oct–Dec -> Q4.
- `airsInQuarter(year, quarter)` decides whether an anime should appear in a given quarter's
  listing:
  - **When `manualType` is set** (and isn't `longRunning`), placement uses a fixed cour-style span
    from `startQuarter`: `allAtOnce`/`singleCour` span 1 quarter, `halfYear` spans 2, `fullYear`
    spans 4. **`manualType` always takes precedence** over any estimate from episode count.
  - **Without `manualType`**, and when `endEpisode` is known, placement estimates the *actual* run
    length in weeks from episode count and `episodeWeekOffsets`
    (`actualWeeks = (episodeCount - 1) + weekOffsetFor(lastEpisode)`), then maps that week count to
    a quarter span with roughly a 2-week tolerance per cour boundary: ≤15 weeks -> 1 quarter, ≤28 ->
    2, ≤41 -> 3, ≤54 -> 4, otherwise `ceil(weeks / 13)` quarters.
  - **Long-running** (no `endEpisode`, no `manualType`) falls back to a simple date-overlap check
    against an estimated 51-week run from `firstAirDate`.

## Episode air dates and late-night rollover

`getEpisodeAirDate(episodeNumber)` and `getEpisodeCalendarDate(episodeNumber)` both compute a
target date from `firstAirDate` plus `(episodeOffset + weekOffsetFor(episodeNumber))` weeks, then
snap forward to the next occurrence of `airDayOfWeek` if the computed weekday doesn't match — so
episode 1 (and every subsequent episode) never lands before `firstAirDate` even when
`airDayOfWeek` disagrees with `firstAirDate`'s actual weekday.

The two getters differ in how they handle broadcast time:

- `getEpisodeAirDate()` applies `airTime`, including late-night values past midnight such as
  `"25:00"` (parsed as 01:00 the next calendar day) — see
  [`../data-formats.md`](../data-formats.md) for why this convention exists. If `airTime` is null,
  it treats the air time as 23:59.
- `getEpisodeCalendarDate()` deliberately skips that time-of-day rollover and stays on the
  scheduled broadcast *date* even for `24:00`/`25:00` values — useful anywhere the app wants "which
  calendar day is this episode's broadcast day" rather than "what UTC/JST instant does it air at."

## Type detection vs. manual override

- `autoType` infers `AnimeType` purely from `totalEpisodes` (see thresholds in
  [`../data-formats.md`](../data-formats.md)).
- `effectiveType` returns `manualType` when set, otherwise falls back to `autoType`. This
  precedence is consistent everywhere `effectiveType` is read, including quarter placement above.

## Status

Viewing status (completed / watching / dropped / not-started) is computed from
`episodeStatuses`, not stored — see [`../data-formats.md`](../data-formats.md) for the derivation
and [`../features/home-management-statistics.md`](home-management-statistics.md) for where it's
displayed.

## Ratings: yours vs. the databases'

Two rating concepts coexist and must not be conflated:

- **`AnimeRating`** is the *user's own* score — a manual overall plus five sub-scores, edited on the
  edit page and shown in the rating card on the detail page. It is the only rating that feeds
  statistics and the local API's ranking endpoint.
- **`externalMeta.ratings`** holds what external databases say, one entry per source, each
  normalized onto a 10-point scale and each remembering the page URL it came from. It is shown in
  a separate "Database Info" card *above* the personal rating card, with an explanatory line, and
  it never feeds statistics.

Nothing writes an external score into `AnimeRating`. Applying a search result, or refreshing an
anime's database info, touches only `externalMeta` — the user's own scores, episode progress, and
manual edits are left exactly as they are. See
[`../data-formats.md`](../data-formats.md#animeexternalmeta-and-animeexternalrating) for the stored
shape and [`multi-source-search.md`](multi-source-search.md) for the refresh flow.

## Local archive

Independent of watching progress, each anime can carry an optional record of a **downloaded local
copy**: whether one is kept, its source medium and resolution, how many copies exist, and which
repository or physical location holds them. The field shape is `AnimeLocalArchive` under the
`localArchive` key — see [`../data-formats.md`](../data-formats.md#animelocalarchive).

It answers one question the rest of the model cannot: *do I already have this, and where?* Nothing
in it feeds quarter placement, air dates, status derivation, or statistics — it is descriptive
metadata about the user's own storage, not about the series.

- **Edited** in the collapsible "Local Archive" section of the edit page, structured like the
  rating section: a switch for `archived`, two dropdowns (source × resolution), and the copies and
  location fields.
- **Displayed** as a read-only card on the anime detail page, next to the rating card, showing the
  joined quality label (`BD · 1080p`), the copy count, and the location.
- **Filtered** on the management page via an AppBar filter with three states — all, archived, not
  archived — applied to the quarter pages, the "Other" page, and search results alike. "Not
  archived" folds together anime with no record and anime explicitly marked as not kept, since the
  question being asked is "what still needs downloading". The filter is view state only; it resets
  to "all" when the page rebuilds.

Because the values name the user's own storage infrastructure, the field is **synced but never
shared**: it travels over WebDAV between the user's devices, but is stripped from `.myanimeitem`
share files and never drawn into shared image cards. See
[`share-and-import.md`](share-and-import.md).
