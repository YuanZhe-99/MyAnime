# Watch-URL Lookup (anime1.me)

`anime1_service.dart` finds the anime1.me series page for a record and reads how far the site has
got with it. Available in **full builds only** — see the flavor-gating section and
[`../architecture.md`](../architecture.md) for the `full`/`store` split. Added in 1.5.7; through
1.5.6 this lived inside `anime_search_service.dart` as `searchAnime1`.

## The search endpoint was the wrong tool

anime1.me is a WordPress site. Its `?s=` search matches **exact Traditional substrings only**: a
Simplified title (`孤独摇滚`), a Japanese one (`ぼっち・ざ・ろっく`), an English one, or a mainland
translation that differs from the Taiwanese one (`间谍过家家` vs `SPY×FAMILY間諜家家酒`) all return
nothing. Through 1.5.6 the code compensated with up to six serial ten-second requests — the raw
query and both script variants of every title — and then guessed with two-character substrings.

The site also serves its whole catalogue as one file: `GET https://anime1.me/animelist.json`
(about 135 KB) is the array its homepage table renders, newest-updated first, one row per series:

```json
[1134, "孤獨搖滾！", "1-12", "2022", "秋", "動漫國"]
[1935, "GRAND BLUE 碧藍之海 第三季", "連載中(09)", "2026", "夏", ""]
[1644, "劇場總集篇 孤獨搖滾！Re:Re:", "劇場版", "2024", "夏", "千夏"]
```

The cells are category id, title, episode text, year, season, and fansub. The series page is
`https://anime1.me/?cat=<id>`, which answers with a 301 to the readable `/category/…` slug. With
the index in hand, matching becomes a local problem, and the episode cell supplies "updated to
episode N" for free.

## Index-first lookup

`Anime1Service.search(query, altQueries:, firstAirDate:, seasonText:)` runs three stages and stops
at the first that produces anything:

1. **Index.** `loadIndex()` fetches `animelist.json` at most once per 30 minutes (concurrent callers
   share one request; a failed refresh keeps serving the stale copy, and only a first-ever failure
   throws). `rank()` scores every row and keeps those at or above `minScore`.
2. **Alias harvest.** When no row reaches `confidentScore` (0.9) and none of the alternate queries
   is already Chinese, `AnimeSearchService.harvestAliases` sends the title to bangumi.tv once and
   collects the Chinese and Latin titles of hits scoring at least the backfill threshold (0.45).
   bangumi.tv's 别名 field usually lists the Taiwanese title next to the mainland one. The index is
   re-ranked with the union — no second anime1.me request — and rows that are new or improved are
   flagged `viaAliases`, which the dialog turns into a one-line caption.
3. **Scrape.** Only when the index could not be loaded or matched nothing does the old `?s=` path
   run (`_scrapeSearch`): the raw title, its script variants and the alternates, at most six
   requests, then the bigram retries. Scrape hits carry no episode or season data.

The alternate queries are the record's Japanese title plus everything `externalMeta` knows —
`titleEn`, `titleRomaji`, and every synonym — because the site keeps Latin franchise names
(`SPY×FAMILY`, `GRAND BLUE`) even when the Chinese half differs completely.

## Matching on a folded, Simplified key

`AnimeSearchService.foldTitle` makes fullwidth ASCII halfwidth, lowercases, strips whitespace and
every Unicode punctuation or symbol character (`！？・:：、「」【】《》～×`), and converts to
Simplified. Both the query and every index title are folded once, and the existing scorer runs on
the folded pair.

**Simplified is the canonical side, not Traditional.** Traditional→Simplified is many-to-one (乾
and 幹 both become 干; 髮 and 發 both become 发), so two regional spellings always meet. The other
direction is one-to-many, and the pre-1.5.7 scorer normalized that way — `toTraditional('弄干净')`
gave `弄幹淨`, which never equalled the site's `弄乾淨`. Folding also maps Japanese kanji (滅 → 灭), so
`鬼滅の刃` reaches `鬼滅之刃`.

The conversion tables themselves were the other half of the problem: a hand-typed list of about
1,200 pairs missing 干/乾/幹, 髮, 裏, 臺, 徵, 迴 and hundreds more. They are now generated from
OpenCC's character dictionaries — see
[`../functions/shared/utils/chinese_convert.md`](../functions/shared/utils/chinese_convert.md).

## Ranking

A row's base score is the best `similarityRaw` (LCS-Dice, character-set Dice, containment) of its
folded title against every folded query. Two gates and three adjustments follow:

| Rule | Value | Why |
|---|---|---|
| `minScore` | 0.5 | Containment floors any "same franchise ± subtitle" pair at 0.7; 0.5 sits above the 0.45 backfill threshold because 1,900 candidates make false positives visible in a ten-row list. |
| `minOrderedScore` | 0.4 | The set-based Dice term is blind to order, and on short Latin strings `bocchitherock` and `tomjerry` share half their letters. An order-aware score (LCS-Dice or containment) must also clear this floor. |
| `seasonBoost` | +0.10 | Sibling rows (`X`, `X 第二季`, `X 第三季`) differ by at most ~0.04 on containment, so a boost keyed to the record's premiere quarter settles them without lifting a partial hit over an exact one. |
| `adjacentSeasonBoost` | +0.03 | A soft net for a first-air date a few weeks off, or the site filing a title one season away. |
| `ordinalBoost` / `ordinalMismatchPenalty` | +0.10 / −0.05 | The record's 第N季 / Season N / Nth Season / S2 / Part 2 ordinal, read from its title or its season label, matches the row's ordinal — or does not. A row without an ordinal is the first season, so a record that asks for a sequel must not tie with the exact-title base row. |

Ties keep file order, which is newest-updated first. Results are capped at ten.

**The premiere quarter is snapped forward.** `Anime.season` is a free-text sequence label, never a
broadcast quarter, so the boost keys off `firstAirDate`. anime1 files a 29 September premiere under
秋, but the calendar says Q3; `quarterIndexFor` therefore moves any premiere on or after the 21st of
a quarter's last month into the next quarter, and 21 December or later into the next year's 冬.

## Episode text

`parseEpisodes` reads the site's cell into a kind plus numbers, first rule wins:

| Cell | Kind | Reads as |
|---|---|---|
| `連載中(09)`, `連載中(3 EP4)` | ongoing | `latest` = the leading integer; the rest is kept as `extras` |
| `1-12`, `13-24`, `1-12.5` | range | `first`, `last`, `latest = last`; the `.5` is dropped |
| `1-12+OVA`, `1-13+SP1-2`, `1-12+劇場版` | range | as above, with the suffix kept verbatim in `extras` |
| `1` | range | a one-episode run |
| `劇場版` | movie | |
| `特別編` | special | |
| `OVA`, `SP`, `ONA`, anything else | other | shown verbatim |

`anime1_labels.dart` turns these into "Updated to episode 9", "Episodes 1-12+OVA", "Movie", and
so on; year and season reuse the calendar's season names.

## Persisted progress

Choosing a result stores more than the URL. `Anime1Match.toProgress` becomes
`AnimeExternalMeta.watchProgress`, an `AnimeWatchProgress` record holding the URL it was read for,
the category id, the newest episode, the raw episode text, the ongoing flag and a UTC `checkedAt`
— see [`../data-formats.md`](../data-formats.md). It lives inside `externalMeta` because it is
exactly that kind of data: a cache of someone else's public information, written through
`AnimeStorage.patchExternalMeta` and therefore **never touching `modifiedAt`** (the load-bearing
rule of [`metadata-auto-update.md`](metadata-auto-update.md)).

`Anime.validWatchProgress` returns the record only while its `sourceUrl` equals the current
`watchUrl`. Editing the URL by hand hides the stale count until the next check, instead of showing
episode 9 of a series the URL no longer points at.

Where it shows:

- the **detail page** shows it as the site progress line under the watched-episode count (a chip in
  the action row through 1.6.5): `Anime1：更新至第 9 集`, the mapped `本地第 12 集／Anime1 第 24 集`,
  or "Check Anime1" when nothing valid is stored. Tapping it re-reads the site and, for an
  anime1.me page URL, force-refreshes the episode directory (1.6.6 — a mapped label comes from the
  directory, so through 1.6.5 the tap changed nothing visible), writing only through
  `patchExternalMeta`. The line renders stored data in every flavor; only the tap is a full-build
  action, and a store build with nothing stored shows no line;
- the **home page** turns an episode row's watch button primary, with the progress as its
  tooltip, when the directory resolves that local episode to a real page;
- the **management page** shows verified local/site progress, or explicitly labeled raw site progress;
- the desktop **local API** reports `watchLatestEpisode` and `watchProgressCheckedAt`.

## Background refresh

`MetadataUpdateService` gained a third step between refresh and discovery. One index download
covers every anime1.me URL in the library, so the whole due set is handled in one tick:

| | Window |
|---|---|
| Never read, or read for a different URL | due now |
| Site says still updating (`連載中`) | 6 hours |
| Site says complete | 7 days |
| Record fully watched and site says complete | never — nothing left to learn |

`?cat=` URLs resolve from the index with no request. A pre-1.5.7 `/category/…` link needs its page
fetched (the body class carries `category-<id>`, after which the index row is preferred); those
are capped at three per tick, two seconds apart. An episode-post URL (`https://anime1.me/19159`)
follows its category link once. Failures set a one-hour **in-memory** retry that is deliberately
separate from the entry backoff, so a flaky watch-site read never delays that anime's metadata
refresh. The manual "Check for updates" pass runs the same batch first, outside the queue the
progress bar counts. Both paths sit behind the existing lifecycle, network-policy and offline gates
by construction.

## Flavor gating

`Anime1Service` does not check the flavor itself, matching `AnimeSearchService`. The edit page's
search icon and the detail page's progress-line tap are gated on `AppFlavor.isFull`; displaying a stored record
is not, for the same reason the external-metadata card is not. The background caller is started
only under `AppFlavor.isFull` by `main.dart`.

Keep [`../../../PRIVACY_POLICY.md`](../data-formats.md) and the in-app privacy policy in step: since
1.5.7 the background updater also contacts anime1.me, and only the saved page address is sent.

## Season-aware episode playback (1.6.4)

Full builds resolve collection and episode URLs into a paginated directory of actual episode
pages. Directory refreshes preserve modifiedAt. User-confirmed season scope, starting number
and individual overrides are separate user data; changing the source invalidates both.
Incomplete fetches never replace a complete directory. Titles and explicit season markers
identify the season. Since 1.6.6 the chosen collection's own Anime1 names — its index title and
page title — count as titles too, because Anime1 names works in Taiwan translations that often
differ from the local title: `GRAND BLUE 碧藍之海 第三季` for 碧蓝之海 第三季 (an English prefix),
`與妳相戀到生命盡頭` for 还要与你相恋到生命尽头 (a different translation that no script conversion
bridges). Every season guard still applies — an explicit season number must agree, an unmarked
group cannot be a sequel, and another record on the same collection with a different season
shares those names, so it keeps an unmarked group ambiguous. A matching index range or an unambiguous episode 1 establishes its
start; the smallest available number greater than 1 does not. Dates, series links and counts
are context, never sufficient evidence for a boundary. Gaps remain gaps, duplicate numbers
need selection, and fractional episodes, OVA and SP remain separate extras.

The mapping screen previews local episodes and provides season scope, starting number,
individual page choices and reset to automatic. Manual choices survive refreshes. Home and
detail use the same mapping. Native playback falls back once to the embedded episode page
on failure. External opening is explicit. Playback never auto-advances. Through 1.6.4 it never
marked anything watched either; since 1.6.5 passing 95% of a numbered episode does (below).

## Player controls (1.6.5)

Native playback draws the app's own controls (`anime_player_controls.dart`) instead of media_kit's
stock ones, identically on every platform. The website fallback keeps the site's own player.

| Input | Effect |
|---|---|
| Tap | Show or hide the controls; they hide after 3 s while playing and stay while paused |
| Double tap | Play or pause |
| Horizontal swipe | Preview the target (`12:34 / 23:40 (+15s)`), seek once on release; a full-width swipe covers at most 90 s |
| Long press | While held, play one step faster — current speed + 1.0, at most 3.0 (1.0 → 2.0, 1.5 → 2.5, 2.0 → 3.0); release restores it |
| −5 s / +5 s buttons | Jump back or forward five seconds, clamped to the episode |
| Speed menu | 0.25, 0.5, 1.0, 1.5, 2.0, 3.0; the choice carries to the next episode of the session |
| Seek bar | Drag to scrub; seeks on release |
| Fullscreen button | media_kit fullscreen: on phones the system bars hide and the screen turns landscape; on desktop native fullscreen. A title row with a back button replaces the app bar there |
| Keyboard (desktop) | Space play/pause, ← / → five seconds, F fullscreen, Esc leave fullscreen |

The seek bar, the jump buttons and the swipe are disabled until the media duration is known.

## Playback progress (1.6.5)

Native playback records where each episode stopped in `playback_progress.json`, a synced and
backed-up data module (schema in [`../data-formats.md`](../data-formats.md), merge in
[`../sync.md`](../sync.md#the-playback-progress-file)).

- **Under 5%** of the episode nothing is written, and an existing resume point is left alone, so
  opening an episode and leaving at once does not erase where it stopped.
- **Between 5% and 95%** the position is written about every five seconds of media, on pause, and
  when playback stops — leaving the player, switching episodes from its menu, or falling back to
  the website player.
- **Past 95%** the resume point is deleted and, for a numbered episode, the episode is marked
  watched in the record with a fresh `modifiedAt`, once per session. Extras only lose their resume
  point.
- **Resuming.** When an episode with a resume point starts, the player seeks there once the duration
  is known and shows a snackbar with **Start over**. The episode screen shows each resume point as
  a bar and “Resume at m:ss”, and its automatic first playback continues the most recently
  stopped unwatched episode before the first unwatched one.
- The website player exposes no position, so it records nothing. No media address or credential is
  ever stored.

Temporary media URLs and credentials are session-only, never synced, backed up or logged.