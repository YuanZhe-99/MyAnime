import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:my_anime/shared/services/webdav_privacy.dart';
import 'package:my_anime/shared/services/webdav_service.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.path);
  final String path;
  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all network entry points refuse unacknowledged devices', () async {
    final dir = await Directory.systemTemp.createTemp('privacy_test');
    addTearDown(() => dir.delete(recursive: true));
    PathProviderPlatform.instance = _Paths(dir.path);
    const config = WebDAVConfig(
      serverUrl: 'https://must-not-connect.invalid',
      username: 'u',
      password: 'p',
      remotePath: '/MyAnime',
    );
    expect(await WebDavPrivacy.allowed(), isFalse);
    expect(await WebDAVService.testConnection(config), isFalse);
    expect((await WebDAVService.sync(config)).success, isFalse);
    expect((await WebDAVService.forceUpload(config)).success, isFalse);
    expect((await WebDAVService.forceDownload(config)).success, isFalse);
    await WebDavPrivacy.store.acknowledge(WebDavPrivacy.noticeVersion);
    expect(await WebDavPrivacy.allowed(), isTrue);
  });
}
