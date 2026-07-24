# Backup, Restore, Export, and Import

Backup logic lives in `lib/shared/services/backup_service.dart`; the safety-critical
restore/auto-sync interplay is orchestrated by the caller in
`lib/features/settings/views/backup_page.dart`. ZIP and Markdown export/import live in
`lib/shared/services/import_export_service.dart`. See
[`data-formats.md`](data-formats.md) for where backups sit in the persisted-data inventory, and
[`examples/backup-restore-walkthrough.md`](examples/backup-restore-walkthrough.md) for a concrete
worked scenario including the WebDAV interaction.

## Backup format v2

Each `backups/backup_*.json` bundle stores data-module JSON strings plus an `_imageRefs` map that
points at content-addressed image blobs under `backups/blobs/<sha256><ext>`.

- **Deduplication:** identical images are stored once (by content hash) and shared by every
  backup that references them.
- **Reference-counted GC:** a blob is physically deleted only when no remaining backup references
  it. GC runs after create/delete/retention-cleanup, aborts entirely if any remaining bundle is
  unparseable (so a corrupt bundle can't cause a false "unreferenced" deletion), and never deletes
  blobs younger than a **10-minute grace window** (`_blobGcGrace = Duration(minutes: 10)` in
  `backup_service.dart`) — this protects a blob that's mid-write by a concurrent backup from being
  collected out from under it.
- **Retention:** configurable in days, with options `[0, 3, 7, 14, 30, 60, 90]` in the backup
  settings UI (`0` = keep forever). Includes a 3-day option specifically for users who want tight
  local retention.
- **Legacy v1 bundles** with inline base64 `_images` remain restorable — restore checks for
  `_imageRefs` (v2) first, then falls back to the legacy `_images` map (v1) if absent.

## Atomic writes

Bundle writes are atomic (tmp-then-rename, `_atomicWriteString`/`_atomicWriteBytes`), so a crash
mid-write can't leave a half-written bundle or restored file behind.

## Corrupt-bundle handling

- A bundle whose JSON can't be parsed is flagged `corrupt` in the backup history.
- Restore is **disabled** for a corrupt bundle.
- A corrupt bundle does **not** count as "already backed up today" — `runAutoBackupIfNeeded()`
  explicitly excludes `corrupt` bundles when deciding whether today's auto-backup already ran
  (`if (b.corrupt) return false;`), so an interrupted/corrupted auto-backup attempt is retried on
  the next trigger instead of being silently skipped for the rest of the day.
- `runAutoBackupIfNeeded()` is re-entrancy guarded.
- Auto-backup triggers: app launch, app resume, and the auto-sync 15-minute periodic timer (this
  last one specifically covers desktop instances that stay running across midnight without a
  fresh launch/resume event).

## Restore validation and safety

- `restoreBackup()` validates every selected module payload via `AnimeData.fromJson` **before**
  writing anything — a bad payload aborts before any file is touched.
- Image names are sanitized to a flat `images/<name>` shape; path traversal and absolute paths are
  rejected (`_safeImageRelativePath`).
- Writes are atomic per file.

### The critical safety rule: WebDAV auto-sync around restore

When WebDAV auto-sync is enabled, **restoring a backup disables auto-sync in `webdav_config.json`
before the first file is written** — with no `mounted` gate on that first disable — so a crash or
page disposal mid-restore can never leave restored-old data on disk with auto-sync still turned
on. (If it did, the next sync would treat the restored-old data as a fresh local edit/deletion and
propagate it to the remote and every other device.)

`BackupService.restoreBackup()` returns a `RestoreResult`:

```dart
class RestoreResult {
  final bool ok;
  final bool wroteAnything;
  final int missingImages;
}
```

- `ok` — whether the restore completed successfully.
- `wroteAnything` — whether any file was actually written. This is the load-bearing flag: auto-sync
  is only re-enabled by the caller when the restore **failed** *and* `wroteAnything == false` —
  i.e. local data is provably untouched. If anything was written and the restore still failed
  partway, auto-sync stays off until the user sorts it out manually, rather than risk re-enabling
  sync on top of a half-restored state.
- `missingImages` — count of v2 image references whose blob was absent from `backups/blobs/` (e.g.
  a bundle copied without its blob store). Surfaced to the user via a localized
  `backupRestoreMissingImages` warning rather than being silently dropped.

After a successful restore, the caller (`backup_page.dart`):

1. Reloads open pages via `AutoSyncService.notifyLocalDataChangedNow()`.
2. Refreshes reminders via `ReminderService.notifyDataChanged()`.
3. Warns about `missingImages` if any.
4. If WebDAV sync **is** configured, asks whether to force-upload the restored data (holding the
   sync wake lock — see [`sync.md`](sync.md)) via `WebDAVService.forceUpload()`, recording the
   result in sync status. Skipping this step leaves auto-sync off until the user re-enables it
   manually or force-uploads; letting auto-sync merge an old restored snapshot as-is would
   otherwise propagate stale records and deletions to the remote and other devices.

## ZIP export/import

`import_export_service.dart` exports a ZIP containing `anime_data.json` and `images/`.

- Import enforces path-traversal protection: only **allowlisted entries** are extracted —
  `anime_data.json` and flat files directly under `images/` — and the resolved output path must
  stay inside the app directory. This specifically prevents a crafted ZIP from overwriting
  configuration files such as `webdav_config.json` via a `../` path.

## Markdown export

Markdown export is LLM-friendly: entries are **sorted by `firstAirDate`, with nulls last**, and
each entry includes titles, type, air schedule, episode range, derived viewing status,
watched/total counts, URLs, and notes. It's meant to give an LLM enough structured context about a
user's watch history without exposing anything beyond what the export already contains.
