# lib/features/anime/services/metadata_update_service.dart

`MetadataUpdateService` is the singleton that keeps anime metadata current while the app is open. It
runs two queues — a silent **refresh** of cached `externalMeta` for records that already know their
source, and a **discovery** search for records that are incomplete, which produces proposals rather
than writes.

Behavior, tuning rationale, and the confidence rules live in
[`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md). This
page covers the declarations.

## The one rule everything depends on

Background writes go through `AnimeStorage.patchExternalMeta`, which **does not touch
`modifiedAt`**. `mergeRecords` decides "changed" purely from `modifiedAt` versus the sync base, so
bumping it here would resurrect records deleted on another device and raise conflicts for edits the
user never made. See [`../../../../sync.md`](../../../../sync.md).

Applying a *proposal* is the opposite case and does bump it — that is a user edit.

## Tuning constants

| Constant | Value | Why |
|---|---|---|
| `_refreshGap` | 5 s | A refresh is ≤3 parallel requests; Jikan allows 3/s and 60/min. |
| `_discoverGap` | 15 s | A `searchAll` is five sources across up to two rounds. |
| `_idleGap` | 3 min | Poll interval when idle or gated off. |
| `_airingFreshness` | 24 h | An airing show's score and episode count still move. |
| `_finishedFreshness` | 14 d | A finished show's do not. |
| `_rediscoverAfter` | 30 d | Before re-searching a record that found nothing usable. |
| `_backoff` | 1 h / 6 h / 1 d / 7 d | Consecutive failures, clamped at the last rung. |
| `_minConfidence` | 0.75 | Minimum relevance to offer a candidate at all. |
| `_confidenceMargin` | 0.08 | How far ahead of a *different work* the winner must be. |
| `_flushEvery` | 10 | Anime between writes of `anime_data.json`. |
| `_manualRefreshGap` | 2 s | Manual scan; a refresh is ≤1 request per host, so ≤30/min per host. |
| `_manualDiscoverGap` | 6 s | Manual scan; a `searchAll` is ≤2 requests per host, so ≤20/min per host. |

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `MetadataUpdateService._` | constructor | B | Prevent instantiation. |
| [`pendingCount`](#pendingcount) | getter | A | How many records await a user decision. |
| `store` | getter | B | Read-only snapshot of the cache. |
| `addListener` / `removeListener` | methods | B | Subscribe to pending-set changes. |
| `_notify` | method | B | Fire listeners over a defensive copy. |
| [`start`](#start) | method | A | Begin the background loop. |
| [`stop`](#stop) | method | A | Stop it and flush buffered metadata. |
| [`_schedule`](#_schedule) | method | A | Schedule the next tick. |
| `_ensureStoreLoaded` | method | B | Load the cache once per session. |
| [`_networkGate`](#_networkgate) | method | A | Decide whether the link satisfies the policy. |
| [`effectivePolicy`](#effectivepolicy) | static method | A | Read the policy, with the platform default. |
| [`refreshableUrls`](#refreshableurls) | static method | A | List the source pages a record can refresh from. |
| [`_tick`](#_tick) | method | A | Run one unit of work; always reschedules. |
| [`_runOnce`](#_runonce) | method | A | Gate, prune, and perform one queue item. |
| [`selectRefreshTarget`](#selectrefreshtarget) | method | A | Test seam for refresh-queue ordering. |
| `selectDiscoveryTarget` | method | B | Test seam for discovery-queue selection. |
| [`backoffFor`](#backofffor) | static method | A | Backoff delay for a failure count. |
| [`_nextRefreshTarget`](#_nextrefreshtarget) | method | A | Pick the next record to refresh. |
| [`_nextDiscoveryTarget`](#_nextdiscoverytarget) | method | A | Pick the next record to search for. |
| [`_refreshOne`](#_refreshone) | method | A | Refresh one record's cached metadata. |
| [`_discoverOne`](#_discoverone) | method | A | Search for a match for one record. |
| [`_isUnambiguous`](#_isunambiguous) | method | A | Whether the top hit clearly beats every rival *work*. |
| `_bestOf` | method | B | Pick the refreshed result matching a record best. |
| [`_recordFailure`](#_recordfailure) | method | A | Advance the backoff ladder. |
| [`_flushPendingMeta`](#_flushpendingmeta) | method | A | Write buffered metadata to disk. |
| `reload` | method | B | Re-read the cache after outside changes. |
| [`applyProposal`](#applyproposal) | method | A | Apply an accepted proposal. |
| `_resolveCoverPath` | method | B | Turn an accepted cover into an `images/` path. |
| [`_promotePrefetchedCover`](#_promoteprefetchedcover) | method | A | Copy a prefetched cover into `images/`. |
| [`dismissProposal`](#dismissproposal) | method | A | Reject a proposal. |
| `isScanning` | getter | B | Whether a manual scan is running. |
| [`buildScanQueue`](#buildscanqueue) | method | A | Build the fixed work list for a manual scan. |
| [`startManualScan`](#startmanualscan) | method | A | Run a user-triggered pass over the library now. |
| [`cancelManualScan`](#cancelmanualscan) | method | A | Ask a running scan to stop. |
| `clearScanProgress` | method | B | Return the progress notifier to its resting state. |
| [`_links`](#_links) | method | A | Read the current link types, or `null` when unavailable. |
| `_hasNoLink` | static method | B | Whether a link list means "no connection". |
| [`_isOffline`](#_isoffline) | method | A | Whether there is no connection at all. |
| [`isMetaStale`](#ismetastale) | static method | A | Whether cached metadata is past its freshness window. |

## Documentation

### `int get pendingCount` <a id="pendingcount"></a>
- **Purpose:** Count records awaiting a user decision.
- **Notes:** Drives the management page badge, which is hidden entirely at zero so the action never
  appears with nothing behind it.

### `Future<void> start()` <a id="start"></a>
- **Side effects:** Loads the local cache, notifies listeners, schedules the first tick 20 s out.
- **Notes:** Idempotent. Does **not** check the flavor — callers gate on `AppFlavor.isFull`, the
  same contract `AnimeSearchService` follows. The 20-second delay keeps the loop out of the way of
  app startup.

### `Future<void> stop()` <a id="stop"></a>
- **Side effects:** Cancels the timer and flushes buffered metadata.
- **Notes:** Flushing on stop matters: buffered `externalMeta` was already paid for in network
  requests, and discarding it would mean fetching it again.

### `void _schedule(Duration)` <a id="_schedule"></a>
- **Notes:** The loop reschedules itself with a per-tick delay rather than running on a fixed
  period, so idle polling stays cheap while active work is paced. Returns without scheduling when
  the service has been stopped.

### `Future<_NetworkGate> _networkGate(MetadataUpdatePolicy)` <a id="_networkgate"></a>
- **Returns:** `allowed`, `blocked`, or `offline`.
- **Side effects:** Queries `connectivity_plus`.
- **Notes:** The three-way result exists so that **offline is distinguishable from blocked**, which
  is what keeps `_recordFailure` from firing when there is simply no connection — otherwise a
  subway ride would push an entire library into a seven-day backoff.

  Under `noCellular`, Wi-Fi, ethernet, and VPN links pass. This is a link-type heuristic, not a
  metered-connection guarantee — a phone hotspot still reports Wi-Fi. A plugin failure is treated as
  `allowed` rather than disabling the feature on a platform that cannot answer. See
  [`../../../../platform-notes.md`](../../../../platform-notes.md).

### `static Future<MetadataUpdatePolicy> effectivePolicy()` <a id="effectivepolicy"></a>
- **Notes:** Absent config means `noCellular` on Android and iOS so a phone never spends cellular
  data unasked, and `always` on desktop.

### `static List<String> refreshableUrls(Anime)` <a id="refreshableurls"></a>
- **Purpose:** Combine `infoUrl` with the URL each stored external rating remembers.
- **Notes:** Shared with the detail page's manual refresh chip, so both agree on what "refreshable"
  means. A record built from several sources refreshes all of them.

### `Future<void> _tick()` <a id="_tick"></a>
- **Notes:** Every exit path reschedules, including the failure path, so an unexpected exception
  cannot silently kill the loop for the rest of the session. The `_busy` flag prevents overlap.

### `Future<Duration> _runOnce()` <a id="_runonce"></a>
- **Returns:** How long to wait before the next tick.
- **Algorithm:**
  1. Flush and idle when the app is not `resumed`.
  2. Flush and idle when the policy or the current link forbids work.
  3. Load the cache and the anime list; prune entries for deleted anime.
  4. Refresh one record if any is due, else discover one, else flush and idle.
- **Notes:** Refresh comes before discovery deliberately: it is far cheaper and it silently improves
  data without asking the user anything.

  **Known, accepted race:** the sync engine writes the module file directly rather than through
  `AnimeStorage`, so a background write and a sync write can in principle overwrite each other.
  tmp-then-rename means the file can never be corrupted; the worst case is one lost cache update,
  which the next sweep redoes. The service also re-reads immediately before writing.

### `Anime? selectRefreshTarget(List<Anime>, DateTime, {MetadataUpdateStore})` <a id="selectrefreshtarget"></a>
- **Kind:** `@visibleForTesting` method
- **Notes:** The selection rule is the part worth pinning down; the network paths around it cannot
  be unit tested, because `AnimeSearchService`'s HTTP calls are static and take no injectable
  client. `store` seeds backoff and dismissal state.

### `static Duration backoffFor(int)` <a id="backofffor"></a>
- **Kind:** `@visibleForTesting` static method
- **Notes:** Clamps at the last rung rather than growing without bound.

### `Anime? _nextRefreshTarget(List<Anime>, DateTime)` <a id="_nextrefreshtarget"></a>
- **Notes:** Records with a source URL but no cached metadata at all win outright — "update the ones
  that have nothing" — and the rest follow oldest-`refreshedAt`-first. Freshness is 24 h while
  airing and 14 d once finished. Entries inside their backoff window are skipped.

### `Anime? _nextDiscoveryTarget(List<Anime>, DateTime)` <a id="_nextdiscoverytarget"></a>
- **Notes:** Skips records the user dismissed, records already awaiting a decision, records inside
  their backoff window, records searched within the last 30 days, and records with no title to
  search for.

### `Future<void> _refreshOne(Anime, DateTime)` <a id="_refreshone"></a>
- **Side effects:** HTTP requests; buffers the merged metadata; writes the local cache.
- **Notes:** Buffers rather than writing immediately — see [`_flushPendingMeta`](#_flushpendingmeta).
  A refresh that reveals a drifted **core** field does not write it; the difference becomes a
  proposal in the same queue a discovery would use.

### `Future<void> _discoverOne(Anime, DateTime)` <a id="_discoverone"></a>
- **Side effects:** A full multi-source search, optionally a cover prefetch, and a cache write.
- **Notes:** Only a clearly best match becomes a `proposed` entry; anything ambiguous is filed as
  `needsManualPick` and excluded from every batch action. A confident match whose diff is empty is
  recorded as `upToDate` rather than shown as an empty proposal.

### `bool _isUnambiguous(List<({AnimeSearchResult result, double score})>)` <a id="_isunambiguous"></a>
- **Notes:** The same show legitimately appears once per source — `searchAll` deliberately does not
  merge across sources. So a near-tie only counts against the winner when the runner-up **shares no
  title with it**; that is a different work competing, not the same one seen twice. Without this
  distinction the margin check would reject almost every correct match.

### `Future<void> _recordFailure(String, DateTime)` <a id="_recordfailure"></a>
- **Notes:** Only reached when the network was available and the request still failed. An offline
  tick returns before any work is attempted, so being offline never advances the ladder.

### `Future<void> _flushPendingMeta()` <a id="_flushpendingmeta"></a>
- **Side effects:** Rewrites `anime_data.json` when the buffer is non-empty.
- **Notes:** Batched every 10 anime. Writing after each one would rewrite the whole file every few
  seconds and keep restarting auto-sync's 30-second save debounce, so a long sweep would postpone
  syncing indefinitely.

### `Future<bool> applyProposal(Anime, Set<MetadataField>)` <a id="applyproposal"></a>
- **Inputs:** `anime` — the record **as currently stored**; `fields` — what the user accepted.
- **Side effects:** Downloads the cover when accepted, writes the record, clears the cache entry.
- **Notes:** Recomputes the diff against the record passed in rather than trusting one stored at
  proposal time, so an anime edited since the proposal was made is never overwritten with stale
  values. **Bumps `modifiedAt`** — this is the user's own edit and has to win the merge.

### `Future<String?> _promotePrefetchedCover(String)` <a id="_promoteprefetchedcover"></a>
- **Notes:** The prefetch directory is not synced, so an accepted cover has to be copied into
  `images/`, which is, before it can reach the user's other devices.

### `Future<void> dismissProposal(String)` <a id="dismissproposal"></a>
- **Notes:** Persists the rejection and deletes any prefetched cover. The record is re-examined only
  after the user edits it or the 30-day rediscovery window elapses.

### `({List<Anime> refresh, List<Anime> discover}) buildScanQueue(List<Anime>, MetadataUpdateStore, DateTime)` <a id="buildscanqueue"></a>
- **Kind:** method (`@visibleForTesting`)
- **Purpose:** Build the fixed work list a user-triggered scan will walk.
- **Inputs:** `animes`, `store`, `now`.
- **Returns:** A record of the anime to refresh and the anime to search for.
- **Side effects:** None — pure, which is why it is the part of the manual scan that is unit tested.
- **Algorithm:** For each anime, in order: if it has refreshable URLs *and* its cache is stale, it
  goes to `refresh` and the record is done. Otherwise, if it is incomplete, has a title, and is
  neither dismissed nor already awaiting a decision, it goes to `discover`.
- **Notes:** What it **ignores** and what it **honours** is the whole design:

  | Gate | Manual scan | Why |
  |---|---|---|
  | Failure backoff (`nextAttemptAt`) | ignored | "Try again now" is what the button means; backoff is only a "don't retry too soon" heuristic. |
  | 30-day rediscovery window | ignored | Same reason. |
  | Dismissals | honoured | Re-proposing what the user already refused would make "ignore" meaningless. |
  | Cache freshness | honoured | Re-fetching fresh metadata on a 200-record library costs minutes and over a thousand requests to change nothing. |

  Refresh takes priority over discovery for the same record, matching the order
  [`_runOnce`](#_runonce) drains the two queues in. Each anime therefore appears **at most once**,
  so the total is a count of records and the progress bar's denominator never moves.

### `Future<bool> startManualScan()` <a id="startmanualscan"></a>
- **Kind:** method
- **Purpose:** Run a check of the whole library right now, on the user's explicit request.
- **Inputs:** None.
- **Returns:** `Future<bool>` — `false` when the device is offline and nothing ran.
- **Side effects:** Cancels the background timer, issues HTTP requests, writes
  `metadata_updates.json` and `anime_data.json`, and publishes to `scanProgress`.
- **Algorithm:** Take a snapshot queue from [`buildScanQueue`](#buildscanqueue), then work through
  refresh items before discovery items, publishing progress before and after each one and checking
  the cancel flag between them. Flush buffered metadata at the end and resume the background loop.
- **Notes:** Deliberately **not** gated on `metadataAutoUpdate`. That setting governs *unattended*
  background traffic; this is one explicit tap the user can watch and stop, and when the policy is
  `off` this button is the only way to check at all.

  Offline is still refused, because every item would fail and push the whole library into backoff
  for nothing. This is why [`_isOffline`](#_isoffline) exists separately from
  [`_networkGate`](#_networkgate), which short-circuits to `blocked` as soon as the policy is `off`
  — exactly the case the manual button has to work in.

  The background timer is cancelled for the duration: two workers hitting the same APIs at once
  would double the request rate `_manualRefreshGap` and `_manualDiscoverGap` are sized for.

### `void cancelManualScan()` <a id="cancelmanualscan"></a>
- **Kind:** method
- **Purpose:** Ask a running scan to stop.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Sets the flag read between queue items.
- **Notes:** The request already in flight is allowed to finish, so a response that has been paid
  for in a network round trip is never thrown away. Everything found so far is kept — cancelling is
  "stop here", not "undo".

### `Future<List<ConnectivityResult>?> _links()` <a id="_links"></a>
- **Kind:** method
- **Purpose:** Read the current link types.
- **Inputs:** None.
- **Returns:** `Future<List<ConnectivityResult>?>` — `null` when the plugin could not answer.
- **Side effects:** Queries `connectivity_plus`.
- **Notes:** Shared by the policy gate and the offline check so the plugin is called one way only.

### `Future<bool> _isOffline()` <a id="_isoffline"></a>
- **Kind:** method
- **Purpose:** Report whether there is no connection at all.
- **Inputs:** None.
- **Returns:** `Future<bool>`.
- **Side effects:** Queries `connectivity_plus`.
- **Notes:** A plugin that cannot answer counts as online, so the request itself gets to fail rather
  than the feature being refused outright on a platform that cannot report link state.

### `static bool isMetaStale(Anime, DateTime)` <a id="ismetastale"></a>
- **Kind:** static method
- **Purpose:** Report whether an anime's cached metadata is past its freshness window.
- **Inputs:** `anime`, `now`.
- **Returns:** `bool` — `true` when it has never been fetched.
- **Side effects:** None.
- **Notes:** Shared by [`_nextRefreshTarget`](#_nextrefreshtarget) and
  [`buildScanQueue`](#buildscanqueue) so the background loop and the manual scan cannot drift on
  what "stale" means. A finished show gets `_finishedFreshness` (14 days) against an airing show's
  `_airingFreshness` (24 hours), because a finished show's score and episode count stop moving.
