# lib/shared/services/webdav_privacy.dart

## AI sources and WebDAV privacy

MyApps-AI v0.6.0 is explicitly split into runtime, platform, models, local UI and llama.cpp packages. Settings uses the unified section skeleton. Global source selection is device-local (`aiSourceSelection`), defaults to system AI, and never chooses online as fallback. Qwen3.5 0.8B/2B Q4_K_M and Gemma 4 E2B Q4_0 run on CPU by default; the GPU is used only when turned on in the source section and only where verified, and GPU failures are recorded on the device. Custom GGUF models can be added from a Hugging Face repository after a mandatory warning, and models can be renamed. The device-local keys `aiComputePreference`, `aiGpuFailures`, `aiCustomModels` and `aiModelAliases` never sync and never enter backups. Downloads require explicit actions, use pinned URLs and SHA-256, and live under `ai_models/` outside data modules, sync, backup and ZIP. Model leases prevent removal during use. Source switches cancel old work and release model resources. System proofreading remains independent in MyNihongo.

WebDAV notice version 1 must be acknowledged on each device before connection testing, manual/force sync or background sync. The record is in device-local storage_config.json. Existing configurations stay intact while sync is paused; the WebDAV page displays a review banner. Declining saves no configuration and makes no request. JSON/images have no application-level encryption; HTTPS protects transit, HTTP does not. Wire format, locks and conflict policy remain unchanged.

Online sources use shared online UI/backend and MyApps-UI inputs. Provider records and plaintext API keys are device-local; keys use SecretStore and never enter sync/backup/ZIP. Explicit selection and host-specific privacy acknowledgement are required. Prompts contain category/recommendation inputs; no online fallback. An online source holds several models; selections are `online:model:<source>:<model>`, and earlier `provider:<id>` selections keep working.

## Declarations

| Declaration | Purpose |
|---|---|
| `static Future<bool> allowed() async =>` | Determine whether sync may run. Inputs: None. Returns: Consent. |
| `static Future<WebDavPrivacyStatus> status(bool configured) async =>` | Classify a configured device. Inputs: configured. Returns: Status. |
| `static Future<bool> ensure(BuildContext context, WebDAVConfig config) async {` | Obtain consent before saving or making any request. |
