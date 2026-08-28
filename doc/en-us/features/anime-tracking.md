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
  a separate "Database Info" card *above* the personal rating card, and it never feeds statistics.
  The separation is carried by the layout — a distinct card, a distinct section heading, and each
  chip prefixed with its source name. 1.5.0 removed a sentence that restated this in prose; it told
  the reader nothing the card was not already showing.

Nothing writes an external score into `AnimeRating`. Applying a search result, refreshing an anime's
database info, or a background metadata refresh all touch only `externalMeta` — the user's own
scores, episode progress, and manual edits are left exactly as they are. See
[`../data-formats.md`](../data-formats.md#animeexternalmeta-and-animeexternalrating) for the stored
shape, [`multi-source-search.md`](multi-source-search.md) for the refresh flow, and
[`metadata-auto-update.md`](metadata-auto-update.md) for the background updater.

## Update proposals

Fields the *user* owns are never written in the background. When the updater finds that a record is
missing a first air date, a cover, or an episode count — or that its episode count disagrees with
the source — it downloads the candidate and files a **proposal** instead of applying it. Proposals
are reviewed from a badge on the management page, one field at a time, and are stored per-device
outside the synced data file. See [`metadata-auto-update.md`](metadata-auto-update.md).

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

## Detail page layout

The detail page adapts to the viewport. On a phone, a folded foldable, or any window that is
meaningfully taller than it is wide, it is the single scrolling column it has always been. Given
enough room and a squarer shape it splits into two panes: a fixed, full-height left column holding
the cover, the Japanese title, the metadata chips and the watch-progress bar, and an independently
scrolling right column holding the rating card, the database-info card, the local-archive card,
the notes, the season navigation, and the episode list.

The choice is made by shape, not by device class, which is what lets one device answer differently
in each orientation: a Galaxy Z Fold 8 unfolds to a 4:3 *landscape* panel, so it splits in
landscape and keeps the single column in portrait, while the near-square Fold 7 and Fold 8 Ultra
split in both. Tablets follow the same rule — split in landscape, single column in portrait. The
exact thresholds and the reasoning behind each of them live in
[`../functions/shared/utils/detail_layout.md`](../functions/shared/utils/detail_layout.md).

## Edit page layout

Since 1.5.5 the edit form takes the same shape on the same windows, through the same rule. The
**cover picker and the two title fields are fixed on the left**; everything from the season down
scrolls on the right. That keeps what is being edited on screen while the rest of the form moves,
which a single long column could not.

The left pane does not scroll. The cover is sized from the height the pane has left over rather
than kept at a fixed 120 × 170, so the column fits by construction at any window the split rule
admits — down to the 480 dp minimum height, where the cover shrinks instead of the fields running
off the bottom. The pane can still scroll if a soft keyboard shrinks the window past what that
arithmetic covers, which degrades gracefully rather than showing an overflow stripe.

Both panes stay inside one `Form`, so saving still validates the title on the left and the season
on the right together. Nothing is stored across the layout swap beyond the text you have typed, so
folding or unfolding mid-edit keeps a half-written title intact.
