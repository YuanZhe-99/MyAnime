import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_anime/features/anime/models/anime.dart';
import 'package:my_anime/features/recommendations/models/recommendation_data.dart';
import 'package:my_anime/features/recommendations/services/recommendation_merge.dart';
import 'package:my_anime/features/recommendations/services/recommendation_service.dart';
import 'package:my_anime/features/recommendations/services/recommendation_store.dart';
import 'package:my_anime/features/recommendations/services/sequel_info_service.dart';
import 'package:my_anime/features/recommendations/views/related_card.dart';
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
final _created = DateTime.utc(2024, 1, 1);

/// Purpose: Build an unstarted fixture record with an external score.
/// Inputs: `id`, `score`.
/// Returns: `Anime`.
/// Side effects: None.
/// Notes: Test helper.
Anime rec(String id, double score) => Anime(
  id: id,
  title: 'Title $id',
  endEpisode: 12,
  externalMeta: AnimeExternalMeta(
    ratings: [AnimeExternalRating(source: 'AniList', score: score)],
  ),
  createdAt: _created,
  modifiedAt: _created,
);

/// Purpose: Encode and decode, as a sync round-trip would.
/// Inputs: `d`.
/// Returns: `RecommendationData`.
/// Side effects: None.
/// Notes: Test helper.
RecommendationData roundTrip(RecommendationData d) =>
    RecommendationData.fromJson(jsonDecode(encodeRecommendationData(d)));

/// Purpose: Build a solid-colour PNG.
/// Inputs: `w`, `h`.
/// Returns: `Uint8List`.
/// Side effects: None.
/// Notes: Test helper.
Uint8List png(int w, int h) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(220, 80, 120));
  return img.encodePng(image);
}

void main() {
  group('model', () {
    test('pins and sequel info round-trip with unknown keys', () {
      final raw = {
        'version': 1,
        'hidden': <Object>[],
        'hiddenSequels': <Object>[],
        'related': {
          's': {
            'generatedAt': '2026-09-01T00:00:00.000Z',
            'items': [
              {'id': 'x'},
            ],
            'pinned': [
              {'id': 'x', 'pinnedAt': '2026-09-01T00:00:00.000Z', 'f': 1},
            ],
          },
        },
        'pinned': [
          {'id': 'a', 'pinnedAt': '2026-09-01T00:00:00.000Z', 'future': 1},
        ],
        'pinnedSequels': [
          {'key': 'anilist:1', 'pinnedAt': '2026-09-01T00:00:00.000Z'},
        ],
        'sequelInfo': {
          'anilist:1': {
            'synopsis': 'A story.',
            'coverUrl': 'https://example.com/c.jpg',
            'coverThumb': 'AAAA',
            'fetchedAt': '2026-09-01T00:00:00.000Z',
            'extra': true,
          },
        },
      };
      final d = RecommendationData.fromJson(raw);
      expect(d.pinned['a']!.extraJson, {'future': 1});
      expect(d.pinnedSequels.keys, ['anilist:1']);
      expect(d.sequelInfo['anilist:1']!.synopsis, 'A story.');
      expect(d.related['s']!.pinned.keys, ['x']);
      expect(jsonDecode(encodeRecommendationData(d)), raw);
    });

    test('a file without the 1.6.3 keys keeps its bytes', () {
      final d = RecommendationData(
        hidden: {'a': HiddenEntry('a', hiddenAt: _t1)},
      );
      final json = jsonDecode(encodeRecommendationData(d)) as Map;
      expect(json.keys, ['version', 'hidden', 'hiddenSequels', 'related']);
    });
  });

  group('merge', () {
    test('pins merge as a set against the base', () {
      final base = RecommendationData(
        pinned: {'gone': PinnedEntry('gone', pinnedAt: _t1)},
      );
      final local = RecommendationData(
        pinned: {'new': PinnedEntry('new', pinnedAt: _t2)},
      );
      final remote = RecommendationData(
        pinned: {'gone': PinnedEntry('gone', pinnedAt: _t1)},
      );
      final m = mergeRecommendations(local, remote, base);
      expect(m.pinned.keys.toSet(), {'new'});
    });

    test('a pin on one device beats a refresh on the other', () {
      final local = RecommendationData(
        pinned: {'a': PinnedEntry('a', pinnedAt: _t2)},
        pinnedSequels: {'anilist:1': PinnedEntry('anilist:1')},
        related: {
          's': RelatedSnapshot(pinned: {'x': PinnedEntry('x')}),
        },
      );
      final remote = RecommendationData(
        hidden: {'a': HiddenEntry('a', hiddenAt: _t2)},
        hiddenSequels: {'anilist:1': const HiddenSequelEntry('anilist:1')},
        related: {
          's': RelatedSnapshot(hidden: {'x': HiddenEntry('x')}),
        },
      );
      final m = mergeRecommendations(local, remote, RecommendationData());
      expect(m.hidden, isEmpty);
      expect(m.hiddenSequels, isEmpty);
      expect(m.related['s']!.hidden, isEmpty);
      expect(m.pinned.keys, ['a']);
    });

    test('sequel info: newer fetch wins; a trashed card loses its info', () {
      final older = SequelInfo(synopsis: 'old', fetchedAt: _t1);
      final newer = SequelInfo(synopsis: 'new', fetchedAt: _t2);
      var m = mergeRecommendations(
        RecommendationData(sequelInfo: {'k': older}),
        RecommendationData(sequelInfo: {'k': newer}),
        null,
      );
      expect(m.sequelInfo['k']!.synopsis, 'new');

      m = mergeRecommendations(
        RecommendationData(sequelInfo: {'k': newer}),
        RecommendationData(hiddenSequels: {'k': const HiddenSequelEntry('k')}),
        null,
      );
      expect(m.sequelInfo, isEmpty);
      expect(m.hiddenSequels.keys, ['k']);
    });

    test('info removed on one side stays removed', () {
      final info = SequelInfo(synopsis: 's', fetchedAt: _t1);
      final m = mergeRecommendations(
        RecommendationData(),
        RecommendationData(sequelInfo: {'k': info}),
        RecommendationData(sequelInfo: {'k': info}),
      );
      expect(m.sequelInfo, isEmpty);
    });
  });

  group('rank', () {
    test('pinned candidates come first and count toward the batch', () {
      final library = [for (var i = 0; i < 12; i++) rec('r$i', 9.0 - i * 0.1)];
      final out = RecommendationService.rank(
        library,
        pinned: {'r11', 'r10'},
        nowJst: DateTime(2026, 9, 24, 12),
      );
      expect(out.map((r) => r.anime.id).take(2), ['r10', 'r11']);
      expect(out, hasLength(RecommendationWeights.globalBatch));
      expect(out.map((r) => r.anime.id), isNot(contains('r9')));
    });

    test('a pinned record that is not a candidate is not shown', () {
      final done = Anime(
        id: 'done',
        title: 'Done',
        endEpisode: 1,
        episodeStatuses: const {1: EpisodeStatus.watched},
        createdAt: _created,
        modifiedAt: _created,
      );
      final out = RecommendationService.rank(
        [done, rec('a', 8)],
        pinned: {'done'},
        nowJst: DateTime(2026, 9, 24, 12),
      );
      expect(out.map((r) => r.anime.id), ['a']);
    });
  });

  group('related pins', () {
    test('keptPinnedItems keeps stored order and restores missing pins', () {
      final snap = RelatedSnapshot(
        items: const [
          RelatedItem('a', reasons: ['baseTitle']),
          RelatedItem('b'),
          RelatedItem('c'),
        ],
        pinned: {
          'c': PinnedEntry('c'),
          'a': PinnedEntry('a'),
          'z': PinnedEntry('z'),
          'deleted': PinnedEntry('deleted'),
        },
      );
      final kept = keptPinnedItems(snap, {'a', 'b', 'c', 'z'});
      expect(kept.map((i) => i.id), ['a', 'c', 'z']);
      expect(kept.first.reasons, ['baseTitle']);
      expect(keptPinnedItems(null, {'a'}), isEmpty);
    });
  });

  group('store', () {
    late Directory temp;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('myanime_rec_pins');
      final docs = Directory(p.join(temp.path, 'docs'))..createSync();
      Directory(p.join(docs.path, 'MyAnime')).createSync();
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
      SequelInfoService.resetSession();
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('pin and trash exclude each other', () async {
      await RecommendationStore.hide(['a']);
      var d = await RecommendationStore.pin(['a']);
      expect(d.hidden, isEmpty);
      expect(d.pinned.keys, ['a']);
      d = await RecommendationStore.hide(['a']);
      expect(d.pinned, isEmpty);
      expect(d.hidden.keys, ['a']);

      d = await RecommendationStore.pinRelated('s', ['x']);
      expect(d.related['s']!.pinned.keys, ['x']);
      d = await RecommendationStore.hideRelated('s', ['x']);
      expect(d.related['s']!.pinned, isEmpty);
      d = await RecommendationStore.pinRelated('s', ['x']);
      expect(d.related['s']!.hidden, isEmpty);
      d = await RecommendationStore.unpinRelated('s', ['x']);
      expect(d.related['s']?.pinned ?? const {}, isEmpty);
    });

    test('putRelated keeps the pins', () async {
      await RecommendationStore.pinRelated('s', ['x']);
      final d = await RecommendationStore.putRelated('s', [
        const RelatedItem('x'),
        const RelatedItem('y'),
      ]);
      expect(d.related['s']!.pinned.keys, ['x']);
    });

    test('trashing a sequel card deletes its info and its pin', () async {
      await RecommendationStore.pinSequels(['k']);
      await RecommendationStore.putSequelInfo(
        'k',
        SequelInfo(synopsis: 's', coverThumb: 'AAAA', fetchedAt: _t1),
      );
      var d = await RecommendationStore.hideSequels([
        const HiddenSequelEntry('k', title: 'Next'),
      ]);
      expect(d.sequelInfo, isEmpty);
      expect(d.pinnedSequels, isEmpty);
      expect(d.hiddenSequels['k']!.title, 'Next');

      // A late fetch cannot bring it back while the card is trashed.
      d = await RecommendationStore.putSequelInfo(
        'k',
        SequelInfo(synopsis: 'x'),
      );
      expect(d.sequelInfo, isEmpty);

      await RecommendationStore.putSequelInfo('j', SequelInfo(synopsis: 'j'));
      d = await RecommendationStore.hideBatch(const [], [
        const HiddenSequelEntry('j'),
      ]);
      expect(d.sequelInfo, isEmpty);
    });

    test(
      'ensure fetches once, builds a small thumbnail, and stores it',
      () async {
        var pages = 0;
        SequelInfoService.fetchPage = (url) async {
          pages++;
          return (
            summary: 'Line one.\r\n\r\nLine two. [Written by MAL Rewrite]',
            coverUrl: 'https://example.com/cover.png',
          );
        };
        SequelInfoService.download = (url) async => png(400, 560);
        addTearDown(() {
          SequelInfoService.fetchPage = (url) async => null;
          SequelInfoService.download = (url) async => null;
        });

        const sequel = AnimeExternalRelation(
          source: 'AniList',
          type: AnimeRelationType.sequel,
          targetUrl: 'https://anilist.co/anime/1',
          title: 'Next',
        );
        final info = await SequelInfoService.ensure('anilist:1', sequel);
        expect(info, isNotNull);
        expect(info!.synopsis, 'Line one. Line two.');
        final thumb = base64Decode(info.coverThumb!);
        expect(
          thumb.length,
          lessThanOrEqualTo(SequelInfoService.thumbMaxBytes),
        );
        final decoded = img.decodeJpg(thumb)!;
        expect(decoded.width, SequelInfoService.thumbWidth);
        expect(decoded.height, (560 * 112 / 400).round()); // aspect kept

        final stored = await RecommendationStore.load();
        expect(stored.sequelInfo['anilist:1']!.coverThumb, info.coverThumb);

        // Stored info is passed back as `existing`: no second request.
        await SequelInfoService.ensure(
          'anilist:1',
          sequel,
          existing: stored.sequelInfo['anilist:1'],
        );
        expect(pages, 1);

        // A failure is not retried within the session.
        SequelInfoService.fetchPage = (url) async {
          pages++;
          return null;
        };
        const other = AnimeExternalRelation(
          source: 'AniList',
          type: AnimeRelationType.sequel,
          targetUrl: 'https://anilist.co/anime/2',
        );
        expect(await SequelInfoService.ensure('anilist:2', other), isNull);
        expect(await SequelInfoService.ensure('anilist:2', other), isNull);
        expect(pages, 2);
      },
    );
  });

  group('synopsis', () {
    test('normalises whitespace, drops credits, caps length', () {
      expect(SequelInfoService.normalizeSynopsis('  \n '), isNull);
      expect(
        SequelInfoService.normalizeSynopsis('A\n\nB (Source: ANN)'),
        'A B',
      );
      final long = SequelInfoService.normalizeSynopsis('x' * 2000)!;
      expect(long.length, SequelInfoService.synopsisMaxLength + 1);
      expect(long.endsWith('…'), isTrue);
    });
  });
}
