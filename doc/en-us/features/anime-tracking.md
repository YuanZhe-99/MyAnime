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
