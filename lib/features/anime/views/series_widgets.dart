import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../models/anime.dart';
import '../services/anime_search_service.dart';
import '../services/anime_storage.dart';
import '../services/series_service.dart';

/// The actions offered by the series card's menu.
enum SeriesAction {
  /// Open the manage sheet: search, suggestions, reorder.
  manage,

  /// Open the create page prefilled for the season after the last member.
  addNextSeason,

  /// Write `{"standalone": true}` on the current record.
  remove,

  /// Remove the current record's `seriesLink`.
  letAppDecide,
}

/// The detail page's *Series* card: every member in order, the current one
/// highlighted, and a menu of curation actions.
class SeriesCard extends StatelessWidget {
  /// The series the current record belongs to; at least two members.
  final AnimeSeries series;

  /// The record whose detail page shows the card.
  final Anime current;

  /// Opens another member's detail page.
  final ValueChanged<Anime> onOpen;

  /// Runs a menu action.
  final ValueChanged<SeriesAction> onAction;

  /// Purpose: Create a series card.
  /// Inputs: `series`, `current`, `onOpen`, `onAction`.
  /// Returns: A new `SeriesCard`.
  /// Side effects: None.
  /// Notes: The detail page shows it only for series with two or more
  /// members.
  const SeriesCard({
    super.key,
    required this.series,
    required this.current,
    required this.onOpen,
    required this.onAction,
  });

  /// Purpose: Build the card.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: "Let the app decide" is offered only when the record has a link
  /// of its own to remove.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 4),
              child: Row(
                children: [
                  const Icon(Icons.collections_bookmark_outlined, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.seriesTitle,
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          series.isCurated
                              ? l10n.seriesCurated
                              : l10n.seriesAuto,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<SeriesAction>(
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: SeriesAction.manage,
                        child: Text(l10n.seriesManage),
                      ),
                      PopupMenuItem(
                        value: SeriesAction.addNextSeason,
                        child: Text(l10n.seriesAddNext),
                      ),
                      PopupMenuItem(
                        value: SeriesAction.remove,
                        child: Text(l10n.seriesRemove),
                      ),
                      if (current.seriesLink != null)
                        PopupMenuItem(
                          value: SeriesAction.letAppDecide,
                          child: Text(l10n.seriesLetAppDecide),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < series.members.length; i++)
              _memberTile(context, series.members[i], i + 1),
          ],
        ),
      ),
    );
  }

  /// Purpose: Build one member row.
  /// Inputs: `context`, `anime`, `position` — 1-based.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. The current record is
  /// highlighted and not tappable.
  Widget _memberTile(BuildContext context, Anime anime, int position) {
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = anime.id == current.id;
    final total = anime.totalEpisodes;
    final watched = anime.episodeStatuses.values
        .where((s) => s == EpisodeStatus.watched)
        .length;
    return ListTile(
      dense: true,
      selected: isCurrent,
      leading: CircleAvatar(radius: 14, child: Text('$position')),
      title: Text(
        anime.displayTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        total != null
            ? '${anime.season} · $watched / $total ${l10n.animeEpisodes}'
            : anime.season,
      ),
      trailing: Icon(viewingStatusIcon(anime.viewingStatus), size: 20),
      onTap: isCurrent ? null : () => onOpen(anime),
    );
  }
}

/// Purpose: Pick an icon for a viewing status.
/// Inputs: `status`.
/// Returns: `IconData`.
/// Side effects: None.
/// Notes: Used by the series card and the manage sheet.
IconData viewingStatusIcon(AnimeViewingStatus status) => switch (status) {
  AnimeViewingStatus.completed => Icons.check_circle_outline,
  AnimeViewingStatus.watching => Icons.play_circle_outline,
  AnimeViewingStatus.dropped => Icons.remove_circle_outline,
  AnimeViewingStatus.notStarted => Icons.radio_button_unchecked,
};

/// Purpose: Open the series manage sheet for `anime`.
/// Inputs: `context`, `anime`, `index` — built from the current library.
/// Returns: `Future<bool>` — whether anything was written.
/// Side effects: May write records through `AnimeStorage.addOrUpdateAll`.
/// Notes: A bottom sheet on a narrow window and a dialog on a wide one, chosen
/// by `canSplitLayout` so it follows the app-wide split rule.
Future<bool> showSeriesManageSheet(
  BuildContext context, {
  required Anime anime,
  required SeriesIndex index,
}) async {
  final screen = MediaQuery.sizeOf(context);
  final sheet = SeriesManageSheet(anime: anime, index: index);
  final bool? changed;
  if (canSplitLayout(screen.width, screen.height)) {
    changed = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
          child: sheet,
        ),
      ),
    );
  } else {
    changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: sheet),
    );
  }
  return changed == true;
}

/// Search, suggestions and member order for one record's series.
class SeriesManageSheet extends StatefulWidget {
  /// The record the sheet was opened from.
  final Anime anime;

  /// The index the sheet's edits are computed against.
  final SeriesIndex index;

  /// Purpose: Create a series manage sheet.
  /// Inputs: `anime`, `index`.
  /// Returns: A new `SeriesManageSheet`.
  /// Side effects: None.
  /// Notes: Shown through [showSeriesManageSheet].
  const SeriesManageSheet({
    super.key,
    required this.anime,
    required this.index,
  });

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<SeriesManageSheet> createState() => _SeriesManageSheetState();
}

class _SeriesManageSheetState extends State<SeriesManageSheet> {
  final _query = TextEditingController();
  late List<Anime> _order;
  bool _orderChanged = false;
  bool _busy = false;

  /// Purpose: Initialise the member order from the index.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _order = [...?widget.index.seriesOf(widget.anime.id)?.members];
  }

  /// Purpose: Release the search controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// Purpose: Write the records an edit produced and close the sheet.
  /// Inputs: `writes`.
  /// Returns: None.
  /// Side effects: Writes `anime_data.json` once; pops the sheet with `true`.
  /// Notes: Internal helper used within this file only.
  Future<void> _apply(List<Anime> writes) async {
    if (_busy) return;
    setState(() => _busy = true);
    await AnimeStorage.addOrUpdateAll(writes);
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Purpose: Return library records matching the search text.
  /// Inputs: `query`.
  /// Returns: `List<Anime>` — at most 30, excluding the current record.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Matches folded
  /// titles by containment, so script and width differences do not matter.
  List<Anime> _search(String query) {
    final q = AnimeSearchService.foldTitle(query.trim());
    if (q.isEmpty) return const [];
    final out = <Anime>[];
    for (final s in widget.index.all) {
      if (s.id == widget.anime.id) continue;
      final hit = seriesTitlesOf(
        s,
      ).any((t) => AnimeSearchService.foldTitle(t).contains(q));
      if (hit) out.add(s);
      if (out.length >= 30) break;
    }
    return out;
  }

  /// Purpose: Build the sheet.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: With an empty search it shows suggestions and the reorderable
  /// member list; with text it shows matching records. Tapping a record links
  /// the current one to its series.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final editor = SeriesEditor(widget.index);
    final query = _query.text;
    final results = query.trim().isEmpty ? null : _search(query);
    final suggestions = widget.index.suggestionsFor(widget.anime.id);

    Widget recordTile(Anime a) => ListTile(
      leading: Icon(viewingStatusIcon(a.viewingStatus)),
      title: Text(a.displayTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(a.season),
      trailing: const Icon(Icons.link),
      enabled: !_busy,
      onTap: () => _apply(editor.link(widget.anime, a)),
    );

    return Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.seriesSearchHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: results != null
                ? (results.isEmpty
                      ? Center(child: Text(l10n.seriesNoMatches))
                      : ListView(
                          children: [for (final a in results) recordTile(a)],
                        ))
                : CustomScrollView(
                    slivers: [
                      if (suggestions.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: _header(theme, l10n.seriesSuggestions),
                        ),
                        SliverList.list(
                          children: [
                            for (final s in suggestions) recordTile(s.anime),
                          ],
                        ),
                      ],
                      if (_order.length >= 2) ...[
                        SliverToBoxAdapter(
                          child: _header(theme, l10n.seriesMembers),
                        ),
                        SliverReorderableList(
                          itemCount: _order.length,
                          onReorderItem: (from, to) => setState(() {
                            _order.insert(to, _order.removeAt(from));
                            _orderChanged = true;
                          }),
                          itemBuilder: (context, i) {
                            final a = _order[i];
                            return ListTile(
                              key: ValueKey(a.id),
                              selected: a.id == widget.anime.id,
                              leading: CircleAvatar(
                                radius: 14,
                                child: Text('${i + 1}'),
                              ),
                              title: Text(
                                a.displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(a.season),
                              trailing: ReorderableDragStartListener(
                                index: i,
                                child: const Icon(Icons.drag_handle),
                              ),
                            );
                          },
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: FilledButton(
                                onPressed: _orderChanged && !_busy
                                    ? () => _apply(
                                        editor.reorder(
                                          widget.index.seriesOf(
                                            widget.anime.id,
                                          )!,
                                          [for (final a in _order) a.id],
                                        ),
                                      )
                                    : null,
                                child: Text(l10n.seriesSaveOrder),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// Purpose: Build a section header.
  /// Inputs: `theme`, `text`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _header(ThemeData theme, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
    ),
  );
}
