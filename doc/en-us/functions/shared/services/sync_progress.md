# lib/shared/services/sync_progress.dart

**Re-export shim.** `SyncPhase`, `SyncProgress`, and `SyncProgressListenable` moved verbatim to
the shared `myapps_data` package (`lib/src/webdav/sync_progress.dart` there). The three apps' copies
were byte-identical, verified by SHA-256, so the move changed no behavior.

This file remains only so existing imports keep working:

```dart
export 'package:myapps_data/myapps_data.dart'
    show SyncPhase, SyncProgress, SyncProgressListenable;
```

## Declarations

None of its own.

## Where the real documentation lives

`packages/myapps_data/doc/en-us/functions/src/webdav/sync_progress.md`.

See also [`webdav_service.md`](webdav_service.md), which exposes the
`ValueNotifier<SyncProgress>` the UI listens to.
