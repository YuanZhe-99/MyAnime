import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../models/anime.dart';
import '../models/metadata_update.dart';
import '../services/anime_storage.dart';
import '../services/metadata_update_service.dart';

/// One reviewable proposal: the record, its cached entry, and the live diff.
typedef _Proposal = ({
  Anime anime,
  MetadataUpdateEntry entry,
  List<MetadataFieldChange> changes,
});

/// Review screen for metadata the background updater downloaded but has not
/// applied.
class MetadataUpdatesPage extends StatefulWidget {
  /// Anime shown on the management page the user came from, for "update this
  /// page". Empty hides that action.
  final List<String> currentPageAnimeIds;

  /// Purpose: Create the metadata updates review page.
  /// Inputs: `currentPageAnimeIds`.
  /// Returns: A new `MetadataUpdatesPage` instance.
  /// Side effects: None.
  /// Notes: The page scope is passed in rather than recomputed, so "this page"
  /// always means exactly what the user was looking at.
  const MetadataUpdatesPage({super.key, this.currentPageAnimeIds = const []});

  /// Purpose: Create the mutable state for this widget.
  /// Inputs: None.
  /// Returns: `State<MetadataUpdatesPage>`.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<MetadataUpdatesPage> createState() => _MetadataUpdatesPageState();
}

class _MetadataUpdatesPageState extends State<MetadataUpdatesPage> {
  List<_Proposal> _proposals = [];
  final Map<String, Set<MetadataField>> _selected = {};
  bool _loading = true;
  bool _working = false;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state and starts the first load.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Purpose: Rebuild the proposal list from storage and the local cache.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the anime file and the update cache.
  /// Notes: Internal helper used within this file only. The diff is recomputed
  /// here rather than read from the cache, so a record edited since the
  /// proposal was made shows an accurate before/after — and an entry whose
  /// changes have since been made by hand simply disappears from the list.
  Future<void> _load() async {
    await MetadataUpdateService.instance.reload();
    final data = await AnimeStorage.load();
    final byId = {for (final a in data.animes) a.id: a};
    final store = MetadataUpdateService.instance.store;

    final proposals = <_Proposal>[];
    for (final entry in store.entries) {
      if (!entry.isPending) continue;
      final anime = byId[entry.animeId];
      if (anime == null) continue;
      final candidate = entry.candidate;
      final changes = candidate == null
          ? const <MetadataFieldChange>[]
          : diffCandidate(anime, candidate);
      if (changes.isEmpty &&
          entry.status != MetadataUpdateStatus.needsManualPick) {
        continue;
      }
      proposals.add((anime: anime, entry: entry, changes: changes));
    }
    proposals.sort(
      (a, b) => a.anime.displayTitle.compareTo(b.anime.displayTitle),
    );

    if (!mounted) return;
    setState(() {
      _proposals = proposals;
      for (final p in proposals) {
        _selected.putIfAbsent(
          p.anime.id,
          () => p.changes.map((c) => c.field).toSet(),
        );
      }
      _loading = false;
    });
  }

  /// Purpose: List the proposals that a batch action may apply.
  /// Inputs: `scopeIds` — restrict to these anime, or empty for all.
  /// Returns: `List<_Proposal>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Entries needing a
  /// manual pick are excluded — a batch action must never guess between
  /// candidates the service itself could not separate.
  List<_Proposal> _batchable(List<String> scopeIds) => _proposals
      .where(
        (p) =>
            p.entry.status == MetadataUpdateStatus.proposed &&
            p.changes.isNotEmpty &&
            (scopeIds.isEmpty || scopeIds.contains(p.anime.id)),
      )
      .toList();

  /// Purpose: Apply one reviewed proposal.
  /// Inputs: `proposal`.
  /// Returns: None.
  /// Side effects: Writes the anime record, may download a cover, reloads.
  /// Notes: Internal helper used within this file only.
  Future<void> _apply(_Proposal proposal) async {
    final l10n = AppLocalizations.of(context)!;
    final fields = _selected[proposal.anime.id] ?? const <MetadataField>{};
    if (fields.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.metaUpdatesNothingSelected)));
      return;
    }
    setState(() => _working = true);
    await MetadataUpdateService.instance.applyProposal(proposal.anime, fields);
    if (!mounted) return;
    _selected.remove(proposal.anime.id);
    await _load();
    if (!mounted) return;
    setState(() => _working = false);
  }

  /// Purpose: Reject one proposal.
  /// Inputs: `proposal`.
  /// Returns: None.
  /// Side effects: Updates the local cache and reloads.
  /// Notes: Internal helper used within this file only.
  Future<void> _dismiss(_Proposal proposal) async {
    setState(() => _working = true);
    await MetadataUpdateService.instance.dismissProposal(proposal.anime.id);
    if (!mounted) return;
    _selected.remove(proposal.anime.id);
    await _load();
    if (!mounted) return;
    setState(() => _working = false);
  }

  /// Purpose: Apply every batchable proposal in a scope, after confirmation.
  /// Inputs: `scopeIds` — empty means the whole library; `requireSecondConfirm`.
  /// Returns: None.
  /// Side effects: Shows confirmation dialogs, then writes each accepted record.
  /// Notes: Internal helper used within this file only. "Update all" asks
  /// **twice** — a single mis-tap must not be able to rewrite the whole
  /// library. This deliberately does not reuse `confirmDelete`'s "don't ask for
  /// 5 minutes" suppression, which would defeat the second prompt entirely.
  Future<void> _applyBatch(
    List<String> scopeIds, {
    required bool requireSecondConfirm,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final targets = _batchable(scopeIds);
    if (targets.isEmpty) return;

    final manualCount = _proposals
        .where((p) => p.entry.status == MetadataUpdateStatus.needsManualPick)
        .length;

    final first = await _confirm(
      title: l10n.metaUpdatesConfirmTitle,
      message: scopeIds.isEmpty
          ? l10n.metaUpdatesConfirmAll(targets.length)
          : l10n.metaUpdatesConfirmPage(targets.length),
      detail: manualCount > 0
          ? l10n.metaUpdatesExcludedManual(manualCount)
          : null,
    );
    if (first != true || !mounted) return;

    if (requireSecondConfirm) {
      final second = await _confirm(
        title: l10n.metaUpdatesConfirmTitle,
        message: l10n.metaUpdatesConfirmAgain(targets.length),
      );
      if (second != true || !mounted) return;
    }

    setState(() => _working = true);
    var applied = 0;
    for (final proposal in targets) {
      final fields = _selected[proposal.anime.id] ?? const <MetadataField>{};
      if (fields.isEmpty) continue;
      final ok = await MetadataUpdateService.instance.applyProposal(
        proposal.anime,
        fields,
      );
      if (ok) applied++;
      _selected.remove(proposal.anime.id);
    }
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    setState(() => _working = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.metaUpdatesApplied(applied))));
  }

  /// Purpose: Show a yes/no dialog.
  /// Inputs: `title`, `message`, optional `detail`.
  /// Returns: `Future<bool?>`.
  /// Side effects: Shows a dialog.
  /// Notes: Internal helper used within this file only.
  Future<bool?> _confirm({
    required String title,
    required String message,
    String? detail,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(detail, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.metaUpdatesApply),
          ),
        ],
      ),
    );
  }

  // ── Formatting ──

  /// Purpose: Localize a proposable field's name.
  /// Inputs: `field`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Reuses the labels the
  /// edit page already shows, so the same field never has two names.
  String _fieldLabel(MetadataField field, AppLocalizations l10n) {
    switch (field) {
      case MetadataField.title:
        return l10n.animeTitle;
      case MetadataField.titleJa:
        return l10n.animeTitleJa;
      case MetadataField.endEpisode:
        return l10n.animeEndEp;
      case MetadataField.firstAirDate:
        return l10n.animeFirstAirDate;
      case MetadataField.airDayOfWeek:
        return l10n.animeAirDay;
      case MetadataField.airTime:
        return l10n.animeAirTime;
      case MetadataField.coverImage:
        return l10n.searchCoverImage;
      case MetadataField.infoUrl:
        return l10n.animeInfoUrl;
      case MetadataField.notes:
        return l10n.animeNotes;
    }
  }

  /// Purpose: Render a field value for the before/after columns.
  /// Inputs: `field`, `value`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Dates use the locale's
  /// short form and weekdays the same names the settings page uses.
  String _formatValue(
    MetadataField field,
    Object? value,
    AppLocalizations l10n,
  ) {
    if (value == null) return l10n.metaUpdatesEmptyValue;
    if (value is String && value.trim().isEmpty) {
      return l10n.metaUpdatesEmptyValue;
    }
    switch (field) {
      case MetadataField.firstAirDate:
        return DateFormat.yMd().format(value as DateTime);
      case MetadataField.airDayOfWeek:
        return _weekdayLabel(value as int, l10n);
      case MetadataField.notes:
        final text = value as String;
        return text.length > 120 ? '${text.substring(0, 120)}…' : text;
      case MetadataField.coverImage:
        // The proposed value is a remote URL. Printing it in full is a clipped
        // wall of text that says nothing the thumbnail above does not already
        // show, so name the host it will be fetched from instead.
        final url = value as String;
        final host = Uri.tryParse(url)?.host;
        return host == null || host.isEmpty ? url : host;
      default:
        return '$value';
    }
  }

  /// Purpose: Return a localized weekday label.
  /// Inputs: `weekday`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Weekday values use
  /// Dart's Monday=1 through Sunday=7 numbering.
  String _weekdayLabel(int weekday, AppLocalizations l10n) {
    final days = [
      '',
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    return days[weekday.clamp(1, 7)];
  }

  // ── Build ──

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final pageScope = widget.currentPageAnimeIds;
    final pageBatch = _batchable(pageScope);
    final allBatch = _batchable(const []);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.metaUpdatesTitle),
        actions: [
          if (allBatch.isNotEmpty)
            PopupMenuButton<int>(
              icon: const Icon(Icons.done_all),
              tooltip: l10n.metaUpdatesApplyAll,
              onSelected: (choice) {
                if (choice == 0) {
                  _applyBatch(pageScope, requireSecondConfirm: false);
                } else {
                  _applyBatch(const [], requireSecondConfirm: true);
                }
              },
              itemBuilder: (context) => [
                if (pageScope.isNotEmpty && pageBatch.isNotEmpty)
                  PopupMenuItem(
                    value: 0,
                    child: Text(
                      '${l10n.metaUpdatesApplyPage} (${pageBatch.length})',
                    ),
                  ),
                PopupMenuItem(
                  value: 1,
                  child: Text(
                    '${l10n.metaUpdatesApplyAll} (${allBatch.length})',
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _proposals.isEmpty
          ? _buildEmpty(theme, l10n)
          : Stack(
              children: [
                ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _proposals.length,
                  itemBuilder: (context, i) =>
                      _buildProposalCard(_proposals[i], theme, l10n),
                ),
                if (_working)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x33000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }

  /// Purpose: Render the empty state.
  /// Inputs: `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildEmpty(ThemeData theme, AppLocalizations l10n) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_done_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(l10n.metaUpdatesEmpty, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l10n.metaUpdatesEmptyHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
  );

  /// Purpose: Render one proposal as a reviewable card.
  /// Inputs: `proposal`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Every field carries its
  /// own checkbox, so a user can accept the episode count and refuse the
  /// synopsis.
  Widget _buildProposalCard(
    _Proposal proposal,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final manual = proposal.entry.status == MetadataUpdateStatus.needsManualPick;
    final selected = _selected[proposal.anime.id] ?? const <MetadataField>{};
    final candidate = proposal.entry.candidate;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildThumbnail(proposal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        proposal.anime.displayTitle,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (candidate != null)
                            l10n.metaUpdatesFrom(candidate.source),
                          // Only meaningful when a candidate is actually being
                          // offered. On a manual-pick card the title can still
                          // score 100% while a rival *work* scores nearly the
                          // same, so showing it beside "no match was clear
                          // enough" reads as a contradiction.
                          if (!manual)
                            l10n.metaUpdatesMatch(
                              (proposal.entry.relevance * 100).round().clamp(
                                0,
                                100,
                              ),
                            ),
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (manual) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.metaUpdatesManualPickHint,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ] else
              for (final change in proposal.changes)
                _buildChangeRow(proposal, change, selected, theme, l10n),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _working ? null : () => _dismiss(proposal),
                  child: Text(l10n.metaUpdatesDismiss),
                ),
                const SizedBox(width: 8),
                if (!manual)
                  FilledButton(
                    onPressed: _working ? null : () => _apply(proposal),
                    child: Text(l10n.metaUpdatesApply),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Purpose: Render one field's checkbox and before/after values.
  /// Inputs: `proposal`, `change`, `selected`, `theme`, `l10n`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildChangeRow(
    _Proposal proposal,
    MetadataFieldChange change,
    Set<MetadataField> selected,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final checked = selected.contains(change.field);
    return InkWell(
      onTap: () => setState(() {
        final set = _selected.putIfAbsent(
          proposal.anime.id,
          () => <MetadataField>{},
        );
        if (checked) {
          set.remove(change.field);
        } else {
          set.add(change.field);
        }
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: checked,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (_) => setState(() {
                  final set = _selected.putIfAbsent(
                    proposal.anime.id,
                    () => <MetadataField>{},
                  );
                  if (checked) {
                    set.remove(change.field);
                  } else {
                    set.add(change.field);
                  }
                }),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 84,
              child: Text(
                _fieldLabel(change.field, l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  Text(
                    _formatValue(change.field, change.currentValue, l10n),
                    style: theme.textTheme.bodySmall?.copyWith(
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Icon(Icons.arrow_right_alt, size: 16),
                  Text(
                    _formatValue(change.field, change.proposedValue, l10n),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Purpose: Render the candidate's cover thumbnail.
  /// Inputs: `proposal`.
  /// Returns: `Widget`.
  /// Side effects: May issue a network image request.
  /// Notes: Internal helper used within this file only. Uses the prefetched
  /// file when cover prefetch is on, and otherwise streams the source URL —
  /// which is why prefetch can stay off by default without costing the review
  /// screen anything.
  Widget _buildThumbnail(_Proposal proposal) {
    const size = Size(44, 62);
    final cached = proposal.entry.coverCachePath;
    final url = proposal.entry.candidate?.coverImageUrl;

    Widget placeholder() => Container(
      width: size.width,
      height: size.height,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.image_not_supported_outlined, size: 18),
    );

    if (cached != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: FutureBuilder<File>(
          future: ImageService.resolve(cached),
          builder: (context, snapshot) {
            final file = snapshot.data;
            if (file == null || !file.existsSync()) return placeholder();
            return Image.file(
              file,
              width: size.width,
              height: size.height,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    }
    if (url == null) return placeholder();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder(),
      ),
    );
  }
}
