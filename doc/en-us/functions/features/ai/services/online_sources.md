# lib/features/ai/services/online_sources.dart

## AI sources and WebDAV privacy

MyApps-AI v0.5.3 is explicitly split into runtime, platform, models, local UI and llama.cpp packages. Settings uses the unified section skeleton. Global source selection is device-local (`aiSourceSelection`), defaults to system AI, and never chooses online as fallback. Qwen3.5 0.8B/2B Q4_K_M and Gemma 4 E2B Q4_0 run on CPU. Downloads require explicit actions, use pinned URLs and SHA-256, and live under `ai_models/` outside data modules, sync, backup and ZIP. Model leases prevent removal during use. Source switches cancel old work and release model resources. System proofreading remains independent in MyNihongo.

WebDAV notice version 1 must be acknowledged on each device before connection testing, manual/force sync or background sync. The record is in device-local storage_config.json. Existing configurations stay intact while sync is paused; the WebDAV page displays a review banner. Declining saves no configuration and makes no request. JSON/images have no application-level encryption; HTTPS protects transit, HTTP does not. Wire format, locks and conflict policy remain unchanged.

Online sources use shared online UI/backend and MyApps-UI inputs. Provider records and plaintext API keys are device-local; keys use SecretStore and never enter sync/backup/ZIP. Explicit selection and host-specific privacy acknowledgement are required. Prompts contain category/recommendation inputs; no online fallback.

## Declarations

| Declaration | Purpose |
|---|---|
| `OnlineSources({StorageAdapter? storage})` | Bind device-local storage. Inputs: optional test storage. |
| `Future<void> initialize() => _loading ??= _load();` | Read local providers once. Inputs: None. Returns: Completion. |
| `Future<void> _load() async {` | Load provider records. Inputs: None. Returns: Completion. |
| `List<OnlineProvider> get providers => List.unmodifiable(_providers);` | Return configured providers. Inputs: None. Returns: List. |
| `Listenable get changes => _notifier;` | Observe changes. Inputs: None. Returns: Listenable. |
| `OnlineProviderTemplateRegistry get templates =>` | Register standard templates. Inputs: None. Returns: Registry. |
| `String newProviderId() => 'provider:${const Uuid().v4()}';` | Allocate a provider id. Inputs: None. Returns: Id. |
| `Future<bool> hasKey(String providerId) async =>` | Check stored key presence. Inputs: id. Returns: Boolean. |
| `Future<void> save(` | Save acknowledged configuration and optional key. |
| `Future<void> remove(String providerId) async {` | Remove a provider and key. Inputs: id. Returns: Completion. |
| `Future<GenAiStatusReport> testConnection(` | Test an explicit draft. Inputs: provider/key. Returns: Report. |
| `OnlinePrivacyNotice? privacyNotice(OnlineProvider provider) =>` | Describe transmitted content. Inputs: provider. Returns: Notice. |
| `Future<OnlinePrivacyAcknowledgement?> acknowledgement(` | Read host-specific consent. Inputs: id. Returns: Record. |
| `Future<void> acknowledge(` | Persist consent. Inputs: id/record. Returns: Completion. |
