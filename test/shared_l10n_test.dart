import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Purpose: Keep adopted shared catalog keys aligned with the pinned library.
/// Inputs: None.
/// Returns: None.
/// Side effects: Reads ARB files during tests.
/// Notes: App-specific strings and unsupported languages remain independent.
void main() {
  test(
    'common appearance and navigation translations match the shared catalog',
    () {
      for (final file in Directory(
        'packages/myapps_ui/l10n',
      ).listSync().whereType<File>()) {
        if (!file.path.endsWith('.arb')) continue;
        final locale = file.uri.pathSegments.last
            .replaceFirst('common_', '')
            .replaceFirst('.arb', '');
        final app = File('lib/l10n/app_$locale.arb');
        if (!app.existsSync()) continue;
        final common =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final data = jsonDecode(app.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in common.entries) {
          expect(data[entry.key], entry.value, reason: '$locale: ${entry.key}');
        }
      }
    },
  );
}
