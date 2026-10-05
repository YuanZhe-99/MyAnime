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
