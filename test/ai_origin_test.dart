import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/ai_origin.dart';
import 'package:my_anime/features/categories/services/category_service.dart';
import 'package:myapps_ai/myapps_ai.dart';
import 'package:my_anime/features/recommendations/models/recommendation_data.dart';
import 'package:my_anime/l10n/app_localizations_en.dart';

void main() {
  test('online results are told apart from on-device ones', () {
    expect(onlineProviderOf(null), isNull);
    expect(onlineProviderOf(''), isNull);
    expect(onlineProviderOf('local:qwen3.5-0.8b · local:qwen3.5-0.8b'), isNull);
    expect(onlineProviderOf('gemini-nano · v2'), isNull);
    expect(
      onlineProviderOf('provider:openai · provider:openai'),
      'provider:openai',
    );
    expect(onlineProviderOf('provider:1f2e-3d'), 'provider:1f2e-3d');
  });

  test('the identity of an online report names its provider', () {
    const report = GenAiStatusReport(
      GenAiStatus.available,
      variant: 'provider:abc',
      baseModelName: 'provider:abc',
    );
    expect(onlineProviderOf(modelIdentityOf(report)), 'provider:abc');
  });

  test('labels name the online provider, or fall back without one', () {
    final l10n = AppLocalizationsEn();
    expect(aiGeneratedLabelFor(l10n, null), l10n.aiGeneratedLabel);
    expect(
      aiGeneratedLabelFor(l10n, 'local:qwen3.5-0.8b'),
      l10n.aiGeneratedLabel,
    );
    expect(
      aiGeneratedLabelFor(l10n, 'provider:missing'),
      l10n.aiGeneratedOnlineUnknownLabel,
    );
  });

  test('a related reason keeps the model that wrote it', () {
    final item = const RelatedItem('a').withAiReason('Same studio', model: 'm');
    final back = RelatedItem.fromJson(item.toJson())!;
    expect(back.aiReason, 'Same studio');
    expect(back.aiReasonModel, 'm');
    expect(back.extraJson, isEmpty);

    final old = RelatedItem.fromJson({'id': 'a', 'aiReason': 'Old'})!;
    expect(old.aiReasonModel, isNull, reason: 'stored before 1.8.12');
    expect(old.toJson().containsKey('aiReasonModel'), isFalse);

    final cleared = item.withAiReason(null, model: 'm');
    expect(cleared.toJson().containsKey('aiReasonModel'), isFalse);
  });
}
