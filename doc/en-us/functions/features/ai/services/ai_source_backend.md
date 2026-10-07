# lib/features/ai/services/ai_source_backend.dart

## AI sources and WebDAV privacy

MyApps-AI v0.5.3 is explicitly split into runtime, platform, models, local UI and llama.cpp packages. Settings uses the unified section skeleton. Global source selection is device-local (`aiSourceSelection`), defaults to system AI, and never chooses online as fallback. Qwen3.5 0.8B/2B Q4_K_M and Gemma 4 E2B Q4_0 run on CPU. Downloads require explicit actions, use pinned URLs and SHA-256, and live under `ai_models/` outside data modules, sync, backup and ZIP. Model leases prevent removal during use. Source switches cancel old work and release model resources. System proofreading remains independent in MyNihongo.

WebDAV notice version 1 must be acknowledged on each device before connection testing, manual/force sync or background sync. The record is in device-local storage_config.json. Existing configurations stay intact while sync is paused; the WebDAV page displays a review banner. Declining saves no configuration and makes no request. JSON/images have no application-level encryption; HTTPS protects transit, HTTP does not. Wire format, locks and conflict policy remain unchanged.

Online sources use shared online UI/backend and MyApps-UI inputs. Provider records and plaintext API keys are device-local; keys use SecretStore and never enter sync/backup/ZIP. Explicit selection and host-specific privacy acknowledgement are required. Prompts contain category/recommendation inputs; no online fallback.

## Declarations

| Declaration | Purpose |
|---|---|
| `AiSourceBackend({StorageAdapter? storage, CapabilityGenAiBackend? system})` | Bind app storage and system inference. |
| `Future<void> initialize() => _initializing ??= _initialize().catchError((` | Read device-local choices and installed metadata. |
| `Future<void> _initialize() async {` | Initialize metadata once. Inputs: None. Returns: Completion. |
| `Future<void> select(String id) async {` | Persist a source change after callers invalidate their service. |
| `void _publish() {` | Publish metadata. Inputs: None. Returns: None. |
| `ModelManagementState get state => ModelManagementState(` | Build management rows. Inputs: None. Returns: State. |
| `Stream<ModelManagementState> get changes => _changes.stream;` | Observe management changes. Inputs: None. Returns: Stream. |
| `Future<void> perform(String modelId, ModelAction action) async {` | Execute an explicit model action. Inputs: model/action. Returns: Completion. |
| `Future<GenAiBackend> _resolve() =>` | Resolve the explicitly chosen backend. Inputs: None. Returns: Backend. |
| `Future<GenAiBackend> _resolveSelected() async {` | Resolve one source without concurrent model allocations. |
| `Future<void> _releaseLocal() async {` | Release the current model. Inputs: None. Returns: Completion. |
| `Future<GenAiStatusReport> statusReport({` | Read selected readiness. Inputs: probe/preference. Returns: Report. |
| `Future<GenAiCoreInfo?> coreInfo({String? localeTag}) async {` | Read backend diagnostics. Inputs: locale. Returns: Info. |
| `Future<bool> download({void Function(int, int)? onProgress}) async =>` | Download a system model explicitly. Inputs: progress. Returns: Readiness. |
| `Future<String> generate({` | Generate with selected source. Inputs: prompt/sampling. Returns: Text. |
| `Future<List<String>> choose({` | Choose validated options. Inputs: prompt/options/cap. Returns: Ids. |
| `Future<void> prewarm() async {` | Prewarm selected backend. Inputs: None. Returns: Completion. |
| `Future<void> cancel() async {` | Cancel active inference. Inputs: None. Returns: Completion. |
| `Future<GenAiStatusReport> capabilityReport(` | Keep proofreading as a separate system capability. |
| `Future<bool> downloadCapability(` | Download an independent capability. Inputs: feature/progress. |
| `Future<List<String>> proofread(String text) => system.proofread(text);` | Correct Japanese with the system capability. Inputs: text. Returns: Suggestions. |
