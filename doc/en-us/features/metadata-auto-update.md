# Background Metadata Updates

`metadata_update_service.dart` keeps anime metadata current while the app is open. It is available
in **full builds only** — see the flavor gating section, and
[`../architecture.md`](../architecture.md) for the `full`/`store` split.

Added in 1.5.0. Before that, everything here was manual: open a record, press "refresh database
info", one anime at a time.

## Two queues, one rule

The service runs two queues that differ in exactly one way — **who owns the field being written.**

| | Applies to | Writes | Asks the user |
|---|---|---|---|
| **Refresh** | Records that already know a source URL | `externalMeta` only | No |
| **Discovery** | Records with no source, missing details, or a disagreeing episode count | Nothing directly — produces a proposal | **Yes** |

`externalMeta` is a local copy of someone else's public data. Overwriting it loses nothing, so it is
written straight through. `title`, `endEpisode`, `firstAirDate`, `coverImage` and the rest are the
user's own record, so a change to one always becomes a proposal that waits for confirmation.

This is why a **refresh** can also produce a proposal: when re-fetching a known source reveals that a
core field drifted — most often an episode count once a season's real length is confirmed — the
difference goes into the confirmation queue rather than being written silently.

## Background writes never touch `modifiedAt`

This is the load-bearing rule of the whole feature, and getting it wrong corrupts data.

[`mergeRecords`](../algorithms/three-way-merge.md) decides whether a record changed **purely by
comparing `modifiedAt` against the sync base** — it never compares content. If a background refresh
bumped `modifiedAt`, two things would follow:

1. **Deleted records would come back.** A record present locally and missing from the remote is
   treated as "deleted remotely"; if the local copy also looks modified, the merge keeps it. A
   background refresh on one device would silently undo a deletion made on another.
2. **Conflicts would appear for edits nobody made.** Both sides would read as changed, producing a
   conflict dialog for a record the user never touched — and conflicts are never auto-resolved here.

Leaving `modifiedAt` alone keeps `localChanged` false, which makes both impossible. The refreshed
data still propagates: when the remote did not touch the record, the merge keeps the local copy, and
the upload decision is made by raw file comparison, so changed content is still uploaded. When the
remote *did* change the record, the remote wins and the local cache update is dropped — which is
correct, because it is a cache and the refresh queue will fetch it again.

`AnimeStorage.patchExternalMeta` is the only write path for cached metadata, and both the background
service and the detail page's manual refresh chip go through it.

> **Trap:** `Anime.copyWith` defaults `modifiedAt` to *now* whenever the argument is omitted. It does
> not preserve the existing value. Every caller that means to preserve it must pass it back in
> explicitly. `test/metadata_update_test.dart` pins this behavior so it cannot be "simplified" away.

Applying a proposal is the opposite case: it **does** bump `modifiedAt`, because it is the user's own
edit and has to win the merge.

## What makes a record eligible

**Refresh** — the record has an `infoUrl`, or a stored external rating that remembers its
`sourceUrl`. Priority order:

1. Records that have a source URL but no cached metadata at all.
2. Everything else, oldest `refreshedAt` first.

Freshness depends on whether the show is still airing: **24 hours** while airing, **14 days** once
finished, because a finished show's score and episode count stop moving.

**Discovery** — the record has no source at all, or is missing a first air date, broadcast weekday,
end episode, or cover, or its episode count disagrees with the source.

### The `startEpisode == 1` guard

An episode-count mismatch is only reported when the record starts at episode 1.

Tracking the second cour of a 24-episode show as a separate entry with `startEpisode: 13,
endEpisode: 24` gives `totalEpisodes == 12` while the source reports 24. That is the **correct** way
to record it. Without this guard the feature would raise false alarms on exactly the records a user
curated most carefully.

An open-ended record (`endEpisode == null`) is treated as a missing field, not a mismatch.

## Confidence, and why "update all" is safe

A discovery result becomes a confident proposal only when both hold:

- the best match scores at least **0.75** on `AnimeSearchService.relevance`, and
- no rival within **0.08** of it belongs to a *different work*. The same show legitimately appears
  once per source, so a near-tie only counts against the winner when the runner-up shares no title
  with it.

Anything short of that is filed as `needsManualPick`: it still appears in the review list, but it is
**excluded from every batch action**. The user has to open the record and pick through the normal
search dialog.

The diff itself is also conservative. `diffCandidate` **never proposes overwriting a non-empty user
value**, with exactly one exception: `endEpisode` when the counts demonstrably disagree. So a batch
apply can only fill blanks and correct a provable mismatch — which is what makes offering "update
everything" defensible at all.

## Watch-site progress

Since 1.5.7 the loop has a third step between refresh and discovery: re-reading what anime1.me
lists for every record whose `watchUrl` points there, and storing it as
`externalMeta.watchProgress` (see [`watch-url-lookup.md`](watch-url-lookup.md#background-refresh)).
It follows the same rule as refresh — a cache of public data, written through `patchExternalMeta`,
never touching `modifiedAt` — and differs in shape: one `animelist.json` download covers the whole
library, so the entire due set is handled in a single tick. A record is due when it was never read
(or read for a different URL), after 6 hours while the site says `連載中`, after 7 days once the
run is complete, and never once the user has watched everything of a completed run. Only
pre-1.5.7 `/category/…` links cost a page request each, capped at three per tick. Failures use a
one-hour **in-memory** retry that is deliberately separate from the entry backoff below, so a flaky
watch-site read never delays that record's metadata refresh. The manual check runs the same batch
first, outside the queue the progress bar counts.

Relevance itself changed slightly in the same release: the scorer's normalized pass now runs on
the folded Simplified form rather than Traditional. That can only raise near-duplicate scores, so
the confidence threshold and margin below are unaffected.

## Rate limiting, backoff, and offline

The external APIs are other people's servers. Jikan documents 3 requests per second and 60 per
minute; AniList allows 90 per minute.

| | Gap |
|---|---|
| Between refreshes (≤3 parallel requests each) | 5 s |
| Between discovery searches (five sources, up to two rounds) | 15 s |
| Idle poll when there is nothing to do | 3 min |
| Re-searching a record that found no usable match | 30 days |

Consecutive failures back off **1 h → 6 h → 24 h → 7 days**, clamped at the last rung, recorded per
anime in the local cache.

**Being offline does not count as a failure.** The tick returns before any work when there is no
connection, so a subway ride cannot push an entire library into a seven-day backoff. Only a request
that actually failed while the network was available increments the counter.

Writes to `anime_data.json` are batched every 10 anime. Writing after each one would rewrite the
whole file every few seconds and, worse, keep restarting auto-sync's 30-second save debounce, so a
long sweep would postpone syncing indefinitely.

## Network policy

`storage_config.json` key `metadataAutoUpdate`, storing a `MetadataUpdatePolicy` name:

| Value | Behavior | Default on |
|---|---|---|
| `off` | Never works in the background | — |
| `noCellular` | Wi-Fi, wired, and VPN links; never cellular | Android, iOS |
| `always` | Any connection | Desktop |

Absent means the platform default, following the same "don't store the default" convention as
`weekStartDay`.

**This is a link-type heuristic, not a metered-connection guarantee.** `connectivity_plus` reports
the transport, not whether it is billed:

- A laptop on a phone's Wi-Fi hotspot reports Wi-Fi while its uplink is cellular.
- A mobile VPN can mask the underlying transport.
- Android has a real answer, `NetworkCapabilities.NET_CAPABILITY_NOT_METERED`, which
  `connectivity_plus` does not expose.

The UI is worded "don't use cellular data" rather than "Wi-Fi only" — that is exactly what the check
does, on every platform including a wired desktop, and it does not promise more than it delivers.

The picker sits on its settings row's **title line** rather than in the tile's trailing slot. A
`ListTile`'s `trailing` shares its horizontal band with the title *and* the subtitle, and the
caveats above are long: beside the dropdown they wrapped into a narrow ragged column — six lines in
the two-pane settings layout. On the title line the dropdown costs the title alone, and the
explanation runs the full width, under it.

A second setting, `metadataPrefetchCovers`, controls whether candidate covers are downloaded ahead
of time. It is **off by default**: covers are the only large data in this cache and everything else
is plain text. With it off, the review screen streams thumbnails from the source URL, so the feature
costs nothing until a proposal is accepted.

## The review screen

Reached from the management page's app bar. The action is **always** offered in full builds; the
badge is what appears and disappears with the pending count. Through 1.5.0 the button itself was
hidden at zero, which left no way into the screen — and therefore no way to ask for a check — for
exactly the users who had nothing yet.

- Each proposal shows the candidate's cover, source, and match percentage, plus a
  **per-field `current → new` diff with its own checkbox** — a user can accept the episode count and
  refuse the synopsis.
- **Apply / Ignore** per record. Ignoring persists, so the record is not offered again until it
  changes or the 30-day rediscovery window elapses.
- **Update this page** applies every confident proposal among the anime the user was looking at on
  the management page — the current quarter, the "Other" page, or the current search results. The
  scope is passed in rather than recomputed, so it always means what was on screen.
- **Update all** applies every confident proposal in the library, behind **two** confirmation
  dialogs. This deliberately does not reuse `confirmDelete`'s "don't ask for 5 minutes" suppression,
  which would defeat the second prompt entirely.

The diff is **recomputed against the stored record** every time the screen loads, never read from the
cache. So a record edited since its proposal was made shows an accurate before/after, and one whose
changes the user has since made by hand simply drops off the list.

**The cards flow into columns on a wide window.** Until 1.5.6 this screen was the one page of its
class with no layout rule at all, so a single column of cards stretched across an unfolded foldable
or a desktop window with several hundred logical pixels of dead space per row. It now takes the
app-wide split rule and then a 360 dp minimum per card — two columns on a Fold in landscape, one in
portrait, four on a desktop. It is pushed **outside** the shell, so it measures the raw window: no
navigation rail to subtract, no bottom bar to reserve for. See
[`../adaptive-layout.md`](../adaptive-layout.md).


## The manual check

The review screen carries a **Check for updates** action — in the app bar, and again as the primary
button of the empty state, since the screen can now be opened with nothing in it.

It walks a **snapshot queue** built once at the start by `buildScanQueue`, so the progress bar has an
honest denominator that never moves and the loop is guaranteed to terminate. What that queue ignores
and what it honours is the whole design:

| Gate | Manual check | Why |
|---|---|---|
| Failure backoff | **ignored** | "Try again now" is what the button means. Backoff is only a "don't retry too soon" heuristic, and it is the first thing an explicit request should override. |
| 30-day rediscovery window | **ignored** | Same reason. |
| Dismissals | **honoured** | Re-proposing what the user already refused would make *Ignore* meaningless. |
| Cache freshness | **honoured** | On a 200-record library, re-fetching still-fresh metadata costs minutes and over a thousand requests to change nothing. |
| Network policy (`metadataAutoUpdate`) | **ignored** | That setting governs *unattended* traffic. This is one explicit tap the user can watch and stop — and when the policy is `off`, this button is the only way to check at all. |
| Being offline | **honoured** | Every item would fail and push the whole library into backoff for nothing. The check refuses to start and says so. |

Each record appears at most once: a stale record with a source URL is refreshed, and only a record
that is *not* being refreshed is searched for. Refresh takes priority, matching the order the
background loop drains its two queues in.

Because the user is watching, the gaps are tighter than the background ones — and still well inside
what the APIs document:

| | Gap | Requests per host |
|---|---|---|
| Refresh | 2 s | ≤1 per item, so ≤30/min |
| Discovery | 6 s | ≤2 per item (both rounds), so ≤20/min |

The background timer is cancelled for the duration. Two workers hitting the same APIs at once would
double the rate these gaps are sized for.

**Progress** is published through `MetadataUpdateService.scanProgress`, a `ValueNotifier` shaped like
`SyncProgress` so both progress UIs bind identically. The banner shows the bar, `done / total`, how
many proposals have been found, and the title being worked on right now — which is what separates
"working slowly" from "hung". Proposals appear in the list one at a time as they are found.

**Cancelling** lets the request already in flight finish, so a response paid for in a network round
trip is never discarded, and keeps everything found so far. It means "stop here", not "undo".

An **empty queue** is reported as *everything is already up to date*, not *no updates found*. Those
are different answers, and only the first is true when nothing was checked because nothing needed
checking.

A proposal marked **needs manual selection** now carries a **Search manually** action, which opens
the record's edit page with the search dialog already open and the title filled in. It reuses the
edit page's existing search-and-apply path rather than adding a second way to write a record from a
search result.
## Storage

`metadata_updates.json` in the app data directory — see
[`../data-formats.md`](../data-formats.md). It holds one entry per anime: pipeline status, the
downloaded candidate, match score, attempt/backoff bookkeeping, and any prefetched cover path.

It is **not synced and not backed up**, and that takes no special handling: the sync and backup
engines only ever touch the file names registered in `ModuleRegistry` plus `images/`, and this file
is deliberately not registered in [`../../../lib/app/data_modules.dart`](../data-formats.md). It does
live under `AnimeStorage.getAppDir()`, so a storage-path change carries it along.

Losing the file costs network work, never user data, so a parse failure yields an empty store rather
than throwing. Entries are pruned when their anime is deleted, and prefetched covers are pruned with
them.

## Flavor gating

`MetadataUpdateService` does **not** check the flavor itself, matching `AnimeSearchService`. Every
caller gates explicitly:

- `main.dart` starts the service only under `AppFlavor.isFull`.
- `management_page.dart` shows the updates badge only under `AppFlavor.isFull`.
- `settings_page.dart` shows both settings only under `AppFlavor.isFull`.

Keep [`../../../PRIVACY_POLICY.md`](../data-formats.md) and the in-app privacy policy in step with
this feature: background network access is the one externally visible behavior change it introduces.
