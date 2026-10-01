import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:my_anime/app/data_modules.dart';
import 'package:my_anime/features/profile/models/profile_data.dart';
import 'package:my_anime/features/profile/services/avatar_image.dart';
import 'package:my_anime/features/profile/services/profile_merge.dart';
import 'package:my_anime/features/profile/services/profile_store.dart';
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

/// Purpose: Test the synced user profile (1.7.0): model, merge, module and
/// store.
/// Inputs: None.
/// Returns: None.
/// Side effects: Creates and deletes temporary app directories.
/// Notes: The merge must be conflict-free and per-field, and the module must
/// make the avatar travel through the image phase.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('model', () {
    test('round-trips and keeps unknown keys', () {
      final json = {
        'version': 1,
        'displayName': 'Yuan',
        'displayNameUpdatedAt': _t1.toIso8601String(),
        'avatar': 'images/avatar_x.jpg',
        'avatarUpdatedAt': _t2.toIso8601String(),
        'futureField': {'a': 1},
      };
      final data = ProfileData.fromJson(json);
      expect(data.name, 'Yuan');
      expect(data.avatar, 'images/avatar_x.jpg');
      expect(data.toJson(), json);
    });

    test('an empty profile writes only its version', () {
      expect(ProfileData().toJson(), {'version': 1});
    });

    test('a removed avatar is written as an explicit null', () {
      final data = ProfileData().withAvatar(null, _t1);
      expect(data.toJson(), containsPair('avatar', null));
      expect(data.toJson(), contains('avatarUpdatedAt'));
    });

    test('rejects a payload that is not an object', () {
      expect(() => ProfileData.fromJson([1]), throwsFormatException);
    });
  });

  group('merge', () {
    test('each field keeps the newer side independently', () {
      final local = ProfileData(
        displayName: 'Local',
        displayNameUpdatedAt: _t2,
        avatar: 'images/avatar_old.jpg',
        avatarUpdatedAt: _t1,
      );
      final remote = ProfileData(
        displayName: 'Remote',
        displayNameUpdatedAt: _t1,
        avatar: 'images/avatar_new.jpg',
        avatarUpdatedAt: _t2,
      );
      final merged = mergeProfile(local, remote);
      expect(merged.name, 'Local');
      expect(merged.avatar, 'images/avatar_new.jpg');
    });

    test('a tie keeps local', () {
      final merged = mergeProfile(
        ProfileData(displayName: 'L', displayNameUpdatedAt: _t1),
        ProfileData(displayName: 'R', displayNameUpdatedAt: _t1),
      );
      expect(merged.name, 'L');
    });

    test('a newer removal beats an older avatar', () {
      final merged = mergeProfile(
        ProfileData(avatar: 'images/avatar_a.jpg', avatarUpdatedAt: _t1),
        ProfileData().withAvatar(null, _t2),
      );
      expect(merged.avatar, isNull);
      expect(merged.avatarUpdatedAt, _t2);
    });

    test('a side that never set a field loses to one that did', () {
      final merged = mergeProfile(
        ProfileData(),
        ProfileData(displayName: 'R', displayNameUpdatedAt: _t1),
      );
      expect(merged.name, 'R');
    });

    test('raw JSON merge output is the store encoding', () {
      final local = encodeProfile(
        ProfileData(displayName: 'L', displayNameUpdatedAt: _t1),
      );
      expect(mergeProfileJson(local, local), local);
    });
  });

  group('module', () {
    test('is registered last with frozen names', () {
      final module = animeModuleRegistry.modules.last;
      expect(module.fileName, 'profile.json');
      expect(module.moduleId, 'profile');
      expect(ProfileStore.fileName, profileFileName);
    });

    test('references the avatar image so it syncs', () {
      final json = encodeProfile(
        ProfileData(avatar: 'images/avatar_x.jpg', avatarUpdatedAt: _t1),
      );
      expect(profileReferencedImages(json), {'avatar_x.jpg'});
      expect(profileReferencedImages(encodeProfile(ProfileData())), isEmpty);
      expect(profileReferencedImages('not json'), isEmpty);
    });

    test('validate rejects foreign payloads', () {
      expect(() => validateProfileJson('[]'), throwsFormatException);
      validateProfileJson('{}');
    });
  });

  group('store', () {
    late Directory temp;
    late Directory appDir;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('myanime_profile');
      final docs = Directory(p.join(temp.path, 'docs'))..createSync();
      appDir = Directory(p.join(docs.path, 'MyAnime'))..createSync();
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('setName writes pretty JSON and is a no-op when unchanged', () async {
      await ProfileStore.setName('  Yuan  ');
      final file = File(p.join(appDir.path, 'profile.json'));
      final first = file.readAsStringSync();
      expect(jsonDecode(first)['displayName'], 'Yuan');
      expect(first, encodeProfile(ProfileData.fromJson(jsonDecode(first))));
      await ProfileStore.setName('Yuan');
      expect(file.readAsStringSync(), first);
      expect((await ProfileStore.load()).name, 'Yuan');
    });

    test('an unreadable file is left untouched', () async {
      final file = File(p.join(appDir.path, 'profile.json'))
        ..writeAsStringSync('{broken');
      await expectLater(ProfileStore.setName('X'), throwsFormatException);
      expect(file.readAsStringSync(), '{broken');
    });

    test('removeAvatar deletes only avatar files', () async {
      final images = Directory(p.join(appDir.path, 'images'))..createSync();
      final avatar = File(p.join(images.path, 'avatar_a.jpg'))
        ..writeAsStringSync('x');
      await ProfileStore.update(
        (d) => d.withAvatar('images/avatar_a.jpg', _t1),
      );
      final data = await ProfileStore.removeAvatar();
      expect(data.avatar, isNull);
      expect(avatar.existsSync(), isFalse);
    });
  });

  test('squareAvatarJpeg crops to a centred square', () {
    final source = img.Image(width: 300, height: 100);
    final jpeg = squareAvatarJpeg(
      Uint8List.fromList(img.encodePng(source)),
      64,
    );
    final out = img.decodeJpg(jpeg)!;
    expect(out.width, 64);
    expect(out.height, 64);
    expect(
      () => squareAvatarJpeg(Uint8List.fromList([1, 2, 3]), 64),
      throwsFormatException,
    );
  });

  group('avatar editor images', () {
    test('prepareAvatarSource rotates and limits the size', () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 4000, height: 1000)),
      );
      final upright = prepareAvatarSource(png);
      expect(upright.width, avatarSourceMaxEdge);
      expect(upright.height, 512);
      final turned = prepareAvatarSource(png, quarterTurns: 1);
      expect(turned.width, 512);
      expect(turned.height, avatarSourceMaxEdge);
      expect(
        () => prepareAvatarSource(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
    });

    test('cropAvatarJpeg cuts the framed square', () {
      // Left half red, right half blue: framing the right half must give a
      // blue avatar.
      final source = img.Image(width: 200, height: 100);
      img.fillRect(
        source,
        x1: 0,
        y1: 0,
        x2: 99,
        y2: 99,
        color: img.ColorRgb8(255, 0, 0),
      );
      img.fillRect(
        source,
        x1: 100,
        y1: 0,
        x2: 199,
        y2: 99,
        color: img.ColorRgb8(0, 0, 255),
      );
      final jpeg = cropAvatarJpeg(
        Uint8List.fromList(img.encodePng(source)),
        x: 100,
        y: 0,
        side: 100,
        size: 64,
      );
      final out = img.decodeJpg(jpeg)!;
      expect(out.width, 64);
      final centre = out.getPixel(32, 32);
      expect(centre.b, greaterThan(200));
      expect(centre.r, lessThan(60));
    });

    test('the background helpers run in another isolate', () async {
      // Regression: calling Isolate.run from inside the editor's State
      // captured the State and failed; the top-level helpers must work.
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 300, height: 200)),
      );
      final source = await prepareAvatarSourceInBackground(
        png,
        quarterTurns: 1,
      );
      expect(source.width, 200);
      final jpeg = await cropAvatarJpegInBackground(
        source.bytes,
        x: 0,
        y: 0,
        side: 200,
        size: 64,
      );
      expect(img.decodeJpg(jpeg)!.width, 64);
    });

    test('cropAvatarJpeg clamps a square that runs off the image', () {
      final png = Uint8List.fromList(
        img.encodePng(img.Image(width: 120, height: 80)),
      );
      final out = img.decodeJpg(
        cropAvatarJpeg(png, x: 100, y: 50, side: 500, size: 32),
      )!;
      expect(out.width, 32);
      expect(out.height, 32);
    });
  });

  group('store avatar', () {
    late Directory temp;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('myanime_avatar');
      final docs = Directory(p.join(temp.path, 'docs'))..createSync();
      Directory(p.join(docs.path, 'MyAnime')).createSync();
      PathProviderPlatform.instance = _FakePathProvider(docs.path);
    });
    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test(
      'setAvatarJpeg stores a fresh file and readAvatarBytes reads it',
      () async {
        final first = Uint8List.fromList([1, 2, 3]);
        final a = await ProfileStore.setAvatarJpeg(first);
        expect(a.avatar, startsWith('images/avatar_'));
        expect(await ProfileStore.readAvatarBytes(), first);
        final b = await ProfileStore.setAvatarJpeg(Uint8List.fromList([4]));
        expect(b.avatar, isNot(a.avatar));
        final dir = Directory(p.join(temp.path, 'docs', 'MyAnime', 'images'));
        expect(dir.listSync(), hasLength(1)); // the replaced file is deleted
      },
    );
  });
}
