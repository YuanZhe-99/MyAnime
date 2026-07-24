# Worked Example: WebDAV Sync

This walks the 10-step flow from [`../sync.md`](../sync.md) and the merge engine from
[`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md) through two concrete
scenarios on the same anime record: one that auto-resolves cleanly, and one that produces a real
conflict requiring user input. JSON is trimmed to the fields that matter for the walkthrough.

Two devices: **Device A** (phone) and **Device B** (desktop), both already synced once, so both
share the same base snapshot at `.sync_base/anime_data.json`.

## Scenario 1: one-sided edit -> auto-resolve

### Base snapshot (both devices, after the last successful sync)

```json
{
  "animes": [
    {
      "id": "a1b2c3",
      "title": "Sample Anime",
      "startEpisode": 1,
      "endEpisode": 12,
      "episodeStatuses": { "1": "watched", "2": "watched" },
      "modifiedAt": "2026-07-20T09:00:00.000Z"
    }
  ]
}
```

### Device A marks episode 3 watched

Device A's local `anime_data.json` now reads:

```json
{
  "id": "a1b2c3",
  "episodeStatuses": { "1": "watched", "2": "watched", "3": "watched" },
  "modifiedAt": "2026-07-22T03:15:00.000Z"
}
```

Device B has not touched this record — its local `anime_data.json` for this ID is still
byte-identical to the base.

### Device A runs sync

1. **Acquire `.lock`** on the WebDAV server with Device A's client id, a fresh upload token, UTC
   timestamp, 60s TTL. No other lock is active, so this succeeds immediately.
2. **Download remote `anime_data.json`.** Since Device B hasn't uploaded anything since the last
   sync, the remote copy still matches the base snapshot exactly (`modifiedAt` =
   `2026-07-20T09:00:00.000Z`) — HTTP 200, not 404, so this is a normal "remote present" case.
3. **Load local and base** copies from disk.
4. **Merge per anime by `modifiedAt`** via `mergeAnimeData()`
   ([`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md)): for ID `a1b2c3`,
   `localChanged = true` (`2026-07-22` > `2026-07-20`), `remoteChanged = false` (remote still
   equals base).
5. **Auto-resolve when only one side changed:** only local changed, so the merged record is
   Device A's copy (episode 3 watched) — no conflict raised, no dialog shown, regardless of
   `autoResolve` true/false, because this branch of `mergeRecords<T>` never reaches the
   conflict/LWW branch at all.
6. No conflict to detect — both-sides-changed didn't happen here.
7. **Re-read local** — nothing changed locally during the network round trip in this scenario.
8. **No record conflicts**, so Device A force-uploads the complete merged JSON (which here is
   identical to its own local copy) under the still-valid `.lock`.
9. (skipped — no conflicts)
10. **Save the new base snapshot** (now matching the uploaded JSON, `modifiedAt =
    2026-07-22T03:15:00.000Z`), then clear the upload lock.

When Device B next syncs, its local copy (still at the old base) gets auto-resolved the same way
in the opposite direction — its own record is unchanged since base, so the newly-downloaded remote
copy wins, and Device B's local file updates to show episode 3 watched.

## Scenario 2: both sides edit differently -> conflict

Starting again from the same base snapshot above (imagine the devices have since re-synced to a
common base after Scenario 1).

### Device A changes the title

```json
{
  "id": "a1b2c3",
  "title": "Sample Anime: Season 2",
  "episodeStatuses": { "1": "watched", "2": "watched", "3": "watched" },
  "modifiedAt": "2026-07-22T05:00:00.000Z"
}
```

### Device B, offline at the same time, marks episode 4 watched

```json
{
  "id": "a1b2c3",
  "title": "Sample Anime",
  "episodeStatuses": { "1": "watched", "2": "watched", "3": "watched", "4": "watched" },
  "modifiedAt": "2026-07-22T05:30:00.000Z"
}
```

Device B syncs first and uploads successfully (same as Scenario 1's flow — Device A hasn't
uploaded yet, so this is a clean auto-resolve from Device B's perspective). The remote now holds
Device B's version.

### Device A syncs next

1. **Acquire `.lock`.**
2. **Download remote `anime_data.json`** — now Device B's version (episode 4 watched, title
   unchanged, `modifiedAt = 2026-07-22T05:30:00.000Z`).
3. **Load local and base.**
4. **Merge:** for ID `a1b2c3`, `localChanged = true` (Device A's title edit, `05:00` > base) and
   `remoteChanged = true` (Device B's episode edit, `05:30` > base).
5. Not auto-resolved by step 5 — both sides changed.
6. **Detect conflict:** since both changed *and* `serialize(local) != serialize(remote)` (title
   differs, episode statuses differ — this is a genuinely different-content conflict, not the
   identical-content case that would otherwise suppress it), and Device A's sync runs with
   `autoResolve: false` (true for both manual sync and auto-sync — see
   [`../sync.md`](../sync.md)), this becomes a `RecordConflict<Anime>` with `localRecord` = Device
   A's copy and `remoteRecord` = Device B's copy.
7. **Re-read local** to catch any concurrent edit during the network round trip — none in this
   scenario.
8. *(skipped — there is a conflict)*
9. **Conflicts are returned to the user.** Device A's WebDAV page shows a conflict dialog
   comparing the two versions. Suppose the user picks "merge manually" and keeps Device B's title
   but Device A's title... actually here the user decides to keep the **local title** ("Sample
   Anime: Season 2") while accepting the **remote episode progress** (episode 4 watched) — a
   resolution the UI supports by letting the user construct the winning `Anime` record from either
   side (or edit directly). The chosen record's `extraJson` is preserved from both
   `localRecord`/`remoteRecord` via `withPreservedUnknownJson` regardless of which side's other
   fields were chosen (see [`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md)
   step 3 of `mergeAnimeData`).
   - If the user instead dismisses the dialog (e.g. system back), **nothing is uploaded**, the
     conflict stays pending in visible sync status, and no record is silently resolved to the
     local version — the next sync attempt will re-detect the same conflict.
10. **`finalizePendingSync` reacquires `.lock`** (a fresh acquisition, since step 1's lock may have
    since expired while the user was looking at the dialog) and force-uploads the complete resolved
    JSON — the whole `anime_data.json`, not just this one record. If reacquiring the lock or the
    upload fails, `finalizePendingSync` returns `false`, the base snapshot is left untouched, and
    the next sync will re-merge from the same starting point rather than silently dropping the
    resolution.

Once the upload succeeds, the base snapshot is updated to the resolved record's `modifiedAt`, and
the lock is cleared. Device B's next sync will see the resolved title as a remote-only change (its
own copy is unchanged since the shared base) and auto-resolve to adopt it — no second conflict
prompt on Device B.
