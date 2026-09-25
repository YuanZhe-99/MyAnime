import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../categories/services/category_service.dart';
import '../models/anime_category.dart';

/// Purpose: Return the localized label of a category id.
/// Inputs: `id`, `l10n`.
/// Returns: `String` — the id itself for an id this build does not know.
/// Side effects: None.
/// Notes: Every id in `animeCategories` has a label in all four languages;
/// `test/categories_test.dart` checks that.
String categoryLabel(String id, AppLocalizations l10n) => switch (id) {
  'action' => l10n.categoryAction,
  'adventure' => l10n.categoryAdventure,
  'comedy' => l10n.categoryComedy,
  'drama' => l10n.categoryDrama,
  'romance' => l10n.categoryRomance,
  'slice_of_life' => l10n.categorySliceOfLife,
  'fantasy' => l10n.categoryFantasy,
  'isekai' => l10n.categoryIsekai,
  'sci_fi' => l10n.categorySciFi,
  'mecha' => l10n.categoryMecha,
  'mystery' => l10n.categoryMystery,
  'suspense' => l10n.categorySuspense,
  'horror' => l10n.categoryHorror,
  'psychological' => l10n.categoryPsychological,
  'supernatural' => l10n.categorySupernatural,
  'sports' => l10n.categorySports,
  'music' => l10n.categoryMusic,
  'school' => l10n.categorySchool,
  'historical' => l10n.categoryHistorical,
  'military' => l10n.categoryMilitary,
  'gourmet' => l10n.categoryGourmet,
  'healing' => l10n.categoryHealing,
  'magical_girl' => l10n.categoryMagicalGirl,
  _ => id,
};

/// The detail page's category chips and their edit button.
class CategoryChips extends StatelessWidget {
  /// The record's effective categories.
  final EffectiveCategories categories;

  /// Opens the edit sheet.
  final VoidCallback onEdit;

  /// Purpose: Create the category chips.
  /// Inputs: `categories`, `onEdit`.
  /// Returns: A new `CategoryChips`.
  /// Side effects: None.
  /// Notes: Shown only while automatic categories are on. AI-suggested chips
  /// carry a sparkle and the "may be wrong" tooltip; the user's own carry a
  /// person icon and "Chosen by you"; mapped ones carry neither.
  const CategoryChips({
    super.key,
    required this.categories,
    required this.onEdit,
  });

  /// Purpose: Build the chips.
  /// Inputs: `context`.
  /// Returns: A `Wrap`.
  /// Side effects: None.
  /// Notes: Since 1.6.3 the chips are compact and *Edit categories* is a
  /// small icon button at the end of the row (its label is the tooltip),
  /// part of the detail-page header redesign.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, tip) = switch (categories.origin) {
      CategoryOrigin.ai => (Icons.auto_awesome, l10n.aiGeneratedLabel),
      CategoryOrigin.user => (Icons.person_outline, l10n.categoriesYours),
      _ => (null, null),
    };
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final id in categories.ids)
          if (tip == null)
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(categoryLabel(id, l10n)),
            )
          else
            Tooltip(
              message: tip,
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(icon, size: 16),
                label: Text(categoryLabel(id, l10n)),
              ),
            ),
        if (categories.ids.isEmpty)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(l10n.categoriesNone),
          ),
        IconButton(
          tooltip: l10n.categoriesEdit,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: onEdit,
        ),
      ],
    );
  }
}

/// What the edit sheet returns.
sealed class CategoryEditResult {
  /// Purpose: Create an edit result.
  /// Inputs: None.
  /// Returns: A result.
  /// Side effects: None.
  /// Notes: None.
  const CategoryEditResult();
}

/// The user chose these ids (possibly none).
final class CategoriesChosen extends CategoryEditResult {
  /// The chosen ids, in taxonomy order.
  final List<String> ids;

  /// Purpose: Create the result.
  /// Inputs: `ids`.
  /// Returns: A new `CategoriesChosen`.
  /// Side effects: None.
  /// Notes: None.
  const CategoriesChosen(this.ids);
}

/// The user asked to go back to automatic categories.
final class CategoriesReset extends CategoryEditResult {
  /// Purpose: Create the result.
  /// Inputs: None.
  /// Returns: A new `CategoriesReset`.
  /// Side effects: None.
  /// Notes: None.
  const CategoriesReset();
}

/// Purpose: Let the user pick a record's categories.
/// Inputs: `context`, `initial` — the ids to start from; `hasOverride` —
/// whether the record already has the user's own list.
/// Returns: `Future<CategoryEditResult?>` — null when dismissed.
/// Side effects: Shows a bottom sheet or, where `canSplitLayout` allows, a
/// dialog.
/// Notes: Ids this build does not know are not offered; the caller keeps
/// them on the record.
Future<CategoryEditResult?> showCategoryEditor(
  BuildContext context, {
  required List<String> initial,
  required bool hasOverride,
}) {
  final screen = MediaQuery.sizeOf(context);
  final body = _CategoryEditor(initial: initial, hasOverride: hasOverride);
  if (canSplitLayout(screen.width, screen.height)) {
    return showDialog<CategoryEditResult>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: body,
        ),
      ),
    );
  }
  return showModalBottomSheet<CategoryEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => body,
  );
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.initial, required this.hasOverride});

  final List<String> initial;
  final bool hasOverride;

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final Set<String> _chosen = {...widget.initial};

  /// Purpose: Build the chip grid and actions.
  /// Inputs: `context`.
  /// Returns: The widget tree.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.categoriesTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in animeCategories)
                FilterChip(
                  label: Text(categoryLabel(c.id, l10n)),
                  selected: _chosen.contains(c.id),
                  onSelected: (on) => setState(
                    () => on ? _chosen.add(c.id) : _chosen.remove(c.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.hasOverride)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const CategoriesReset()),
                  child: Text(l10n.categoriesReset),
                ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.cancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  CategoriesChosen([
                    for (final c in animeCategories)
                      if (_chosen.contains(c.id)) c.id,
                  ]),
                ),
                child: Text(l10n.save),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
