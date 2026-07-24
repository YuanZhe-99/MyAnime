# lib/shared/services/sync_progress.dart

Defines `SyncPhase` and the immutable `SyncProgress` snapshot that `WebDAVService.progress`
(a `ValueNotifier<SyncProgress>`, see [`webdav_service.md`](webdav_service.md)) publishes during a
sync, force-upload, or force-download run. This file only models raw phase/count data — the WebDAV
settings page is responsible for mapping phases to localized text and rendering a
`LinearProgressIndicator`. See [`../../../sync.md`](../../../sync.md) `SyncProgress` phases section.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`SyncProgress(...)`](#syncprogress-new) | constructor (`SyncProgress`) | A | Create an immutable progress snapshot for one phase. |
| [`fraction`](#fraction) | getter (`SyncProgress`) | A | Completed fraction (0..1) of the current phase, or null if indeterminate. |
| [`isRunning`](#isrunning) | getter (`SyncProgress`) | A | Whether a sync/force operation is currently in progress. |
| [`SyncProgressListenable`](#syncprogresslistenable) | type alias | A | `ValueListenable<SyncProgress>` alias for UI consumers. |

## Documentation

### `const SyncProgress(this.phase, {this.detail, this.current = 0, this.total = 0})` <a id="syncprogress-new"></a>
- **Kind:** constructor of `SyncProgress`
- **Source:** `lib/shared/services/sync_progress.dart` (line 38)
- **Purpose:** Create one immutable progress snapshot: a phase plus optional detail text and item counts.
- **Inputs:** `phase` (`SyncPhase`); optional `detail` (file/image name, or the error message for `SyncPhase.error`); `current`/`total` (both default 0, meaning indeterminate).
- **Returns:** A new `SyncProgress`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment; no derived state computed at construction time (`fraction` computes lazily on read).
- **Usage:**
  ```dart
  progress.value = SyncProgress(phase, detail: detail, current: current, total: total);
  ```
  (`WebDAVService._reportProgress`, [`webdav_service.md`](webdav_service.md#reportprogress))
- **Notes:** `SyncProgress.idle` (`static const idle = SyncProgress(SyncPhase.idle)`) is the resting value shown when no operation is running.

### `double? get fraction` <a id="fraction"></a>
- **Kind:** getter of `SyncProgress`
- **Source:** `lib/shared/services/sync_progress.dart` (line 53)
- **Purpose:** Compute the completed fraction of the current phase for progress-bar binding.
- **Inputs:** None.
- **Returns:** `double?` in `0..1`, or `null` when `total == 0` (indeterminate).
- **Side effects:** None.
- **Algorithm:** `total > 0 ? (current / total).clamp(0.0, 1.0).toDouble() : null` — the `.clamp` guards against a transient `current > total` reading being shown as over 100%.
- **Usage:**
  ```dart
  valueListenable: WebDAVService.progress,
  builder: (context, progress, _) => LinearProgressIndicator(value: progress.fraction),
  ```
  (`lib/shared/views/webdav_config_page.dart`, shape of the progress binding — adapted for brevity)
- **Notes:** Bind this directly to `LinearProgressIndicator.value`; `null` renders Flutter's built-in indeterminate animation.

### `bool get isRunning` <a id="isrunning"></a>
- **Kind:** getter of `SyncProgress`
- **Source:** `lib/shared/services/sync_progress.dart` (line 61)
- **Purpose:** Report whether a sync/force operation is actively in progress (as opposed to idle or finished).
- **Inputs:** None.
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** `phase != SyncPhase.idle && phase != SyncPhase.done && phase != SyncPhase.error` — every other `SyncPhase` value (`connecting`, `downloadingData`, `merging`, `uploadingData`, `uploadingImages`, `downloadingImages`) counts as running.
- **Usage:** Consumed via `WebDAVService.progress`'s `ValueListenableBuilder<SyncProgress>` in the WebDAV settings page to decide whether to show the progress UI at all.
- **Notes:** `done` and `error` are terminal states, not "running" — a UI checking `isRunning` to decide whether to show a spinner will correctly stop at either.

### `typedef SyncProgressListenable = ValueListenable<SyncProgress>` <a id="syncprogresslistenable"></a>
- **Kind:** top-level type alias
- **Source:** `lib/shared/services/sync_progress.dart` (line 72)
- **Purpose:** Give the `ValueListenable<SyncProgress>` shape a descriptive name for UI code that consumes `WebDAVService.progress`.
- **Inputs:** None (type alias).
- **Returns:** None.
- **Side effects:** None.
- **Algorithm:** Direct type alias; no runtime behavior.
- **Usage:** UI pages bind with `ValueListenableBuilder<SyncProgress>` directly against `WebDAVService.progress`, which is typed as `ValueNotifier<SyncProgress>` (a `ValueListenable<SyncProgress>` subtype) — the alias documents the intended listener-side type without changing how `progress` itself is declared.
- **Notes:** None.
