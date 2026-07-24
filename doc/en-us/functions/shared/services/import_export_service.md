# lib/shared/services/import_export_service.dart

`ImportExportService` implements the "export all data" / "import all data" ZIP flow, plus a
one-way, human/LLM-readable Markdown export. This is distinct from the per-anime/collection
`.myanimeitem` sharing flow in [`file_open_service.md`](file_open_service.md) — this file exports
**everything** (`anime_data.json` and every image) as a single portable archive, primarily for
manual backup/restore or moving data between devices without WebDAV. See
[`../../../backup-restore.md`](../../../backup-restore.md)'s "ZIP export/import" and "Markdown
export" sections for the format and security rationale (path-traversal protection).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`exportZIP`](#exportzip) | method (`ImportExportService`) | A | Export all anime data and images as a ZIP file. |
| [`importZIP`](#importzip) | method (`ImportExportService`) | A | Import data from a previously exported ZIP file, with path-traversal protection. |
| [`exportMarkdown`](#exportmarkdown) | method (`ImportExportService`) | A | Export all anime data as an LLM-friendly Markdown file, sorted by first air date. |
| `_typeLabel` | method (`ImportExportService`) | B | English label for an `AnimeType` value. |
| `_dayLabel` | method (`ImportExportService`) | B | English weekday name for a 1–7 day-of-week code. |
| [`_deriveStatus`](#_derivestatus) | method (`ImportExportService`) | A | Derive a plain-English viewing status label for the Markdown export. |

## Documentation

### `static Future<String?> exportZIP(String destDir)` <a id="exportzip"></a>
- **Kind:** static method of `ImportExportService`
- **Source:** `lib/shared/services/import_export_service.dart` (approx. line 17)
- **Purpose:** Bundle `anime_data.json` and every file under `images/` into a single ZIP archive.
- **Inputs:** `destDir` — the directory to write the resulting `.zip` into.
- **Returns:** `Future<String?>` — the written file's path, or `null` on any failure.
- **Side effects:** Reads `anime_data.json` and every file under `<app dir>/images/`; writes
  `myanime_export_<yyyyMMdd_HHmmss>.zip` into `destDir`.
- **Algorithm:**
  1. Build an in-memory `Archive`; add `anime_data.json` as one entry if it exists.
  2. List every file under `<app dir>/images/` and add each as an `images/<basename>` entry.
  3. Encode with `ZipEncoder`, write the bytes to a timestamped filename in `destDir`.
  4. Any exception anywhere returns `null` instead of propagating.
- **Usage:**
  ```dart
  path = await ImportExportService.exportZIP(dir);
  ```
  (from `lib/features/settings/views/settings_page.dart`'s export flow, after the user picks a
  destination directory and chooses the ZIP format)
- **Notes:** Does not include `webdav_config.json`, `storage_config.json`, or backups — only the
  live `anime_data.json` and `images/` — see
  [`../../../backup-restore.md`](../../../backup-restore.md) for how this differs from the
  dedicated backup system in `backup_service.dart`.

### `static Future<bool> importZIP(String filePath)` <a id="importzip"></a>
- **Kind:** static method of `ImportExportService`
- **Source:** `lib/shared/services/import_export_service.dart` (approx. line 59)
- **Purpose:** Restore `anime_data.json` and images from a previously exported ZIP, safely.
- **Inputs:** `filePath` — path to the `.zip` file to import.
- **Returns:** `Future<bool>` — `true` on success, `false` on any failure.
- **Side effects:** Writes `anime_data.json` and image files under the app data directory,
  overwriting any existing files at those paths.
- **Algorithm:**
  1. Read and `ZipDecoder().decodeBytes` the archive.
  2. For each file entry, normalize its name (`p.normalize`, backslashes to forward slashes) and
     allow it through **only** if it is exactly `anime_data.json`, or a flat file directly under
     `images/` (exactly two path segments, so `images/sub/x.png` is rejected) — and the normalized
     name must not contain `..`.
  3. Additionally re-verify the *resolved absolute output path* is inside the app directory via
     `p.isWithin`, as defense in depth against the name check above.
  4. Create the parent directory if needed and write the entry's bytes.
  5. Any exception anywhere returns `false` instead of propagating.
- **Usage:**
  ```dart
  final success = await ImportExportService.importZIP(
    result.files.single.path!,
  );
  ```
  (from `lib/features/settings/views/settings_page.dart`'s import flow, after the user picks a
  `.zip` file and confirms the overwrite warning)
- **Notes:** The allowlist + path-containment double-check specifically prevents a crafted ZIP
  entry like `../webdav_config.json` from overwriting configuration files outside `anime_data.json`
  and `images/` — see [`../../../backup-restore.md`](../../../backup-restore.md).

### `static Future<String?> exportMarkdown(String destDir)` <a id="exportmarkdown"></a>
- **Kind:** static method of `ImportExportService`
- **Source:** `lib/shared/services/import_export_service.dart` (approx. line 102)
- **Purpose:** Export the whole anime library as a single Markdown document, intended to give an
  LLM (or a human) readable structured context about the user's watch history.
- **Inputs:** `destDir` — destination directory.
- **Returns:** `Future<String?>` — the written file's path, or `null` on failure (including when
  `anime_data.json` doesn't exist).
- **Side effects:** Reads `anime_data.json`; writes
  `myanime_export_<yyyyMMdd_HHmmss>.md` into `destDir`.
- **Algorithm:**
  1. Load and parse `anime_data.json` into `AnimeData`.
  2. Sort entries by `firstAirDate` ascending, with **nulls last** (undated entries then break ties
     by `displayTitle`).
  3. Write a header (title, export timestamp, total count), then one `##` section per anime with:
     Japanese title (only if it differs from the main title), season (only if not `"Season 1"`),
     type label (via `_typeLabel`), first air date, air
     schedule (day + time, via `_dayLabel`), episode range, viewing
     status + watched/total/skipped counts (via [`_deriveStatus`](#_derivestatus)), info/watch URLs,
     and notes — each field only emitted when present.
- **Usage:**
  ```dart
  path = await ImportExportService.exportMarkdown(dir);
  ```
  (from `lib/features/settings/views/settings_page.dart`'s export flow, the "Markdown" export
  option)
- **Notes:** Unlike `exportZIP`/ZIP import, this is **export-only** — there is no corresponding
  Markdown import path. See [`../../../backup-restore.md`](../../../backup-restore.md) for the
  sorting rationale and intended LLM-context use case.

### `static String _deriveStatus(Anime anime)` <a id="_derivestatus"></a>
- **Kind:** static method of `ImportExportService`
- **Source:** `lib/shared/services/import_export_service.dart` (approx. line 253)
- **Purpose:** Compute a plain-English viewing status label (`"Completed"`, `"Dropped"`,
  `"Watching"`, or `"Not Started"`) for one Markdown export row.
- **Inputs:** `anime`.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:**
  1. If `anime.isCompleted`, return `"Completed"`.
  2. Compute `hasWatched` (any episode marked watched), `hasUnwatched` (only meaningful when
     `endEpisode` is known — any episode in range that is null/`unwatched`), and `hasSkipped` (any
     episode marked `skippedThisWeek`).
  3. If `hasSkipped` and not `hasUnwatched`, return `"Dropped"`.
  4. Else if `hasWatched` (regardless of `hasUnwatched`), return `"Watching"`.
  5. Otherwise return `"Not Started"`.
- **Usage:** Called internally from [`exportMarkdown`](#exportmarkdown) only.
- **Notes:** This is a Markdown-export-local status derivation with its own English string
  constants — it is **not** the same code path as `Anime.viewingStatus` (used by the API server and
  UI), though the two are intended to agree in spirit. `hasUnwatched` requires `endEpisode` to be
  known; an anime with an unknown end episode can never be classified `"Dropped"` by this
  particular function even if some early episodes were skipped.
