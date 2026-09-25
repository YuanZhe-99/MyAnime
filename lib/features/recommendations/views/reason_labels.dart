import '../../../l10n/app_localizations.dart';
import '../../anime/models/anime.dart';
import '../../anime/views/category_widgets.dart';
import '../services/recommendation_service.dart';

/// Purpose: Word one recommendation reason chip.
/// Inputs: `reason`, `l10n`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Shared by the global page and the detail page's related card
/// (1.6.2). The `switch` is exhaustive over the sealed class, so a new reason
/// type cannot ship without a label.
String reasonLabel(RecommendationReason reason, AppLocalizations l10n) =>
    switch (reason) {
      NextAfterReason(:final previous) => l10n.reasonNextAfter(
        previous.displayTitle,
      ),
      CategoryMatchReason(:final categoryIds) => l10n.reasonLikeCategories(
        categoryIds.map((id) => categoryLabel(id, l10n)).join(', '),
      ),
      SameStudioReason(:final liked) => l10n.reasonSameStudio(
        liked.displayTitle,
      ),
      ExternalScoreReason(:final source, :final score) =>
        '$source ${score.toStringAsFixed(1)}',
      CatchUpReason() => l10n.reasonCatchUp,
      SharedCategoriesReason(:final categoryIds) => l10n.reasonSharedCategories(
        categoryIds.map((id) => categoryLabel(id, l10n)).join(', '),
      ),
      SharedStudioReason(:final studio) => l10n.reasonSharedStudio(studio),
      RelatedByDatabaseReason(:final type) => switch (type) {
        AnimeRelationType.spinOff => l10n.seriesSuggestionSpinOff,
        AnimeRelationType.alternative => l10n.seriesSuggestionAlternative,
        _ => l10n.reasonRelatedByDatabase,
      },
      SharedTitleReason() => l10n.reasonSharedTitle,
    };
