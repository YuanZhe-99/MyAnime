# On-device AI

MyAnime!!!!! can use the device's own language model — Gemini Nano through Android AICore, or Apple
Intelligence's model through the Foundation Models framework — to fill gaps in automatic
categories and to write short reasons for recommendations. This page holds the platform
facts behind that, how the code is laid out, and what still has to be checked on a device.

> **Last verified:** 2026-09-24, against the official documentation and the published libraries
> (sources below). **Not verified on a device.** Neither an Android device with AICore nor an
> Apple device with Apple Intelligence has run this code yet; the
> [device checklist](#device-checklist) is what to do when one is available. The Android bridge is
> a port of MyNihongo!!!!!'s, which has run on a Pixel 10 and a Galaxy Z Fold 8.

## Policy

Rules 1–3, 7 and 8 are enforced in code on `master` and covered by `test/on_device_ai_test.dart`
and `test/ai_settings_tiles_ui_test.dart`. Rules 4–6 bind the features that use the model; for
automatic categories (1.6.0 M4) they are implemented and covered by `test/categories_test.dart`:
AI-suggested category chips carry a sparkle and the rule 4 label as their tooltip, the genre
mapping is the deterministic fallback and the model only fills records it leaves empty, and results
live in `ai_insights.json`. For recommendations (1.6.0 M5) they are implemented and covered by
`test/recommendations_test.dart` and `test/recommendations_page_ui_test.dart`: each AI reason sits
under the rule 4 label, the deterministic ranking and its chips render first and stay whenever the
model fails or its reply is invalid, and reasons are kept in memory only — nothing is written. See
[`features/categories-and-recommendations.md`](features/categories-and-recommendations.md).

1. **Off by default.** `onDeviceAiEnabled` is absent from `storage_config.json` until the user turns
   the switch on.
2. **The switch is a gate.** While it is off, the method channel is never called, not even for
   status.
3. **Status is re-checked before every request.** The system can remove a model between two
   requests.
4. **Generated output is labelled** "Generated on this device — may be wrong".
5. **The fallback is the app.** Categories and recommendations are deterministic first; the model
   only fills gaps and adds reasons.
6. **Nothing generated is synced or backed up.** Results live in `ai_insights.json`, which is not
   registered in `lib/app/data_modules.dart`.
7. **Nothing is downloaded on the user's behalf.** On Android the model download starts only from
   the Download button in Settings and is performed by AICore; on Apple platforms the system
   manages the model.
8. **On-device only.** Never Apple's Private Cloud Compute and never any other remote model.

Both flavors ship the feature: it makes no network call of its own.

## Layout

| Path | Role |
|---|---|
| `lib/features/ai/services/genai_backend.dart` | The Dart seam: `GenAiStatus`, `GenAiFailure`, `GenAiStatusReport`, `GenAiCoreInfo`, the `GenAiBackend` interface and `MethodChannelGenAiBackend` |
| `lib/features/ai/services/on_device_ai_service.dart` | `OnDeviceAiService`: the switch, status before every use, the single-flight priority queue, the 45-second timeout, lifecycle, busy backoff and the daily quota stop |
| `lib/features/ai/services/output_validation.dart` | Parsing a choice reply, stripping Markdown, the script check, cleaning one sentence |
| `lib/features/ai/services/prompt_templates.dart` | The versioned classification instructions and prompt (1.6.0 M4) |
| `lib/features/ai/services/ai_insights_cache.dart` | `AiInsightsCache`: `ai_insights.json`, the per-device cache of generated results (1.6.0 M4) |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | `AiSettingsTiles`: the switch, the status row, the size preference, the notes and the technical details |
| `lib/features/categories/services/category_service.dart` | `CategoryClassifier`: the per-session trickle (at most 20 records) and *Categorise now* (1.6.0 M4) |
| `lib/features/recommendations/services/ai_reason_service.dart` | Recommendation reasons: the top eight candidates, the reply parser, the request language and Chinese variant conversion (1.6.0 M5); the prompt is in `reason_prompt.dart` |
| `android/app/src/main/kotlin/com/yuanzhe/my_anime/GenAiChannel.kt` | The Android bridge to ML Kit GenAI |
| `packages/on_device_ai_apple/` | A local Flutter plugin with one shared Darwin source for iOS and macOS |

Since 1.6.0 (M4) the Settings rows are shown in the *Categories & recommendations* section after
General: the *Automatic categories* switch, then `AiSettingsTiles`, then *Categorise now* while
automatic categories are on; since M5 the *Recommendations* switch sits between the first two. The AI
switch can be turned on only while automatic categories or recommendations are on, and turning the
last of them off turns it off too. The AI switches are stored as
`onDeviceAiEnabled` and `onDeviceAiPreferFast` in `storage_config.json` (see
[`data-formats.md`](data-formats.md)).

The channel is `com.yuanzhe.my_anime/genai` on all three platforms. Its methods are `status`
(`force`, `preferFast`), `info` (`locale`), `download` (Android only), `generate` (`instructions`,
`prompt`, `maxOutputTokens`, `temperature`, `topK`), `choose` (`instructions`, `prompt`, `options`,
`maxItems`; Apple only — on Android the Dart backend runs `generate` and parses the lines),
`prewarm` and `cancel`. `platformMayHaveOnDeviceModel` is true on Android, iOS and macOS; on every
other platform the backend answers `unsupported` without touching the channel and Settings shows
no AI rows. A `MissingPluginException` on iOS or macOS is reported as `unreachable` with the detail
"channel not registered", never as `unsupported`, so a plugin that failed to register is noticed.

### Statuses and failures

| Status | Meaning |
|---|---|
| `unsupported` | This platform has no on-device model (Windows, Linux, iOS or macOS before 26) |
| `unavailable` | The system was asked and said no |
| `unreachable` | The system could not be asked at all |
| `notEnabled` | Apple Intelligence is off in system settings |
| `downloadable` | Android: the model can be fetched by AICore |
| `downloading` | The model is being fetched or prepared (Apple's `modelNotReady` too) |
| `available` | Ready |
| `unknown` | A status this build has no name for |

Failures are `unavailable`, `busy`, `failed`, `cancelled`, `tooLong`, `timeout`, `background`,
`quota`, `guardrail` and `unsupportedLanguage`.

The Apple plugin answers `unsupported` on iOS and macOS before 26, which Settings words as
"Needs iOS 26 or macOS 26 with Apple Intelligence".

### The queue

One request runs at a time. Interactive requests (recommendation reasons, one per visit to the page) go ahead of
background ones (classification). Nothing runs unless the app is `AppLifecycleState.resumed`. After `busy`,
background work waits 5 seconds, doubling up to 5 minutes; after `quota`, background work stops
for the rest of the day; after `background`, the queue waits for the next resume.

## Android: ML Kit GenAI over AICore

- `com.google.mlkit:genai-prompt:1.0.0-beta4` (2026-07-21) is the version used and was still the
  newest on Google Maven on 2026-09-24. It is the floor for Gemini Nano v4 devices and the first
  client that can ask for a named model variant. The Structured Output API added in beta3
  (`genai-schema`, alpha, needs KSP 2.3.6+) is **not** used.
- API 26 or later, so the app's `minSdk` is 26 since 1.6.0 (Android 7.0 and 7.1 are dropped). The
  APIs refuse to run on an unlocked bootloader. Input must stay under about 4,000 tokens.
- Inference is allowed only while the app is the top foreground app; background use fails with
  `BACKGROUND_USE_BLOCKED`. AICore enforces a per-app quota: `BUSY` and
  `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`. Both constants were confirmed in the beta4 AAR with
  `javap` (values 30 and 27) and map to `background` and `quota`.
- Devices serve different model variants, so `GenAiChannel.probePrompt` tries all four
  combinations of `ModelReleaseStage` (STABLE, PREVIEW) and `ModelPreference` (FULL, FAST) and keeps
  the first that serves. Settings offers "Prefer the faster model" only when both sizes are served.
- Instructions are sent as a `SystemInstruction` where the model reports `isSystemPromptAvailable`,
  and prepended to the prompt otherwise.
- R8 broke ML Kit twice in MyNihongo's release builds; `android/app/proguard-rules.pro` carries both
  keep rules, with the explanation.
- `AndroidManifest.xml` has a `<queries>` entry for `com.google.android.aicore` so `info` can read
  AICore's version.
- The toolchain is the same as MyNihongo's: AGP 9.1.1, Kotlin Gradle Plugin 2.2.20,
  `android.builtInKotlin=false`.
- Log tag: `MyAnimeGenAi`. Exceptions are logged, prompts never are.

Sources: <https://developers.google.com/ml-kit/genai>,
<https://developers.google.com/ml-kit/genai/prompt/android/get-started>,
<https://developers.google.com/ml-kit/release-notes>, and MyNihongo's `doc/en-us/android-aicore.md`.

## Apple: the Foundation Models framework

- iOS, iPadOS and macOS 26.0 or later. `SystemLanguageModel.default.availability` is `.available`
  or `.unavailable(reason)` with `deviceNotEligible`, `appleIntelligenceNotEnabled` or
  `modelNotReady`; availability also depends on the region.
- A new `LanguageModelSession(instructions:)` per request, so earlier turns cannot leak into later
  answers; greedy sampling for classification.
- `choose` uses guided generation with a run-time vocabulary:
  `DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(name:description:anyOf:),
  minimumElements: 0, maximumElements: n)`, read back through `GeneratedContent.jsonString`.
- The listed languages include en-US, ja-JP and zh-CN; Traditional Chinese is not listed.
  `info` reports `supportsLocale` for the app's locale. Recommendation reasons (1.6.0 M5) read the
  last answer: when it rejects Traditional Chinese they ask for Simplified and convert, when it
  rejects any other UI language they are skipped, and when it is unknown they go ahead in the UI
  language.
- The context window is 4,096 tokens. Background calls are rate limited.
- Errors on the 26 SDK are `LanguageModelSession.GenerationError`: `rateLimited` → `quota`,
  `concurrentRequests` → `busy`, `guardrailViolation` and `refusal` → `guardrail`,
  `unsupportedLanguageOrLocale` → `unsupportedLanguage`, `exceededContextWindowSize` → `tooLong`,
  `assetsUnavailable` → `unavailable`, anything else → `failed`. OS 27 deprecates the type, but apps
  built with Xcode 26 keep receiving it.
- CI builds with the `macos-latest` image's default Xcode 26.6. Everything is written against the
  26 SDK; a 27-only symbol would need a compile-time guard.
- The model changes with OS updates, so prompts must be re-checked against each model version.
- No entitlement, `Info.plist` key or usage description is needed, and the Private Cloud Compute
  entitlement is deliberately absent.

### Weak linking

The deployment targets stay iOS 13.0 and macOS 13.0. Every FoundationModels reference is behind
`#if canImport(FoundationModels)` and `@available(iOS 26.0, macOS 26.0, *)`, and the podspec declares
`s.weak_frameworks = 'FoundationModels'`. An app that strong-links the framework will not launch on
iOS 18 or macOS 15 and earlier, so this is **checked, not assumed**: `tool/check_weak_link.sh`
fails a CI build unless every binary that links FoundationModels uses `LC_LOAD_WEAK_DYLIB`, and
also fails when nothing links it (the plugin did not make it into the build). See
[`ci-cd.md`](ci-cd.md).

Sources: <https://developer.apple.com/documentation/foundationmodels> and its pages for
`SystemLanguageModel`, `DynamicGenerationSchema` and `LanguageModelSession.GenerationError`;
"Supporting languages and locales with Foundation Models"; Apple's acceptable-use requirements for
the framework; <https://github.com/actions/runner-images> for the Xcode versions.

## Store policy

Google Play's AI-Generated Content policy treats productivity apps that use AI to improve an
existing feature as out of scope; the output is still labelled and a recommendation can be hidden.
Apple's acceptable-use requirements for Foundation Models prohibit, among other things, generating
adult content, so the category taxonomy has no such category.

## Device checklist

Run this when a device becomes available, and update **Last verified** above.

1. With the switch off, confirm nothing touches the model (logcat tag `MyAnimeGenAi` stays silent).
2. Turn the switch on; check the status row, the technical details and, on Android, the AICore
   version and the served and refused variants.
3. Android: Download, with progress in MB; the status becomes available.
4. Categorise one record with no genres; the chips show the sparkle and the tooltip.
5. Open recommendations in all four UI languages; the reasons arrive in the right script, and
   Traditional Chinese is converted where the model answers in Simplified.
6. Send the app to the background mid-request; it resumes cleanly.
7. Repeat 2–5 on a **release** build (R8).
8. Apple: turn Apple Intelligence off in system settings; the row says so.
9. Apple: install on an iOS 18 or macOS 15 device, or boot one in a simulator, and confirm the app
   launches.

## How to refresh this page

1. Compare `genai-prompt` against the Google Maven group index
   (`https://dl.google.com/android/maven2/com/google/mlkit/group-index.xml`) and the ML Kit release
   notes.
2. Re-read the Foundation Models documentation for the current SDK and the runner image's default
   Xcode.
3. Re-check the error codes: `javap -public -constants` on `GenAiException$ErrorCode` in the
   `genai-common` AAR.
4. Update **Last verified** and the facts above in both languages.
