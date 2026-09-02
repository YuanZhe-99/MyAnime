import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/shared/utils/chinese_convert.dart';
import 'package:my_anime/shared/utils/chinese_convert_data.dart';

/// Purpose: Pin the behavior of the generated Simplified/Traditional tables.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Traditional→Simplified is the canonical, many-to-one direction the
/// title matcher relies on; Simplified→Traditional keeps the legacy choices.
void main() {
  group('toSimplified (many-to-one canonical)', () {
    test('folds every Traditional variant onto one Simplified character', () {
      expect(ChineseConvert.toSimplified('乾'), '干');
      expect(ChineseConvert.toSimplified('幹'), '干');
      expect(ChineseConvert.toSimplified('髮'), '发');
      expect(ChineseConvert.toSimplified('發'), '发');
      expect(ChineseConvert.toSimplified('裏'), '里');
      expect(ChineseConvert.toSimplified('裡'), '里');
      expect(ChineseConvert.toSimplified('臺'), '台');
      expect(ChineseConvert.toSimplified('徵'), '征');
      expect(ChineseConvert.toSimplified('迴'), '回');
      expect(ChineseConvert.toSimplified('隻'), '只');
      expect(ChineseConvert.toSimplified('麼'), '么');
      expect(ChineseConvert.toSimplified('著'), '着');
    });

    test('handles the phrase the old bigram fallback was written for', () {
      expect(ChineseConvert.toSimplified('可以幫忙洗乾淨嗎'), '可以帮忙洗干净吗');
      expect(ChineseConvert.toSimplified('孤獨搖滾！'), '孤独摇滚！');
      expect(ChineseConvert.toSimplified('葬送的芙莉蓮'), '葬送的芙莉莲');
    });
  });

  group('toTraditional', () {
    test('keeps the legacy Taiwan-flavoured choices', () {
      expect(ChineseConvert.toTraditional('里'), '裡');
      expect(ChineseConvert.toTraditional('着'), '著');
      expect(ChineseConvert.toTraditional('爱'), '愛');
    });

    test('covers characters the hand table lacked', () {
      expect(ChineseConvert.toTraditional('台'), '臺');
      expect(ChineseConvert.toTraditional('征'), '徵');
      expect(ChineseConvert.toTraditional('干'), isNot('干'));
    });

    test('round-trips ordinary Simplified text', () {
      const text = '简体中文测试';
      expect(
        ChineseConvert.toSimplified(ChineseConvert.toTraditional(text)),
        text,
      );
    });
  });

  group('pass-through', () {
    test('leaves kana, ASCII, punctuation and non-BMP runes alone', () {
      const text = 'ぼっち・ざ・ろっく！ Bocchi, the Rock! \u{20000}';
      expect(ChineseConvert.toTraditional(text), text);
      expect(ChineseConvert.toSimplified(text), text);
    });

    test('empty input stays empty', () {
      expect(ChineseConvert.toTraditional(''), '');
      expect(ChineseConvert.toSimplified(''), '');
    });
  });

  group('generated data integrity', () {
    test('both pair strings hold whole pairs with unique keys', () {
      for (final pairs in [
        kSimplifiedToTraditionalPairs,
        kTraditionalToSimplifiedPairs,
      ]) {
        final runes = pairs.runes.toList();
        expect(runes.length.isEven, isTrue);
        final keys = <int>{};
        for (var i = 0; i < runes.length; i += 2) {
          expect(keys.add(runes[i]), isTrue, reason: 'duplicate key');
          expect(runes[i], isNot(runes[i + 1]), reason: 'identity pair');
        }
        expect(keys.length, greaterThan(3000));
      }
    });
  });
}
