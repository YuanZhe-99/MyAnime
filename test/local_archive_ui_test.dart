import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/views/anime_edit_page.dart';
import 'package:my_anime/features/anime/views/archive_labels.dart';
import 'package:my_anime/l10n/app_localizations.dart';

/// Purpose: Test the Local Archive editing UI and its enum label helpers.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: The edit page is pumped in create mode (`animeId == null`) so it never
/// touches `AnimeStorage`, keeping the test free of file-system setup.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: child,
  );

  group('archive labels', () {
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    test('source and resolution render as technical tokens', () {
      expect(archiveSourceLabel(ArchiveSource.bd, l10n), 'BD');
      expect(archiveSourceLabel(ArchiveSource.dvd, l10n), 'DVD');
      expect(archiveSourceLabel(ArchiveSource.web, l10n), 'WEB');
      expect(archiveSourceLabel(ArchiveSource.tv, l10n), 'TV');
      expect(
        archiveSourceLabel(ArchiveSource.other, l10n),
        l10n.animeArchiveOther,
      );

      expect(archiveResolutionLabel(ArchiveResolution.uhd2160p, l10n), '2160p');
      expect(archiveResolutionLabel(ArchiveResolution.fhd1080p, l10n), '1080p');
      expect(archiveResolutionLabel(ArchiveResolution.hd720p, l10n), '720p');
      expect(archiveResolutionLabel(ArchiveResolution.sd480p, l10n), '480p');
      expect(
        archiveResolutionLabel(ArchiveResolution.other, l10n),
        l10n.animeArchiveOther,
      );
    });

    test('quality label joins both halves and never dangles a separator', () {
      expect(
        archiveQualityLabel(
          const AnimeLocalArchive(
            source: ArchiveSource.bd,
            resolution: ArchiveResolution.fhd1080p,
          ),
          l10n,
        ),
        'BD · 1080p',
      );
      expect(
        archiveQualityLabel(
          const AnimeLocalArchive(source: ArchiveSource.bd),
          l10n,
        ),
        'BD',
      );
      expect(
        archiveQualityLabel(
          const AnimeLocalArchive(resolution: ArchiveResolution.hd720p),
          l10n,
        ),
        '720p',
      );
      expect(
        archiveQualityLabel(const AnimeLocalArchive(archived: true), l10n),
        isNull,
      );
    });
  });

  /// Purpose: Pump the edit page in create mode and open its Local Archive section.
  /// Inputs: `tester`.
  /// Returns: The loaded `AppLocalizations` for assertions.
  /// Side effects: Scrolls the form's `ListView` and expands the section.
  /// Notes: The section sits below the fold in a lazily-built `ListView`, so it
  /// must be scrolled into existence before it can be found or tapped. The
  /// scrollable is addressed through the `ListView` rather than as the first
  /// `Scrollable` on the page, because the default 800 x 600 test viewport
  /// passes `canSplitLayout`: since 1.5.5 the edit page renders two panes, and
  /// the first `Scrollable` is now the left pane's, which holds only the cover
  /// and the two titles. Every text field contributes a `Scrollable` of its own
  /// too, so positional indexing either way is not a stable way to name it.
  Future<AppLocalizations> openArchiveSection(WidgetTester tester) async {
    await tester.pumpWidget(wrap(const AnimeEditPage()));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.scrollUntilVisible(
      find.text(l10n.animeLocalArchive),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('edit page exposes a collapsed Local Archive section', (
    tester,
  ) async {
    final l10n = await openArchiveSection(tester);

    // The section header is present, and its controls stay collapsed until the
    // user opens it — the same shape as the rating section above it.
    expect(find.text(l10n.animeLocalArchive), findsOneWidget);
    expect(find.text(l10n.animeLocalArchiveArchived), findsNothing);

    await tester.tap(find.text(l10n.animeLocalArchive));
    await tester.pumpAndSettle();

    // Expanded: the archived switch plus all four detail controls.
    expect(find.text(l10n.animeLocalArchiveArchived), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);
    expect(find.text(l10n.animeArchiveSource), findsOneWidget);
    expect(find.text(l10n.animeArchiveResolution), findsOneWidget);
    expect(find.text(l10n.animeArchiveCopies), findsOneWidget);
    expect(find.text(l10n.animeArchiveLocation), findsOneWidget);
  });

  testWidgets('the archived switch toggles', (tester) async {
    final l10n = await openArchiveSection(tester);
    await tester.tap(find.text(l10n.animeLocalArchive));
    await tester.pumpAndSettle();

    final switchFinder = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(switchFinder).value, isFalse);

    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(switchFinder).value, isTrue);
  });

  testWidgets('the source dropdown offers every medium plus a blank', (
    tester,
  ) async {
    final l10n = await openArchiveSection(tester);
    await tester.tap(find.text(l10n.animeLocalArchive));
    await tester.pumpAndSettle();

    final sourceDropdown = find.byType(DropdownButtonFormField<ArchiveSource?>);
    expect(sourceDropdown, findsOneWidget);

    await tester.ensureVisible(sourceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(sourceDropdown);
    await tester.pumpAndSettle();

    // Every enum member is offered, plus the leading '-' meaning "not recorded".
    for (final source in ArchiveSource.values) {
      expect(
        find.text(archiveSourceLabel(source, l10n)),
        findsWidgets,
        reason: 'missing option for ${source.name}',
      );
    }
    expect(find.text('-'), findsWidgets);

    // Picking one stages it without leaving the form.
    await tester.tap(find.text('BD').last);
    await tester.pumpAndSettle();
    expect(find.text('BD'), findsOneWidget);
  });
}
