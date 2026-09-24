/// Shared parsing and checking of on-device model output.
///
/// Everything a model says passes through here before it is shown or cached,
/// on both platforms: a small model ignores formats, wraps answers in
/// Markdown, and sometimes answers in the wrong script. Nothing here trusts the
/// reply; anything that does not fit is dropped.
library;

final _codeFence = RegExp(r'```[a-zA-Z]*');
final _markdownMarks = RegExp(
  r'(\*\*|__|`|^#+\s*|^\s*[-*•]\s+|^\s*\d+[.)]\s+)',
  multiLine: true,
);
final _itemSplit = RegExp(r'[,，、;；/\n|]+');
final _labelPrefix = RegExp(r'^[^:：]{0,40}[:：]\s*');

/// Purpose: Remove code fences and Markdown decoration from a reply.
/// Inputs: `text`.
/// Returns: `String` — trimmed plain text.
/// Side effects: None.
/// Notes: Removes fences, bold and italic markers, inline code ticks, headings,
/// bullets and list numbers. Line breaks are kept.
String stripMarkdown(String text) =>
    text.replaceAll(_codeFence, '').replaceAll(_markdownMarks, '').trim();

/// The result of reading a choice reply.
class ChoiceParse {
  /// Known option ids, deduplicated, in reply order, capped.
  final List<String> ids;

  /// Whether the model answered `NONE`.
  final bool none;

  /// Whether the reply followed the format at all. An invalid reply is
  /// dropped whole.
  final bool valid;

  /// Purpose: Create a choice parse result.
  /// Inputs: `ids`, `none`, `valid`.
  /// Returns: A new `ChoiceParse`.
  /// Side effects: None.
  /// Notes: None.
  const ChoiceParse(this.ids, {this.none = false, this.valid = true});

  /// A reply that ignored the format.
  static const invalid = ChoiceParse([], valid: false);
}

/// Purpose: Read a model's pick of ids from a list of options.
/// Inputs: `reply` — the raw text; `options` — the allowed ids; `maxItems`.
/// Returns: `ChoiceParse`.
/// Side effects: None.
/// Notes: Accepts `id, id`, one id per line, and `<label>: id, id`. Matching is
/// case-insensitive and treats spaces and hyphens like underscores, so
/// `slice of life` reads as `slice_of_life`. Unknown ids are dropped. A reply
/// whose only token is `NONE` (or `none`) is a valid empty answer; a reply
/// with no known id and no `NONE` is invalid.
ChoiceParse parseChoiceReply(
  String reply,
  List<String> options, {
  int maxItems = 3,
}) {
  final known = {for (final o in options) _normalizeId(o): o};
  final text = stripMarkdown(reply);
  if (text.isEmpty) return ChoiceParse.invalid;
  final ids = <String>[];
  var sawNone = false;
  for (final rawLine in text.split('\n')) {
    final line = rawLine.replaceFirst(_labelPrefix, '');
    for (final token in line.split(_itemSplit)) {
      final t = _normalizeId(token);
      if (t.isEmpty) continue;
      if (t == 'none') {
        sawNone = true;
        continue;
      }
      final id = known[t];
      if (id != null && !ids.contains(id)) ids.add(id);
    }
  }
  if (ids.isEmpty) {
    return sawNone ? const ChoiceParse([], none: true) : ChoiceParse.invalid;
  }
  return ChoiceParse(ids.length > maxItems ? ids.sublist(0, maxItems) : ids);
}

/// Purpose: Normalize a token for id matching.
/// Inputs: `s`.
/// Returns: `String` — lowercased, trimmed, with spaces and hyphens as
/// underscores and surrounding quotes and full stops removed.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String _normalizeId(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'''^["'「『（(\[]+|["'」』）)\].。]+$'''), '')
    .trim()
    .replaceAll(RegExp(r'[\s\-]+'), '_');

final _han = RegExp(r'\p{Script=Han}', unicode: true);
final _kana = RegExp(
  r'[\p{Script=Hiragana}\p{Script=Katakana}]',
  unicode: true,
);
final _latin = RegExp(r'[A-Za-z]');

/// Purpose: Check that generated prose is in the script the UI language uses.
/// Inputs: `text`; `languageCode` — `en`, `ja` or `zh` (either variant).
/// Returns: `bool`.
/// Side effects: None.
/// Notes: CJK (Han or kana) must dominate letters for `zh` and `ja`, and
/// Japanese needs at least one kana; for any other language Latin letters
/// must make up most of the letters. Titles quoted inside a reason are why
/// this is a proportion rather than an absolute rule.
bool matchesScript(String text, String languageCode) {
  final han = _han.allMatches(text).length;
  final kana = _kana.allMatches(text).length;
  final latin = _latin.allMatches(text).length;
  final letters = han + kana + latin;
  if (letters == 0) return false;
  switch (languageCode) {
    case 'zh':
      return (han + kana) / letters >= 0.6 && han > 0;
    case 'ja':
      return (han + kana) / letters >= 0.6 && kana > 0;
    default:
      return latin / letters >= 0.6;
  }
}

/// Purpose: Clean one generated sentence for display.
/// Inputs: `text`; `maxLength` — the longest acceptable result.
/// Returns: `String?` — the single-line, Markdown-free sentence, or null when
/// it is empty or longer than `maxLength`.
/// Side effects: None.
/// Notes: Over-long output is dropped rather than truncated, because a cut
/// sentence reads as a wrong one.
String? cleanSentence(String text, {int maxLength = 140}) {
  final t = stripMarkdown(text).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty || t.runes.length > maxLength) return null;
  return t;
}
