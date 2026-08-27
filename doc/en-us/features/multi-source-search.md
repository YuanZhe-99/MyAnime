# Multi-Source Search

`anime_search_service.dart` searches or scrapes multiple sources, available in **full builds
only** — see the flavor gating section below and [`../architecture.md`](../architecture.md) for
the `full`/`store` flavor split.

## Sources

- `bangumi.tv` — v0 search API (`POST /v0/search/subjects`).
- MyAnimeList — via Jikan v4.
- AniList — GraphQL API.
- `acgsecrets.hk` — seasonal page JSON-LD.
- `filmarks.com` — HTML scraping.
- `anime1.me` — used for watch URL lookup specifically (not general metadata search).

Each source is queried for up to `_maxPerSource` (10) results.

### Two sources were silently dead before 1.4.0

Both were found by running the real APIs during 1.4.0 verification, and neither had ever surfaced
an error, because every source method treats a failure as an empty result so one dead source cannot
break the whole search. That resilience is correct, but it also means **a source can disappear
without anyone noticing.**

- **bangumi.tv** was on the legacy `GET /search/subject/<query>` endpoint from the first release
  through 1.3.3. It now returns `502 Bad gateway` from Cloudflare for every request — search and
  by-id alike. Moved to the v0 API, which is alive and returns strictly more (see below).
- **filmarks.com** moved its detail URLs from `/anime/<id>` to `/animes/<series>/<season>` and now
  renders results client-side. The `/anime/` patterns, unchanged since v0.1.0, matched nothing.
  Rewritten against the current markup.

If a source starts returning nothing, suspect the source before the query.

## What each source supplies

Only `sourceUrl` and at least one title are guaranteed. Everything else depends on the source:

| Field | bangumi.tv | MyAnimeList | AniList | acgsecrets.hk | filmarks.com |
|---|---|---|---|---|---|
| `title` / `titleJa` | ✅ | ✅ | ✅ | ✅ | title only |
| `titleRomaji` / `titleEn` | — | ✅ | ✅ | — | — |
| `synonyms` | ✅ (`infobox`) | ✅ | ✅ | ✅ | — |
| `episodes` | ✅ | ✅ | ✅ | when present | — |
| `firstAirDate` | ✅ | ✅ | ✅ | ✅ | — |
| `endDate` | ✅ (`infobox`) | ✅ | ✅ | — | — |
| `airDayOfWeek` | ✅ (`infobox`) | ✅ | ✅ | — | — |
| `airTime` | — | ✅ (JST only) | ✅ | — | — |
| `format` / `status` | — | ✅ | ✅ | — | — |
| `durationMinutes` | — | ✅ | ✅ | — | — |
| `genres` / `studios` | ✅ (tags + `infobox`) | ✅ | ✅ | — | — |
| `score` / `votes` / `rank` | ✅ | ✅ | ✅ (no rank) | — | — |
| `coverImageUrl` | ✅ | ✅ | ✅ | ✅ | ✅ |
| `summary` | ✅ | ✅ | ✅ | — | — |

Three schedule details are worth calling out, because getting them wrong silently mis-schedules
every episode:

- **AniList broadcast time comes from the real airing schedule.** `nextAiringEpisode.airingAt` is
  preferred (a currently-airing show's live slot), falling back to the first `airingSchedule` node
  so finished shows still yield a real slot. The Unix timestamp is converted to Japan time (UTC+9)
  and split into weekday plus `HH:mm`. Only when AniList has no schedule at all does the weekday
  fall back to `startDate.weekday` — which is what the pre-1.4.0 code always did.
- **Late-night slots are filed under the previous day, in `25:00` form.** Japanese scheduling treats
  everything before **04:00** as the previous evening's late-night block, and this app's `airTime`
  already supports hours past midnight (see the `airTime` notes in
  [`../data-formats.md`](../data-formats.md)). A show airing 01:00 Thursday is therefore stored as
  Wednesday `25:00`, not Thursday `01:00`.

  This matters because **`getEpisodeCalendarDate()` ignores `airTime` entirely** — it places an
  episode purely from `firstAirDate` + `airDayOfWeek`. Reporting the raw wall-clock weekday would
  put every late-night episode one day later than the schedule it belongs to. The weekday and the
  first-air date are therefore shifted **together**: shifting only the weekday would leave the two
  fields disagreeing, and the forward-snap would push episode 1 a whole week out.

  `_alignFirstAirDateToSlot` only moves the date when the source's own first-air date sits on the
  wall-clock day — which is how AniList and MyAnimeList both record it — so a source that already
  reports the programming day is left alone and cannot be double-shifted.
- **Jikan's `broadcast.time` is only trusted when `broadcast.timezone` is `Asia/Tokyo`.** Any other
  timezone is dropped rather than stored as if it were Japan time.

`bangumi.tv`'s v0 API states the broadcast day as **free text** in `infobox.放送星期` (`星期五`,
`週六`, `金曜日`, …), so `parseBangumiWeekday` accepts the Simplified, Traditional, and Japanese
forms and returns `null` for anything else (`不定期`) rather than mis-scheduling it.

## Two-round cross-language search

`searchAll(query, {preferredLanguage})` runs **two rounds**, both fully parallel across sources.

**Round one — per-source language targeting.** Each source receives the query variant it indexes
best, rather than the raw string:

| Source | Receives |
|---|---|
| bangumi.tv | the Simplified variant |
| acgsecrets.hk | the Traditional variant |
| filmarks.com | the raw query, with `Accept-Language: ja` |
| MyAnimeList, AniList | the raw query (both index every language) |

This replaces the older special case that re-queried bangumi.tv a second time whenever the query
contained Traditional characters.

**Round two — cross-language backfill.** From round one's hits scoring at least
`_backfillMinRelevance` (0.45), the service harvests up to three titles: a Kana-containing Japanese
title, a romaji/English title, and a Chinese title (Han characters, no Kana). It then re-queries
**only the sources that returned nothing**, each with the harvested title in its own language. This
is what lets a Chinese query reach `filmarks.com`, which indexes Japanese titles only.

Guards: round two is skipped entirely when every source already returned something, or when no
title cleared the relevance threshold. It never recurses — there is exactly one extra round, so the
worst case roughly doubles latency.

Results are then deduplicated by `sourceUrl` (falling back to a title) and sorted by descending
relevance.

**Results are not merged across sources.** The same show appearing once from AniList and once from
bangumi.tv is deliberate: the user picks which source to take metadata from, and merging would
remove that choice.

## Relevance scoring

`relevance(result, queryVariants)` scores every title a result knows about — `title`, `titleJa`,
`titleRomaji`, `titleEn`, and every `synonym` — against every query variant, and keeps the best.
It reuses the same fuzzy scorer (`_similarity`: LCS-Dice, character-set Dice, and containment, each
computed on both the raw and Traditional-normalized forms) that ranks `anime1.me` watch-URL hits, so
a Simplified query still scores highly against a Traditional-only title.

`queryVariants(query)` is public so the search dialog can score with exactly the variant set the
service searched with, instead of re-deriving it.

## Result UI

The search dialog (`anime_search_dialog.dart`) presents the combined list with:

- **Sort** — relevance (default), first air date, episode count, or source. Results missing the
  sorted value always sink to the bottom rather than sorting as zero.
- **Filter** — a multi-select source chip set plus "only with cover image" and "only with air date"
  switches, in a bottom sheet. Only sources that actually returned results are offered.
- **Group by source** — toggles between a flat list and one collapsible section per source.
- **Long-press for full details** — a row's title is clipped to one line; long-pressing opens a
  sheet with every known title as selectable, copyable text plus all fetched metadata. Desktop also
  gets a hover tooltip listing the titles.

Applying a result writes each field the user checked. External metadata (studios, genres, format,
status, duration, alternate titles, and the source's score) is a single checkbox that produces one
`AnimeExternalMeta` record, folded into whatever a previous source already contributed.

## Refreshing saved metadata

`fetchByUrl(url)` re-fetches one anime from the page URL it came from, by id:

| URL | Endpoint |
|---|---|
| `anilist.co/anime/<id>` | GraphQL `Media(id:)`, same field selection as search |
| `myanimelist.net/anime/<id>` | `api.jikan.moe/v4/anime/<id>/full` |
| `bgm.tv` / `bangumi.tv` / `chii.in` `/subject/<id>` | `api.bgm.tv/v0/subjects/<id>` (plural path) |

Anything else returns `null`. `acgsecrets.hk` and `filmarks.com` are scraped rather than queried by
id, so they have no stable by-URL endpoint and are skipped. Each API's response is run through the
*same* mapper the search path uses, so search and refresh can never drift apart.

`refreshAll(urls)` fetches several in parallel, skipping failures rather than failing the batch.

The detail page (`anime_detail_page.dart`) exposes this as a "refresh database info" action chip. It
collects `infoUrl` plus every `externalMeta.ratings[].sourceUrl`, merges each fetched result into
the existing record via `AnimeExternalMeta.mergedWith`, and saves. **Only external metadata is
touched** — the user's own rating, episode progress, and manual edits are left exactly as they are.

## Flavor gating

`AnimeSearchService` itself does **not** enforce flavor gating — it is a shared utility. Every
store-reachable caller must gate access explicitly:

- `anime_edit_page.dart` gates its search actions behind `AppFlavor.isFull`, so online anime search
  stays hidden from store-facing UI (`store` flavor: Google Play / App Store builds).
- `anime_detail_page.dart` gates the "refresh database info" chip behind `AppFlavor.isFull` for the
  same reason. The external-metadata *card* is not gated — displaying already-synced data is not a
  network feature.
- The desktop local API server (`local_api_server.dart`, see
  [`../platform-notes.md`](../platform-notes.md)) can call `AnimeSearchService.searchAll()`
  directly, because it is a desktop-only feature and desktop builds ship as the `full` flavor, not
  a store/mobile surface.

Keep public data-source behavior reflected in `PRIVACY_POLICY.md` when sources change.
