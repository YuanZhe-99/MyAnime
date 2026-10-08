# lib/features/ai/services/ai_source_backend.dart

## AI sources and WebDAV privacy

MyApps-AI v0.6.0 is explicitly split into runtime, platform, models, local UI and llama.cpp packages. Settings uses the unified section skeleton. Global source selection is device-local (`aiSourceSelection`), defaults to system AI, and never chooses online as fallback. Qwen3.5 0.8B/2B Q4_K_M and Gemma 4 E2B Q4_0 run on CPU by default; the GPU is used only when turned on in the source section and only where verified, and GPU failures are recorded on the device. Custom GGUF models can be added from a Hugging Face repository after a mandatory warning, and models can be renamed. The device-local keys `aiComputePreference`, `aiGpuFailures`, `aiCustomModels` and `aiModelAliases` never sync and never enter backups. Downloads require explicit actions, use pinned URLs and SHA-256, and live under `ai_models/` outside data modules, sync, backup and ZIP. Model leases prevent removal during use. Source switches cancel old work and release model resources. System proofreading remains independent in MyNihongo.

WebDAV notice version 1 must be acknowledged on each device before connection testing, manual/force sync or background sync. The record is in device-local storage_config.json. Existing configurations stay intact while sync is paused; the WebDAV page displays a review banner. Declining saves no configuration and makes no request. JSON/images have no application-level encryption; HTTPS protects transit, HTTP does not. Wire format, locks and conflict policy remain unchanged.

Online sources use shared online UI/backend and MyApps-UI inputs. Provider records and plaintext API keys are device-local; keys use SecretStore and never enter sync/backup/ZIP. Explicit selection and host-specific privacy acknowledgement are required. Prompts contain category/recommendation inputs; no online fallback. An online source holds several models; selections are `online:model:<source>:<model>`, and earlier `provider:<id>` selections keep working.

## Declarations

| Declaration | Purpose |
|---|---|
| `createOnlineSources({StorageAdapter? storage})` | Create the shared `OnlineSourceManager` over MyAnime's configuration and the existing secret file |
| `createAiSourceRouter({StorageAdapter? storage, CapabilityGenAiBackend? system, OnlineSourceManager? online})` | Create the shared `AiSourceRouter` over MyAnime storage, the system AI channel, `ai_models/` and the online sources |

Since 1.9.0 the app's own `AiSourceBackend` class is gone: routing, model management, custom Hugging
Face models, the GPU option, names and technical details come from `AiSourceRouter` in the
`myapps_ai_sources` package (MyApps-AI v0.6.0). The file also re-exports `OnlineSourceManager` and
`AiSourceRouter`. Online records, keys and acknowledgements keep the 1.8.11 keys and file
(`aiOnlineProviders`, `aiOnlineAcknowledgements`, `anime_ai_secrets.json`), so existing sources carry
over. The router stores the device-local keys `aiSourceSelection`, `aiComputePreference`,
`aiGpuFailures`, `aiCustomModels` and `aiModelAliases`.
