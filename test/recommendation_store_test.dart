import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/app/data_modules.dart';
import 'package:my_anime/features/ai/services/ai_insights_cache.dart';
import 'package:my_anime/features/recommendations/models/recommendation_data.dart';
import 'package:my_anime/features/recommendations/services/recommendation_merge.dart';
import 'package:my_anime/features/recommendations/services/recommendation_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

final _t1 = DateTime.utc(2026, 9, 1);
final _t2 = DateTime.utc(2026, 9, 2);

/// Purpose: Build store contents from short lists.
/// Inputs: `hidden`, `sequels`, `related`.
/// Returns: `RecommendationData`.
/// Side effects: None.
/// Notes: Test helper.
RecommendationData data({
  List<String> hidden = const [],
  List<String> sequels = const [],
  Map<String, RelatedSnapshot> related = const {},
}) => RecommendationData(
  hidden: {for (final id in hidden) id: HiddenEntry(id, hiddenAt: _t1)},
  hiddenSequels: {
    for (final k in sequels) k: HiddenSequelEntry(k, hiddenAt: _t1),
  },
  related: {...related},
);

/// Purpose: Encode store contents the way the file stores them.
/// Inputs: `d`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Test helper.
String enc(RecommendationData d) => encodeRecommendationData(d);

/// Purpose: Decode a merged file.
/// Inputs: `json`.
/// Returns: `RecommendationData`.
/// Side effects: None.
/// Notes: Test helper.
RecommendationData dec(String json) =>
    RecommendationData.fromJson(jsonDecode(json));

void main() {
  group('model', () {
    test('round-trips and keeps unknown keys at every level', () {
      final raw = {
        'version': 1,
        'future': {'x': 1},
        'hidden': [
          {'id': 'a', 'hiddenAt': '2026-09-01T00:00:00.000Z', 'why': 'bored'},
        ],
        'hiddenSequels': [
          {'key': 'anilist:9', 'title': 'Next', 'source': 'AniList', 'z': 2},
        ],
        'related': {
          'subject': {
            'generatedAt': '2026-09-01T00:00:00.000Z',
            'items': [
              {
                'id': 'b',
                'reasons': ['studio:Madhouse', 'future:code'],
                'aiReason': 'Same mood.',
                'score': 3,
              },
            ],
            'hidden': [
              {'id': 'c'},
            ],
            'note': true,
          },
        },
      };
      final d = RecommendationData.fromJson(raw);
      final back = d.toJson();
      expect(back['future'], {'x': 1});
      expect((back['hidden'] as List).single['why'], 'bored');
      expect((back['hiddenSequels'] as List).single['z'], 2);
      final snap = (back['related'] as Map)['subject'] as Map;
      expect(snap['note'], true);
      final item = (snap['items'] as List).single as Map;
      expect(item['score'], 3);
      expect(item['reasons'], ['studio:Madhouse', 'future:code']);
      expect(item['aiReason'], 'Same mood.');
      expect((snap['hidden'] as List).single, {'id': 'c'});
    });

    test('malformed entries are dropped, a non-object is rejected', () {
      final d = RecommendationData.fromJson({
        'hidden': [
          42,
          {'nope': 1},
          {'id': 'ok'},
        ],
        'related': {'x': 'not an object'},
      });
      expect(d.hidden.keys, ['ok']);
      expect(d.related, isEmpty);
      expect(() => RecommendationData.fromJson([]), throwsFormatException);
      expect(() => validateRecommendationsJson('[]'), throwsFormatException);
    });

    test('encoding is sorted, so unchanged data writes identical bytes', () {
      final a = data(hidden: ['b', 'a'], sequels: ['y', 'x']);
      final b = data(hidden: ['a', 'b'], sequels: ['x', 'y']);
      expect(enc(a), enc(b));
      expect(enc(dec(enc(a))), enc(a));
    });
  });

  group('merge', () {
    test('first sync keeps everything from both sides', () {
      final out = dec(
        mergeRecommendationJson(
          enc(data(hidden: ['a'])),
          enc(data(hidden: ['b'], sequels: ['s'])),
          null,
        ),
      );
      expect(out.hidden.keys.toSet(), {'a', 'b'});
      expect(out.hiddenSequels.keys, ['s']);
    });

    test('an add on either side is kept', () {
      final base = enc(data(hidden: ['a']));
      final out = dec(
        mergeRecommendationJson(
          enc(data(hidden: ['a', 'l'])),
          enc(data(hidden: ['a', 'r'])),
          base,
        ),
      );
      expect(out.hidden.keys.toSet(), {'a', 'l', 'r'});
    });

    test('a restore on one side wins over an untouched other side', () {
      final base = enc(data(hidden: ['a', 'b'], sequels: ['s']));
      final out = dec(
        mergeRecommendationJson(
          enc(data(hidden: ['b'])),
          enc(data(hidden: ['a', 'b'], sequels: ['s'])),
          base,
        ),
      );
      expect(out.hidden.keys, ['b']);
      expect(out.hiddenSequels, isEmpty);
    });

    test('the earlier hiddenAt survives when both sides trashed it', () {
      final local = RecommendationData(
        hidden: {'a': HiddenEntry('a', hiddenAt: _t2)},
      );
      final remote = RecommendationData(
        hidden: {'a': HiddenEntry('a', hiddenAt: _t1)},
      );
      final out = dec(mergeRecommendationJson(enc(local), enc(remote), null));
      expect(out.hidden['a']!.hiddenAt, _t1);
    });

    test('the newer snapshot wins; its trash merges as a set', () {
      RelatedSnapshot snap(DateTime at, String item, List<String> hidden) =>
          RelatedSnapshot(
            generatedAt: at,
            items: [RelatedItem(item)],
            hidden: {for (final h in hidden) h: HiddenEntry(h)},
          );
      final base = enc(
        data(
          related: {
            's': snap(_t1, 'old', ['x']),
          },
        ),
      );
      final out = dec(
        mergeRecommendationJson(
          enc(
            data(
              related: {
                's': snap(_t1, 'old', ['x', 'l']),
              },
            ),
          ),
          enc(
            data(
              related: {
                's': snap(_t2, 'new', ['x', 'r']),
              },
            ),
          ),
          base,
        ),
      );
      final s = out.related['s']!;
      expect(s.generatedAt, _t2);
      expect(s.items.map((i) => i.id), ['new']);
      expect(s.hidden.keys.toSet(), {'x', 'l', 'r'});
    });

    test('unknown top-level keys are unioned, local winning', () {
      final local = RecommendationData(extraJson: {'k': 'local', 'l': 1});
      final remote = RecommendationData(extraJson: {'k': 'remote', 'r': 2});
      final out = jsonDecode(
        mergeRecommendationJson(enc(local), enc(remote), null),
      );
      expect(out['k'], 'local');
      expect(out['l'], 1);
      expect(out['r'], 2);
    });

    test('the module never reports a conflict', () {
      final outcome = mergeRecommendationsModule(
        localJson: enc(data(hidden: ['a'])),
        remoteJson: enc(data()),
        baseJson: enc(data(hidden: ['a'])),
      );
      expect(outcome.conflicts, isEmpty);
      expect(dec(outcome.mergedJson!).hidden, isEmpty);
    });

    test('the registry lists anime first, then recommendations', () {
      expect(animeModuleRegistry.modules.map((m) => m.fileName), [
        animeDataFileName,
        recommendationsFileName,
      ]);
      expect(recommendationsFileName, RecommendationStore.fileName);
    });
  });

  group('store', () {
    late Directory temp;
    late Directory appDir;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('myanime_rec_store');
      final docs = Directory(p.join(temp.path, 'docs'))..createSync();
      appDir = Directory(p.join(docs.path, 'MyAnime'))..createSync();
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    File file() => File(p.join(appDir.path, RecommendationStore.fileName));

    test('an empty store never creates the file', () async {
      await RecommendationStore.restore(['nothing']);
      expect(file().existsSync(), isFalse);
      expect((await RecommendationStore.load()).hidden, isEmpty);
    });

    test('hide, restore and batch writes round-trip', () async {
      await RecommendationStore.hide(['a', 'b']);
      await RecommendationStore.hideBatch(
        ['c'],
        [const HiddenSequelEntry('anilist:1', title: 'Next')],
      );
      var d = await RecommendationStore.load();
      expect(d.hidden.keys.toSet(), {'a', 'b', 'c'});
      expect(d.hiddenSequels['anilist:1']!.title, 'Next');
      expect(d.hidden['a']!.hiddenAt, isNotNull);

      await RecommendationStore.restore(['a']);
      await RecommendationStore.restoreSequels(['anilist:1']);
      d = await RecommendationStore.load();
      expect(d.hidden.keys.toSet(), {'b', 'c'});
      expect(d.hiddenSequels, isEmpty);
      expect(file().readAsStringSync(), enc(d));
    });

    test('related lists keep their own trash across regeneration', () async {
      await RecommendationStore.putRelated('s', [
        const RelatedItem('x'),
        const RelatedItem('y'),
      ]);
      await RecommendationStore.hideRelated('s', ['x']);
      var snap = (await RecommendationStore.load()).related['s']!;
      expect(snap.items.map((i) => i.id), ['y']);
      expect(snap.hidden.keys, ['x']);

      await RecommendationStore.putRelated('s', [const RelatedItem('z')]);
      snap = (await RecommendationStore.load()).related['s']!;
      expect(snap.items.map((i) => i.id), ['z']);
      expect(snap.hidden.keys, ['x']);

      await RecommendationStore.restoreRelated('s', ['x']);
      snap = (await RecommendationStore.load()).related['s']!;
      expect(snap.hidden, isEmpty);
    });

    test('concurrent updates are applied one after another', () async {
      await Future.wait([
        for (var i = 0; i < 10; i++) RecommendationStore.hide(['id$i']),
      ]);
      expect((await RecommendationStore.load()).hidden, hasLength(10));
    });

    test('the pre-1.6.2 hidden list moves into the store once', () async {
      await AiInsightsCache.save(AiInsights(hiddenRecommendations: {'old'}));
      expect(await RecommendationStore.migrateFromInsights(), isTrue);
      expect((await RecommendationStore.load()).hidden.keys, ['old']);
      expect((await AiInsightsCache.load()).hiddenRecommendations, isEmpty);
      expect(await RecommendationStore.migrateFromInsights(), isFalse);
    });

    test('a corrupt file reads as empty', () async {
      file().writeAsStringSync('{');
      expect((await RecommendationStore.load()).hidden, isEmpty);
    });
  });
}
