/// Season-label helpers shared by the anime1.me lookup and the series index.
///
/// Everything here is pure string work: reading a season ordinal out of a
/// title or a season label, removing season markers so that two seasons of
/// one work fold to the same base title, and producing the label of the next
/// season.
library;

/// The ordinal given to a "final season" marker that carries no number, so it
/// sorts after every numbered season of the same work.
const int finalSeasonOrdinal = 99;

const _cjkDigits = '一二三四五六七八九';

final _cjkSeason = RegExp(r'第\s*([一二三四五六七八九十\d]+)\s*[季期]');
final _latinSeasonPatterns = [
  RegExp(r'season\s*(\d+)', caseSensitive: false),
  RegExp(r'(\d+)(?:st|nd|rd|th)\s+season', caseSensitive: false),
  RegExp(r'\bS(\d+)\b'),
  RegExp(r'part\s*(\d+)', caseSensitive: false),
];
final _bareKi = RegExp(r'(?<![\d第])(\d+)\s*期');
final _wordSeason = RegExp(
  r'\b(second|third|fourth|fifth|sixth)\s+season\b',
  caseSensitive: false,
);
const _wordOrdinals = {
  'second': 2,
  'third': 3,
  'fourth': 4,
  'fifth': 5,
  'sixth': 6,
};
final _finalMarker = RegExp(
  r'\bfinal\s+season\b|最终季|最終季|完结篇|完结编|完結編|完結篇',
  caseSensitive: false,
);
final _trailingRoman = RegExp(r'\s+(II|III|IV)\s*$');
const _romanOrdinals = {'II': 2, 'III': 3, 'IV': 4};

final _markerPatterns = [
  RegExp(r'第\s*[一二三四五六七八九十百零〇两\d]+\s*(?:季|期|部|クール)'),
  RegExp(r'(?<!\d)\d+\s*期'),
  RegExp(r'\b(?:the\s+)?final\s+season\b', caseSensitive: false),
  RegExp(r'\bseason\s*\d+\b', caseSensitive: false),
  RegExp(r'\b\d+(?:st|nd|rd|th)\s+season\b', caseSensitive: false),
  RegExp(
    r'\b(?:second|third|fourth|fifth|sixth)\s+season\b',
    caseSensitive: false,
  ),
  RegExp(r'\bS\d+\b'),
  RegExp(r'\bpart\s*\d+\b', caseSensitive: false),
  RegExp(r'\bcour\s*\d+\b', caseSensitive: false),
  RegExp(r'最终季|最終季|完结篇|完结编|完結編|完結篇'),
  RegExp(r'続編|续篇|續篇'),
];
final _emptyBrackets = RegExp(r'[\(（\[【「『〔]\s*[\)）\]】」』〕]');
final _trailingSeparators = RegExp(r'[\s:：\-－~～・|/]+$');
final _spaces = RegExp(r'\s+');

/// Purpose: Make full-width ASCII letters, digits and spaces half-width.
/// Inputs: `text`.
/// Returns: `String` — the same text with U+FF01–U+FF5E and U+3000 folded.
/// Side effects: None.
/// Notes: Titles such as `ゆるキャン△ SEASON２` mix widths; every other helper
/// here normalizes first so that one pattern covers both.
String halfWidthAscii(String text) {
  final buf = StringBuffer();
  for (final c in text.runes) {
    if (c >= 0xFF01 && c <= 0xFF5E) {
      buf.writeCharCode(c - 0xFEE0);
    } else if (c == 0x3000) {
      buf.write(' ');
    } else {
      buf.writeCharCode(c);
    }
  }
  return buf.toString();
}

/// Purpose: Read a season ordinal out of a title or season label.
/// Inputs: `text` — e.g. `第二季`, `第2期`, `Season 2`, `2nd Season`, `S2`, `Part 2`.
/// Returns: `int?` — `null` when no ordinal is present.
/// Side effects: None.
/// Notes: Chinese numerals up to 十 are understood. Moved here from
/// `Anime1Service` in 1.6.0 unchanged; `Anime1Service` still ranks with it.
int? seasonOrdinal(String text) {
  if (text.trim().isEmpty) return null;
  final cjk = _cjkSeason.firstMatch(text);
  if (cjk != null) return parseCjkNumber(cjk.group(1)!);
  for (final p in _latinSeasonPatterns) {
    final m = p.firstMatch(text);
    if (m != null) return int.tryParse(m.group(1)!);
  }
  return null;
}

/// Purpose: Parse a small Chinese or Arabic numeral.
/// Inputs: `s` — `2`, `二`, `十`, `十二`, `二十`.
/// Returns: `int?` — `null` for anything else.
/// Side effects: None.
/// Notes: Covers 1–99, which is every season number a title carries.
int? parseCjkNumber(String s) {
  final arabic = int.tryParse(s);
  if (arabic != null) return arabic;
  if (s == '十') return 10;
  if (s.length == 1) {
    final i = _cjkDigits.indexOf(s);
    return i < 0 ? null : i + 1;
  }
  if (s.startsWith('十') && s.length == 2) {
    final i = _cjkDigits.indexOf(s[1]);
    return i < 0 ? null : 10 + i + 1;
  }
  if (s.endsWith('十') && s.length == 2) {
    final i = _cjkDigits.indexOf(s[0]);
    return i < 0 ? null : (i + 1) * 10;
  }
  if (s.length == 3 && s[1] == '十') {
    final tens = _cjkDigits.indexOf(s[0]);
    final ones = _cjkDigits.indexOf(s[2]);
    return tens < 0 || ones < 0 ? null : (tens + 1) * 10 + ones + 1;
  }
  return null;
}

/// Purpose: Write a number from 1 to 99 as a Chinese numeral.
/// Inputs: `n`.
/// Returns: `String` — `二`, `十`, `十二`, `二十三`; Arabic digits outside 1–99.
/// Side effects: None.
/// Notes: The inverse of [parseCjkNumber] for the range it covers.
String toCjkNumber(int n) {
  if (n < 1 || n > 99) return '$n';
  if (n < 10) return _cjkDigits[n - 1];
  final tens = n ~/ 10;
  final ones = n % 10;
  final head = tens == 1 ? '十' : '${_cjkDigits[tens - 1]}十';
  return ones == 0 ? head : '$head${_cjkDigits[ones - 1]}';
}

/// Purpose: Read the season ordinal a title implies, more permissively than
/// [seasonOrdinal].
/// Inputs: `title`.
/// Returns: `int?` — the ordinal; [finalSeasonOrdinal] for an unnumbered
/// "final season" marker; `null` when the title carries no season marker.
/// Side effects: None.
/// Notes: Adds bare `N期`, `Second Season`-style words, the final-season
/// markers and a trailing Roman numeral II–IV to what [seasonOrdinal] reads,
/// after making full-width characters half-width.
int? titleSeasonOrdinal(String title) {
  final t = halfWidthAscii(title);
  final base = seasonOrdinal(t);
  if (base != null) return base;
  final ki = _bareKi.firstMatch(t);
  if (ki != null) return int.tryParse(ki.group(1)!);
  final word = _wordSeason.firstMatch(t);
  if (word != null) return _wordOrdinals[word.group(1)!.toLowerCase()];
  if (_finalMarker.hasMatch(t)) return finalSeasonOrdinal;
  final roman = _trailingRoman.firstMatch(t);
  if (roman != null) return _romanOrdinals[roman.group(1)!];
  return null;
}

/// Purpose: Remove season markers from a title, leaving the work's base title.
/// Inputs: `title`.
/// Returns: `String` — trimmed, with markers such as 第二季, 2期, Season 2,
/// 2nd Season, S2, Part 2, Cour 2, The Final Season, 最终季, 完結編, 続編 and a
/// trailing Roman numeral II–IV removed, along with any brackets they leave
/// empty.
/// Side effects: None.
/// Notes: For matching only — the result is folded before comparison and is
/// never shown. Full-width characters are made half-width first.
String stripSeasonMarkers(String title) {
  var t = halfWidthAscii(title);
  for (final p in _markerPatterns) {
    t = t.replaceAll(p, ' ');
  }
  t = t.replaceAll(_trailingRoman, '');
  t = t.replaceAll(_emptyBrackets, ' ');
  t = t.replaceAll(_spaces, ' ').trim();
  t = t.replaceAll(_trailingSeparators, '');
  return t.trim();
}

/// Purpose: Produce the season label that follows `label`.
/// Inputs: `label` — e.g. `Season 1`, `第一季`, `第1期`, `2nd Season`.
/// Returns: `String?` — the same label with its number incremented in the
/// same numeral style (`Season 2`, `第二季`, `第2期`, `3rd Season`), or
/// `null` when no ordinal can be read.
/// Side effects: None.
/// Notes: Used to prefill "Add next season".
String? nextSeasonLabel(String label) {
  final cjk = RegExp(r'(第\s*)([一二三四五六七八九十\d]+)(\s*[季期])');
  final cjkMatch = cjk.firstMatch(label);
  if (cjkMatch != null) {
    final raw = cjkMatch.group(2)!;
    final n = parseCjkNumber(raw);
    if (n == null) return null;
    final next = int.tryParse(raw) != null ? '${n + 1}' : toCjkNumber(n + 1);
    return label.replaceFirstMapped(cjk, (m) => '${m[1]}$next${m[3]}');
  }
  final ordinalWord = RegExp(
    r'(\d+)(?:st|nd|rd|th)(\s+season)',
    caseSensitive: false,
  );
  final wordMatch = ordinalWord.firstMatch(label);
  if (wordMatch != null) {
    final n = int.parse(wordMatch.group(1)!) + 1;
    return label.replaceFirstMapped(
      ordinalWord,
      (m) => '$n${_englishSuffix(n)}${m[2]}',
    );
  }
  final latin = [
    RegExp(r'(season\s*)(\d+)', caseSensitive: false),
    RegExp(r'(\bS)(\d+)\b'),
    RegExp(r'(part\s*)(\d+)', caseSensitive: false),
  ];
  for (final p in latin) {
    final m = p.firstMatch(label);
    if (m != null) {
      final n = int.parse(m.group(2)!) + 1;
      return label.replaceFirstMapped(p, (m) => '${m[1]}$n');
    }
  }
  return null;
}

/// Purpose: Return the English ordinal suffix for a number.
/// Inputs: `n`.
/// Returns: `String` — `st`, `nd`, `rd` or `th`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String _englishSuffix(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return 'th';
  return switch (n % 10) {
    1 => 'st',
    2 => 'nd',
    3 => 'rd',
    _ => 'th',
  };
}
