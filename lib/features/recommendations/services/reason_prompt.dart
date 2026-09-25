/// Versioned prompt for recommendation reasons, in the style of
/// `prompt_templates.dart`: English instructions, prose requested in the UI
/// language with Apple's exact locale phrase, and a version that is part of
/// nothing cached — reasons live in memory for one session only.
library;

/// Version of [reasonInstructions] and [reasonPrompt].
const int reasonPromptVersion = 1;

/// Purpose: Build the system instructions for writing recommendation reasons.
/// Inputs: `localeTag` — e.g. `zh_CN`, `zh_TW`, `ja_JP`, `en_US`;
/// `languageName` — the language to write in, in English, e.g. `Japanese`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Uses Apple's exact locale phrase. The model picks by number only and
/// is never asked to name a title that is not in the list.
String reasonInstructions(String localeTag, String languageName) =>
    'The person\'s locale is $localeTag. '
    'You help choose what to watch next from the person\'s own anime list. '
    'Pick up to three of the numbered candidates that best fit their taste, '
    'and for each write one short reason in $languageName, under 20 words. '
    'Use only the facts given. Answer one line per pick, exactly in the form '
    '"<number>: <reason>", with no other text.';

/// One candidate as the reason prompt describes it.
class ReasonCandidate {
  /// The number the model answers with, from 1.
  final int number;

  /// The title.
  final String title;

  /// Category labels, in English ids.
  final List<String> categories;

  /// Studios.
  final List<String> studios;

  /// Short deterministic facts, e.g. `next after Frieren`.
  final List<String> facts;

  /// Purpose: Create a reason candidate.
  /// Inputs: `number`, `title`, `categories`, `studios`, `facts`.
  /// Returns: A new `ReasonCandidate`.
  /// Side effects: None.
  /// Notes: None.
  const ReasonCandidate({
    required this.number,
    required this.title,
    this.categories = const [],
    this.studios = const [],
    this.facts = const [],
  });
}

/// Purpose: Build the prompt for writing recommendation reasons.
/// Inputs: `candidates` — at most eight; `topCategories`, `topStudios`;
/// `recent` — recently completed titles with the user's rating, if any.
/// Returns: `String`.
/// Side effects: None.
/// Notes: A compact profile, never notes or episode-level history.
String reasonPrompt({
  required List<ReasonCandidate> candidates,
  required List<String> topCategories,
  required List<String> topStudios,
  required List<(String, double?)> recent,
}) {
  final b = StringBuffer('Taste:\n');
  if (topCategories.isNotEmpty) {
    b.writeln('- Likes: ${topCategories.join(', ')}');
  }
  if (topStudios.isNotEmpty) {
    b.writeln('- Studios they liked: ${topStudios.join(', ')}');
  }
  for (final (title, rating) in recent) {
    b.writeln(
      '- Finished: $title${rating == null ? '' : ' (rated ${rating.toStringAsFixed(1)}/10)'}',
    );
  }
  b.writeln('Candidates:');
  for (final c in candidates) {
    final parts = [
      if (c.categories.isNotEmpty) c.categories.join(', '),
      if (c.studios.isNotEmpty) 'studio ${c.studios.join(', ')}',
      ...c.facts,
    ];
    b.writeln(
      '${c.number}. ${c.title}${parts.isEmpty ? '' : ' — ${parts.join('; ')}'}',
    );
  }
  return b.toString().trimRight();
}

/// Version of [relatedReasonInstructions] and [relatedReasonPrompt] (1.6.2).
const int relatedReasonPromptVersion = 1;

/// Purpose: Build the system instructions for explaining related records.
/// Inputs: `localeTag` — e.g. `zh_CN`; `languageName` — in English.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Same contract as [reasonInstructions]: the model picks by number,
/// writes at most three reasons, and never names a title that is not listed.
String relatedReasonInstructions(String localeTag, String languageName) =>
    'The person\'s locale is $localeTag. '
    'You explain why anime in the person\'s own list are similar to one '
    'anime they are looking at. Pick up to three of the numbered candidates '
    'that are most alike to it, and for each write one short reason in '
    '$languageName, under 20 words, about what they have in common. '
    'Use only the facts given. Answer one line per pick, exactly in the form '
    '"<number>: <reason>", with no other text.';

/// Purpose: Build the prompt for explaining related records.
/// Inputs: `subject` — the record being viewed (its `number` is ignored);
/// `candidates` — at most five related records.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Titles, categories, studios and deterministic facts only; never
/// notes, ratings or episode history.
String relatedReasonPrompt({
  required ReasonCandidate subject,
  required List<ReasonCandidate> candidates,
}) {
  String describe(ReasonCandidate c) {
    final parts = [
      if (c.categories.isNotEmpty) c.categories.join(', '),
      if (c.studios.isNotEmpty) 'studio ${c.studios.join(', ')}',
      ...c.facts,
    ];
    return '${c.title}${parts.isEmpty ? '' : ' — ${parts.join('; ')}'}';
  }

  final b = StringBuffer('Looking at: ${describe(subject)}\n');
  b.writeln('Candidates:');
  for (final c in candidates) {
    b.writeln('${c.number}. ${describe(c)}');
  }
  return b.toString().trimRight();
}
