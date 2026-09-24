import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/features/ai/services/ai_insights_cache.dart';
import 'package:my_anime/features/ai/services/on_device_ai_service.dart';
import 'package:my_anime/features/ai/services/prompt_templates.dart';
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/anime/models/anime_category.dart';
import 'package:my_anime/features/anime/views/category_widgets.dart';
import 'package:my_anime/features/categories/services/category_service.dart';
import 'package:my_anime/l10n/app_localizations.dart';
import 'package:my_anime/shared/services/duplicate_service.dart';
import 'package:my_anime/shared/services/file_open_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'on_device_ai_test.dart' show FakeBackend;

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

final _t = DateTime.utc(2024, 1, 1);

/// Purpose: Build a fixture record.
/// Inputs: `id`, `genres`, `categories`.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper.
Anime rec(
  String id, {
  List<String> genres = const [],
  List<String>? categories,
  String title = 'Show',
}) => Anime(
  id: id,
  title: title,
  categories: categories,
  externalMeta: genres.isEmpty ? null : AnimeExternalMeta(genres: genres),
  createdAt: _t,
  modifiedAt: _t,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('taxonomy', () {
    test('ids are unique and every one has a label in all four languages', () {
      expect(animeCategoryIds, hasLength(animeCategories.length));
      for (final locale in AppLocalizations.supportedLocales) {
        final l10n = lookupAppLocalizations(locale);
        for (final c in animeCategories) {
          expect(
            categoryLabel(c.id, l10n),
            isNot(c.id),
            reason: '$locale ${c.id}',
          );
        }
      }
    });

    test('has no adult category', () {
      expect(animeCategoryIds.any((id) => id.contains('ecchi')), isFalse);
    });

    test('genres map from all three sources, unknown tags ignored', () {
      expect(
        mapGenresToCategories(['Slice of Life', 'Mahou Shoujo', 'Ecchi']),
        ['slice_of_life', 'magical_girl'],
      );
      expect(mapGenresToCategories(['Iyashikei', 'Gourmet']), [
        'gourmet',
        'healing',
      ]);
      expect(mapGenresToCategories(['恋愛', '校園', '異世界']), [
        'romance',
        'isekai',
        'school',
      ]);
      expect(mapGenresToCategories(['萌', 'something']), isEmpty);
    });
  });

  group('resolution', () {
    test('the user list wins, even when empty, and hides unknown ids', () {
      expect(
        resolveCategories(rec('a', genres: ['Romance'], categories: [])).ids,
        isEmpty,
      );
      final own = resolveCategories(
        rec('a', genres: ['Romance'], categories: ['comedy', 'future_id']),
      );
      expect(own.ids, ['comedy']);
      expect(own.origin, CategoryOrigin.user);
    });

    test('mapped genres come before AI results', () {
      final insights = AiInsights(
        categories: {
          'a': AiCategoryEntry(
            fingerprint: classificationFingerprint(
              classificationInputOf(rec('a')),
              'm',
            ),
            model: 'm',
            ids: ['horror'],
            status: AiCategoryStatus.ok,
            generatedAt: _t,
          ),
        },
      );
      expect(
        resolveCategories(rec('a', genres: ['Sports']), insights: insights).ids,
        ['sports'],
      );
      final ai = resolveCategories(rec('a'), insights: insights);
      expect(ai.ids, ['horror']);
      expect(ai.origin, CategoryOrigin.ai);
      expect(resolveCategories(rec('a')).origin, isNull);
    });
  });

  group('categories field', () {
    Map<String, dynamic> base([Map<String, dynamic> extra = const {}]) => {
      'id': 'c-1',
      'title': 'x',
      'season': 'Season 1',
      'startEpisode': 1,
      'episodeStatuses': <String, dynamic>{},
      'createdAt': '2026-01-01T00:00:00.000Z',
      'modifiedAt': '2026-01-01T00:00:00.000Z',
      ...extra,
    };

    test('absent means automatic and is not written', () {
      final a = Anime.fromJson(base());
      expect(a.categories, isNull);
      expect(a.toJson().containsKey('categories'), isFalse);
    });

    test('an empty list is meaningful and round-trips', () {
      final a = Anime.fromJson(base({'categories': <String>[]}));
      expect(a.categories, isEmpty);
      expect(a.toJson()['categories'], <String>[]);
    });

    test('unknown ids are kept; unparseable values are preserved', () {
      final a = Anime.fromJson(
        base({
          'categories': ['romance', 'newer_id'],
        }),
      );
      expect(a.toJson()['categories'], ['romance', 'newer_id']);
      final odd = Anime.fromJson(base({'categories': 'romance'}));
      expect(odd.categories, isNull);
      expect(odd.toJson()['categories'], 'romance');
    });

    test('clearing returns to automatic', () {
      final a = Anime.fromJson(
        base({
          'categories': ['romance'],
        }),
      );
      expect(
        a.copyWith(clearCategories: true).toJson().containsKey('categories'),
        isFalse,
      );
    });
  });

  group('prompts and fingerprints', () {
    test('the instructions list every id and ask for NONE', () {
      final i = classificationInstructions();
      for (final c in animeCategories) {
        expect(i, contains('- ${c.id}: '));
      }
      expect(i, contains('NONE'));
    });

    test('the prompt carries the work only', () {
      final prompt = classificationPrompt(
        classificationInputOf(
          rec('a', title: 'Frieren').copyWith(
            notes: 'my private note',
            rating: const AnimeRating(overall: 9),
          ),
        ),
      );
      expect(prompt, contains('Frieren'));
      expect(prompt, isNot(contains('private')));
      expect(prompt, isNot(contains('9')));
    });

    test('a changed input or model changes the fingerprint', () {
      final a = classificationInputOf(rec('a', title: 'One'));
      final b = classificationInputOf(rec('a', title: 'Two'));
      expect(
        classificationFingerprint(a, 'm1'),
        classificationFingerprint(a, 'm1'),
      );
      expect(
        classificationFingerprint(a, 'm1'),
        isNot(classificationFingerprint(b, 'm1')),
      );
      expect(
        classificationFingerprint(a, 'm1'),
        isNot(classificationFingerprint(a, 'm2')),
      );
    });
  });

  group('cache', () {
    late Directory temp;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('myanime_ai_cache');
      final docs = Directory(p.join(temp.path, 'docs'))..createSync();
      Directory(p.join(docs.path, 'MyAnime')).createSync();
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('saves, loads and prunes deleted records', () async {
      await AiInsightsCache.save(
        AiInsights(
          categories: {
            'a': AiCategoryEntry(
              fingerprint: 'f',
              ids: ['comedy'],
              status: AiCategoryStatus.ok,
              model: 'stable/full',
              generatedAt: _t,
            ),
            'gone': AiCategoryEntry(
              fingerprint: 'g',
              ids: const [],
              status: AiCategoryStatus.none,
              generatedAt: _t,
            ),
          },
          hiddenRecommendations: {'a', 'gone'},
        ),
      );
      final loaded = await AiInsightsCache.load(liveIds: {'a'});
      expect(loaded.categories.keys, ['a']);
      expect(loaded.categories['a']!.ids, ['comedy']);
      expect(loaded.hiddenRecommendations, {'a'});
    });

    test('a corrupt file reads as empty', () async {
      final dir = Directory(p.join(temp.path, 'docs', 'MyAnime'));
      File(p.join(dir.path, AiInsightsCache.fileName)).writeAsStringSync('{');
      expect((await AiInsightsCache.load()).categories, isEmpty);
    });
  });

  group('classifier', () {
    late FakeBackend backend;
    late OnDeviceAiService ai;
    late AiInsights saved;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      backend = FakeBackend();
      ai = OnDeviceAiService(backend: backend);
      saved = AiInsights();
    });
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    CategoryClassifier make(List<Anime> library) => CategoryClassifier(
      ai: ai,
      loadLibrary: () async => library,
      loadInsights: (_) async => saved,
      saveInsights: (i) async => saved = i,
    );

    test('does nothing while automatic categories are off', () async {
      await ai.setEnabled(true);
      final c = make([rec('a')]);
      expect(await c.trickle(), 0);
      expect(backend.calls.where((x) => x.startsWith('choose')), isEmpty);
    });

    test('does nothing while AI is off', () async {
      final c = make([rec('a')])..enabled = true;
      expect(await c.trickle(), 0);
      expect(backend.calls, isEmpty);
    });

    test(
      'classifies only records with no user list and no mapped genres',
      () async {
        await ai.setEnabled(true);
        final c = make([
          rec('mapped', genres: ['Romance']),
          rec('own', categories: const []),
          rec('gap'),
        ])..enabled = true;
        expect(await c.trickle(), 1);
        expect(saved.categories.keys, ['gap']);
        // FakeBackend.choose answers the first option, which is `action`.
        expect(saved.categories['gap']!.ids, ['action']);
        // Nothing left to do while the fingerprint is unchanged.
        expect(await c.classifyAll(), 0);
        await c.refreshCounts();
        expect(c.candidates, 1);
        expect(c.pending, 0);
      },
    );
  });

  group('widgets', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: child),
      ),
    );

    testWidgets('AI chips carry the sparkle', (tester) async {
      await pump(
        tester,
        CategoryChips(
          categories: const EffectiveCategories(['romance'], CategoryOrigin.ai),
          onEdit: () {},
        ),
      );
      expect(find.text('Romance'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('the editor returns the chosen ids in taxonomy order', (
      tester,
    ) async {
      CategoryEditResult? result;
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showCategoryEditor(
              context,
              initial: const ['school'],
              hasOverride: true,
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Reset to automatic'), findsOneWidget);
      await tester.tap(find.text('Romance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result, isA<CategoriesChosen>());
      expect((result! as CategoriesChosen).ids, ['romance', 'school']);
    });
  });

  group('travel', () {
    test('duplicate merge keeps the primary categories, else a fallback', () {
      expect(
        DuplicateService.merge(rec('p', categories: ['comedy']), [
          rec('o', categories: ['drama']),
        ]).categories,
        ['comedy'],
      );
      expect(
        DuplicateService.merge(rec('p'), [
          rec('o1'),
          rec('o2', categories: const []),
        ]).categories,
        isEmpty,
      );
    });

    test('share files keep categories through export and import', () {
      final json = FileOpenService.stripPersonalData(
        rec('a', categories: ['romance']).toJson(),
      );
      expect(json['categories'], ['romance']);
      final imported = FileOpenService.importedCopy(
        Anime.fromJson(json),
        id: 'new',
        now: _t,
      );
      expect(imported.categories, ['romance']);
    });

    test('stale AI results are hidden once the inputs change', () {
      final anime = rec('a', title: 'Old title');
      final input = classificationInputOf(anime);
      final insights = AiInsights(
        categories: {
          'a': AiCategoryEntry(
            fingerprint: classificationFingerprint(input, 'm'),
            ids: ['drama'],
            status: AiCategoryStatus.ok,
            model: 'm',
            generatedAt: _t,
          ),
        },
      );
      expect(resolveCategories(anime, insights: insights).ids, ['drama']);
      expect(
        resolveCategories(
          anime.copyWith(title: 'New title'),
          insights: insights,
        ).ids,
        isEmpty,
      );
    });
  });
}
