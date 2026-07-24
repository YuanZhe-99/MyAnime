# Worked Example: Backup, Corruption, and Restore

This traces a concrete scenario through the mechanics described in
[`../backup-restore.md`](../backup-restore.md): creating backups, a corrupted bundle, and
restoring an older backup while WebDAV auto-sync is enabled.

## 1. Creating backups

The user has auto-backup enabled with 7-day retention. Over a week, the app writes:

```text
backups/backup_2026-07-16.json
backups/backup_2026-07-17.json
backups/backup_2026-07-18.json
backups/backup_2026-07-19.json
backups/backup_2026-07-20.json
backups/backup_2026-07-21.json
backups/backup_2026-07-22.json
backups/blobs/
  3f2a9c...e1.jpg   <- shared by several backups' cover images
  7b8d10...c4.png
```

Each `backup_*.json` bundle looks roughly like:

```json
{
  "anime_data.json": "{\"animes\": [ ... ]}",
  "_imageRefs": {
    "images/cover_a1b2c3.jpg": "3f2a9c...e1.jpg"
  }
}
```

Because the cover image for `a1b2c3` hasn't changed all week, every bundle's `_imageRefs` points
at the *same* blob file `3f2a9c...e1.jpg` — the image is stored once on disk and shared by all
seven backups, per the content-addressed dedup rule in
[`../backup-restore.md`](../backup-restore.md).

## 2. A corrupt bundle

Suppose `backup_2026-07-21.json` gets truncated by a disk-full condition mid-write. Two things
protect against this actually happening in the first place (bundle writes are atomic,
tmp-then-rename), but assume it happened anyway via some other corruption path (e.g. a bad sector,
or the file was manually edited and broken):

- The backup history UI flags `backup_2026-07-21.json` as **`corrupt`** — its JSON can't be
  parsed.
- **Restore is disabled** for that entry.
- Critically, `runAutoBackupIfNeeded()` does **not** count the corrupt `2026-07-21` bundle as
  "already backed up today" (`if (b.corrupt) return false;`). So the next auto-backup trigger
  (app launch, resume, or the 15-minute timer) retries the backup for that day instead of skipping
  it — the user ends up with a fresh, valid `backup_2026-07-21b.json`-equivalent rather than being
  stuck with a permanently broken day.
- **Blob GC** aborts entirely while any bundle is unparseable — so even though
  `backup_2026-07-21.json` is corrupt and can't confirm its own `_imageRefs`, the GC pass doesn't
  treat that as "this bundle references nothing" and doesn't risk deleting a blob still needed by
  the corrupt file once it's eventually fixed or removed.

## 3. Restoring an older backup, with WebDAV auto-sync enabled

The user's WebDAV auto-sync is on. They decide `backup_2026-07-18.json` had data they want back
(reverting a week of accidental deletions).

Flow (`backup_page.dart._restoreBackup`, from [`../backup-restore.md`](../backup-restore.md)):

1. User picks `backup_2026-07-18.json` and selects modules to restore, confirms the restore
   dialog.
2. **Before any file is written**, the app loads the current WebDAV config, sees
   `config.autoSync == true`, and immediately saves `config.copyWith(autoSync: false)` to
   `webdav_config.json`. This happens with no `mounted` gate — even if the page were disposed a
   moment later, auto-sync is already off.
3. `BackupService.restoreBackup(file, moduleKeys: selected)` runs:
   - Validates every selected module's JSON via `AnimeData.fromJson` first — if
     `backup_2026-07-18.json`'s `anime_data.json` payload were itself unparseable, nothing would be
     written at all, and `wroteAnything` would stay `false`.
   - It parses fine, so it atomically writes the restored `anime_data.json`, then restores
     `images/cover_a1b2c3.jpg` from blob `3f2a9c...e1.jpg` (still present — it was never GC'd since
     newer backups keep referencing it).
   - Returns `RestoreResult(ok: true, wroteAnything: true, missingImages: 0)`.
4. Since `result.ok` is true, the failure/re-enable branch is skipped entirely — auto-sync stays
   **off** (this is deliberate: a successful restore just replaced local data with a week-old
   snapshot; letting a background sync merge that snapshot with the *current* remote state right
   now would treat the "missing" week of changes as deletions and could propagate them outward).
5. Open pages reload (`AutoSyncService.notifyLocalDataChangedNow()`) and reminders refresh
   (`ReminderService.notifyDataChanged()`).
6. `missingImages == 0`, so no warning is shown.
7. Because WebDAV **was** configured, `_handlePostRestoreSync(config)` runs: it shows a dialog
   explaining that sync is now disabled and asking whether to force-upload the restored (older)
   data.
   - If the user picks **force upload**: `SyncWakeLock.acquire()` is held (see
     [`../sync.md`](../sync.md)), then `WebDAVService.forceUpload(config)` overwrites the remote
     `anime_data.json` and referenced images with the restored-old data, under `.lock`, with no
     merge step — this is the explicit, user-confirmed way to make the restored state the new
     source of truth everywhere. The wake lock releases in `finally` regardless of outcome.
   - If the user picks **skip**: the remote is left as-is, and auto-sync **stays disabled** until
     the user manually re-enables it in WebDAV settings — intentionally, so the app doesn't
     silently resume merging a stale local snapshot against a live remote later.

### Contrast: what if the restore itself had failed?

If step 3 had instead failed before writing anything (e.g. the selected `anime_data.json` payload
inside the bundle didn't validate), `RestoreResult` would come back as
`RestoreResult(ok: false, wroteAnything: false, missingImages: 0)`. Because `wroteAnything` is
`false` — local data is provably untouched — the caller re-enables auto-sync immediately
(`config.copyWith(autoSync: true)`), since there's nothing restored that could conflict with a
resumed sync. This is the exact safety rule described in
[`../backup-restore.md`](../backup-restore.md): auto-sync is only ever re-enabled automatically
when the restore failed *and* nothing was written.
