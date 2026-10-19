import 'dart:ui' show Locale;

import '../../../shared/utils/chinese_convert.dart';

/// The language an insight card is requested in, and how its lines are
/// post-processed. A port of MyAnime!!!!!'s `ReasonLanguage`.
class InsightLanguage {
  /// Tag stated in the instructions, e.g. `zh_CN`.
  final String localeTag;

  /// The language's English name for the instructions.
  final String name;

  /// `en`, `ja` or `zh`, for the script check.
  final String code;

  /// Convert the result to Traditional Chinese.
  final bool toTraditional;

  /// Convert the result to Simplified Chinese.
  final bool toSimplified;

  /// Purpose: Create an insight language.
  /// Inputs: see fields.
  /// Returns: A new `InsightLanguage`.
  /// Side effects: None.
  /// Notes: None.
  const InsightLanguage(
    this.localeTag,
    this.name,
    this.code, {
    this.toTraditional = false,
    this.toSimplified = false,
  });

  /// Purpose: Pick the request language for the UI locale.
  /// Inputs: `locale`; `localeSupported` — Apple's `supportsLocale` answer
  /// for the UI locale, null when unknown (Android).
  /// Returns: `InsightLanguage?` — null when the model cannot write in the
  /// UI language, so the card says so instead of generating.
  /// Side effects: None.
  /// Notes: Chinese output is always converted to the UI's variant, so a
  /// reply in the other variant is fixed rather than discarded. When Apple
  /// rejects Traditional Chinese, Simplified is requested and converted;
  /// when it rejects any other UI language, the card is skipped.
  static InsightLanguage? forLocale(Locale locale, {bool? localeSupported}) {
    final lang = locale.languageCode;
    final traditional =
        lang == 'zh' &&
        (locale.countryCode == 'TW' ||
            locale.countryCode == 'HK' ||
            locale.scriptCode == 'Hant');
    if (localeSupported == false && !traditional) return null;
    return switch (lang) {
      'zh' when traditional && localeSupported == false =>
        const InsightLanguage(
          'zh_CN',
          'Simplified Chinese',
          'zh',
          toTraditional: true,
        ),
      'zh' when traditional => const InsightLanguage(
        'zh_TW',
        'Traditional Chinese',
        'zh',
        toTraditional: true,
      ),
      'zh' => const InsightLanguage(
        'zh_CN',
        'Simplified Chinese',
        'zh',
        toSimplified: true,
      ),
      'ja' => const InsightLanguage('ja_JP', 'Japanese', 'ja'),
      _ => const InsightLanguage('en_US', 'English', 'en'),
    };
  }

  /// Purpose: Post-process a validated line.
  /// Inputs: `text`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Converts the Chinese variant with `ChineseConvert`.
  String finish(String text) {
    if (toTraditional) return ChineseConvert.toTraditional(text);
    if (toSimplified) return ChineseConvert.toSimplified(text);
    return text;
  }
}
