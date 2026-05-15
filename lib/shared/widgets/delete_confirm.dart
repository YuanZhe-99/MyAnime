import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Global "don't ask" state: if non-null and still in the future, skip confirmation.
DateTime? _suppressUntil;

/// Purpose: Ask the user to confirm deletion and optionally suppress prompts briefly.
/// Inputs: `context`, `itemLabel`.
/// Returns: `Future<bool>`.
/// Side effects: May read or mutate application state, storage, or service resources.
/// Notes: Returns immediately when the global suppression window is still active.
Future<bool> confirmDelete(BuildContext context, String itemLabel) async {
  // If suppressed, allow immediately
  if (_suppressUntil != null && DateTime.now().isBefore(_suppressUntil!)) {
    return true;
  }

  bool dontAsk = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.commonDelete ?? 'Confirm Delete',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)?.commonDeleteConfirm(itemLabel) ??
                  'Delete $itemLabel?',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: dontAsk,
                    onChanged: (v) =>
                        setDialogState(() => dontAsk = v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)?.commonDontAskMinutes ??
                        "Don't ask for 5 minutes",
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(context)?.commonDelete ?? 'Delete'),
          ),
        ],
      ),
    ),
  );

  if (result == true && dontAsk) {
    _suppressUntil = DateTime.now().add(const Duration(minutes: 5));
  }
  return result ?? false;
}
