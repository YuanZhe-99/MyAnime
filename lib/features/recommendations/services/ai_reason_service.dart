import 'dart:ui' show Locale;

import '../../../shared/utils/chinese_convert.dart';
import '../../ai/services/ai_insights_cache.dart';
import '../../ai/services/on_device_ai_service.dart';
import '../../ai/services/output_validation.dart';
import '../../anime/models/anime.dart';
import '../../categories/services/category_service.dart';
import 'reason_prompt.dart';
import 'recommendation_service.dart';

/// How many of the top candidates are offered to the model.
const int aiReasonCandidates = 8;

/// The longest reason shown, in characters.
const int aiReasonMaxLength = 140;

final _answerLine = RegExp(r'^\s*(\d+)\s*[:：.)、]\s*(.+?)\s*$');

/// Purpose: Read the model's `<number>: <reason>` lines.
/// Inputs: `reply`; `count` — how many candidates were offered;
/// `languageCode` — `en`, `ja` or `zh`.
/// Returns: `Map<int, String>` — candidate number (1-based) to reason; at
/// most three.
/// Side effects: None.
/// Notes: Unknown or repeated numbers, over-long reasons and reasons in the
/// wrong script are dropped; Markdown is stripped first.
Map<int, String> parseReasonReply(
  String reply,
  int count,
  String languageCode,
) {
  final out = <int, String>{};
  for (final line in stripMarkdown(reply).split('\n')) {
    final m = _answerLine.firstMatch(line);
    if (m == null) continue;
    final n = int.parse(m.group(1)!);
    if (n < 1 || n > count || out.containsKey(n)) continue;
    final text = cleanSentence(m.group(2)!, maxLength: aiReasonMaxLength);
    if (text == null || !matchesScript(text, languageCode)) continue;
    out[n] = text;
    if (out.length == 3) break;
  }
  return out;
}

/// The language a reason is requested in, and how to post-process it.
class ReasonLanguage {
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

  /// Purpose: Create a reason language.
  /// Inputs: see fields.
  /// Returns: A new `ReasonLanguage`.
  /// Side effects: None.
  /// Notes: None.
  const ReasonLanguage(
    this.localeTag,
    this.name,
    this.code, {
    this.toTraditional = false,
    this.toSimplified = false,
  });

  /// Purpose: Pick the request language for the UI locale.
  /// Inputs: `locale`; `localeSupported` — Apple's `supportsLocale` answer
  /// for the UI locale, null when unknown (Android).
  /// Returns: `ReasonLanguage?` — null when AI reasons should be skipped.
  /// Side effects: None.
  /// Notes: Chinese output is always converted to the UI's variant, so a
  /// reply in the other variant is fixed rather than discarded. When Apple
  /// rejects Traditional Chinese, Simplified is requested and converted;
  /// when it rejects any other UI language, reasons are skipped.
  static ReasonLanguage? forLocale(Locale locale, {bool? localeSupported}) {
    final lang = locale.languageCode;
    final traditional =
        lang == 'zh' &&
        (locale.countryCode == 'TW' || locale.countryCode == 'HK');
    if (localeSupported == false && !traditional) return null;
    return switch (lang) {
      'zh' when traditional && localeSupported == false => const ReasonLanguage(
        'zh_CN',
        'Simplified Chinese',
        'zh',
        toTraditional: true,
      ),
      'zh' when traditional => const ReasonLanguage(
        'zh_TW',
        'Traditional Chinese',
        'zh',
        toTraditional: true,
      ),
      'zh' => const ReasonLanguage(
        'zh_CN',
        'Simplified Chinese',
        'zh',
        toSimplified: true,
      ),
      'ja' => const ReasonLanguage('ja_JP', 'Japanese', 'ja'),
      _ => const ReasonLanguage('en_US', 'English', 'en'),
    };
  }

  /// Purpose: Post-process a validated reason.
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

/// Purpose: Ask the on-device model for up to three short reasons.
/// Inputs: `ai`; `ranked` — the deterministic list; `library`; `language`;
/// `insights` — the AI cache, so AI-derived categories count as they do in
/// the ranking.
/// Returns: `Future<Map<String, String>>` — anime id to reason; empty on any
/// failure.
/// Side effects: Runs the model once, as an interactive request.
/// Notes: The deterministic list is shown first; these reasons fill in when
/// they arrive and live in memory only. Never throws.
Future<Map<String, String>> writeAiReasons(
  OnDeviceAiService ai, {
  required List<Recommendation> ranked,
  required List<Anime> library,
  required ReasonLanguage language,
  AiInsights? insights,
}) async {
  if (!ai.canGenerate || ranked.isEmpty) return const {};
  final top = ranked.take(aiReasonCandidates).toList();
  final candidates = [
    for (var i = 0; i < top.length; i++)
      ReasonCandidate(
        number: i + 1,
        title: top[i].anime.displayTitle,
        categories: resolveCategories(top[i].anime, insights: insights).ids,
        studios: top[i].anime.externalMeta?.studios ?? const [],
        facts: [
          for (final r in top[i].reasons)
            if (r is NextAfterReason) 'next after ${r.previous.displayTitle}',
        ],
      ),
  ];
  final completed =
      library
          .where((a) => a.viewingStatus == AnimeViewingStatus.completed)
          .toList()
        ..sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
  final categories = <String, double>{};
  final studios = <String, double>{};
  for (final a in library) {
    final p = preferenceOf(a);
    if (p <= 0) continue;
    for (final c in resolveCategories(a, insights: insights).ids) {
      categories[c] = (categories[c] ?? 0) + p;
    }
    for (final s in a.externalMeta?.studios ?? const <String>[]) {
      studios[s] = (studios[s] ?? 0) + p;
    }
  }
  final topStudios = studios.keys.toList()
    ..sort((a, b) => studios[b]!.compareTo(studios[a]!));
  final topCategories = categories.keys.toList()
    ..sort((a, b) => categories[b]!.compareTo(categories[a]!));
  try {
    final reply = await ai.generate(
      instructions: reasonInstructions(language.localeTag, language.name),
      prompt: reasonPrompt(
        candidates: candidates,
        topCategories: topCategories.take(3).toList(),
        topStudios: topStudios.take(3).toList(),
        recent: [
          for (final a in completed.take(3))
            (a.displayTitle, a.rating?.effectiveOverall),
        ],
      ),
      maxOutputTokens: 256,
      priority: AiPriority.interactive,
    );
    final parsed = parseReasonReply(reply, top.length, language.code);
    return {
      for (final e in parsed.entries)
        top[e.key - 1].anime.id: language.finish(e.value),
    };
  } catch (_) {
    return const {};
  }
}
