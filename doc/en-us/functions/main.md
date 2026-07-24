# lib/main.dart

The application entry point. It wires up every desktop-only background service (launch-at-startup,
the local API server, the system tray, backup, auto-sync, reminders, and the file-open handler)
before handing control to Flutter's widget tree via `runApp`. See
[../architecture.md](../architecture.md) if present for the broader service-lifecycle picture, and
`AGENTS.md` at the repo root for the desktop feature overview (local API server, tray, reminders).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`main`](#main) | top-level function | A | Initialize startup services and launch the app entry point. |

## Documentation

### `void main(List<String> args) async` <a id="main"></a>
- **Kind:** top-level function (entry point)
- **Source:** `lib/main.dart` (approx. line 23)
- **Purpose:** Initialize desktop-only background services, core app services, and pending
  file-open state, then start the Flutter widget tree.
- **Inputs:** `args` — process command-line arguments; scanned for a `.myanimeitem` path (desktop
  cold start via file association/double-click).
- **Returns:** None (the isolate keeps running via `runApp`).
- **Side effects:** Calls `WidgetsFlutterBinding.ensureInitialized()`; on Windows/macOS/Linux only,
  sets up `launch_at_startup`, starts `LocalApiServer`, and initializes `TrayService`; initializes
  `ReminderService` local notifications; fires `BackupService.runAutoBackupIfNeeded()`
  (fire-and-forget); starts `AutoSyncService.instance` lifecycle observer; starts
  `ReminderService.startPeriodicCheck()`; initializes `FileOpenService`; and calls `runApp` to mount
  the widget tree wrapped in `DevicePreview`.
- **Algorithm:**
  1. Ensure Flutter bindings are initialized before any plugin call.
  2. If running on a desktop platform (`!kIsWeb && (Windows || macOS || Linux)`), read
     `PackageInfo.fromPlatform()` and register the app with `launch_at_startup` using the app name
     and `Platform.resolvedExecutable`.
  3. On the same desktop-platform check, start `LocalApiServer` (no-ops internally if the feature
     is disabled in settings).
  4. On the same desktop-platform check, initialize `TrayService.instance`.
  5. Initialize `ReminderService` (local notification plugin setup) unconditionally — this call is
     awaited on all platforms.
  6. Fire `BackupService.runAutoBackupIfNeeded()` without awaiting (runs the once-per-day auto
     backup check in the background).
  7. Start `AutoSyncService.instance` so it begins observing app lifecycle events for sync triggers.
  8. Start `ReminderService.startPeriodicCheck()` (desktop 60-second in-process reminder check).
  9. Initialize `FileOpenService` (registers the mobile file-association `MethodChannel`).
  10. Scan `args` for the first entry ending in `.myanimeitem`; if found, stash it with
      `FileOpenService.setPendingFile()` for desktop cold-start file association.
  11. Call `runApp`, wrapping `ProviderScope(child: MyAnimeApp())` in `DevicePreview` (enabled only
      in `kDebugMode`).
  12. If a pending file was found in step 10, schedule
      `FileOpenService.processPendingFile()` to run after the first frame via
      `WidgetsBinding.instance.addPostFrameCallback`, so the file is opened once the widget tree
      (and therefore navigation) exists.
- **Usage:** This is the Dart program entry point; Flutter's tooling invokes it directly (e.g. via
  `flutter run` or the built executable). It is not called from other application code.
- **Notes:** The three desktop-platform gates are each written as separate `if` blocks with the same
  condition rather than one shared block — functionally equivalent, just repeated. The
  `.myanimeitem` pending-file dance (steps 10–12) exists because `FileOpenService.processPendingFile`
  needs a valid navigation context, which is only available after the first frame is rendered.
