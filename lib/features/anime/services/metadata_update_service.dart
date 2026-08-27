/// Purpose: Keep anime metadata fresh in the background — silently refreshing
/// the cached `externalMeta` of records that already know their source, and
/// proposing (never applying) changes to records that are incomplete.
/// Inputs: The stored anime list, the local update cache, the user's network
/// policy, and the app lifecycle state.
/// Returns: A singleton service plus the apply/dismiss entry points the review
/// UI calls.
/// Side effects: Timers, HTTP requests to public anime databases, and writes to
/// both `anime_data.json` and the local `metadata_updates.json` cache.
/// Notes: Two queues, one rule that separates them — **who owns the field.**
/// `externalMeta` is a cache of someone else's data, so it is written straight
/// through. Core `Anime` fields belong to the user, so every change to one
/// becomes a proposal that waits for confirmation. See
/// `doc/en-us/features/metadata-auto-update.md`.
///
/// Callers must not start this in store builds: it is an online lookup feature
/// and is gated on `AppFlavor.isFull` at the call site, matching how the search
/// dialog and the detail page's refresh chip are gated.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;

import '../../../shared/services/image_service.dart';
import '../models/anime.dart';
import '../models/metadata_update.dart';
import 'anime_search_service.dart';
import 'anime_storage.dart';
import 'metadata_cache.dart';

/// Why a tick may not run right now.
enum _NetworkGate {
  /// The link satisfies the user's policy.
  allowed,

  /// The user's policy forbids this link type (cellular under `noCellular`).
  blocked,

  /// There is no connection at all.
  offline,
}

/// Background metadata refresher and update proposer.
class MetadataUpdateService {
  /// Purpose: Prevent direct instantiation and expose only the singleton.
  /// Inputs: None.
  /// Returns: A new `MetadataUpdateService._` instance.
  /// Side effects: None.
  /// Notes: None.
  MetadataUpdateService._();

  /// The single instance used across the app.
  static final instance = MetadataUpdateService._();

  // ── Tuning ──
  //
  // The external APIs are other people's servers. Jikan documents 3 requests
  // per second and 60 per minute; AniList allows 90 per minute. One anime at a
  // time with these gaps stays far below both, even though a refresh fires all
  // of one anime's URLs together.

  /// Gap between two refreshes (each is at most three parallel requests).
  static const _refreshGap = Duration(seconds: 5);

  /// Gap between two discovery searches — a `searchAll` is five sources across
  /// up to two rounds, so it is far more expensive than a refresh.
  static const _discoverGap = Duration(seconds: 15);

  /// Poll interval when there is nothing to do, or work is gated off.
  static const _idleGap = Duration(minutes: 3);

  /// How long a still-airing show's cached metadata stays fresh.
  static const _airingFreshness = Duration(hours: 24);

  /// How long a finished show's cached metadata stays fresh — scores and
  /// episode counts stop moving once a show ends.
  static const _finishedFreshness = Duration(days: 14);

  /// How long before an anime with no usable match is searched for again.
  static const _rediscoverAfter = Duration(days: 30);

  /// Backoff ladder applied after consecutive failures.
  static const _backoff = [
    Duration(hours: 1),
    Duration(hours: 6),
    Duration(days: 1),
    Duration(days: 7),
  ];

  /// Minimum relevance for a candidate to be offered without manual review.
  static const _minConfidence = 0.75;

  /// How far ahead of the runner-up the winner must be to count as unambiguous.
  static const _confidenceMargin = 0.08;

  /// Anime processed between two writes of `anime_data.json`.
  ///
  /// Writing after every single anime would rewrite the whole file every few
  /// seconds and, worse, keep restarting auto-sync's 30-second save debounce so
  /// a long sweep would postpone syncing indefinitely.
  static const _flushEvery = 10;

  /// Gap between two refreshes during a user-triggered scan.
  ///
  /// Tighter than [_refreshGap] because the user is watching, and still safe: a
  /// refresh sends at most one request per host, so 2s stays at 30 per minute
  /// per host against Jikan's documented 60 and AniList's 90.
  static const _manualRefreshGap = Duration(seconds: 2);

  /// Gap between two discovery searches during a user-triggered scan.
  ///
  /// A `searchAll` can hit one host twice — the first round plus the
  /// cross-language backfill round — so 6s keeps it under 20 requests per
  /// minute per host.
  static const _manualDiscoverGap = Duration(seconds: 6);

  Timer? _timer;
  bool _started = false;
  bool _busy = false;
  MetadataUpdateStore _store = const MetadataUpdateStore();
  bool _storeLoaded = false;
  final Map<String, AnimeExternalMeta> _pendingMeta = {};
  int _sinceFlush = 0;
  final List<VoidCallback> _listeners = [];
  bool _scanning = false;
  bool _scanCancelled = false;

  /// Live progress of the user-triggered scan, for `ValueListenableBuilder`.
  ///
  /// Static so the review page can bind to it before the service has done any
  /// work, and so a scan started on one visit is still observable on the next.
  static final scanProgress = ValueNotifier<MetadataScanProgress>(
    MetadataScanProgress.idle,
  );

  /// Purpose: Report how many anime are waiting for the user's decision.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Drives the management page's badge; counts both confident
  /// proposals and entries that need a manual pick.
  int get pendingCount {
    var count = 0;
    for (final entry in _store.entries) {
      if (entry.isPending) count++;
    }
    return count;
  }

  /// Purpose: Expose the current cache to the review UI.
  /// Inputs: None.
  /// Returns: `MetadataUpdateStore`.
  /// Side effects: None.
  /// Notes: Read-only snapshot; mutate through this service's methods.
  MetadataUpdateStore get store => _store;

  /// Purpose: Register a callback fired whenever the pending set changes.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Pair with [removeListener] in widget `dispose`.
  void addListener(VoidCallback cb) => _listeners.add(cb);

  /// Purpose: Remove a previously registered callback.
  /// Inputs: `cb`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: None.
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  /// Purpose: Notify listeners that the pending set changed.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Invokes every registered callback.
  /// Notes: Internal helper used within this file only. Iterates a copy so a
  /// listener that unregisters itself cannot corrupt the iteration.
  void _notify() {
    for (final cb in List<VoidCallback>.of(_listeners)) {
      cb();
    }
  }

  /// Purpose: Begin the background loop.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Loads the local cache and schedules the first tick.
  /// Notes: Idempotent. The caller gates on `AppFlavor.isFull`; this service
  /// does not check the flavor itself, matching `AnimeSearchService`.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await _ensureStoreLoaded();
    _notify();
    _schedule(const Duration(seconds: 20));
  }

  /// Purpose: Stop the background loop.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the pending timer and flushes buffered metadata.
  /// Notes: Buffered `externalMeta` is flushed so work already paid for in
  /// network requests is not thrown away.
  Future<void> stop() async {
    _started = false;
    _timer?.cancel();
    _timer = null;
    await _flushPendingMeta();
  }

  /// Purpose: Schedule the next tick.
  /// Inputs: `delay`.
  /// Returns: None.
  /// Side effects: Replaces the pending timer.
  /// Notes: Internal helper used within this file only. The loop reschedules
  /// itself with a delay chosen per tick rather than running on a fixed
  /// period, so idle polling is cheap and active work is paced.
  void _schedule(Duration delay) {
    _timer?.cancel();
    if (!_started) return;
    _timer = Timer(delay, () {
      unawaited(_tick());
    });
  }

  /// Purpose: Load the local cache once per session.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `metadata_updates.json`.
  /// Notes: Internal helper used within this file only.
  Future<void> _ensureStoreLoaded() async {
    if (_storeLoaded) return;
    _store = await MetadataCache.load();
    _storeLoaded = true;
  }

  /// Purpose: Decide whether the current link satisfies the user's policy.
  /// Inputs: `policy`.
  /// Returns: `Future<_NetworkGate>`.
  /// Side effects: Queries the platform connectivity plugin.
  /// Notes: Internal helper used within this file only. `connectivity_plus`
  /// reports the transport, not whether it is metered, so `noCellular` is a
  /// good heuristic rather than a guarantee — a phone hotspot still reports
  /// Wi-Fi. A plugin failure is treated as allowed rather than blocking the
  /// feature outright on a platform that cannot answer.
  Future<_NetworkGate> _networkGate(MetadataUpdatePolicy policy) async {
    if (policy == MetadataUpdatePolicy.off) return _NetworkGate.blocked;
    final results = await _links();
    if (results == null) return _NetworkGate.allowed;
    if (_hasNoLink(results)) return _NetworkGate.offline;
    if (policy == MetadataUpdatePolicy.always) return _NetworkGate.allowed;
    // noCellular: refuse when mobile is the only usable transport.
    final hasUnmetered = results.any(
      (r) =>
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet ||
          r == ConnectivityResult.vpn,
    );
    return hasUnmetered ? _NetworkGate.allowed : _NetworkGate.blocked;
  }

  /// Purpose: Read the current link types.
  /// Inputs: None.
  /// Returns: `Future<List<ConnectivityResult>?>` — `null` when the plugin
  /// could not answer.
  /// Side effects: Queries the platform connectivity plugin.
  /// Notes: Internal helper used within this file only. Kept separate from
  /// [_networkGate] so the manual scan can ask "is there a connection at all?"
  /// without going through the policy check, which short-circuits to `blocked`
  /// as soon as the policy is `off` — exactly the case where the manual button
  /// is the user's only way to check.
  Future<List<ConnectivityResult>?> _links() async {
    try {
      return await Connectivity().checkConnectivity();
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Decide whether a link list means "no connection".
  /// Inputs: `results`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static bool _hasNoLink(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  /// Purpose: Report whether the device currently has no connection at all.
  /// Inputs: None.
  /// Returns: `Future<bool>`.
  /// Side effects: Queries the platform connectivity plugin.
  /// Notes: Internal helper used within this file only. A plugin that cannot
  /// answer counts as online, so the request itself gets to fail rather than
  /// the feature being refused on a platform that cannot report link state.
  Future<bool> _isOffline() async {
    final results = await _links();
    return results != null && _hasNoLink(results);
  }

  /// Purpose: Read the effective background-update policy.
  /// Inputs: None.
  /// Returns: `Future<MetadataUpdatePolicy>`.
  /// Side effects: Reads `storage_config.json`.
  /// Notes: Absent config means the platform default: `noCellular` on Android
  /// and iOS so a phone never spends cellular data unasked, `always` on
  /// desktop.
  static Future<MetadataUpdatePolicy> effectivePolicy() async {
    final raw = await AnimeStorage.getMetadataUpdatePolicy();
    final fallback = (Platform.isAndroid || Platform.isIOS)
        ? MetadataUpdatePolicy.noCellular
        : MetadataUpdatePolicy.always;
    return parseMetadataUpdatePolicy(raw, fallback);
  }

  /// Purpose: List the source pages an anime can be refreshed from.
  /// Inputs: `anime`.
  /// Returns: `List<String>`.
  /// Side effects: None.
  /// Notes: Combines `infoUrl` with the URL each stored external rating
  /// remembers, so a record built from several sources refreshes all of them.
  /// Shared with the detail page's manual refresh chip so both agree on what
  /// "refreshable" means.
  static List<String> refreshableUrls(Anime anime) {
    final urls = <String>{
      if (anime.infoUrl != null && anime.infoUrl!.isNotEmpty) anime.infoUrl!,
      for (final rating in anime.externalMeta?.ratings ?? const [])
        if (rating.sourceUrl != null && rating.sourceUrl!.isNotEmpty)
          rating.sourceUrl!,
    };
    return urls.toList();
  }

  /// Purpose: Run one unit of background work.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: HTTP requests, cache writes, and possibly a data write.
  /// Notes: Internal helper used within this file only. Every exit path
  /// reschedules, so the loop cannot stall on an unexpected failure.
  Future<void> _tick() async {
    // A manual scan owns the network while it runs; the background loop would
    // otherwise double the request rate the gaps are sized for. Reschedule so
    // the loop survives even if the scan's own reschedule is missed.
    if (_scanning) {
      _schedule(_idleGap);
      return;
    }
    if (_busy || !_started) return;
    _busy = true;
    var next = _idleGap;
    try {
      next = await _runOnce();
    } catch (_) {
      // An unexpected failure must not kill the loop; back off to idle.
      next = _idleGap;
    } finally {
      _busy = false;
      _schedule(next);
    }
  }

  /// Purpose: Perform the gating checks and one queue item.
  /// Inputs: None.
  /// Returns: `Future<Duration>` — how long to wait before the next tick.
  /// Side effects: HTTP requests and file writes.
  /// Notes: Internal helper used within this file only.
  Future<Duration> _runOnce() async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      await _flushPendingMeta();
      return _idleGap;
    }

    final policy = await effectivePolicy();
    final gate = await _networkGate(policy);
    if (gate != _NetworkGate.allowed) {
      await _flushPendingMeta();
      return _idleGap;
    }

    await _ensureStoreLoaded();
    final data = await AnimeStorage.load();
    final animes = data.animes;
    final liveIds = {for (final a in animes) a.id};
    if (_store.entries.length != liveIds.length) {
      final pruned = _store.prunedTo(liveIds);
      if (pruned.entries.length != _store.entries.length) {
        _store = pruned;
        await MetadataCache.save(_store);
        unawaited(MetadataCache.pruneCovers(_store));
      }
    }

    final now = DateTime.now().toUtc();

    final refreshTarget = _nextRefreshTarget(animes, now);
    if (refreshTarget != null) {
      await _refreshOne(refreshTarget, now);
      return _refreshGap;
    }

    final discoverTarget = _nextDiscoveryTarget(animes, now);
    if (discoverTarget != null) {
      await _discoverOne(discoverTarget, now);
      return _discoverGap;
    }

    await _flushPendingMeta();
    return _idleGap;
  }

  // ── Queue selection ──

  /// Purpose: Expose the refresh-queue ordering to tests.
  /// Inputs: `animes`, `now`; `store` seeds the backoff state.
  /// Returns: `Anime?`.
  /// Side effects: Replaces the in-memory cache with `store`.
  /// Notes: The selection rule is the part worth pinning down — the network
  /// paths around it cannot be unit tested, because `AnimeSearchService`'s HTTP
  /// calls are static and take no injectable client.
  @visibleForTesting
  Anime? selectRefreshTarget(
    List<Anime> animes,
    DateTime now, {
    MetadataUpdateStore store = const MetadataUpdateStore(),
    Map<String, AnimeExternalMeta> pending = const {},
  }) {
    _store = store;
    _storeLoaded = true;
    _pendingMeta
      ..clear()
      ..addAll(pending);
    final target = _nextRefreshTarget(animes, now);
    _pendingMeta.clear();
    return target;
  }

  /// Purpose: Expose the discovery-queue selection to tests.
  /// Inputs: `animes`, `now`; `store` seeds dismissals and backoff.
  /// Returns: `Anime?`.
  /// Side effects: Replaces the in-memory cache with `store`.
  /// Notes: Companion to [selectRefreshTarget].
  @visibleForTesting
  Anime? selectDiscoveryTarget(
    List<Anime> animes,
    DateTime now, {
    MetadataUpdateStore store = const MetadataUpdateStore(),
  }) {
    _store = store;
    _storeLoaded = true;
    return _nextDiscoveryTarget(animes, now);
  }

  /// Purpose: Compute the backoff delay for a given consecutive-failure count.
  /// Inputs: `failureCount` — 1 for the first failure.
  /// Returns: `Duration`.
  /// Side effects: None.
  /// Notes: Exposed so the ladder can be asserted directly; clamps at the last
  /// rung rather than growing without bound.
  @visibleForTesting
  static Duration backoffFor(int failureCount) =>
      _backoff[(failureCount - 1).clamp(0, _backoff.length - 1)];

  /// Purpose: Report whether an anime's cached metadata is past its freshness
  /// window.
  /// Inputs: `anime`, `now`.
  /// Returns: `bool` — `true` when it has never been fetched.
  /// Side effects: None.
  /// Notes: Shared by the background queue and the manual scan so both agree on
  /// what "stale" means. A finished show gets a far longer window than an
  /// airing one because its score and episode count stop moving once it ends.
  static bool isMetaStale(Anime anime, DateTime now) {
    final refreshedAt = anime.externalMeta?.refreshedAt;
    if (refreshedAt == null) return true;
    final freshness = anime.isCompleted ? _finishedFreshness : _airingFreshness;
    return now.difference(refreshedAt) >= freshness;
  }

  /// Purpose: Pick the next anime whose cached metadata should be refreshed.
  /// Inputs: `animes`, `now`.
  /// Returns: `Anime?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Anime that have a
  /// source URL but no cached metadata at all come first — "update the ones
  /// that have nothing" — and the rest follow oldest-first. Freshness depends
  /// on whether the show is still airing, because a finished show's score and
  /// episode count stop moving.
  Anime? _nextRefreshTarget(List<Anime> animes, DateTime now) {
    Anime? best;
    DateTime? bestRefreshedAt;
    for (final anime in animes) {
      if (refreshableUrls(anime).isEmpty) continue;
      // Already refreshed this sweep and still waiting to be written. Without
      // this the record still looks never-fetched on disk and gets queued
      // again, spending a second request on a result already in hand.
      if (_pendingMeta.containsKey(anime.id)) continue;
      final entry = _store.entryFor(anime.id);
      if (entry != null && !entry.isDue(now)) continue;

      final refreshedAt = anime.externalMeta?.refreshedAt;
      if (!isMetaStale(anime, now)) continue;

      // Never-fetched records win outright; otherwise oldest first.
      if (refreshedAt == null) {
        if (bestRefreshedAt == null && best != null) continue;
        best = anime;
        bestRefreshedAt = null;
        continue;
      }
      if (best != null && bestRefreshedAt == null) continue;
      if (bestRefreshedAt == null || refreshedAt.isBefore(bestRefreshedAt)) {
        best = anime;
        bestRefreshedAt = refreshedAt;
      }
    }
    return best;
  }

  /// Purpose: Pick the next incomplete anime to search for.
  /// Inputs: `animes`, `now`.
  /// Returns: `Anime?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Skips anything the
  /// user dismissed, anything still inside its backoff window, and anything
  /// already carrying an undecided proposal.
  Anime? _nextDiscoveryTarget(List<Anime> animes, DateTime now) {
    for (final anime in animes) {
      if (anime.displayTitle.isEmpty) continue;
      if (!needsMetadataDiscovery(anime)) continue;
      final entry = _store.entryFor(anime.id);
      if (entry != null) {
        if (entry.status == MetadataUpdateStatus.dismissed) continue;
        if (entry.isPending) continue;
        if (!entry.isDue(now)) continue;
        final last = entry.lastAttemptAt;
        if (last != null && now.difference(last) < _rediscoverAfter) continue;
      }
      return anime;
    }
    return null;
  }

  // ── Work items ──

  /// Purpose: Refresh one anime's cached external metadata.
  /// Inputs: `anime`, `now`.
  /// Returns: None.
  /// Side effects: HTTP requests; buffers the result for the next data flush;
  /// writes the local cache.
  /// Notes: Internal helper used within this file only. Writes **only**
  /// `externalMeta`, through `AnimeStorage.patchExternalMeta`, which leaves
  /// `modifiedAt` alone. If the refreshed data disagrees with a core field the
  /// difference becomes a proposal instead of a silent edit.
  Future<void> _refreshOne(Anime anime, DateTime now) async {
    final urls = refreshableUrls(anime);
    final results = await AnimeSearchService.refreshAll(urls);
    if (results.isEmpty) {
      await _recordFailure(anime.id, now);
      return;
    }

    var merged = anime.externalMeta ?? const AnimeExternalMeta();
    for (final result in results) {
      merged = merged.mergedWith(
        AnimeSearchService.toExternalMeta(result, fetchedAt: now),
        refreshedAt: now,
      );
    }
    _pendingMeta[anime.id] = merged;
    _sinceFlush++;

    // A refresh can also reveal that a core field drifted — most often the
    // episode count once a season's length is confirmed. That never becomes a
    // silent write; it enters the same confirmation queue as a discovery.
    final best = _bestOf(results, anime);
    final changes = best == null
        ? const <MetadataFieldChange>[]
        : diffCandidate(anime, best);

    var entry =
        _store.entryFor(anime.id) ?? MetadataUpdateEntry(animeId: anime.id);
    entry = entry.copyWith(
      lastAttemptAt: now,
      failureCount: 0,
      clearNextAttemptAt: true,
      status: changes.isEmpty
          ? MetadataUpdateStatus.upToDate
          : MetadataUpdateStatus.proposed,
      candidate: changes.isEmpty ? null : best,
      clearCandidate: changes.isEmpty,
      relevance: changes.isEmpty ? 0 : 1,
    );
    _store = _store.withEntry(entry);
    await MetadataCache.save(_store);

    if (_sinceFlush >= _flushEvery) await _flushPendingMeta();
    _notify();
  }

  /// Purpose: Search for a match for one incomplete anime.
  /// Inputs: `anime`, `now`.
  /// Returns: None.
  /// Side effects: A full multi-source search, optionally a cover download,
  /// and a cache write.
  /// Notes: Internal helper used within this file only. Only a clearly best
  /// match becomes a proposal; anything ambiguous is filed as
  /// `needsManualPick` and excluded from batch apply, which is what makes
  /// "update everything" a defensible action.
  Future<void> _discoverOne(Anime anime, DateTime now) async {
    final results = await AnimeSearchService.searchAll(anime.displayTitle);
    var entry =
        _store.entryFor(anime.id) ?? MetadataUpdateEntry(animeId: anime.id);

    if (results.isEmpty) {
      _store = _store.withEntry(
        entry.copyWith(
          status: MetadataUpdateStatus.noMatch,
          lastAttemptAt: now,
          clearCandidate: true,
        ),
      );
      await MetadataCache.save(_store);
      _notify();
      return;
    }

    final variants = AnimeSearchService.queryVariants(anime.displayTitle);
    final scored = [
      for (final r in results)
        (result: r, score: AnimeSearchService.relevance(r, variants)),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final top = scored.first;
    final confident = top.score >= _minConfidence && _isUnambiguous(scored);
    final changes = diffCandidate(anime, top.result);

    if (!confident) {
      _store = _store.withEntry(
        entry.copyWith(
          status: MetadataUpdateStatus.needsManualPick,
          candidate: top.result,
          relevance: top.score,
          lastAttemptAt: now,
        ),
      );
      await MetadataCache.save(_store);
      _notify();
      return;
    }

    if (changes.isEmpty) {
      _store = _store.withEntry(
        entry.copyWith(
          status: MetadataUpdateStatus.upToDate,
          lastAttemptAt: now,
          clearCandidate: true,
        ),
      );
      await MetadataCache.save(_store);
      _notify();
      return;
    }

    String? coverPath;
    final wantsCover = changes.any(
      (c) => c.field == MetadataField.coverImage,
    );
    if (wantsCover && await AnimeStorage.getMetadataPrefetchCovers()) {
      final url = top.result.coverImageUrl;
      if (url != null) coverPath = await MetadataCache.prefetchCover(anime.id, url);
    }

    entry = entry.copyWith(
      status: MetadataUpdateStatus.proposed,
      candidate: top.result,
      relevance: top.score,
      lastAttemptAt: now,
      failureCount: 0,
      clearNextAttemptAt: true,
      coverCachePath: coverPath,
    );
    _store = _store.withEntry(entry);
    await MetadataCache.save(_store);
    _notify();
  }

  /// Purpose: Decide whether the top hit clearly beats every rival work.
  /// Inputs: `scored` — results sorted by descending relevance.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The same show legitimately
  /// appears once per source, so a near-tie only counts against the winner when
  /// the runner-up shares no title with it — that is a different work competing,
  /// not the same one seen twice.
  bool _isUnambiguous(
    List<({AnimeSearchResult result, double score})> scored,
  ) {
    final topTitles = scored.first.result.allTitles
        .map((t) => t.toLowerCase())
        .toSet();
    for (final other in scored.skip(1)) {
      if (scored.first.score - other.score >= _confidenceMargin) break;
      final shares = other.result.allTitles.any(
        (t) => topTitles.contains(t.toLowerCase()),
      );
      if (!shares) return false;
    }
    return true;
  }

  /// Purpose: Choose the refreshed result that best matches an anime.
  /// Inputs: `results`, `anime`.
  /// Returns: `AnimeSearchResult?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. A refresh can hit
  /// several sources; the one whose titles match the record best supplies the
  /// core-field comparison.
  AnimeSearchResult? _bestOf(List<AnimeSearchResult> results, Anime anime) {
    if (results.isEmpty) return null;
    final variants = AnimeSearchService.queryVariants(anime.displayTitle);
    AnimeSearchResult? best;
    var bestScore = -1.0;
    for (final r in results) {
      final score = AnimeSearchService.relevance(r, variants);
      if (score > bestScore) {
        bestScore = score;
        best = r;
      }
    }
    return best;
  }

  /// Purpose: Record a failed attempt and push out the next one.
  /// Inputs: `animeId`, `now`.
  /// Returns: None.
  /// Side effects: Writes the local cache.
  /// Notes: Internal helper used within this file only. Only reached when the
  /// network was available and the request still failed — an offline tick
  /// returns before any work, so a subway ride cannot push the whole library
  /// into a seven-day backoff.
  Future<void> _recordFailure(String animeId, DateTime now) async {
    final entry =
        _store.entryFor(animeId) ?? MetadataUpdateEntry(animeId: animeId);
    final failures = entry.failureCount + 1;
    final delay = backoffFor(failures);
    _store = _store.withEntry(
      entry.copyWith(
        failureCount: failures,
        lastAttemptAt: now,
        nextAttemptAt: now.add(delay),
      ),
    );
    await MetadataCache.save(_store);
  }

  /// Purpose: Write buffered external metadata to the anime data file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Rewrites `anime_data.json` when the buffer is non-empty.
  /// Notes: Internal helper used within this file only. Batched so a long
  /// sweep does not rewrite the file every few seconds, which would also keep
  /// resetting auto-sync's save debounce.
  Future<void> _flushPendingMeta() async {
    if (_pendingMeta.isEmpty) return;
    final batch = Map<String, AnimeExternalMeta>.of(_pendingMeta);
    _pendingMeta.clear();
    _sinceFlush = 0;
    await AnimeStorage.patchExternalMeta(batch);
  }

  // ── Review UI entry points ──

  /// Purpose: Reload the cache after data changed outside this service.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the local cache.
  /// Notes: The review UI calls this when it opens so it never renders a stale
  /// snapshot, for instance after a sync replaced the anime file.
  Future<void> reload() async {
    _store = await MetadataCache.load();
    _storeLoaded = true;
    _notify();
  }

  /// Purpose: Apply an accepted proposal to the stored anime record.
  /// Inputs: `anime` — the record as currently stored; `fields` — the fields
  /// the user accepted.
  /// Returns: `Future<bool>` — whether anything was written.
  /// Side effects: Downloads the cover when accepted, writes `anime_data.json`,
  /// and clears the entry from the local cache.
  /// Notes: **Bumps `modifiedAt`**, unlike the background refresh: this is the
  /// user's own edit and has to win the sync merge. The diff is recomputed
  /// against the record passed in rather than trusting one stored at proposal
  /// time, so an anime edited since the proposal was made is never overwritten
  /// with stale values.
  Future<bool> applyProposal(Anime anime, Set<MetadataField> fields) async {
    final entry = _store.entryFor(anime.id);
    final candidate = entry?.candidate;
    if (entry == null || candidate == null || fields.isEmpty) return false;

    final changes = diffCandidate(anime, candidate);
    final accepted = changes.where((c) => fields.contains(c.field)).toList();
    if (accepted.isEmpty) {
      await dismissProposal(anime.id);
      return false;
    }

    String? coverPath;
    if (fields.contains(MetadataField.coverImage)) {
      coverPath = await _resolveCoverPath(entry, candidate);
    }

    final updated = applyMetadataChanges(
      anime,
      changes: accepted,
      selected: fields,
      coverImagePath: coverPath,
    );
    await AnimeStorage.addOrUpdate(
      updated.copyWith(modifiedAt: DateTime.now().toUtc()),
    );

    await MetadataCache.deleteCover(entry.coverCachePath);
    _store = _store.withEntry(
      entry.copyWith(
        status: MetadataUpdateStatus.upToDate,
        clearCandidate: true,
        clearCoverCachePath: true,
        relevance: 0,
      ),
    );
    await MetadataCache.save(_store);
    _notify();
    return true;
  }

  /// Purpose: Turn an accepted cover into a path inside `images/`.
  /// Inputs: `entry`, `candidate`.
  /// Returns: `Future<String?>`.
  /// Side effects: Copies a prefetched file, or downloads the cover.
  /// Notes: Internal helper used within this file only. A prefetched cover is
  /// reused when present; otherwise the image is fetched now, which is the
  /// normal path since cover prefetch is off by default.
  Future<String?> _resolveCoverPath(
    MetadataUpdateEntry entry,
    AnimeSearchResult candidate,
  ) async {
    final cached = entry.coverCachePath;
    if (cached != null) {
      final promoted = await _promotePrefetchedCover(cached);
      if (promoted != null) return promoted;
    }
    final url = candidate.coverImageUrl;
    if (url == null) return null;
    try {
      return await ImageService.saveImageFromUrl(url);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Move a prefetched cover into the synced `images/` directory.
  /// Inputs: `relativePath`.
  /// Returns: `Future<String?>` — the new `images/...` path, or `null`.
  /// Side effects: Copies a file.
  /// Notes: Internal helper used within this file only. The prefetch cache is
  /// not synced, so an accepted cover has to be copied into `images/` to reach
  /// the user's other devices.
  Future<String?> _promotePrefetchedCover(String relativePath) async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final source = File(p.join(appDir.path, relativePath));
      if (!await source.exists()) return null;
      return ImageService.saveImageFromFile(source);
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Reject a proposal so it is not offered again.
  /// Inputs: `animeId`.
  /// Returns: None.
  /// Side effects: Deletes any prefetched cover and writes the local cache.
  /// Notes: The record is re-examined only after the user edits it or the
  /// rediscovery window elapses.
  Future<void> dismissProposal(String animeId) async {
    final entry = _store.entryFor(animeId);
    if (entry == null) return;
    await MetadataCache.deleteCover(entry.coverCachePath);
    _store = _store.withEntry(
      entry.copyWith(
        status: MetadataUpdateStatus.dismissed,
        clearCandidate: true,
        clearCoverCachePath: true,
      ),
    );
    await MetadataCache.save(_store);
    _notify();
  }

  // ── Manual scan ──

  /// Purpose: Report whether a user-triggered scan is running right now.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: The review page uses this to swap its scan button for a cancel one.
  bool get isScanning => _scanning;

  /// Purpose: Build the work list for a user-triggered scan.
  /// Inputs: `animes`, `store`, `now`.
  /// Returns: A record of the anime to refresh and the anime to search for.
  /// Side effects: None.
  /// Notes: **Ignores** the failure backoff and the 30-day rediscovery window —
  /// "try again now" is the whole point of pressing the button, and those two
  /// are only "don't retry too soon" heuristics. **Honours** dismissals and
  /// cache freshness: re-proposing what the user already refused would make
  /// "ignore" meaningless, and re-fetching metadata that is still fresh would
  /// spend hundreds of requests to change nothing. Each anime appears at most
  /// once, refresh taking priority the same way [_runOnce] drains the refresh
  /// queue first, so the total is a count of records and the progress bar's
  /// denominator never moves.
  @visibleForTesting
  ({List<Anime> refresh, List<Anime> discover}) buildScanQueue(
    List<Anime> animes,
    MetadataUpdateStore store,
    DateTime now,
  ) {
    final refresh = <Anime>[];
    final discover = <Anime>[];
    for (final anime in animes) {
      if (refreshableUrls(anime).isNotEmpty && isMetaStale(anime, now)) {
        refresh.add(anime);
        continue;
      }
      if (!needsMetadataDiscovery(anime)) continue;
      if (anime.displayTitle.isEmpty) continue;
      final entry = store.entryFor(anime.id);
      if (entry != null) {
        if (entry.status == MetadataUpdateStatus.dismissed) continue;
        if (entry.isPending) continue;
      }
      discover.add(anime);
    }
    return (refresh: refresh, discover: discover);
  }

  /// Purpose: Run a user-triggered pass over the library right now.
  /// Inputs: None.
  /// Returns: `Future<bool>` — `false` when the device is offline and nothing
  /// ran.
  /// Side effects: Pauses the background loop, issues HTTP requests, writes the
  /// local cache and the anime file, and publishes progress to [scanProgress].
  /// Notes: Deliberately **not** gated on `metadataAutoUpdate`. That setting
  /// governs unattended background traffic; this is one explicit tap the user
  /// can watch and cancel, and when the policy is `off` this button is the only
  /// way to check at all. Offline is still refused, because every item would
  /// fail and push the whole library into backoff for nothing.
  Future<bool> startManualScan() async {
    if (_scanning) return true;
    if (await _isOffline()) return false;

    // Stop the background loop for the duration. Two workers hitting the same
    // APIs at once would double the request rate the gaps below are sized for.
    _timer?.cancel();
    _timer = null;
    _scanning = true;
    _scanCancelled = false;

    var done = 0;
    var total = 0;
    var found = 0;
    try {
      await _ensureStoreLoaded();
      final data = await AnimeStorage.load();
      final queue = buildScanQueue(
        data.animes,
        _store,
        DateTime.now().toUtc(),
      );
      final items = <({Anime anime, bool discovery})>[
        for (final a in queue.refresh) (anime: a, discovery: false),
        for (final a in queue.discover) (anime: a, discovery: true),
      ];
      total = items.length;
      scanProgress.value = MetadataScanProgress(
        phase: MetadataScanPhase.scanning,
        total: total,
      );

      for (var i = 0; i < items.length; i++) {
        if (_scanCancelled) break;
        final item = items[i];
        scanProgress.value = MetadataScanProgress(
          phase: MetadataScanPhase.scanning,
          done: done,
          total: total,
          currentTitle: item.anime.displayTitle,
          found: found,
        );
        final before = pendingCount;
        final at = DateTime.now().toUtc();
        if (item.discovery) {
          await _discoverOne(item.anime, at);
        } else {
          await _refreshOne(item.anime, at);
        }
        if (pendingCount > before) found += pendingCount - before;
        done++;
        // No title between items: the count means "checked", so leaving the
        // finished record named would read as though it were still in flight
        // for the whole of the pacing gap.
        scanProgress.value = MetadataScanProgress(
          phase: MetadataScanPhase.scanning,
          done: done,
          total: total,
          found: found,
        );
        if (_scanCancelled || i == items.length - 1) break;
        await Future<void>.delayed(
          item.discovery ? _manualDiscoverGap : _manualRefreshGap,
        );
      }

      await _flushPendingMeta();
    } finally {
      scanProgress.value = MetadataScanProgress(
        phase: _scanCancelled
            ? MetadataScanPhase.cancelled
            : MetadataScanPhase.done,
        done: done,
        total: total,
        found: found,
      );
      _scanning = false;
      _scanCancelled = false;
      _schedule(_idleGap);
      _notify();
    }
    return true;
  }

  /// Purpose: Ask a running scan to stop.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Sets the cancel flag read between queue items.
  /// Notes: The item already in flight is allowed to finish, so a paid-for
  /// network response is never thrown away. Everything found so far is kept.
  void cancelManualScan() {
    if (_scanning) _scanCancelled = true;
  }

  /// Purpose: Return the progress notifier to its resting state.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Publishes [MetadataScanProgress.idle].
  /// Notes: Called by the review page once it has shown the finished scan's
  /// summary, so re-entering the page does not replay an old result. Ignored
  /// while a scan is running.
  void clearScanProgress() {
    if (_scanning) return;
    scanProgress.value = MetadataScanProgress.idle;
  }
}
