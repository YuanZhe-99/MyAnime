# WebDAV Sync

Sync lives in `lib/shared/services/webdav_service.dart` (client id, locking, upload/download,
retries, heartbeat, force operations) and `lib/shared/services/sync_merge.dart` (the generic
per-record three-way merge engine, detailed separately in
[`algorithms/three-way-merge.md`](algorithms/three-way-merge.md)). Sync progress state lives in
`sync_progress.dart`, and the wake lock used during foreground sync operations lives in
`sync_wake_lock.dart`. Background triggering lives in `auto_sync_service.dart`. See
[`data-formats.md`](data-formats.md) for the files sync touches on disk, and
[`examples/sync-walkthrough.md`](examples/sync-walkthrough.md) for a concrete worked scenario.

WebDAV sync is **per-record three-way merge, not whole-file replacement.**

## The 10-step flow

1. **Acquire the remote `.lock`** before any data download, using the stable local client id, one
   upload token, a UTC timestamp, and a **60-second TTL**. An active lock from another client
   blocks uploads; an expired lock is treated as a failed upload and may be replaced. A local
   `.sync_base/upload_lock.json` file lets the *next* app launch detect an upload that was
   interrupted mid-flight, so it can re-download/re-merge before uploading again instead of
   silently retrying blind.
2. **Download remote `anime_data.json`** with a discriminated result: **only HTTP 404** counts as
   "missing on remote." Any other failure (auth, server error, network error) aborts the sync with
   a visible error, so local data is never uploaded over a remote file the client simply failed to
   read.
3. **Load local `anime_data.json` and `.sync_base/anime_data.json`** (the base snapshot from the
   last successful sync).
4. **Merge per anime using `modifiedAt`**, via the generic engine in
   [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md). Records whose serialized
   content is identical on both sides merge without raising a conflict, even if both sides bumped
   `modifiedAt` independently (this can happen after a stale base caused by an earlier failed
   upload).
5. **Auto-resolve when only one side changed** since the base snapshot — the changed side's
   version is taken, no user input needed.
6. **Detect conflict when the same anime changed on both sides** after the last sync (i.e. both
   `modifiedAt` are newer than the base, and the serialized content differs).
7. **Re-read the local file** to catch concurrent saves made *during* the network I/O of steps
   1–6, and re-merge if it changed in the meantime.
8. **If there are no record conflicts**, force-upload the complete merged JSON while the `.lock`
   is still valid. Data JSON PUTs do **not** use `If-Match`/`If-None-Match` — `.lock` is the sole
   concurrency guard for data uploads.
9. **If there are record conflicts**, return them to the user instead of resolving automatically.
   After the user resolves them, `finalizePendingSync` reacquires `.lock` and force-uploads the
   complete resolved JSON.
10. **Save the new base snapshot only after the upload succeeds**, then clear the matching
    remote/local upload lock.

## Manual vs. auto-sync conflict handling

Both manual sync and background auto-sync call the merge engine with **`autoResolve: false`.**
Neither one silently applies last-writer-wins to a true two-sided conflict.

- **Manual sync** (triggered from the WebDAV settings page) shows conflict dialogs directly.
- **Auto-sync** also leaves `autoResolve` disabled: it records failures and true two-sided
  conflicts as visible status in Settings/WebDAV instead of silently resolving them. The user must
  open the WebDAV page and resolve conflicts manually.
- **Dismissing any conflict dialog** (e.g. system back) aborts the whole resolution: nothing is
  uploaded, the conflict stays pending in the visible sync status, and no record is silently
  resolved to the local version.
- `finalizePendingSync` returns `false` when applying or force-uploading the resolution under
  `.lock` fails, so the UI can report the failure; the base snapshot stays untouched and the next
  sync re-merges from scratch.

## Wake lock

Foreground sync operations on the WebDAV page — manual sync, conflict finalize upload, force
upload, force download — hold a screen wake lock through `shared/services/sync_wake_lock.dart`
(built on `wakelock_plus`). Rules:

- Reference-counted (multiple concurrent holders don't release the lock until all release it).
- Only enabled if no other feature already holds one.
- Acquired only after force-action confirmation (i.e. after the user confirms the destructive
  dialog, not before).
- Released in a `finally` block on completion, failure, cancellation, or exception.
- **Never used by background auto-sync** — only foreground, user-initiated operations hold it.

## Retry policy

Transient network failures — socket/timeout/client errors and HTTP 5xx — on data GET/PUT, byte
(image) GET/PUT, and PROPFIND listings are retried up to **2 extra attempts**, with **1-second**
then **2-second** backoff between attempts (`Future.delayed(Duration(seconds: attemptIndex))` for
`attemptIndex` 1 then 2).

- `.lock` writes are **never retried**, so a retried create-only PUT can't misreport lock
  contention as if a second client held it.
- HTTP 4xx responses are **never retried.**

## Heartbeat

While a data or image PUT is in flight, the held `.lock` is heartbeat-refreshed every
**20 seconds** (`_withLockHeartbeat`, `_lockHeartbeatInterval`). This keeps a transfer slower than
the 60-second lock TTL from ever letting another client treat the lock as expired and upload
concurrently. Heartbeat failures are swallowed and never abort the in-flight transfer.

## Image sync

- Images sync **additively** and only for cover images actually **referenced** by a local or
  remote anime record.
- The referenced set is the **union** of `coverImage` basenames from local and remote anime data.
- Orphaned images (no longer referenced by either side) are **not** uploaded or downloaded, but
  they are also **not automatically deleted.**
- Remote image directory listings return `null` on any failure; `_syncImages` then skips the image
  phase with a visible warning instead of treating an unknown remote state as "empty" — this
  previously caused every referenced image to be re-uploaded after a transient PROPFIND failure.
- Downloaded images set the local-data-changed flag so UI pages reload even when the data JSON
  itself didn't change.

## `SyncProgress` phases

`WebDAVService.progress` is a `ValueNotifier<SyncProgress>` (`sync_progress.dart`) publishing
`connecting` / `downloading` / `merging` / `uploading` phases with per-file and per-image counts.
The service only emits raw phases and file names — the WebDAV settings page is responsible for
mapping phases to localized text and rendering a `LinearProgressIndicator`.

## Force operations

- `WebDAVService.forceUpload()` overwrites remote data files and uploads referenced images
  **without any merge or conflict check**, under the remote `.lock`, then saves base snapshots.
- `WebDAVService.forceDownload()` replaces local data files (JSON-validated first, atomic writes)
  and downloads referenced images without merging, saves base snapshots, and sets the
  local-data-changed flag. It is download-only and takes **no** remote lock.
- Both share the `_syncing` guard and require a destructive-action confirmation dialog in the
  WebDAV page.
- See [`examples/backup-restore-walkthrough.md`](examples/backup-restore-walkthrough.md) for a
  concrete scenario where `forceUpload()` is offered after a backup restore.

## Auto-sync triggers

- App launch.
- App resume.
- A **30-second debounce** after storage saves.
- Immediate sync right after enabling/saving auto-sync configuration.
- A **15-minute timer** while the app process is alive (the same timer also runs the daily
  auto-backup check — see [`backup-restore.md`](backup-restore.md)).

Home, Manage, and Stats pages register `AutoSyncService.addOnLocalDataChanged` reload callbacks in
`initState`/`dispose`, so background sync merges, downloaded images, and backup restores refresh
open pages without needing renavigation. Mobile OS suspension may delay timers until resume.
Storage-layer `save()` methods should notify auto-sync so non-UI writes are covered. Auto-sync
records latest success, failure, and pending-conflict state in memory so Settings and the WebDAV
page can surface sync health.

After manual sync or force operations, the WebDAV page calls
`AutoSyncService.notifyLocalDataChangedIfNeeded()` so open pages reload without waiting for the
next background sync cycle.

## Other important constraints

- `anime_data.json` merges `Anime` records by `id` and `modifiedAt`.
- Unknown top-level and per-anime JSON fields must survive parsing, editing, importing, exporting,
  and sync merging (see the `extraJson` pattern in [`data-formats.md`](data-formats.md)).
- `_syncing` prevents concurrent sync runs.
- `_atomicWrite()` uses tmp-then-rename so a crash mid-write can never corrupt local files.
- Local files are re-read after network I/O specifically to detect concurrent user edits made
  during sync (step 7 above).
- Sync errors and image transfer warnings are shown in dialogs, not only snackbars, since they
  need to stay visible.
