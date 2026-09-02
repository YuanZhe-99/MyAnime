import 'chinese_convert_data.dart';

/// Simplified ↔ Traditional Chinese character conversion for search.
///
/// The tables live in the generated `chinese_convert_data.dart` (OpenCC
/// character dictionaries merged with the app's original hand-typed table —
/// see `tool/gen_chinese_convert.dart`). Traditional→Simplified is the
/// many-to-one canonical direction (乾/幹→干, 髮/發→发), which is why title
/// matching folds both sides to Simplified rather than to Traditional.
class ChineseConvert {
  /// Purpose: Prevent direct instantiation and expose only static members.
  /// Inputs: None.
  /// Returns: A new `ChineseConvert._` instance.
  /// Side effects: None.
  /// Notes: None.
  ChineseConvert._();

  static Map<int, int>? _s2t;
  static Map<int, int>? _t2s;

  /// Purpose: Convert simplified Chinese characters to their traditional variants.
  /// Inputs: `text`.
  /// Returns: `String`.
  /// Side effects: Builds the lookup table on first use.
  /// Notes: One-to-many characters take the legacy table's choice where it had
  /// one (里→裡, 着→著) and OpenCC's first candidate otherwise (干→幹), so the
  /// result is a *plausible* Traditional form, not a guaranteed regional one.
  static String toTraditional(String text) =>
      _convert(text, _s2t ??= _table(kSimplifiedToTraditionalPairs));

  /// Purpose: Convert traditional Chinese characters to their simplified variants.
  /// Inputs: `text`.
  /// Returns: `String`.
  /// Side effects: Builds the lookup table on first use.
  /// Notes: Many-to-one, so this is the direction to normalize on when
  /// comparing titles from different regions.
  static String toSimplified(String text) =>
      _convert(text, _t2s ??= _table(kTraditionalToSimplifiedPairs));

  /// Purpose: Build a rune→rune map from an interleaved pair string.
  /// Inputs: `pairs`.
  /// Returns: `Map<int, int>`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Iterates `runes`, not
  /// code units — OpenCC includes CJK Extension B characters, which are
  /// surrogate pairs in UTF-16.
  static Map<int, int> _table(String pairs) {
    final r = pairs.runes.toList();
    assert(r.length.isEven, 'pair string must hold whole pairs');
    return {for (var i = 0; i + 1 < r.length; i += 2) r[i]: r[i + 1]};
  }

  /// Purpose: Map every rune of `text` through `table`, passing others through.
  /// Inputs: `text`, `table`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _convert(String text, Map<int, int> table) {
    final buf = StringBuffer();
    for (final rune in text.runes) {
      buf.writeCharCode(table[rune] ?? rune);
    }
    return buf.toString();
  }
}
