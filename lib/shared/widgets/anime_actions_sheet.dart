import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';
import '../../l10n/app_localizations.dart';
import 'delete_confirm.dart';

/// One action a user can pick from the anime long-press sheet.
enum _AnimeQuickAction { edit, delete }

/// Purpose: Show one anime's full name and its edit and delete actions.
/// Inputs: `context` — a page context that outlives the sheet; `anime`.
/// Returns: `Future<bool>` — true when the anime was edited or deleted, so the
/// caller should reload its list.
/// Side effects: Shows a modal bottom sheet; may navigate to the edit page,
/// show a delete confirmation, and delete the anime from storage.
/// Notes: The list rows in all three data-browsing modules truncate the title
/// to a single line, so this sheet renders every stored title in full — no
/// `maxLines`, selectable, free to wrap — which is the reason it exists. The
/// sheet is dismissed before the chosen action runs so the confirmation dialog
/// and the edit route use the caller's still-mounted context rather than the
/// sheet's.
Future<bool> showAnimeActionsSheet(BuildContext context, Anime anime) async {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final titles = <String>[
    if (anime.title?.isNotEmpty == true) anime.title!,
    if (anime.titleJa?.isNotEmpty == true && anime.titleJa != anime.title)
      anime.titleJa!,
  ];

  final action = await showModalBottomSheet<_AnimeQuickAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < titles.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                    child: SelectableText(
                      titles[i],
                      style: i == 0
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text(l10n.animeEdit),
            onTap: () => Navigator.pop(sheetContext, _AnimeQuickAction.edit),
          ),
          ListTile(
            leading: Icon(Icons.delete, color: theme.colorScheme.error),
            title: Text(
              l10n.delete,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            onTap: () => Navigator.pop(sheetContext, _AnimeQuickAction.delete),
          ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return false;

  switch (action) {
    case _AnimeQuickAction.edit:
      await context.push('/anime/edit/${anime.id}');
      return true;
    case _AnimeQuickAction.delete:
      final confirmed = await confirmDelete(context, anime.displayTitle);
      if (!confirmed) return false;
      await AnimeStorage.deleteAnime(anime.id);
      return true;
  }
}
