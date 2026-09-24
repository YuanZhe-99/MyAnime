/// Versioned prompt templates for the on-device model.
///
/// Instructions are English on every platform: the small models follow English
/// instructions most reliably, and the categories are ids rather than prose.
/// Only prose the user will read (recommendation reasons) is requested in the
/// UI language, and Apple's guidance to state the locale with the exact phrase
/// `"The person's locale is <identifier>."` is followed there.
///
/// Changing a template's wording means bumping its version: the version is
/// part of every cached result's fingerprint, so old results are re-queued.
library;

import '../../anime/models/anime_category.dart';

/// Version of [classificationInstructions] and [classificationPrompt].
const int classificationPromptVersion = 1;

/// Purpose: Build the system instructions for classifying one work.
/// Inputs: None.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Lists every category id with its one-line description, asks for at
/// most three, and for `NONE` when unsure. On Apple the answer is also
/// constrained by the schema; on Android the line parser enforces it.
String classificationInstructions() {
  final lines = [
    for (final c in animeCategories) '- ${c.id}: ${c.description}',
  ].join('\n');
  return 'You classify anime. Choose at most three category ids from this '
      'list that clearly describe the work:\n$lines\n'
      'Use only the facts given. Answer with the ids only, separated by '
      'commas, on one line. If you are unsure, answer NONE.';
}

/// The facts about one work that classification may use. Never notes, ratings
/// or viewing progress: only what describes the work itself.
class ClassificationInput {
  /// Every title the work is known by, capped at five.
  final List<String> titles;

  /// Release format, e.g. `TV`.
  final String? format;

  /// Year of the first episode.
  final int? year;

  /// The app's episode-count type, e.g. `singleCour`.
  final String? type;

  /// Episode count, when known.
  final int? episodes;

  /// Studios.
  final List<String> studios;

  /// The source databases' raw genre and tag names.
  final List<String> genres;

  /// Purpose: Create the classification input.
  /// Inputs: `titles`, `format`, `year`, `type`, `episodes`, `studios`,
  /// `genres`.
  /// Returns: A new `ClassificationInput`.
  /// Side effects: None.
  /// Notes: None.
  const ClassificationInput({
    required this.titles,
    this.format,
    this.year,
    this.type,
    this.episodes,
    this.studios = const [],
    this.genres = const [],
  });

  /// Purpose: Serialize the input for fingerprinting.
  /// Inputs: None.
  /// Returns: `String` — stable across runs.
  /// Side effects: None.
  /// Notes: The order of fields and list items is fixed.
  String canonical() => [
    titles.join('|'),
    format ?? '',
    year?.toString() ?? '',
    type ?? '',
    episodes?.toString() ?? '',
    studios.join('|'),
    genres.join('|'),
  ].join('\n');
}

/// Purpose: Build the prompt for classifying one work.
/// Inputs: `input`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: One work per prompt (batch size 1) until latency has been measured
/// on a device.
String classificationPrompt(ClassificationInput input) {
  final b = StringBuffer('Anime:\n');
  b.writeln('- Titles: ${input.titles.join(' / ')}');
  if (input.format != null) b.writeln('- Format: ${input.format}');
  if (input.year != null) b.writeln('- Year: ${input.year}');
  if (input.type != null) b.writeln('- Length: ${input.type}');
  if (input.episodes != null) b.writeln('- Episodes: ${input.episodes}');
  if (input.studios.isNotEmpty) {
    b.writeln('- Studios: ${input.studios.join(', ')}');
  }
  if (input.genres.isNotEmpty) {
    b.writeln('- Tags: ${input.genres.join(', ')}');
  }
  b.write('Category ids:');
  return b.toString();
}
