# lib/shared/services/file_open_service.dart

`FileOpenService` implements `.myanimeitem` export/import for both the single-anime (v1) and
multi-anime bundle (v2) formats, and wires up the OS-level "open with MyAnime" flow via a
`MethodChannel` (mobile) and command-line argument (desktop cold start). It is the entry point used
by [`share_service.md`](share_service.md) (for exporting) and
`lib/shared/widgets/import_bundle_dialog.dart` (for importing with conflict resolution, using
[`duplicate_service.md`](duplicate_service.md)'s grouping logic). See
[`../../../features/share-and-import.md`](../../../features/share-and-import.md) for the
higher-level flow and [`../../../data-formats.md`](../../../data-formats.md) for the exact v1/v2
JSON shapes, and [`../../../platform-notes.md`](../../../platform-notes.md) for how each platform
registers the `.myanimeitem` file association.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`init`](#init) | method (`FileOpenService`) | A | Register the mobile file-open `MethodChannel` handler. |
| `setPendingFile` | method (`FileOpenService`) | B | Remember a file path opened before the app finished starting up. |
| [`processPendingFile`](#processpendingfile) | method (`FileOpenService`) | A | Import and navigate to a previously-remembered pending file. |
| [`handleFile`](#handlefile) | method (`FileOpenService`) | A | Import a `.myanimeitem` file (v1 or v2) directly into storage. |
| [`_importOne`](#_importone) | method (`FileOpenService`) | A | Build a fresh `Anime` (new UUID, decoded cover image) from parsed JSON. |
| [`parseBundle`](#parsebundle) | method (`FileOpenService`) | A | Parse a `.myanimeitem` file into an `ImportBundle` without writing storage. |
| [`pickAndParseBundle`](#pickandparsebundle) | method (`FileOpenService`) | A | Let the user pick a `.myanimeitem` file and parse it into a bundle. |
| [`applyBundle`](#applybundle) | method (`FileOpenService`) | A | Persist the chosen subset of a parsed bundle to storage. |
| [`replaceAnime`](#replaceanime) | method (`FileOpenService`) | A | Replace (or add) a local anime record by id. |
| [`deleteAnimeByIds`](#deleteanimebyids) | method (`FileOpenService`) | A | Delete anime records by id from storage. |
| [`importFromPicker`](#importfrompicker) | method (`FileOpenService`) | A | Let the user pick and directly import a `.myanimeitem` file. |
| [`exportAnimeItem`](#exportanimeitem) | method (`FileOpenService`) | A | Export one anime to a v1 `.myanimeitem` JSON file. |
| [`exportAnimeBundle`](#exportanimebundle) | method (`FileOpenService`) | A | Export a collection of anime to a v2 multi-anime `.myanimeitem` file. |
| `_stripPersonalData` | method (`FileOpenService`) | B | Remove `episodeStatuses`/`episodeWeekOffsets` from exported JSON. |
| [`_readCoverBase64`](#_readcoverbase64) | method (`FileOpenService`) | A | Read an anime's cover image file and base64-encode it. |
| [`_writeBundleFile`](#_writebundlefile) | method (`FileOpenService`) | A | Write a JSON bundle to a temp `.myanimeitem` file. |
| [`_sanitizeFileName`](#_sanitizefilename) | method (`FileOpenService`) | A | Sanitize a display name for use as a cross-platform filename. |

## Documentation

### `static void init()` <a id="init"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 24)
- **Purpose:** Register the `com.yuanzhe.my_anime/file_open` `MethodChannel` handler so native code
  (Android/iOS file association) can hand an opened file path to Dart.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Sets a method-call handler on the shared `MethodChannel`; on `'openFile'`,
  imports the file and navigates the app router to the new anime's detail page.
- **Algorithm:** On `'openFile'`, call [`handleFile`](#handlefile) with the given path; if it
  returned a non-null anime id, call `appRouter.go('/anime/detail/$id')`.
- **Usage:**
  ```dart
  FileOpenService.init();
  ```
  (from `lib/main.dart`, during startup, right after registering the reminder/tray services)
- **Notes:** None.

### `static Future<void> processPendingFile()` <a id="processpendingfile"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 48)
- **Purpose:** Import a `.myanimeitem` file path that was captured via
  `setPendingFile` before the widget tree existed, then navigate to it.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Clears `_pendingFile`; imports the file into storage; navigates the router.
- **Algorithm:** If `_pendingFile` is set, clear it, call [`handleFile`](#handlefile), and if it
  returned an id, navigate to `/anime/detail/$id`.
- **Usage:**
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FileOpenService.processPendingFile();
  });
  ```
  (from `lib/main.dart`, after the first frame, for a desktop cold start via
  `args.where((a) => a.endsWith('.myanimeitem'))`)
- **Notes:** Designed to run after the first frame so `appRouter.go` has a valid `Navigator` to
  target.

### `static Future<String?> handleFile(String path)` <a id="handlefile"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 64)
- **Purpose:** Backward-compatible import of a `.myanimeitem` file straight into storage — supports
  both v1 (single anime) and v2 (multi-anime bundle) without any conflict UI.
- **Inputs:** `path` — absolute path to the file.
- **Returns:** `Future<String?>` — the imported anime's id (v1) or the *last* imported anime's id
  (v2), or `null` on any failure (missing file, bad JSON, unrecognized version).
- **Side effects:** Writes to `AnimeStorage` (one `addOrUpdate` per imported record); may write
  decoded cover images to `<app dir>/images/` via [`_importOne`](#_importone).
- **Algorithm:**
  1. Return `null` if the file doesn't exist.
  2. Decode JSON. If `version == 1` and `anime` is present, import that single record via
     [`_importOne`](#_importone) and `AnimeStorage.addOrUpdate`.
  3. Else if `version == 2` and `items` is a list, import every item the same way, tracking the
     last imported id.
  4. Any other shape (or an exception anywhere above) returns `null`.
- **Usage:**
  ```dart
  final id = await handleFile(path);
  ```
  (from [`init`](#init) and [`processPendingFile`](#processpendingfile), the two file-association
  cold-start paths; also from [`importFromPicker`](#importfrompicker))
- **Notes:** Always assigns a **new UUID** to every imported record and never overwrites an
  existing anime — this is the "no conflict UI" fast path used for file-association opens; use
  [`parseBundle`](#parsebundle) + [`applyBundle`](#applybundle) when conflict resolution is needed.

### `static Future<Anime> _importOne(Anime parsed, Map<String, dynamic> itemJson)` <a id="_importone"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 106)
- **Purpose:** Turn one parsed `.myanimeitem` record into a brand-new local `Anime`, decoding any
  embedded base64 cover image to a file on disk.
- **Inputs:** `parsed` — the `Anime` decoded from the item's `anime` JSON; `itemJson` — the raw item
  map, used for `coverImage`/`coverImageExt`.
- **Returns:** `Future<Anime>` — a new record with a fresh UUID, current UTC `createdAt`/
  `modifiedAt`, and (if present) a locally-saved cover path.
- **Side effects:** If `itemJson['coverImage']` is present, base64-decodes it and writes it to
  `<app dir>/images/<uuid><ext>` (creating the directory if needed).
- **Algorithm:**
  1. If `itemJson['coverImage']` exists, decode it and write it under a fresh UUID filename (using
     `coverImageExt` or `.jpg` as the extension).
  2. Construct a new `Anime` copying every field from `parsed` except `id` (fresh UUID),
     `coverImage` (the just-written local path, or `parsed.coverImage` if there was no embedded
     image), and `createdAt`/`modifiedAt` (both set to now).
- **Usage:** Called internally from [`handleFile`](#handlefile) and [`parseBundle`](#parsebundle).
- **Notes:** Personal viewing fields (`episodeStatuses`, `episodeWeekOffsets`) are carried over
  as-is from `parsed` — stripping only happens on export (see
  `_stripPersonalData`), not on import.

### `static Future<ImportBundle?> parseBundle(String path)` <a id="parsebundle"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 154)
- **Purpose:** Parse a `.myanimeitem` file (v1 or v2) into an `ImportBundle`, detecting conflicts
  against current local data, *without* writing anything to storage yet.
- **Inputs:** `path` — absolute path to the file.
- **Returns:** `Future<ImportBundle?>` — `null` on any parse failure or if the bundle contained no
  valid records.
- **Side effects:** Writes any embedded base64 cover images to `<app dir>/images/` (via
  [`_importOne`](#_importone)); reads current local anime via `AnimeStorage.load()`.
- **Algorithm:**
  1. Read and JSON-decode the file; return `null` if it doesn't exist or the JSON doesn't parse.
  2. Collect per-item JSON maps: for v1, the single top-level object; for v2, every element of
     `items`.
  3. Run each item through [`_importOne`](#_importone) (fresh UUID + cover decode) to build the
     candidate `Anime` list; return `null` if none parsed.
  4. Load current local anime and, for each candidate, call
     [`DuplicateService.findConflict`](duplicate_service.md#findconflict) — record its bundle index
     and matching local record when found.
  5. Return an `ImportBundle(animes: parsed, conflictIndices: ..., localVersions: ...)`.
- **Usage:**
  ```dart
  final bundle = await FileOpenService.pickAndParseBundle();
  ```
  (from `lib/shared/widgets/import_bundle_dialog.dart`'s `showImportBundleFlow`, which then drives a
  per-conflict dialog before calling [`applyBundle`](#applybundle)/[`replaceAnime`](#replaceanime))
- **Notes:** Every candidate already has a fresh UUID assigned (via `_importOne`) even before the
  user resolves conflicts — the UUID a record ends up keeping is decided later by whether the user
  picks "use imported" (new UUID) vs. "merge" (kept local id, via
  [`DuplicateService.merge`](duplicate_service.md#merge)).

### `static Future<ImportBundle?> pickAndParseBundle()` <a id="pickandparsebundle"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 210)
- **Purpose:** Open the file picker (any file type) and parse the selected file as a bundle.
- **Inputs:** None.
- **Returns:** `Future<ImportBundle?>` — `null` if the user cancels or the path is invalid.
- **Side effects:** Shows the OS file picker; see [`parseBundle`](#parsebundle) for further effects.
- **Algorithm:** `FilePicker.platform.pickFiles(type: FileType.any)`, then delegate to
  [`parseBundle`](#parsebundle) with the chosen path.
- **Usage:**
  ```dart
  final bundle = await FileOpenService.pickAndParseBundle();
  ```
  (from `lib/shared/widgets/import_bundle_dialog.dart`'s `showImportBundleFlow`, the user-initiated
  "Import" entry point)
- **Notes:** Uses `FileType.any` rather than a `.myanimeitem` filter, since some platforms don't
  filter custom extensions reliably.

### `static Future<int> applyBundle(ImportBundle bundle, {Set<int> skipIndices = const {}})` <a id="applybundle"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 224)
- **Purpose:** Persist the non-skipped records of a parsed bundle as new anime.
- **Inputs:** `bundle` — a previously-parsed `ImportBundle`; `skipIndices` — bundle indices to
  leave out (e.g. conflicts the user chose to keep local, or that will be merged separately).
- **Returns:** `Future<int>` — the number of records actually added.
- **Side effects:** Appends records to `AnimeStorage` (one bulk `save`, not per-record
  `addOrUpdate`).
- **Algorithm:** Load current data, append every `bundle.animes[i]` not in `skipIndices` to the
  list, save the combined list once, return the count added.
- **Usage:**
  ```dart
  final added = await FileOpenService.applyBundle(
    bundle,
    skipIndices: {...skipIndices, ...mergeIndices},
  );
  ```
  (from `lib/shared/widgets/import_bundle_dialog.dart`, after the user has resolved every conflict —
  merge-bound indices are excluded here because they're applied separately via
  [`replaceAnime`](#replaceanime))
- **Notes:** A single `AnimeStorage.save()` call for the whole batch, unlike `handleFile`'s
  per-record `addOrUpdate` — more efficient for multi-anime bundles.

### `static Future<void> replaceAnime(String localId, Anime replacement)` <a id="replaceanime"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 246)
- **Purpose:** Replace an existing local anime with a merged or imported-as-is version (or add it,
  if the id is somehow no longer present).
- **Inputs:** `localId` — the existing record's id to replace; `replacement` — the new record.
- **Returns:** `Future<void>`.
- **Side effects:** Updates (or appends to) `AnimeStorage`.
- **Algorithm:** Load current data; find `localId`'s index; if found, overwrite it in place,
  otherwise append `replacement`; save.
- **Usage:**
  ```dart
  final merged = DuplicateService.merge(local, [imported]);
  await FileOpenService.replaceAnime(local.id, merged);
  ```
  (from `lib/shared/widgets/import_bundle_dialog.dart`, applying the user's "merge" choice for an
  import conflict)
- **Notes:** None.

### `static Future<void> deleteAnimeByIds(Iterable<String> ids)` <a id="deleteanimebyids"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 264)
- **Purpose:** Delete a set of anime records by id, typically the redundant copies left over after
  a duplicate merge.
- **Inputs:** `ids` — the ids to remove.
- **Returns:** `Future<void>`.
- **Side effects:** Rewrites `AnimeStorage` with the matching records removed.
- **Algorithm:** Load current data, filter out any anime whose `id` is in the given set, save the
  filtered list.
- **Usage:**
  ```dart
  await FileOpenService.deleteAnimeByIds(others.map((a) => a.id));
  ```
  (from `lib/shared/widgets/duplicate_check_page.dart`'s `_resolveGroup`, removing the
  non-kept members of a duplicate group after an optional merge)
- **Notes:** None.

### `static Future<String?> importFromPicker()` <a id="importfrompicker"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 276)
- **Purpose:** Open the file picker and directly import the selected `.myanimeitem` file (no
  conflict UI), returning the imported anime's id.
- **Inputs:** None.
- **Returns:** `Future<String?>` — the imported anime id, or `null` on cancel/failure.
- **Side effects:** Shows the file picker; see [`handleFile`](#handlefile) for further effects.
- **Algorithm:** `FilePicker.platform.pickFiles(type: FileType.any)`, then delegate to
  [`handleFile`](#handlefile).
- **Usage:** Not currently called elsewhere in the repo; the conflict-aware
  [`pickAndParseBundle`](#pickandparsebundle) + [`applyBundle`](#applybundle) path is what the
  "Import" UI actually uses.
- **Notes:** Same "always new UUID, never overwrites" behavior as `handleFile`.

### `static Future<String?> exportAnimeItem(Anime anime)` <a id="exportanimeitem"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 289)
- **Purpose:** Export a single anime to a v1 `.myanimeitem` JSON file, with personal viewing data
  stripped.
- **Inputs:** `anime` — the record to export.
- **Returns:** `Future<String?>` — the written file's temp path, or `null` on failure.
- **Side effects:** Reads the cover image file (if any) and base64-encodes it; writes a temp
  `.myanimeitem` file under the system temp directory.
- **Algorithm:** Strip personal fields via `_stripPersonalData`; build
  `{version: 1, anime: <stripped json>, coverImage: <base64 or null>}` (plus `coverImageExt` if a
  cover exists); write it via [`_writeBundleFile`](#_writebundlefile) using a sanitized filename
  from `anime.displayTitle`.
- **Usage:**
  ```dart
  final filePath = await FileOpenService.exportAnimeItem(anime);
  ```
  (from [`share_service.md`](share_service.md)'s `_shareAnimeData`, sharing a single anime as a data
  file)
- **Notes:** None.

### `static Future<String?> exportAnimeBundle(List<Anime> animes, {String displayName = 'myanime_collection'})` <a id="exportanimebundle"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 313)
- **Purpose:** Export a collection of anime to a v2 multi-anime `.myanimeitem` bundle, with personal
  viewing data stripped from every record.
- **Inputs:** `animes` — the records to export; `displayName` — base filename (sanitized).
- **Returns:** `Future<String?>` — the written file's temp path, or `null` on failure.
- **Side effects:** Reads each anime's cover image (if any); writes one temp `.myanimeitem` file.
- **Algorithm:** For each anime, strip personal fields and build an item map (`anime` json +
  base64 `coverImage`/`coverImageExt`); wrap all items as `{version: 2, items: [...]}`; write via
  [`_writeBundleFile`](#_writebundlefile).
- **Usage:**
  ```dart
  final filePath = await FileOpenService.exportAnimeBundle(
    animes,
    displayName: displayName,
  );
  ```
  (from [`share_service.md`](share_service.md)'s `shareStatisticsData`, sharing the current
  statistics view's anime list as a data file)
- **Notes:** Uses bundle version 2 specifically so single-anime v1 files remain a distinct,
  backward-compatible format.

### `static Future<String?> _readCoverBase64(Anime anime)` <a id="_readcoverbase64"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 356)
- **Purpose:** Read an anime's cover image file and return it as base64, for embedding in an
  exported `.myanimeitem` file.
- **Inputs:** `anime`.
- **Returns:** `Future<String?>` — base64 string, or `null` if there's no cover, the file is
  missing, or reading fails.
- **Side effects:** Reads a file from `<app dir>/images/`.
- **Algorithm:** If `anime.coverImage` is null return `null`; else resolve the app-relative path,
  and if the file exists, read and base64-encode its bytes (any exception is swallowed, returning
  `null`).
- **Usage:** Called internally from [`exportAnimeItem`](#exportanimeitem) and
  [`exportAnimeBundle`](#exportanimebundle).
- **Notes:** Failure is silent by design — a missing/corrupt cover image should not block exporting
  the rest of the anime's data.

### `static Future<String?> _writeBundleFile(String safeName, Map<String, dynamic> json)` <a id="_writebundlefile"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 374)
- **Purpose:** Write a JSON bundle (already assembled) to a temp `.myanimeitem` file.
- **Inputs:** `safeName` — a filesystem-safe base name (no extension); `json` — the bundle payload.
- **Returns:** `Future<String?>` — the written file's absolute path.
- **Side effects:** Writes a pretty-printed (`JsonEncoder.withIndent('  ')`) JSON file under
  `getTemporaryDirectory()`.
- **Algorithm:** Join the temp directory with `"$safeName.myanimeitem"`, write the indented JSON
  encoding of `json`, return the path.
- **Usage:** Called internally from [`exportAnimeItem`](#exportanimeitem) and
  [`exportAnimeBundle`](#exportanimebundle).
- **Notes:** Writing to the temp directory (not app storage) is deliberate — these files are meant
  to be immediately handed off to the platform share sheet or a save-as dialog, not retained.

### `static String _sanitizeFileName(String name)` <a id="_sanitizefilename"></a>
- **Kind:** static method of `FileOpenService`
- **Source:** `lib/shared/services/file_open_service.dart` (approx. line 391)
- **Purpose:** Sanitize an anime/collection display name for safe use as a filename across Windows,
  macOS, and Linux.
- **Inputs:** `name` — the raw display name.
- **Returns:** `String` — a filesystem-safe name, never empty, capped at 100 characters.
- **Side effects:** None.
- **Algorithm:** Strip characters illegal on Windows/macOS/Linux filesystems (`/ \ : * ? " < > |`)
  and ASCII control characters via regex; trim; fall back to `'anime'` if the result is empty;
  truncate to 100 characters.
- **Usage:** Called internally from [`exportAnimeItem`](#exportanimeitem) and
  [`exportAnimeBundle`](#exportanimebundle).
- **Notes:** CJK, accented, and other Unicode letters are deliberately preserved — only the
  filesystem-illegal ASCII punctuation and control characters are stripped.
