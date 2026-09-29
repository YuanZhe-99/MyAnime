// Golden (characterization) harness for MyAnime.
//
// Drives the REAL, unmodified `WebDAVService` / `BackupService` /
// `ImportExportService` against an in-memory fake WebDAV server, recording the
// exact request sequence and on-disk formats into golden files. This is PLAN
// task P0.2: post-extraction (Phase 3), the new shared engine must reproduce
// these identical sequences (invariants I1-I3). Re-run / re-record with:
//   flutter test test/golden/webdav_golden_test.dart            (verify)
//   flutter test --dart-define=GOLDEN_RECORD=true test/golden/webdav_golden_test.dart  (record)
// (must be literally `true` — bool.fromEnvironment treats `1` as false, so the
// run silently stays in verify mode.)
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/src/client.dart' show runWithClient;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:my_anime/shared/services/backup_service.dart';
import 'package:my_anime/shared/services/import_export_service.dart';
import 'package:my_anime/shared/services/webdav_service.dart';

import 'fake_webdav_server.dart';
import 'request_recorder.dart';

/// Whether to rewrite goldens instead of verifying them.
const bool _record =
    bool.fromEnvironment('GOLDEN_RECORD', defaultValue: false);

/// Fake application-documents provider (pattern from existing app tests).
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);
  final String documentsPath;
  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

/// Fixed WebDAV config pointing at the fake server.
WebDAVConfig _config() => const WebDAVConfig(
      serverUrl: 'https://golden.test/dav/files/u',
      username: 'u',
      password: 'p',
      remotePath: '/MyAnime',
    );

/// One scenario sandbox: a fresh temp dir + fresh fake server + recorder.
class _Sandbox {
  _Sandbox(this.dir, this.server, this.recorder);
  final Directory dir;
  final FakeWebDAVServer server;
  final RequestRecorder recorder;

  String get appDir => p.join(dir.path, 'MyAnime');

  /// Remote path for a data file (server keys on full request path).
  String remote(String name) => '/dav/files/u/MyAnime/$name';

  Future<File> dataFile() async =>
      File(p.join(appDir, 'anime_data.json'));

  Future<void> writeLocalData(String json) async {
    await Directory(appDir).create(recursive: true);
    await (await dataFile()).writeAsString(json);
  }

  String transcript() => GoldenTranscript(recorder.exchanges).render();
}

/// Minimal valid anime_data.json with [animes] as raw record maps.
String _animeData(List<Map<String, dynamic>> animes) =>
    const JsonEncoder.withIndent('  ').convert({'animes': animes});

Map<String, dynamic> _anime(String id, String title, String modifiedAt,
        {String? coverImage}) =>
    {
      'id': id,
      'title': title,
      'createdAt': modifiedAt,
      'modifiedAt': modifiedAt,
      if (coverImage != null) 'coverImage': coverImage, // ignore: use_null_aware_elements
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final goldensDir = Directory(p.join('test', 'golden', 'goldens', 'myanime'));

  Future<_Sandbox> newSandbox() async {
    final dir = await Directory.systemTemp.createTemp('myanime_golden_');
    PathProviderPlatform.instance = _FakePathProvider(dir.path);
    final server = FakeWebDAVServer();
    final recorder = RequestRecorder(server);
    return _Sandbox(dir, server, recorder);
  }

  Future<void> expectGolden(_Sandbox sb, String name) async {
    final file = File(p.join(goldensDir.path, '$name.txt'));
    final mismatch = await GoldenMatcher(file, record: _record)
        .check(sb.transcript());
    expect(mismatch, isNull, reason: 'golden "$name" mismatch:\n$mismatch');
  }

  /// Run `body` against the fake server inside the recording zone.
  Future<T> zone<T>(_Sandbox sb, Future<T> Function() body) =>
      runWithClient(body, () => sb.recorder);

  group('webdav sync request-sequence goldens', () {
    test('first sync (local data, empty remote)', () async {
      final sb = await newSandbox();
      await sb.writeLocalData(_animeData(
          [_anime('a1', 'Frieren', '2026-07-01T00:00:00.000Z')]));
      final result = await zone(sb, () => WebDAVService.sync(_config()));
      expect(result.success, isTrue, reason: result.error);
      await expectGolden(sb, 'sync_first');
      // Remote now holds the uploaded data + base snapshot written.
      expect(sb.server.readText(sb.remote('anime_data.json')),
          contains('Frieren'));
      await sb.dir.delete(recursive: true);
    });

    test('true conflict then finalize', () async {
      final sb = await newSandbox();
      final base = _animeData(
          [_anime('a1', 'Frieren', '2026-07-01T00:00:00.000Z')]);
      final local = _animeData(
          [_anime('a1', 'Frieren Local', '2026-07-05T00:00:00.000Z')]);
      final remote = _animeData(
          [_anime('a1', 'Frieren Remote', '2026-07-06T00:00:00.000Z')]);
      await sb.writeLocalData(local);
      sb.server.seed(sb.remote('anime_data.json'), remote);
      final baseDir = Directory(p.join(sb.appDir, '.sync_base'));
      await baseDir.create(recursive: true);
      await File(p.join(baseDir.path, 'anime_data.json')).writeAsString(base);

      final syncResult = await zone(sb, () => WebDAVService.sync(_config()));
      expect(syncResult.pending, isNotNull,
          reason: 'both-changed-different must conflict');

      // Resolve: choose the remote record for the conflicted id.
      final conflict = syncResult.pending!.allConflicts.single;
      final resolutions = {conflict.id: conflict.remoteRecord};
      final fin = await zone(
          sb,
          () => WebDAVService.finalizePendingSync(
              _config(), syncResult.pending!, resolutions));
      expect(fin, isTrue);
      await expectGolden(sb, 'sync_conflict_finalize');
      expect(sb.server.readText(sb.remote('anime_data.json')),
          contains('Frieren Remote'));
      await sb.dir.delete(recursive: true);
    });

    test('force upload', () async {
      final sb = await newSandbox();
      final local = _animeData(
          [_anime('a1', 'Frieren', '2026-07-01T00:00:00.000Z')]);
      await sb.writeLocalData(local);
      // Remote has different (older) content that force upload must overwrite.
      sb.server.seed(sb.remote('anime_data.json'),
          _animeData([_anime('a9', 'Stale', '2020-01-01T00:00:00.000Z')]));
      final result = await zone(sb, () => WebDAVService.forceUpload(_config()));
      expect(result.success, isTrue, reason: result.error);
      await expectGolden(sb, 'force_upload');
      expect(sb.server.readText(sb.remote('anime_data.json')),
          contains('Frieren'));
      await sb.dir.delete(recursive: true);
    });

  });

  group('backup goldens (on-disk format)', () {
    test('v2 create bundle layout', () async {
      final sb = await newSandbox();
      BackupService.appDirProvider = () async => Directory(sb.appDir);
      BackupService.autoBackupEnabled = false;
      await sb.writeLocalData(_animeData(
          [_anime('a1', 'Frieren', '2026-07-01T00:00:00.000Z')]));
      final imgDir = Directory(p.join(sb.appDir, 'images'));
      await imgDir.create(recursive: true);
      await File(p.join(imgDir.path, 'cover1.jpg')).writeAsBytes([1, 2, 3]);

      final backup = await BackupService.createBackup();
      expect(backup, isNotNull);
      expect(await backup!.exists(), isTrue);

      // Render the bundle JSON layout (normalized) as the golden.
      final bundle =
          jsonDecode(await backup.readAsString()) as Map<String, dynamic>;
      final blobDir = Directory(p.join(sb.appDir, 'backups', 'blobs'));
      final blobs = await blobDir
          .list()
          .where((e) => e is File)
          .map((e) => p.basename(e.path))
          .toList();
      blobs.sort();
      final golden = StringBuffer()
        ..writeln('backupFormat: ${bundle['_backupFormat']}')
        ..writeln('topLevelKeys: ${(bundle.keys.toList()..sort()).join(',')}')
        ..writeln('hasImageRefs: ${bundle.containsKey('_imageRefs')}')
        ..writeln('imageRefKeys: '
            '${((bundle['_imageRefs'] as Map?)?.keys.toList() ?? [])}')
        ..writeln('dataIsString: ${bundle['anime_data.json'] is String}')
        ..writeln('blobs: ${blobs.map((b) => b.replaceAll(RegExp('[0-9a-f]{64}'), '<sha256>')).join(',')}');
      final file = File(p.join(goldensDir.path, 'backup_v2_create.txt'));
      final mismatch = await GoldenMatcher(file, record: _record)
          .check(golden.toString());
      expect(mismatch, isNull, reason: mismatch);
      BackupService.appDirProvider = null;
      await sb.dir.delete(recursive: true);
    });

  });

  group('zip goldens', () {
    test('export entry list', () async {
      final sb = await newSandbox();
      await sb.writeLocalData(_animeData(
          [_anime('a1', 'Frieren', '2026-07-01T00:00:00.000Z')]));
      final imgDir = Directory(p.join(sb.appDir, 'images'));
      await imgDir.create(recursive: true);
      await File(p.join(imgDir.path, 'cover1.jpg')).writeAsBytes([1, 2, 3]);
      final outDir = await Directory.systemTemp.createTemp('myanime_zip_');
      final zipPath = await ImportExportService.exportZIP(outDir.path);
      expect(zipPath, isNotNull);
      final entries = _zipEntries(File(zipPath!));
      final file = File(p.join(goldensDir.path, 'zip_export_entries.txt'));
      final mismatch = await GoldenMatcher(file, record: _record)
          .check('${entries.join('\n')}\narchiveName: ${p.basename(zipPath).replaceAll(RegExp(r'\d{8}_\d{6}'), '<stamp>')}\n');
      expect(mismatch, isNull, reason: mismatch);
      await sb.dir.delete(recursive: true);
      await outDir.delete(recursive: true);
    });

  });
}

/// Read entry names from a ZIP file.
List<String> _zipEntries(File zipFile) {
  final bytes = zipFile.readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);
  final names = archive.map((f) => f.name).toList()..sort();
  return names;
}
