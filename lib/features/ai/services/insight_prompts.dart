import 'insight_language.dart';
import 'output_validation.dart';

/// Bump when any wording below, or the facts a builder emits, changes in a
/// way that should replace cached insights. Part of every fingerprint. The
/// statistics insight cards start at 1 (MyAnime 1.9.1).
const int insightPromptVersion = 1;

/// The longest insight line shown, in characters. Longer lines are dropped,
/// not truncated. Thirty English words with a title or two can pass
/// 160, which is why this is 200 (same limit as MyDay!!!!!).
const int insightLineMaxLength = 200;

/// Output budget for one card. Up to four sentences of under 30 words, with
/// room for a small model that ignores the word limit on one of them.
const int insightMaxOutputTokens = 400;

/// Which card an insight belongs to: the Statistics page's summary or
/// ranking view. The name is the key in `ai_insight_cards.json`, so it must
/// never be renamed.
enum InsightModule { statsSummary, statsRanking }

/// One numbered answer the model is asked for.
class InsightSlot {
  /// Stable identifier, part of the canonical form.
  final String id;

  /// The English request shown to the model.
  final String ask;

  /// Purpose: Create a slot.
  /// Inputs: `id`, `ask`.
  /// Returns: A new `InsightSlot`.
  /// Side effects: None.
  /// Notes: None.
  const InsightSlot(this.id, this.ask);
}

/// The app-computed facts for one card and the answers requested.
///
/// Built only by the pure `*_insight_facts.dart` builders, which never put
/// free-text notes or identifying details into [lines].
class InsightFacts {
  /// Which card.
  final InsightModule module;

  /// English `- key: value` fact lines, already rounded and capped.
  final List<String> lines;

  /// The numbered answers requested, in order.
  final List<InsightSlot> slots;

  /// Titles, studios and categories that may appear in an answer; they
  /// are ignored by the script check so a Chinese sentence that quotes an
  /// English title is not discarded.
  final List<String> quotedTerms;

  /// Purpose: Create a facts value.
  /// Inputs: see fields.
  /// Returns: A new `InsightFacts`.
  /// Side effects: None.
  /// Notes: None.
  const InsightFacts({
    required this.module,
    required this.lines,
    required this.slots,
    this.quotedTerms = const [],
  });

  /// Purpose: Serialize the facts for fingerprinting.
  /// Inputs: None.
  /// Returns: `String` — stable for equal facts.
  /// Side effects: None.
  /// Notes: Changing any line or slot changes the fingerprint.
  String canonical() =>
      [module.name, ...lines, slots.map((s) => s.id).join('|')].join('\n');
}

/// Purpose: Build the system instructions for one card.
/// Inputs: `language`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Written in English with the locale sentence Apple documents; the
/// reply language is named explicitly. One template for both statistics
/// views; it asks for the pattern behind the numbers rather than the numbers
/// the page already shows.
String insightInstructions(InsightLanguage language) =>
    "The person's locale is ${language.localeTag}. "
    'You are an analytical assistant inside a personal anime-tracking app. '
    'Using only the facts given, answer each numbered question with one '
    'concise sentence in ${language.name}, under 30 words, in the form '
    '"<number>: <sentence>". '
    'NEVER merely restate counts, scores or totals already on screen; '
    'synthesize the change, pattern or contrast behind them and, where '
    'asked, give a concrete next step. Write titles exactly as the facts '
    'give them and never invent numbers or titles.';

/// Purpose: Build the prompt for one card.
/// Inputs: `facts`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Facts, then the numbered questions, then the exact reply template.
/// The template is what keeps a small model on the `<number>: <sentence>`
/// form; the questions are headed `Questions:` rather than `Answer:` so they
/// do not read as answers to be echoed (v1.5.1).
String insightPrompt(InsightFacts facts) {
  final b = StringBuffer('Facts:\n');
  for (final line in facts.lines) {
    b.writeln(line);
  }
  b.writeln();
  b.writeln('Questions:');
  for (var i = 0; i < facts.slots.length; i++) {
    b.writeln('${i + 1}. ${facts.slots[i].ask}');
  }
  b.writeln();
  final n = facts.slots.length;
  b.writeln(
    'Reply with exactly $n line${n == 1 ? '' : 's'}, one per question, '
    'in this form:',
  );
  for (var i = 0; i < n; i++) {
    b.writeln('${i + 1}: <sentence>');
  }
  return b.toString();
}

final _answerLine = RegExp(r'^\s*(\d+)\s*[:：.)、]\s*(.+?)\s*$');
final _bareNumber = RegExp(r'^\s*(\d+)\s*[:：.)、]?\s*$');
final _heading = RegExp(r'^\s*.{0,60}[:：]\s*$');
final _inlineMarks = RegExp(r'(```[a-zA-Z]*|\*\*|__|`)');

/// Purpose: Read the model's `<number>: <sentence>` lines.
/// Inputs: `reply`; `slotCount`; `languageCode` — `en`, `ja` or `zh`;
/// `quotedTerms` — user-typed words removed before the script check;
/// `asks` — the questions, so an echoed question is not taken as an answer.
/// Returns: `Map<int, String>` — slot number (1-based) to sentence.
/// Side effects: None.
/// Notes: Reasoning blocks (`stripThinking`), then bold and code marks are
/// stripped first; list markers are kept
/// because `1. ` is a numbering. Three shapes are accepted, in order of
/// preference: `<number>: <sentence>`; a number alone on a line with the
/// sentence on the next; and, only when no line is numbered at all, the first
/// `slotCount` prose lines in order. Unknown or repeated numbers, over-long
/// lines, echoed questions and lines in the wrong script are dropped. A
/// quoted term shorter than two runes is not removed before the script check,
/// because it would gut the prose it appears in.
Map<int, String> parseInsightReply(
  String reply,
  int slotCount,
  String languageCode, {
  List<String> quotedTerms = const [],
  List<String> asks = const [],
}) {
  final normalizedAsks = {for (final a in asks) _normalize(a)};
  String? accept(String raw) {
    final text = cleanSentence(raw, maxLength: insightLineMaxLength);
    if (text == null) return null;
    if (normalizedAsks.contains(_normalize(text))) return null;
    var scriptText = text;
    for (final term in quotedTerms) {
      if (term.runes.length >= 2) scriptText = scriptText.replaceAll(term, ' ');
    }
    // A sentence made only of quoted titles and numbers still has to carry
    // some prose in the right script.
    if (!matchesScript(scriptText, languageCode)) return null;
    return text;
  }

  // Only inline marks are removed here: `stripMarkdown` would also drop a
  // `1. ` list marker, which is the very number being looked for. That is
  // why a reply numbered `1. …` parsed to nothing in v1.5.0.
  // Reasoning goes first: a draft inside it looks like a numbered answer.
  final lines = stripThinking(reply).replaceAll(_inlineMarks, '').split('\n');
  final out = <int, String>{};
  var numbered = false;
  for (var i = 0; i < lines.length; i++) {
    var m = _answerLine.firstMatch(lines[i]);
    String? body;
    if (m != null) {
      body = m.group(2);
    } else {
      m = _bareNumber.firstMatch(lines[i]);
      if (m == null) continue;
      // `1:` alone, sentence on the next non-empty line.
      var j = i + 1;
      while (j < lines.length && lines[j].trim().isEmpty) {
        j++;
      }
      if (j >= lines.length || _answerLine.hasMatch(lines[j])) continue;
      body = lines[j];
      i = j;
    }
    numbered = true;
    final n = int.parse(m.group(1)!);
    if (n < 1 || n > slotCount || out.containsKey(n)) continue;
    final text = accept(body!);
    if (text != null) out[n] = text;
  }
  if (numbered || slotCount == 0) return out;
  // No numbering at all: take the prose lines in order.
  var n = 1;
  for (final line in lines) {
    if (n > slotCount) break;
    if (line.trim().isEmpty || _heading.hasMatch(line)) continue;
    final text = accept(line);
    if (text != null) out[n] = text;
    n++;
  }
  return out;
}

/// Purpose: Fold a line for the echoed-question comparison.
/// Inputs: `s`.
/// Returns: `String` — lower-case, without punctuation or spaces.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String _normalize(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s\p{P}]+', unicode: true), '');

/// Purpose: Shorten a user-typed title for a fact line.
/// Inputs: `title`, `maxRunes`.
/// Returns: `String` — single-line, trimmed, with `…` when cut.
/// Side effects: None.
/// Notes: Used by the fact builders for device names.
String clipTitle(String title, int maxRunes) {
  final t = title.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = t.runes.toList();
  if (runes.length <= maxRunes) return t;
  return '${String.fromCharCodes(runes.take(maxRunes))}…';
}

/// Purpose: Format a number for a fact line.
/// Inputs: `value`, `digits`.
/// Returns: `String` without trailing zeros.
/// Side effects: None.
/// Notes: Keeps fingerprints stable across float noise.
String factNumber(double value, [int digits = 1]) {
  final s = value.toStringAsFixed(digits);
  if (!s.contains('.')) return s;
  return s.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Purpose: Format a date as `yyyy-MM-dd` for a fact line.
/// Inputs: `d`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Local calendar date.
String factDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
