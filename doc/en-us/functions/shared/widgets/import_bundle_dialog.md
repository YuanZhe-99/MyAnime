# lib/shared/widgets/import_bundle_dialog.dart

Drives the `.myanimeitem` bundle import UI flow: picks and parses a bundle via
`FileOpenService.pickAndParseBundle()`, shows a per-conflict resolution dialog
(`_ImportConflictDialog`) for records that collide with existing local anime, and applies the
result. See `AGENTS.md`'s "Share and File Import" section and
[../../../data-formats.md](../../../data-formats.md) for the `.myanimeitem` v1/v2 bundle format.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`showImportBundleFlow`](#showimportbundleflow) | top-level function | A | Run the full import-bundle flow with conflict resolution. |
| [`ImportBundleResult.new`](#importbundleresult-new) | constructor (`ImportBundleResult`) | A | Create an import bundle result instance. |
| `_ImportConflictDialog` | class (`StatelessWidget`) | B | Show a single import conflict resolution dialog. |
| `_ImportConflictDialog.new` | constructor (`_ImportConflictDialog`) | B | Create an import conflict dialog instance. |
| `_ImportConflictDialog.build` | method (`_ImportConflictDialog`, widget build) | B | Build the conflict dialog's title/body/actions. |
| `_ImportConflictDialog._buildSummary` | method (widget helper) | B | Render a compact summary (title, date, progress, URL) for one side of a conflict. |

The private `_ConflictResolution` enum has no `/// Purpose:` comment and is not indexed as a
separate row.

## Documentation

### `Future<ImportBundleResult?> showImportBundleFlow(BuildContext context)` <a id="showimportbundleflow"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/widgets/import_bundle_dialog.dart` (approx. line 18)
- **Purpose:** Drive the end-to-end `.myanimeitem` bundle import: pick a file, resolve any
  conflicts with existing local records interactively, then apply the result.
- **Inputs:** `context` — used for the file picker, conflict dialogs, and snackbars.
- **Returns:** `Future<ImportBundleResult?>` — `null` if the user cancelled the file picker,
  otherwise an `ImportBundleResult` with the imported/merged anime IDs and total count (possibly
  `0` if every conflict was resolved as "keep local").
- **Side effects:** Shows a file picker (via `FileOpenService.pickAndParseBundle`), may show one
  modal conflict dialog per conflicting record, writes to anime storage (via
  `FileOpenService.applyBundle` and `FileOpenService.replaceAnime`), and shows a success `SnackBar`.
- **Algorithm:**
  1. Call `FileOpenService.pickAndParseBundle()`; return `null` immediately if the user cancelled
     (result is `null`) or if `context` is no longer mounted.
  2. If `bundle.hasConflicts`, iterate `bundle.conflictIndices`: for each conflicting index, show a
     modal, non-dismissible `_ImportConflictDialog` comparing the local and imported versions and
     await a `_ConflictResolution` (`keepLocal`, `useImported`, or `merge`).
     - `null` (dialog dismissed) or `keepLocal` → add the index to `skipIndices`.
     - `useImported` → leave the index alone (it will be imported as-is with its new UUID).
     - `merge` → add the index to `mergeIndices`.
     If there are no conflicts, show a "no conflicts" snackbar instead.
  3. Call `FileOpenService.applyBundle(bundle, skipIndices: {...skipIndices, ...mergeIndices})` to
     import every record that is neither skipped nor being merged; capture the count as `added`.
  4. For each index in `mergeIndices`, compute `DuplicateService.merge(local, [imported])` and
     write it back via `FileOpenService.replaceAnime(local.id, merged)`, incrementing
     `mergedCount`.
  5. If `context` is mounted and `added + mergedCount > 0`, show a success `SnackBar` with the
     total.
  6. Build `importedIds`: for every bundle index not in `skipIndices`, use the *local* record's ID
     if it was merged (the local record survives, updated), or the *imported* record's (new) ID
     otherwise.
  7. Return `ImportBundleResult(importedIds: importedIds, count: added + mergedCount)`.
- **Usage:**
  ```dart
  final result = await showImportBundleFlow(context);
  ```
  (from `lib/features/anime/views/home_page.dart` and
  `lib/features/anime/views/management_page.dart`, both invoked from an "Import" menu action)
- **Notes:** Dismissing a conflict dialog (e.g. system back) is treated the same as explicitly
  choosing "keep local" for that one record — it does *not* abort the whole import flow, unlike the
  WebDAV sync conflict dialog described in `AGENTS.md`. Each conflict is resolved independently in
  the loop; a dismissed dialog only skips that single record.

### `const ImportBundleResult({required this.importedIds, required this.count})` <a id="importbundleresult-new"></a>
- **Kind:** constructor of `ImportBundleResult`
- **Source:** `lib/shared/widgets/import_bundle_dialog.dart` (approx. line 112)
- **Purpose:** Construct the immutable result value returned by `showImportBundleFlow`.
- **Inputs:** `importedIds` — IDs of anime that were newly added or updated via merge; `count` —
  total number of records imported or merged.
- **Returns:** A new `ImportBundleResult`.
- **Side effects:** None.
- **Algorithm:** Plain `const` field assignment; no logic.
- **Usage:**
  ```dart
  return ImportBundleResult(
    importedIds: importedIds,
    count: totalImported,
  );
  ```
  (from `showImportBundleFlow`, same file)
- **Notes:** `count` is not necessarily `importedIds.length` in every conceivable caller — in this
  file they're always kept in sync (`totalImported = added + mergedCount` and `importedIds` is
  built from the same non-skipped set), but the class itself does not enforce that invariant.
