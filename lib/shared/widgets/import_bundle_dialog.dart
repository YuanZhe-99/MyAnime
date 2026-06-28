import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../features/anime/models/anime.dart';
import '../services/duplicate_service.dart';
import '../services/file_open_service.dart';

/// Resolution chosen for a single import conflict.
enum _ConflictResolution { keepLocal, useImported, merge }

/// Purpose: Run the full import-bundle flow with conflict resolution.
/// Inputs: `context`.
/// Returns: `Future<ImportBundleResult?>`.
/// Side effects: Shows file picker, dialogs, and writes to storage.
/// Notes: Returns null when the user cancels the file picker. Otherwise
/// returns the list of imported anime IDs (may be empty when all conflicts
/// were kept local).
Future<ImportBundleResult?> showImportBundleFlow(
  BuildContext context,
) async {
  final l10n = AppLocalizations.of(context)!;
  final bundle = await FileOpenService.pickAndParseBundle();
  if (bundle == null) return null;
  if (!context.mounted) return null;

  final skipIndices = <int>{};
  final mergeIndices = <int>{};

  if (bundle.hasConflicts) {
    for (final idx in bundle.conflictIndices) {
      if (!context.mounted) break;
      final imported = bundle.animes[idx];
      final local = bundle.localVersions[idx]!;

      final resolution = await showDialog<_ConflictResolution>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ImportConflictDialog(
          local: local,
          imported: imported,
        ),
      );

      if (resolution == null) {
        // User cancelled the whole flow.
        skipIndices.add(idx);
      } else if (resolution == _ConflictResolution.keepLocal) {
        skipIndices.add(idx);
      } else if (resolution == _ConflictResolution.useImported) {
        // Import as-is (new UUID already assigned, will be added).
      } else if (resolution == _ConflictResolution.merge) {
        mergeIndices.add(idx);
      }
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importBundleNoConflicts)),
    );
  }

  // Apply non-conflict records.
  final added = await FileOpenService.applyBundle(
    bundle,
    skipIndices: {...skipIndices, ...mergeIndices},
  );

  // Apply merged records.
  var mergedCount = 0;
  for (final idx in mergeIndices) {
    final imported = bundle.animes[idx];
    final local = bundle.localVersions[idx]!;
    final merged = DuplicateService.merge(local, [imported]);
    await FileOpenService.replaceAnime(local.id, merged);
    mergedCount++;
  }

  final totalImported = added + mergedCount;
  if (context.mounted && totalImported > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importBundleSuccess(totalImported))),
    );
  }

  // Collect imported IDs (non-skipped records that were added as new).
  final importedIds = <String>[];
  for (var i = 0; i < bundle.animes.length; i++) {
    if (skipIndices.contains(i)) continue;
    if (mergeIndices.contains(i)) {
      // Merged into existing local record.
      importedIds.add(bundle.localVersions[i]!.id);
    } else {
      importedIds.add(bundle.animes[i].id);
    }
  }

  return ImportBundleResult(
    importedIds: importedIds,
    count: totalImported,
  );
}

/// Result of an import bundle flow.
class ImportBundleResult {
  final List<String> importedIds;
  final int count;

  /// Purpose: Create an import bundle result instance.
  /// Inputs: `importedIds`, `count`.
  /// Returns: A new `ImportBundleResult` instance.
  /// Side effects: None.
  /// Notes: None.
  const ImportBundleResult({required this.importedIds, required this.count});
}

/// Purpose: Show a single import conflict resolution dialog.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Internal widget used within this file only.
class _ImportConflictDialog extends StatelessWidget {
  final Anime local;
  final Anime imported;

  /// Purpose: Create an import conflict dialog instance.
  /// Inputs: `local`, `imported`.
  /// Returns: A new `_ImportConflictDialog` instance.
  /// Side effects: None.
  /// Notes: None.
  const _ImportConflictDialog({required this.local, required this.imported});

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = imported.displayTitle.isNotEmpty
        ? imported.displayTitle
        : local.displayTitle;

    return AlertDialog(
      title: Text(l10n.importBundleConflictTitle(displayName)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importBundleConflictDesc),
            const SizedBox(height: 16),
            Text(
              l10n.importBundleLocalVersion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildSummary(local),
            const SizedBox(height: 12),
            Text(
              l10n.importBundleImportedVersion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            _buildSummary(imported),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ConflictResolution.keepLocal),
          child: Text(l10n.importBundleKeepLocal),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ConflictResolution.merge),
          child: Text(l10n.importBundleMerge),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ConflictResolution.useImported),
          child: Text(l10n.importBundleKeepImport),
        ),
      ],
    );
  }

  /// Purpose: Provide the internal build summary helper for this file.
  /// Inputs: `anime`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSummary(Anime anime) {
    final watchedCount = anime.episodeStatuses.values
        .where((s) => s == EpisodeStatus.watched)
        .length;
    final totalEps =
        (anime.endEpisode ?? anime.startEpisode) - anime.startEpisode + 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(anime.displayTitle.isNotEmpty ? anime.displayTitle : '(no title)'),
        if (anime.firstAirDate != null)
          Text(
            '${anime.firstAirDate!.year}-${anime.firstAirDate!.month.toString().padLeft(2, '0')}-${anime.firstAirDate!.day.toString().padLeft(2, '0')}',
          ),
        Text('$watchedCount/$totalEps'),
        if (anime.infoUrl != null) Text(anime.infoUrl!),
      ],
    );
  }
}
