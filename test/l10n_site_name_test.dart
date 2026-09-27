import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Purpose: Keep the site's name spelled one way in every language.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads the four ARB files.
/// Notes: 1.6.6. The site is "Anime1" in text; lowercase survives only in the
/// domain `anime1.me`. Through 1.6.5 the stored-progress strings said
/// "anime1" while the 1.6.4 mapping strings said "Anime1", so the management
/// page mixed both.
void main() {
  for (final lang in ['en', 'ja', 'zh', 'zh_TW']) {
    test('ARB values spell the site Anime1 ($lang)', () {
      final arb =
          jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
              as Map<String, dynamic>;
      final offenders = [
        for (final e in arb.entries)
          if (!e.key.startsWith('@') &&
              e.value is String &&
              RegExp(r'anime1(?!\.me)').hasMatch(e.value as String))
            '${e.key}: ${e.value}',
      ];
      expect(offenders, isEmpty);
    });
  }
}
