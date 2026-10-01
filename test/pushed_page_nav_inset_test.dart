import 'package:flutter/material.dart' hide LicensePage;
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/settings/views/license_page.dart';
import 'package:my_anime/l10n/app_localizations.dart';

/// Purpose: Guard the floating-nav-bar inset on a page whose body is a
/// `SingleChildScrollView`, which never applies `MediaQuery` padding itself.
void main() {
  testWidgets('license page can scroll its last line above the nav bar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 600),
            padding: EdgeInsets.only(bottom: 100),
          ),
          child: const LicensePage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -20000),
    );
    await tester.pumpAndSettle();

    final bottom = tester.getBottomLeft(find.byType(SelectableText)).dy;
    expect(bottom, lessThanOrEqualTo(600 - 100));
  });
}
