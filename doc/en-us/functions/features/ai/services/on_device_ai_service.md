# lib/features/ai/services/on_device_ai_service.dart

`OnDeviceAiService`, added in 1.6.0 (M3), owns the on-device AI policy: whether the model may be
asked anything at all, what it can do right now, and the one-at-a-time queue in front of it. **While
the user's switch is off, the backend is never called — not even for status.** Every request
re-checks the status first, runs under a 45-second timeout, and waits while the app is not resumed.
After `busy` background work backs off from 5 seconds, doubling up to 5 minutes; after `quota` it
stops for the rest of the day. The service is a `ChangeNotifier` singleton adapted from
MyNihongo!!!!!'s `AiAssistService`; `AppSettingsNotifier` tells it the persisted switch values and
`main` starts its lifecycle listener. See [`genai_backend.md`](genai_backend.md) for the seam it
calls and [`../../../../on-device-ai.md`](../../../../on-device-ai.md) for the policy. **Not verified
on a device** (2026-09-24).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `GenAiDownload.new` | constructor (`GenAiDownload`) | B | Describe download progress. |
| `GenAiDownload.fraction` | getter (`GenAiDownload`) | B | Return the fraction done; null when the total is unknown. |
| `_AiJob.attempt` | method (`_AiJob`) | B | Run the body once, with a timeout. |
| `_AiJob.succeed` | method (`_AiJob`) | B | Settle the completer with a value. |
| `_AiJob.failWith` | method (`_AiJob`) | B | Settle the completer with an error. |
| `_AiJob.fail` | method (`_AiJob`) | B | Settle the completer with a failure without running. |
| `OnDeviceAiService.new` | constructor (`OnDeviceAiService`) | B | Create the service with an injectable backend and clock; off until `setEnabled`. |
| `OnDeviceAiService.setInstanceForTest` | static method (`OnDeviceAiService`) | B | Replace the singleton for a test. |
| `OnDeviceAiService.canGenerate` | getter (`OnDeviceAiService`) | B | Report whether the model can generate right now, from the last status. |
| [`OnDeviceAiService.setEnabled`](#ondeviceaiservice-setenabled) | method (`OnDeviceAiService`) | A | Turn on-device AI on or off. |
| `OnDeviceAiService.setPreferFast` | method (`OnDeviceAiService`) | B | Choose the larger or the faster model; re-probes when enabled. |
| [`OnDeviceAiService.refreshStatus`](#ondeviceaiservice-refreshstatus) | method (`OnDeviceAiService`) | A | Ask the device what the model can do. |
| [`OnDeviceAiService.download`](#ondeviceaiservice-download) | method (`OnDeviceAiService`) | A | Ask the system to fetch the model (Android). |
| [`OnDeviceAiService.generate`](#ondeviceaiservice-generate) | method (`OnDeviceAiService`) | A | Generate one answer through the queue. |
| `OnDeviceAiService.choose` | method (`OnDeviceAiService`) | B | Ask the model to pick from a fixed list, through the queue (background priority by default). |
| `OnDeviceAiService.prewarm` | method (`OnDeviceAiService`) | B | Load the model ahead of a batch; does nothing while off. |
| [`OnDeviceAiService.cancelBackground`](#ondeviceaiservice-cancelbackground) | method (`OnDeviceAiService`) | A | Stop the running request and drop queued background work. |
| [`OnDeviceAiService.start`](#ondeviceaiservice-start) | method (`OnDeviceAiService`) | A | Start following the app lifecycle. |
| `OnDeviceAiService.handleLifecycle` | method (`OnDeviceAiService`) | B | Follow the app lifecycle: pause while not resumed, pump the queue on resume. |
| [`OnDeviceAiService._enqueue`](#ondeviceaiservice-_enqueue) | method (`OnDeviceAiService`) | A | Queue a request. |
| [`OnDeviceAiService._pump`](#ondeviceaiservice-_pump) | method (`OnDeviceAiService`) | A | Run the next eligible job. |
| [`OnDeviceAiService._pace`](#ondeviceaiservice-_pace) | method (`OnDeviceAiService`) | A | Adjust pacing after a job finished. |
| `OnDeviceAiService._failQueued` | method (`OnDeviceAiService`) | B | Fail queued jobs, optionally only background ones. |
| `OnDeviceAiService.dispose` | method (`OnDeviceAiService`) | B | Release the resume timer and the lifecycle listener. |

The `AiPriority` enum (`interactive`, `background`), the `timeout`, `maxBackoff` and
`initialBackoff` constants, `instance`, the plain state getters (`enabled`, `preferFast`, `report`,
`coreInfo`, `downloadProgress`, `downloading`, `busy`, `pausedUntil`, `quotaReachedToday`) and the
top-level `onDeviceAiServiceProvider` — a plain `Provider` over the singleton, so a rebuilt
`ProviderScope` never disposes it — carry no `/// Purpose:` comment and are not rows.

## Documentation

### `Future<void> setEnabled(bool value)` <a id="ondeviceaiservice-setenabled"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 200)
- **Purpose:** Turn on-device AI on or off.
- **Inputs:** `value`.
- **Returns:** `Future<void>`.
- **Side effects:** On: refreshes the status. Off: fails every queued job with `unavailable`,
  resets the report to `unsupported`, forgets the core info, and cancels the running request.
  Notifies listeners.
- **Algorithm:** No-op when unchanged. Otherwise set the flag and notify; when switching on, await
  `refreshStatus()`; when switching off, remember whether a job was running, fail the queue, clear
  the status, call `backend.cancel()` only if something was running, and notify again.
- **Usage:** `AppSettingsNotifier._loadPersisted` and `AppSettingsNotifier.setOnDeviceAiEnabled`.
- **Notes:** Persisting the choice is `AppSettingsNotifier`'s job. The `cancel` call is the only
  backend call on the way off, and only when a request is in flight.

### `Future<void> refreshStatus({String? localeTag})` <a id="ondeviceaiservice-refreshstatus"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 237)
- **Purpose:** Ask the device what the model can do.
- **Inputs:** `localeTag` — the app's locale, for Apple's `supportsLocale` report.
- **Returns:** `Future<void>`.
- **Side effects:** A forced `statusReport` probe and one `coreInfo` call; notifies listeners.
- **Algorithm:** Return while off. Off the supported platforms, set `unsupported` and notify.
  Otherwise store `statusReport(force: true, preferFast: ...)` and `coreInfo(localeTag: ...)`.
- **Usage:** `setEnabled(true)`, `setPreferFast` while on, `AiSettingsTiles.initState` when Settings
  opens, and the Check again button.
- **Notes:** Does nothing while the switch is off — this is the status half of the gate.

### `Future<bool> download()` <a id="ondeviceaiservice-download"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 255)
- **Purpose:** Ask the system to fetch the model (Android).
- **Inputs:** None.
- **Returns:** `Future<bool>` — whether the model is usable afterwards.
- **Side effects:** AICore downloads the model; `downloadProgress` updates as bytes arrive; notifies
  listeners.
- **Algorithm:**
  1. Refuse (return false) while off, while a request runs, or while a download already runs.
  2. Set `downloading` and a zero progress, then call `backend.download`, keeping the last known
     total when a callback reports none.
  3. Swallow `GenAiException`; clear the progress in `finally`.
  4. Re-read the status and return whether it is `available`.
- **Usage:** The Download button in `AiSettingsTiles`.
- **Notes:** Started only from that button, never on the user's behalf.

### `Future<String> generate({required String instructions, required String prompt, int maxOutputTokens = 256, AiPriority priority = AiPriority.interactive})` <a id="ondeviceaiservice-generate"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 286)
- **Purpose:** Generate one answer through the queue.
- **Inputs:** `instructions`, `prompt`, `maxOutputTokens`, `priority` (interactive by default).
- **Returns:** `Future<String>`; throws `GenAiException` on failure.
- **Side effects:** Runs the model on the device when its turn comes.
- **Algorithm:** Wraps `backend.generate` in [`_enqueue`](#ondeviceaiservice-_enqueue).
- **Usage:** No caller on `master` yet; M5's recommendation reasons are the planned one.
- **Notes:** Refused at once with `unavailable` while the switch is off. `choose` is the same shape
  with background priority by default.

### `Future<void> cancelBackground()` <a id="ondeviceaiservice-cancelbackground"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 336)
- **Purpose:** Stop the running request and drop queued background work.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Fails queued background jobs with `cancelled`; calls `backend.cancel()` when a
  request is running and the switch is on.
- **Algorithm:** Keep the interactive jobs in order, fail and drop the rest, then cancel the
  running request.
- **Usage:** No caller on `master` yet; intended for a batch the user stops.
- **Notes:** Interactive requests already queued stay queued. The running request is cancelled
  whatever its priority.

### `void start()` <a id="ondeviceaiservice-start"></a>
- **Kind:** method of `OnDeviceAiService`
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 355)
- **Purpose:** Start following the app lifecycle.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Registers an `AppLifecycleListener` (once) whose `onStateChange` is
  `handleLifecycle`.
- **Algorithm:** `_lifecycle ??= AppLifecycleListener(onStateChange: handleLifecycle)`.
- **Usage:** `main`, after `AutoSyncService.instance.start()`.
- **Notes:** Calls nothing on the backend; the switch still decides whether anything ever runs.
  The source comment on `handleLifecycle` still says it is called from `app.dart`; the listener
  registered here is what actually calls it.

### `Future<T> _enqueue<T>(AiPriority priority, Future<T> Function(GenAiBackend backend) body)` <a id="ondeviceaiservice-_enqueue"></a>
- **Kind:** method of `OnDeviceAiService` (private)
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 375)
- **Purpose:** Queue a request.
- **Inputs:** `priority`, `body` — the backend call to make.
- **Returns:** `Future<T>` — the job's completer future.
- **Side effects:** Adds a job and schedules `_pump` in a microtask.
- **Algorithm:**
  1. While off, return `Future.error(GenAiException(unavailable))`.
  2. A background request after today's quota stop fails with `quota`.
  3. An interactive job goes in front of the first background job, behind earlier interactive
     ones; a background job goes to the end.
- **Usage:** `generate` and `choose`.
- **Notes:** None.

### `Future<void> _pump()` <a id="ondeviceaiservice-_pump"></a>
- **Kind:** method of `OnDeviceAiService` (private)
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 412)
- **Purpose:** Run the next eligible job.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Runs at most one job at a time; re-checks the status; notifies listeners; may
  arm a resume timer; re-arms itself.
- **Algorithm:**
  1. Return if a job is running, the queue is empty, the switch is off or the app is not resumed.
  2. For a background head: fail all background jobs with `quota` after today's quota stop; wait on
     a timer while a busy backoff is in force.
  3. Dequeue, set `busy`, and re-read `statusReport(preferFast: ...)`. Fail the job with
     `unavailable` if the switch went off or the model is not `available`.
  4. Otherwise run `attempt` with the 45-second timeout, apply `_pace`, then settle the job — so a
     caller that sees the failure also sees its effect on the queue.
  5. Clear `busy`, notify, and pump again.
- **Usage:** `_enqueue`, `handleLifecycle` on resume, the resume timer, and itself.
- **Notes:** The status check before every use is policy rule 3: the system can remove a model
  between two requests.

### `void _pace(GenAiFailure? failure)` <a id="ondeviceaiservice-_pace"></a>
- **Kind:** method of `OnDeviceAiService` (private)
- **Source:** `lib/features/ai/services/on_device_ai_service.dart` (approx. line 461)
- **Purpose:** Adjust pacing after a job finished.
- **Inputs:** `failure` — null on success.
- **Returns:** None.
- **Side effects:** Sets the busy backoff, the quota day, or the not-resumed flag.
- **Algorithm:** `busy` → pause until now plus the current backoff, then double it up to 5 minutes;
  `quota` → record today; `background` → treat the app as not resumed until the next lifecycle
  change; success → reset the backoff to 5 seconds and clear the pause; other failures change
  nothing.
- **Usage:** `_pump`.
- **Notes:** The busy pause and the quota stop affect background jobs only; interactive jobs still
  run.
