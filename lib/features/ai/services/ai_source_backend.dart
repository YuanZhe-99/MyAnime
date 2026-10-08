import 'dart:io';

import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_models/myapps_ai_models.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart';
import 'package:myapps_ai_sources/myapps_ai_sources.dart';
import 'package:myapps_data/myapps_data.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/data_modules.dart';
import 'genai_backend.dart' show MethodChannelGenAiBackend;

export 'package:myapps_ai_online/myapps_ai_online.dart'
    show OnlineSourceManager;
export 'package:myapps_ai_sources/myapps_ai_sources.dart' show AiSourceRouter;

/// Purpose: Create MyAnime's online sources over its configuration and the
/// existing secret file.
/// Inputs: Optional [storage] for tests. Returns: The manager.
/// Side effects: None until used.
/// Notes: Records, keys and acknowledgements keep the keys and file of
/// 1.8.11 (`aiOnlineProviders`, `aiOnlineAcknowledgements`,
/// `anime_ai_secrets.json`), so existing sources carry over.
OnlineSourceManager createOnlineSources({StorageAdapter? storage}) {
  final s = storage ?? const AnimeStorageAdapter();
  final secrets = SecretStore(
    storage: s,
    fileName: 'anime_ai_secrets.json',
    namespaces: {'provider'},
  );
  return OnlineSourceManager(
    readConfig: s.readConfig,
    writeConfig: s.writeConfig,
    readKey: secrets.keyFor,
    writeKey: secrets.setKey,
    notice: (p) => OnlinePrivacyNotice.forProvider(
      version: 1,
      host: p.recipientHost,
      providerName: p.name,
      sent: const [
        OnlineDataItem(OnlineDataCategory.promptText),
        OnlineDataItem(OnlineDataCategory.appDataSummary),
      ],
      keySync: OnlineKeySync.deviceOnly,
    ),
  );
}

/// Purpose: Create the app's AI source router over MyAnime storage.
/// Inputs: Optional [storage], [system] and [online] for tests.
/// Returns: The router.
/// Side effects: Reads the app version in the background for technical
/// details.
/// Notes: Model files live in `<app dir>/ai_models`, outside sync and
/// backups; the choices stay in this device's configuration.
AiSourceRouter createAiSourceRouter({
  StorageAdapter? storage,
  CapabilityGenAiBackend? system,
  OnlineSourceManager? online,
}) {
  final s = storage ?? const AnimeStorageAdapter();
  final appInfo = <String, String>{};
  PackageInfo.fromPlatform()
      .then((i) => appInfo['app'] = 'MyAnime ${i.version}+${i.buildNumber}')
      .catchError((_) => appInfo['app'] = 'MyAnime');
  return AiSourceRouter(
    store: CallbackAiSourceStore(
      readConfig: s.readConfig,
      writeConfig: s.writeConfig,
    ),
    system: system ?? MethodChannelGenAiBackend(),
    models: CallbackModelStorageRoot(
      () async => Directory('${(await s.getAppDir()).path}/ai_models'),
    ),
    online: online ?? createOnlineSources(storage: s),
    appInfo: appInfo,
  );
}
