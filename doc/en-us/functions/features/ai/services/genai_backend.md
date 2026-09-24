# lib/features/ai/services/genai_backend.dart

The Dart seam between `OnDeviceAiService` and the platform's on-device model, added in 1.6.0 (M3).
It holds the `GenAiStatus` and `GenAiFailure` enums, the `GenAiStatusReport` and `GenAiCoreInfo`
value classes the platform answers with, the abstract `GenAiBackend` interface that tests replace
with a fake, and `MethodChannelGenAiBackend`, which talks over `com.yuanzhe.my_anime/genai` to
`GenAiChannel.kt` on Android and the `on_device_ai_apple` plugin on iOS and macOS. Policy — the
switch, the queue, the parsing — lives on the service's side of this seam, so everything worth
testing runs without a device. See [`../../../../on-device-ai.md`](../../../../on-device-ai.md) for
the platform facts, the channel's methods and the status table. **Not verified on a device**
(2026-09-24).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`platformMayHaveOnDeviceModel`](#platformmayhaveondevicemodel) | top-level getter | A | Report whether this platform can have an on-device model at all. |
| `GenAiException.new` | constructor (`GenAiException`) | B | Create a generation failure. |
| `GenAiException.toString` | method (`GenAiException`) | B | Describe the failure for logs. |
| `GenAiStatusReport.new` | constructor (`GenAiStatusReport`) | B | Describe the model's availability. |
| [`GenAiStatusReport.hasSizeChoice`](#genaistatusreport-hassizechoice) | getter (`GenAiStatusReport`) | A | Say whether the served variants include both model sizes. |
| [`GenAiStatusReport.fromJson`](#genaistatusreport-fromjson) | static method (`GenAiStatusReport`) | A | Read the map the platform channel sends. |
| `GenAiCoreInfo.new` | constructor (`GenAiCoreInfo`) | B | Describe the device's model system. |
| `GenAiCoreInfo.fromJson` | static method (`GenAiCoreInfo`) | B | Read the map the platform channel sends; null when nothing usable came back. |
| `GenAiBackend.statusReport` | abstract method (`GenAiBackend`) | B | Ask what the model can do, and what the device said about it. |
| `GenAiBackend.coreInfo` | abstract method (`GenAiBackend`) | B | Describe the device's model system. |
| `GenAiBackend.download` | abstract method (`GenAiBackend`) | B | Ask the system to fetch the model (Android only). |
| `GenAiBackend.generate` | abstract method (`GenAiBackend`) | B | Generate one answer. |
| `GenAiBackend.choose` | abstract method (`GenAiBackend`) | B | Pick up to `maxItems` of `options`. |
| `GenAiBackend.prewarm` | abstract method (`GenAiBackend`) | B | Load the model ahead of a batch. |
| `GenAiBackend.cancel` | abstract method (`GenAiBackend`) | B | Stop whatever is running. |
| `MethodChannelGenAiBackend.new` | constructor (`MethodChannelGenAiBackend`) | B | Create the channel backend; the channel is injectable for tests. |
| [`MethodChannelGenAiBackend.statusReport`](#methodchannelgenaibackend-statusreport) | method (`MethodChannelGenAiBackend`) | A | Ask the platform for the model's status. |
| `MethodChannelGenAiBackend.coreInfo` | method (`MethodChannelGenAiBackend`) | B | Read the device's model-system details; null whenever the call fails. |
| [`MethodChannelGenAiBackend.download`](#methodchannelgenaibackend-download) | method (`MethodChannelGenAiBackend`) | A | Ask the system to fetch the model. |
| `MethodChannelGenAiBackend.generate` | method (`MethodChannelGenAiBackend`) | B | Generate one answer over the channel. |
| [`MethodChannelGenAiBackend.choose`](#methodchannelgenaibackend-choose) | method (`MethodChannelGenAiBackend`) | A | Pick up to `maxItems` of `options`. |
| `MethodChannelGenAiBackend.prewarm` | method (`MethodChannelGenAiBackend`) | B | Load the model ahead of a batch; errors are swallowed. |
| `MethodChannelGenAiBackend.cancel` | method (`MethodChannelGenAiBackend`) | B | Stop whatever is running; errors are swallowed. |
| `MethodChannelGenAiBackend._handlePlatformCall` | method (`MethodChannelGenAiBackend`) | B | Receive download progress from the platform. |
| [`MethodChannelGenAiBackend.failureForCode`](#methodchannelgenaibackend-failureforcode) | static method (`MethodChannelGenAiBackend`) | A | Map a platform error code to a failure. |

The `GenAiStatus` and `GenAiFailure` enums, the value fields of `GenAiStatusReport` and
`GenAiCoreInfo`, `GenAiStatusReport.unsupported` and `MethodChannelGenAiBackend.channelName` carry
no `/// Purpose:` comment and are not rows. The status and failure values are listed in
[`../../../../on-device-ai.md`](../../../../on-device-ai.md#statuses-and-failures).

## Documentation

### `bool get platformMayHaveOnDeviceModel` <a id="platformmayhaveondevicemodel"></a>
- **Kind:** top-level getter
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 15)
- **Purpose:** Report whether this platform can have an on-device model at all.
- **Inputs:** None.
- **Returns:** `bool` — true on Android, iOS and macOS; false on Windows, Linux and the web.
- **Side effects:** None.
- **Algorithm:** `!kIsWeb` and `defaultTargetPlatform` is Android, iOS or macOS.
- **Usage:** Every `MethodChannelGenAiBackend` method checks it first;
  `OnDeviceAiService.refreshStatus` and `AiSettingsTiles.build` check it too.
- **Notes:** A coarse gate: off these platforms the backend answers `unsupported` without touching
  the channel, and Settings shows no AI rows. Because it reads `defaultTargetPlatform`, tests switch
  it with `debugDefaultTargetPlatformOverride`.

### `bool get hasSizeChoice` <a id="genaistatusreport-hassizechoice"></a>
- **Kind:** getter of `GenAiStatusReport`
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 164)
- **Purpose:** Say whether the served variants include both model sizes.
- **Inputs:** None.
- **Returns:** `bool` — true when `served` contains both `/full` and `/fast`.
- **Side effects:** None.
- **Algorithm:** A substring check on the comma-separated `served` list reported by Android's probe.
- **Usage:** `AiSettingsTiles.build` shows "Prefer the faster model" only when it is true.
- **Notes:** A control that cannot change anything is not shown. Apple never reports `served`.

### `static GenAiStatusReport fromJson(Map<Object?, Object?>? answer)` <a id="genaistatusreport-fromjson"></a>
- **Kind:** static method of `GenAiStatusReport`
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 176)
- **Purpose:** Read the map the platform channel sends.
- **Inputs:** `answer` — the `status` reply, possibly null.
- **Returns:** `GenAiStatusReport`.
- **Side effects:** None.
- **Algorithm:**
  1. Map the `status` string to a `GenAiStatus` by name. Any other string becomes `unknown`; a
     missing or non-string value becomes `unavailable`.
  2. Take `code` and `tokenLimit` only when they are `int` (`code` defaults to -1).
  3. Take `detail`, `variant`, `served`, `refused` and `baseModelName` with `toString()`.
- **Usage:** `MethodChannelGenAiBackend.statusReport`.
- **Notes:** An unknown status is reported as itself rather than folded into `unavailable`, so a
  newer platform value is visible in the technical details. Missing fields are absent, not wrong.
  `unsupported` is what the Apple plugin answers on iOS and macOS older than 26.

### `Future<GenAiStatusReport> statusReport({bool force = false, bool preferFast = false})` <a id="methodchannelgenaibackend-statusreport"></a>
- **Kind:** method of `MethodChannelGenAiBackend`
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 375)
- **Purpose:** Ask the platform for the model's status.
- **Inputs:** `force` — re-probe rather than trust a model that is already serving; `preferFast` —
  ask for the smaller model where a device serves both.
- **Returns:** `Future<GenAiStatusReport>`; never throws.
- **Side effects:** One `status` channel call with `{feature: 'prompt', force, preferFast}`.
- **Algorithm:**
  1. Off the supported platforms, return `GenAiStatusReport.unsupported` without a call.
  2. Invoke `status` and parse the reply with `GenAiStatusReport.fromJson`.
  3. `MissingPluginException` → `unreachable` with detail `channel not registered`;
     `PlatformException` → `unreachable` with `code: message`; anything else → `unreachable` with
     the error's type name.
- **Usage:** `OnDeviceAiService.refreshStatus`, `download` and `_pump`.
- **Notes:** A missing plugin is never reported as `unsupported`: that is how a plugin that failed
  to register on iOS or macOS gets noticed.

### `Future<bool> download({void Function(int bytes, int total)? onProgress})` <a id="methodchannelgenaibackend-download"></a>
- **Kind:** method of `MethodChannelGenAiBackend`
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 431)
- **Purpose:** Ask the system to fetch the model.
- **Inputs:** `onProgress` — bytes so far and the total, -1 when unknown.
- **Returns:** `Future<bool>` — true when the download completed.
- **Side effects:** AICore downloads the model; progress arrives as `downloadProgress` method calls
  from the platform. Registers the channel's call handler once.
- **Algorithm:**
  1. Off the supported platforms, throw `GenAiException(unavailable)`.
  2. Store `onProgress`; on first use, install `_handlePlatformCall` as the method-call handler.
  3. Invoke `download` with `{feature: 'prompt'}`; map a `PlatformException` through
     `failureForCode` and a `MissingPluginException` to `unavailable`.
  4. Clear the stored callback in `finally`.
- **Usage:** `OnDeviceAiService.download`, from the Download button in Settings.
- **Notes:** The app never downloads anything itself. The Apple plugin has no `download`; the
  button is shown only on Android.

### `Future<List<String>> choose({required String instructions, required String prompt, required List<String> options, int maxItems = 3})` <a id="methodchannelgenaibackend-choose"></a>
- **Kind:** method of `MethodChannelGenAiBackend`
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 497)
- **Purpose:** Pick up to `maxItems` of `options`.
- **Inputs:** `instructions`, `prompt`, `options` — the allowed ids, `maxItems`.
- **Returns:** `Future<List<String>>` — the chosen ids, possibly empty.
- **Side effects:** Runs the model on the device.
- **Algorithm:**
  1. Off the supported platforms, throw `GenAiException(unavailable)`.
  2. On Android, call `generate` with `maxOutputTokens: 64`, read the reply with
     [`parseChoiceReply`](output_validation.md#parsechoicereply), and throw
     `GenAiException(failed, 'unparseable reply')` when it is invalid.
  3. Elsewhere, invoke the native `choose` (constrained decoding on Apple) and keep the string
     entries of the reply.
- **Usage:** `OnDeviceAiService.choose`.
- **Notes:** Both paths return ids the caller validates again against its own list.

### `static GenAiFailure failureForCode(String code)` <a id="methodchannelgenaibackend-failureforcode"></a>
- **Kind:** static method of `MethodChannelGenAiBackend` (`@visibleForTesting`)
- **Source:** `lib/features/ai/services/genai_backend.dart` (approx. line 588)
- **Purpose:** Map a platform error code to a failure.
- **Inputs:** `code` — the `PlatformException.code` sent by `GenAiChannel` or the Apple plugin.
- **Returns:** `GenAiFailure`.
- **Side effects:** None.
- **Algorithm:** A `switch` on the failure names `unavailable`, `busy`, `cancelled`, `tooLong`,
  `background`, `quota`, `guardrail` and `unsupportedLanguage`; anything else is `failed`.
- **Usage:** `download`, `generate` and `choose` in the same class.
- **Notes:** `timeout` is never sent by a platform; `OnDeviceAiService` raises it itself.
