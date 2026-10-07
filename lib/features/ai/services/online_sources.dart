import 'package:flutter/foundation.dart';
import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_online/myapps_ai_online.dart';
import 'package:myapps_ai_online_ui/myapps_ai_online_ui.dart';
import 'package:myapps_data/myapps_data.dart';
import 'package:uuid/uuid.dart';

import '../../../app/data_modules.dart';

/// Device-local providers and keys; no sync/backup data module.
class OnlineSources implements OnlineSourcesController {
  /// Purpose: Bind device-local storage. Inputs: optional test storage.
  /// Returns: Controller. Side effects: None. Notes: No network calls.
  OnlineSources({StorageAdapter? storage})
    : storage = storage ?? const AnimeStorageAdapter();
  final StorageAdapter storage;
  late final secrets = SecretStore(
    storage: storage,
    fileName: 'anime_ai_secrets.json',
    namespaces: {'provider'},
  );
  final _notifier = ValueNotifier<int>(0);
  List<OnlineProvider> _providers = [];
  Future<void>? _loading;

  /// Purpose: Read local providers once. Inputs: None. Returns: Completion.
  /// Side effects: Reads config. Notes: Never contacts a provider.
  Future<void> initialize() => _loading ??= _load();

  /// Purpose: Load provider records. Inputs: None. Returns: Completion.
  /// Side effects: Reads config/notifies. Notes: Unknown provider fields retained.
  Future<void> _load() async {
    final raw = (await storage.readConfig())['aiOnlineProviders'];
    if (raw is Map) {
      _providers = [
        for (final e in raw.entries)
          if (e.key is String && e.value is Map<String, dynamic>)
            OnlineProvider.fromJson(
              e.key as String,
              e.value as Map<String, dynamic>,
            ),
      ];
    }
    _notifier.value++;
  }

  /// Purpose: Return configured providers. Inputs: None. Returns: List.
  /// Side effects: None. Notes: Device-local.
  @override
  List<OnlineProvider> get providers => List.unmodifiable(_providers);

  /// Purpose: Observe changes. Inputs: None. Returns: Listenable.
  /// Side effects: None. Notes: Includes secret edits.
  @override
  Listenable get changes => _notifier;

  /// Purpose: Register standard templates. Inputs: None. Returns: Registry.
  /// Side effects: None. Notes: No connections.
  @override
  OnlineProviderTemplateRegistry get templates =>
      OnlineProviderTemplateRegistry.builtIn();

  /// Purpose: Allocate a provider id. Inputs: None. Returns: Id.
  /// Side effects: None. Notes: Does not reuse seeded ids.
  @override
  String newProviderId() => 'provider:${const Uuid().v4()}';

  /// Purpose: Check stored key presence. Inputs: id. Returns: Boolean.
  /// Side effects: Reads secret file. Notes: No key displayed.
  @override
  Future<bool> hasKey(String providerId) async =>
      (await secrets.keyFor(providerId))?.isNotEmpty ?? false;

  /// Purpose: Save acknowledged configuration and optional key.
  /// Inputs: provider/key/removal. Returns: Completion.
  /// Side effects: Writes local configuration/secrets. Notes: UI obtains consent first.
  @override
  Future<void> save(
    OnlineProvider provider, {
    String? newKey,
    bool clearKey = false,
  }) async {
    await initialize();
    if (clearKey || newKey != null) {
      await secrets.setKey(provider.id, clearKey ? null : newKey);
    }
    final config = await storage.readConfig();
    final raw = Map<String, dynamic>.from(
      config['aiOnlineProviders'] as Map? ?? {},
    );
    raw[provider.id] = provider.toJson();
    config['aiOnlineProviders'] = raw;
    await storage.writeConfig(config);
    _providers = [..._providers.where((p) => p.id != provider.id), provider];
    _notifier.value++;
  }

  /// Purpose: Remove a provider and key. Inputs: id. Returns: Completion.
  /// Side effects: Local writes. Notes: Invalid selection reports unavailable.
  @override
  Future<void> remove(String providerId) async {
    await secrets.setKey(providerId, null);
    final config = await storage.readConfig();
    final raw = Map<String, dynamic>.from(
      config['aiOnlineProviders'] as Map? ?? {},
    );
    raw.remove(providerId);
    config['aiOnlineProviders'] = raw;
    await storage.writeConfig(config);
    _providers.removeWhere((p) => p.id == providerId);
    _notifier.value++;
  }

  /// Purpose: Test an explicit draft. Inputs: provider/key. Returns: Report.
  /// Side effects: One server request. Notes: Sends no library content.
  @override
  Future<GenAiStatusReport> testConnection(
    OnlineProvider draft,
    String? draftKey,
  ) => OpenAiCompatibleLlmBackend(
    provider: draft,
    readSecret: (_) async => draftKey ?? await secrets.keyFor(draft.id),
  ).testConnection();

  /// Purpose: Describe transmitted content. Inputs: provider. Returns: Notice.
  /// Side effects: None. Notes: Local keys never enter sync, backup or ZIP.
  @override
  OnlinePrivacyNotice? privacyNotice(OnlineProvider provider) =>
      OnlinePrivacyNotice.forProvider(
        version: 1,
        host: provider.recipientHost,
        providerName: provider.name,
        sent: const [
          OnlineDataItem(OnlineDataCategory.promptText),
          OnlineDataItem(OnlineDataCategory.appDataSummary),
        ],
        keySync: OnlineKeySync.deviceOnly,
      );

  /// Purpose: Read host-specific consent. Inputs: id. Returns: Record.
  /// Side effects: Reads config. Notes: Device-local.
  @override
  Future<OnlinePrivacyAcknowledgement?> acknowledgement(
    String providerId,
  ) async {
    final raw = (await storage.readConfig())['aiOnlineAcknowledgements'];
    return OnlinePrivacyAcknowledgement.tryParse(
      raw is Map ? raw[providerId] : null,
    );
  }

  /// Purpose: Persist consent. Inputs: id/record. Returns: Completion.
  /// Side effects: Config write. Notes: Never synchronized.
  @override
  Future<void> acknowledge(
    String providerId,
    OnlinePrivacyAcknowledgement record,
  ) async {
    final config = await storage.readConfig();
    final raw = Map<String, dynamic>.from(
      config['aiOnlineAcknowledgements'] as Map? ?? {},
    );
    raw[providerId] = record.toJson();
    config['aiOnlineAcknowledgements'] = raw;
    await storage.writeConfig(config);
  }
}
