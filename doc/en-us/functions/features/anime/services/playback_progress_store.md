# lib/features/anime/services/playback_progress_store.dart

`PlaybackProgressStore` (1.6.5) owns `playback_progress.json` under `AnimeStorage.getAppDir()`. It
is a copy of the recommendations store's pattern: a read-modify-write queue, atomic writes, no
write when the bytes are unchanged, never an empty file, and `AutoSyncService.notifySaved` after
each real write. See [`../../../app/data_modules.md`](../../../app/data_modules.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `PlaybackProgressStore._` | constructor | B | Prevent instantiation. |
| `_file` | static method | B | Resolve the file under the app directory. |
| [`load`](#load) | static method | A | Load the store; empty when absent or unreadable. |
| `update` | static method | B | Apply one queued change and save it. |
| `_apply` | static method | B | Run one queued update. |
| `put` | static method | B | Store or replace one resume point, keeping the old entry's unknown keys. |
| `remove` | static method | B | Delete one resume point. |

`fileName` (`playback_progress.json`, which a test pins to `playbackProgressFileName`) and the queue
`_tail` carry no `/// Purpose:` comment.

## load

- **Notes:** entries for records that no longer exist are kept. Pruning here would read to sync as
  a deliberate deletion and could remove another device's entries for a record this device has not
  received yet.

## Changes in 1.6.7

- **An unreadable `playback_progress.json` is never overwritten.** `_apply` used to treat a parse failure as an empty store and then save over the file, which erased every resume point and, once synced, deleted them on every device. It now throws a `FormatException` (a blank file still counts as empty) and leaves the bytes untouched; `PlaybackProgressService.report` catches it so the player keeps working. `load()` still reads such a file as empty.
- The file is written with `atomicWriteString` (unique temporary name) instead of a fixed `<file>.tmp`.
