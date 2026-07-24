# lib/shared/services/image_service.dart

`ImageService` centralizes storage of cover-art images on disk, under `<app dir>/images/`. It is
the single place that picks images from the device, downloads them from a URL, resolves a stored
relative path to an absolute `File`, and deletes an image that is no longer referenced. It is used
by anime edit/search flows to attach cover art, and by [`share_service.md`](share_service.md) and
[`file_open_service.md`](file_open_service.md) to read cover files for share-image generation and
`.myanimeitem` export/import. See [`../../../features/share-and-import.md`](../../../features/share-and-import.md)
for how exported covers are embedded as base64.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_getImageDir`](#_getimagedir) | method (`ImageService`) | A | Get (creating if needed) the app's `images/` directory. |
| [`pickAndSaveImage`](#pickandsaveimage) | method (`ImageService`) | A | Let the user pick an image file and copy it into app storage. |
| [`resolve`](#resolve) | method (`ImageService`) | A | Resolve a relative image path (e.g. `images/xxx.png`) to an absolute `File`. |
| [`saveImageFromUrl`](#saveimagefromurl) | method (`ImageService`) | A | Download an image from a URL and save it into app storage. |
| [`delete`](#delete) | method (`ImageService`) | A | Delete a previously saved image file. |

## Documentation

### `static Future<Directory> _getImageDir()` <a id="_getimagedir"></a>
- **Kind:** static method of `ImageService`
- **Source:** `lib/shared/services/image_service.dart` (approx. line 16)
- **Purpose:** Return the app's `images/` subdirectory, creating it first if it doesn't exist yet.
- **Inputs:** None.
- **Returns:** `Future<Directory>` — the `images/` directory under the app data directory
  (`AnimeStorage.getAppDir()`).
- **Side effects:** May create the `images/` directory on disk (`recursive: true`).
- **Algorithm:**
  1. Resolve the app data directory via `AnimeStorage.getAppDir()`.
  2. Join it with `images` to get the target `Directory`.
  3. If it doesn't already exist, create it recursively.
  4. Return the directory.
- **Usage:** Called internally by [`pickAndSaveImage`](#pickandsaveimage) and
  [`saveImageFromUrl`](#saveimagefromurl); not exposed outside this file.
- **Notes:** None.

### `static Future<String?> pickAndSaveImage()` <a id="pickandsaveimage"></a>
- **Kind:** static method of `ImageService`
- **Source:** `lib/shared/services/image_service.dart` (approx. line 30)
- **Purpose:** Open the platform file picker restricted to images, and copy the chosen file into
  app storage under a fresh UUID-based name.
- **Inputs:** None.
- **Returns:** `Future<String?>` — the new relative path (e.g. `"images/<uuid>.png"`), or `null` if
  the user cancelled the picker.
- **Side effects:** Shows the OS file picker; copies the selected file into `<app dir>/images/`.
- **Algorithm:**
  1. Call `FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false)`.
  2. Return `null` if the result is null/empty or the picked path is null.
  3. Ensure the `images/` directory exists (via `_getImageDir`).
  4. Build a new filename `"<uuid.v4()><original extension>"`.
  5. Copy the picked file to that destination and return the relative `images/<name>` path.
- **Usage:**
  ```dart
  final path = await ImageService.pickAndSaveImage();
  ```
  (from `lib/features/anime/views/anime_edit_page.dart`, setting the cover image when the user taps
  "choose from device")
- **Notes:** None.

### `static Future<File> resolve(String relativePath)` <a id="resolve"></a>
- **Kind:** static method of `ImageService`
- **Source:** `lib/shared/services/image_service.dart` (approx. line 52)
- **Purpose:** Resolve a relative image path stored on an `Anime` record (e.g. `coverImage`) to an
  absolute `File` under the app data directory.
- **Inputs:** `relativePath` — a path like `"images/<uuid>.jpg"`, normally an `Anime.coverImage`
  value.
- **Returns:** `Future<File>` — the absolute file (existence is not checked by this method itself).
- **Side effects:** None (pure path join; callers typically check `.existsSync()`/`.exists()`
  themselves).
- **Algorithm:** Join `AnimeStorage.getAppDir()` with `relativePath` and wrap in a `File`.
- **Usage:**
  ```dart
  future: ImageService.resolve(anime.coverImage!),
  ```
  (from `lib/features/anime/views/anime_detail_page.dart`, and reused throughout the anime list,
  home calendar, statistics, and share-image code wherever a cover thumbnail is rendered)
- **Notes:** Does not validate that the file exists; every caller that then reads the file guards
  with an existence check first (see [`share_service.md`](share_service.md)'s cover-loading logic).

### `static Future<String?> saveImageFromUrl(String url)` <a id="saveimagefromurl"></a>
- **Kind:** static method of `ImageService`
- **Source:** `lib/shared/services/image_service.dart` (approx. line 62)
- **Purpose:** Download an image from a remote URL and save it into app storage, for anime search
  results that only provide a cover image URL.
- **Inputs:** `url` — the source image URL.
- **Returns:** `Future<String?>` — the new relative path (e.g. `"images/<uuid>.jpg"`), or `null` on
  a non-200 HTTP response.
- **Side effects:** Performs an HTTP GET request (15-second timeout); writes the downloaded bytes
  to `<app dir>/images/`.
- **Algorithm:**
  1. `GET` the URL with a `User-Agent: MyAnime/0.1` header and a 15-second timeout.
  2. If the response status isn't 200, return `null`.
  3. Derive a file extension from the URL path; fall back to `.jpg` if empty or longer than 5
     characters (guards against a URL whose "extension" is actually a query fragment).
  4. Build a new filename `"<uuid.v4()><ext>"`, write the response bytes to it, and return the
     relative `images/<name>` path.
- **Usage:**
  ```dart
  final path = await ImageService.saveImageFromUrl(result.coverImageUrl!);
  ```
  (from `lib/features/anime/views/anime_search_dialog.dart`, saving a search result's cover image
  locally when the user adds that result)
- **Notes:** Network or decoding failures are not distinguished from a non-200 response — both
  surface to the caller as a `null` return; there is no retry.

### `static Future<void> delete(String relativePath)` <a id="delete"></a>
- **Kind:** static method of `ImageService`
- **Source:** `lib/shared/services/image_service.dart` (approx. line 82)
- **Purpose:** Delete a previously saved image file if it still exists.
- **Inputs:** `relativePath` — the stored relative path to remove.
- **Returns:** `Future<void>`.
- **Side effects:** Deletes a file under `<app dir>/images/` when present.
- **Algorithm:** Resolve the path via [`resolve`](#resolve); if the file exists, delete it;
  otherwise do nothing.
- **Usage:** Not currently called elsewhere in the repo (available for callers that replace or
  remove a cover image and want to reclaim disk space); mirrors the pattern used inline by
  `AnimeStorage` when anime records are deleted.
- **Notes:** Silently no-ops when the file is already gone — callers do not need to check
  existence first.
