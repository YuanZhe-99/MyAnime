# Shared AI

## Ownership

MyApps-AI v0.4.1 is embedded at `packages/myapps_ai` using the relative sibling
URL `../MyApps-AI.git`. Run `git submodule update --init --recursive` before
`flutter pub get` in a fresh checkout. The dependency is
`packages/myapps_ai/packages/myapps_ai`.

`genai_backend.dart` preserves the existing channel name and exports shared types.
`on_device_ai_service.dart` owns the singleton and Riverpod provider while shared
code owns execution. `output_validation.dart` exports shared cleaning utilities.
Native channels are registered by the shared myapps_ai_platform plugin. Business
prompts, facts, parsers and cache formats stay here.
The license page names myapps_ai and its GPL v3 source.

## Behavior

Disabled means no backend query or generation. Changes to enabled or model
preference invalidate late responses. The 45-second timeout now asks the native
backend to cancel before the queue advances. App disposal fails queued work.
Interactive priority, background pacing, lifecycle gate and daily quota behavior
are retained. Cancellation remains subject to the native system implementation.

## Verification

Run flutter analyze and the app test suite after adapter changes. Shared package
tests cover independent capability states and late-result invalidation. Native
plugin passed Android ARM64 release, iOS/macOS release and Apple weak-link checks
in shared CI. Consumer release builds and device inference remain separate checks.

Shared presentation uses myapps_ai_ui. Settings labels, feature gates and actions
remain app-owned. Classification and recommendation workflows remain app-owned.

## AI sources and WebDAV privacy

MyApps-AI v0.5.2 is explicitly split into runtime, platform, models, local UI and llama.cpp packages. Settings uses the unified section skeleton. Global source selection is device-local (`aiSourceSelection`), defaults to system AI, and never chooses online as fallback. Qwen3.5 0.8B/2B Q4_K_M and Gemma 4 E2B Q4_0 run on CPU. Downloads require explicit actions, use pinned URLs and SHA-256, and live under `ai_models/` outside data modules, sync, backup and ZIP. Model leases prevent removal during use. Source switches cancel old work and release model resources. System proofreading remains independent in MyNihongo.

WebDAV notice version 1 must be acknowledged on each device before connection testing, manual/force sync or background sync. The record is in device-local storage_config.json. Existing configurations stay intact while sync is paused; the WebDAV page displays a review banner. Declining saves no configuration and makes no request. JSON/images have no application-level encryption; HTTPS protects transit, HTTP does not. Wire format, locks and conflict policy remain unchanged.

Online sources use shared online UI/backend and MyApps-UI inputs. Provider records and plaintext API keys are device-local; keys use SecretStore and never enter sync/backup/ZIP. Explicit selection and host-specific privacy acknowledgement are required. Prompts contain category/recommendation inputs; no online fallback.
