import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../ai/services/on_device_ai_service.dart';
import '../../anime/models/anime.dart';
import '../models/recommendation_data.dart';
import '../services/ai_reason_service.dart';
import '../services/recommendation_service.dart';
import '../services/recommendation_store.dart';
import 'reason_labels.dart';
import 'recommendations_page.dart' show recommendationCover;

/// Actions in the related card's menu.
enum _RelatedAction { refresh, trash }

/// The detail page's "Related" card (1.6.2): up to five library records like
/// this one, persisted in `recommendations.json` so they are the same on
/// every visit and every device until the user refreshes. Refresh puts the
/// shown batch into this record's own trash and generates the next one;
/// since 1.6.3 pinned rows are kept.
class RelatedRecommendationsCard extends ConsumerStatefulWidget {
  /// The record the list is for.
  final Anime anime;

  /// The whole library, to rank and to resolve stored ids.
  final List<Anime> library;

  /// Purpose: Create the card.
  /// Inputs: `anime`, `library`.
  /// Returns: A new `RelatedRecommendationsCard`.
  /// Side effects: None.
  /// Notes: The detail page shows it only while recommendations are on.
  const RelatedRecommendationsCard({
    super.key,
    required this.anime,
    required this.library,
  });

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<RelatedRecommendationsCard> createState() =>
      _RelatedRecommendationsCardState();
}

class _RelatedRecommendationsCardState
    extends ConsumerState<RelatedRecommendationsCard> {
  RelatedSnapshot? _snapshot;
  bool _busy = false;
  bool _aiPending = false;

  /// Purpose: Load or generate on first build, and follow synced changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads (and may write) `recommendations.json`; registers
  /// with auto-sync.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    _load();
  }

  /// Purpose: Reload when the card is rebuilt for another record.
  /// Inputs: `oldWidget`.
  /// Returns: None.
  /// Side effects: May reload.
  /// Notes: Flutter lifecycle override. A new library for the same record
  /// only changes which stored ids resolve; nothing is regenerated.
  @override
  void didUpdateWidget(covariant RelatedRecommendationsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.anime.id != widget.anime.id) {
      _snapshot = null;
      _load();
    }
  }

  /// Purpose: Stop following synced changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Unregisters from auto-sync.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(_load);
    super.dispose();
  }

  /// Purpose: Read the persisted list, generating it the first time.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads `recommendations.json`; writes it when no list has
  /// been generated for this record yet.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    final data = await RecommendationStore.load();
    if (!mounted) return;
    final snap = data.related[widget.anime.id];
    if (snap == null || !snap.isGenerated) {
      await _generate(snap?.hidden.keys.toSet() ?? const {});
      return;
    }
    setState(() => _snapshot = snap);
  }

  /// Purpose: Rank a new list, save it, then ask the model for reasons.
  /// Inputs: `exclude` — this record's trash.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` once for the list and once
  /// more if the model wrote reasons; may run the model once.
  /// Notes: Internal helper used within this file only. The list shows at
  /// once; the reasons fill in when they arrive. Since 1.6.3 pinned items
  /// are kept at the front with their stored reasons, and only the remaining
  /// slots are ranked anew.
  Future<void> _generate(Set<String> exclude) async {
    if (_busy) return;
    _busy = true;
    try {
      final stored =
          (await RecommendationStore.load()).related[widget.anime.id];
      final kept = keptPinnedItems(stored, {
        for (final a in widget.library) a.id,
      });
      final insights = await AiInsightsCache.load();
      final room = RecommendationWeights.relatedBatch - kept.length;
      final ranked = room <= 0
          ? const <Recommendation>[]
          : RecommendationService.related(
              widget.anime,
              widget.library,
              insights: insights,
              exclude: {...exclude, for (final i in kept) i.id},
              limit: room,
            );
      final fresh = [
        for (final r in ranked)
          RelatedItem(
            r.anime.id,
            reasons: [for (final x in r.reasons) ?encodeRelatedReason(x)],
          ),
      ];
      final at = DateTime.now().toUtc();
      var data = await RecommendationStore.putRelated(widget.anime.id, [
        ...kept,
        ...fresh,
      ], generatedAt: at);
      if (!mounted) return;
      setState(() => _snapshot = data.related[widget.anime.id]);

      final reasons = await _aiReasons(ranked, insights);
      if (reasons.isEmpty || !mounted) return;
      data = await RecommendationStore.putRelated(widget.anime.id, [
        ...kept,
        for (final i in fresh) i.withAiReason(reasons[i.id]),
      ], generatedAt: at);
      if (!mounted) return;
      setState(() => _snapshot = data.related[widget.anime.id]);
    } finally {
      _busy = false;
    }
  }

  /// Purpose: Ask the on-device model for reasons, if it can answer.
  /// Inputs: `ranked`, `insights`.
  /// Returns: `Future<Map<String, String>>` — empty when skipped.
  /// Side effects: Shows a thin progress bar while waiting.
  /// Notes: Internal helper used within this file only. The same language
  /// rules as the global page.
  Future<Map<String, String>> _aiReasons(
    List<Recommendation> ranked,
    AiInsights insights,
  ) async {
    final ai = ref.read(onDeviceAiServiceProvider);
    if (!ai.canGenerate || ranked.isEmpty) return const {};
    final locale = Localizations.localeOf(context);
    if (ai.coreInfo?.localeSupported == null &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      await ai.refreshStatus(
        localeTag: locale.countryCode == null
            ? locale.languageCode
            : '${locale.languageCode}_${locale.countryCode}',
      );
      if (!mounted || !ai.canGenerate) return const {};
    }
    final language = ReasonLanguage.forLocale(
      locale,
      localeSupported: ai.coreInfo?.localeSupported,
    );
    if (language == null) return const {};
    setState(() => _aiPending = true);
    try {
      return await writeRelatedAiReasons(
        ai,
        subject: widget.anime,
        related: ranked,
        language: language,
        insights: insights,
      );
    } finally {
      if (mounted) setState(() => _aiPending = false);
    }
  }

  /// Purpose: Trash the shown batch and generate the next one.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced).
  /// Notes: Internal helper used within this file only. What the card's
  /// refresh action means. Pinned items (1.6.3) are not trashed.
  Future<void> _refresh() async {
    final pinned = _snapshot?.pinned ?? const {};
    final shown = [
      for (final (_, i) in _resolved)
        if (!pinned.containsKey(i.id)) i.id,
    ];
    final data = await RecommendationStore.hideRelated(widget.anime.id, shown);
    if (!mounted) return;
    await _generate(
      data.related[widget.anime.id]?.hidden.keys.toSet() ?? const {},
    );
  }

  /// Purpose: Trash one related record.
  /// Inputs: `id`.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced).
  /// Notes: Internal helper used within this file only. The list shrinks;
  /// the next refresh fills it again.
  Future<void> _hide(String id) async {
    final data = await RecommendationStore.hideRelated(widget.anime.id, [id]);
    if (!mounted) return;
    setState(() => _snapshot = data.related[widget.anime.id]);
  }

  /// Purpose: Pin or unpin one related item.
  /// Inputs: `id`.
  /// Returns: None.
  /// Side effects: Writes `recommendations.json` (synced).
  /// Notes: Internal helper used within this file only (1.6.3). The item
  /// keeps its place; a pinned item survives the card's refresh.
  Future<void> _togglePin(String id) async {
    final pinned = _snapshot?.pinned.containsKey(id) ?? false;
    final data = pinned
        ? await RecommendationStore.unpinRelated(widget.anime.id, [id])
        : await RecommendationStore.pinRelated(widget.anime.id, [id]);
    if (!mounted) return;
    setState(() => _snapshot = data.related[widget.anime.id]);
  }

  /// Purpose: Open this record's own trash, then reload.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Navigation; reads the store.
  /// Notes: Internal helper used within this file only.
  Future<void> _openTrash() async {
    await context.push('/recommendations/trash?anime=${widget.anime.id}');
    await _load();
  }

  /// Purpose: Pair each stored item with its record.
  /// Inputs: None.
  /// Returns: `List<(Anime, RelatedItem)>`.
  /// Side effects: None.
  /// Notes: Items whose record was deleted, or that are trashed, are
  /// skipped.
  List<(Anime, RelatedItem)> get _resolved {
    final snap = _snapshot;
    if (snap == null) return const [];
    final byId = {for (final a in widget.library) a.id: a};
    return [
      for (final i in snap.items)
        if (!snap.hidden.containsKey(i.id))
          if (byId[i.id] case final a?) (a, i),
    ];
  }

  /// Purpose: Build the card.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Nothing is drawn until the first load finishes.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (_snapshot == null) return const SizedBox.shrink();
    final items = _resolved;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(l10n.relatedTitle, style: theme.textTheme.titleMedium),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: l10n.relatedRefresh,
                  icon: const Icon(Icons.refresh),
                  onPressed: _busy ? null : _refresh,
                ),
                PopupMenuButton<_RelatedAction>(
                  onSelected: (a) => switch (a) {
                    _RelatedAction.refresh => _refresh(),
                    _RelatedAction.trash => _openTrash(),
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: _RelatedAction.refresh,
                      child: Text(l10n.relatedRefresh),
                    ),
                    PopupMenuItem(
                      value: _RelatedAction.trash,
                      child: Text(l10n.recommendationsTrash),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_aiPending) const LinearProgressIndicator(minHeight: 2),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(l10n.relatedEmpty),
            ),
          for (final (anime, item) in items) _row(anime, item, l10n, theme),
        ],
      ),
    );
  }

  /// Purpose: Build one related row.
  /// Inputs: `anime`, `item`, `l10n`, `theme`.
  /// Returns: `Widget`.
  /// Side effects: None; a tap pushes the record's detail page.
  /// Notes: Internal helper used within this file only. Reason codes this
  /// build does not know are not shown.
  Widget _row(
    Anime anime,
    RelatedItem item,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    final reasons = [for (final c in item.reasons) ?decodeRelatedReason(c)];
    final pinned = _snapshot?.pinned.containsKey(item.id) ?? false;
    return InkWell(
      onTap: () => context.push('/anime/detail/${anime.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            recommendationCover(anime, size: const Size(40, 56)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anime.displayTitle,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (reasons.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final r in reasons)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(reasonLabel(r, l10n)),
                          ),
                      ],
                    ),
                  ],
                  if (item.aiReason case final ai?) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            l10n.aiGeneratedLabel,
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                      ],
                    ),
                    Text(ai, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: pinned
                  ? l10n.recommendationsUnpin
                  : l10n.recommendationsPin,
              isSelected: pinned,
              icon: const Icon(Icons.push_pin_outlined),
              selectedIcon: const Icon(Icons.push_pin),
              onPressed: () => _togglePin(item.id),
            ),
            IconButton(
              tooltip: l10n.recommendationsNotInterested,
              icon: const Icon(Icons.close),
              onPressed: () => _hide(item.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// Purpose: Pick the pinned items a regenerated related list must keep.
/// Inputs: `stored` — the record's current snapshot, if any; `libraryIds`.
/// Returns: `List<RelatedItem>` — pinned items in their stored order (with
/// their reasons), then pinned ids the stored list lacks as bare items;
/// records no longer in the library are left out.
/// Side effects: None.
/// Notes: 1.6.3. A pinned id can be missing from the stored list when a sync
/// took another device's newer list; it is put back rather than lost.
List<RelatedItem> keptPinnedItems(
  RelatedSnapshot? stored,
  Set<String> libraryIds,
) {
  if (stored == null || stored.pinned.isEmpty) return const [];
  final pinned = stored.pinned.keys.where(libraryIds.contains).toSet();
  final kept = [
    for (final i in stored.items)
      if (pinned.contains(i.id)) i,
  ];
  final have = {for (final i in kept) i.id};
  for (final id in stored.pinned.keys.toList()..sort()) {
    if (pinned.contains(id) && have.add(id)) kept.add(RelatedItem(id));
  }
  return kept;
}
