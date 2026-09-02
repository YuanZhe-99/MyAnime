# lib/features/anime/views/anime1_labels.dart

Four pure label helpers that turn anime1.me's episode cell, year/season cell, a ranked match, and
a stored `AnimeWatchProgress` into user-facing text. They exist as one shared file, like
[`archive_labels.md`](archive_labels.md), because three call sites need them —
[`anime_edit_page.md`](anime_edit_page.md) (the watch-URL dialog rows),
[`anime_detail_page.md`](anime_detail_page.md) (the progress chip), and the tests — and the same
"Episodes 1-12+OVA" must read identically wherever it appears. Season names reuse the calendar's
`seasonWinter`/`seasonSpring`/`seasonSummer`/`seasonFall` keys; the site's own suffixes such as
`+OVA` are not translated. See
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md#episode-text).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`anime1EpisodesLabel`](#anime1episodeslabel) | function | A | Localize an episode cell for a chip or subtitle. |
| [`anime1SeasonLabel`](#anime1seasonlabel) | function | A | Localize the year/season cell, e.g. "2022 Fall". |
| [`anime1InfoLine`](#anime1infoline) | function | A | Compose the one-line description under a search result. |
| [`watchProgressLabel`](#watchprogresslabel) | function | A | Localize a stored watch-progress record. |

## Documentation

### `String anime1EpisodesLabel(AppLocalizations l10n, Anime1EpisodeInfo info)` <a id="anime1episodeslabel"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/anime1_labels.dart` (approx. line 12)
- **Purpose:** Localize an anime1.me episode cell for a chip or subtitle.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** ongoing → `anime1Ongoing(latest)` (or the raw text when no number was read); range → `anime1EpisodeRange` with the raw text when the cell has extras, else `first-last` (or a single number); movie → `anime1Movie`; special → `anime1Special`; other → the raw text.
- **Usage:**
  ```dart
  expect(anime1EpisodesLabel(en, Anime1Service.parseEpisodes('連載中(09)')), 'Updated to episode 9');
  ```
  (`test/anime1_service_test.dart`)
- **Notes:** Keeping `+OVA` verbatim is deliberate — it is the site's own notation.

### `String? anime1SeasonLabel(AppLocalizations l10n, String? year, String? season)` <a id="anime1seasonlabel"></a>
- **Kind:** top-level function
- **Source:** approx. line 37
- **Purpose:** Localize anime1.me's year/season cell, e.g. "2022 Fall".
- **Returns:** `String?` — `null` when both parts are blank.
- **Side effects:** None.
- **Notes:** An unrecognized season value is shown as the site wrote it.

### `String? anime1InfoLine(AppLocalizations l10n, Anime1Match match)` <a id="anime1infoline"></a>
- **Kind:** top-level function
- **Source:** approx. line 57
- **Purpose:** Compose the one-line description under a search result: season, episodes and fansub joined with a middle dot, blank parts skipped.
- **Returns:** `String?` — `null` for scrape-fallback hits, which carry no data.
- **Side effects:** None.
- **Usage:**
  ```dart
  final info = anime1InfoLine(l10n, r);
  ```
  (`anime_edit_page.dart`, `_WatchUrlSearchDialogState._buildBody`)
- **Notes:** None.

### `String? watchProgressLabel(AppLocalizations l10n, AnimeWatchProgress progress)` <a id="watchprogresslabel"></a>
- **Kind:** top-level function
- **Source:** approx. line 74
- **Purpose:** Localize a stored watch-progress record.
- **Returns:** `String?` — `null` when the record holds no episode data.
- **Side effects:** None.
- **Algorithm:** Re-parse the stored episode text through `Anime1Service.parseEpisodes` and hand it to [`anime1EpisodesLabel`](#anime1episodeslabel); with no text, fall back to `latestEpisode` alone.
- **Notes:** Re-parsing the stored text is what makes a completed run and an ongoing one read differently on the detail page exactly as they did in the dialog.
