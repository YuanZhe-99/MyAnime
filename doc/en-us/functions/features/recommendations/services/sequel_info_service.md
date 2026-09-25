# lib/features/recommendations/services/sequel_info_service.dart

`SequelInfoService` (1.6.3) fetches a short synopsis and a small cover thumbnail for a
"Not in your library yet" missing-sequel card and stores them in the synced `recommendations.json`
under the card's dedupe key (`sequelTrashKey`), through
[`RecommendationStore.putSequelInfo`](recommendation_store.md#putsequelinfo). The page request goes
through [`AnimeSearchService.fetchByUrl`](../../anime/services/anime_search_service.md), so only
AniList, MyAnimeList and bangumi.tv sequels can be fetched. **It is a network feature: every caller
gates on `AppFlavor.isFull`**, like every other caller of the search service. Store builds still show
what a full build fetched, because the result syncs. See
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#missing-sequel-cards).

The thumbnail is a base64 JPEG inside the JSON file rather than a file in `images/`. Image sync is
additive and never deletes, so a thumbnail file would outlive its trashed card on every device; a
JSON field disappears everywhere with the next sync.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `SequelInfoService._` | constructor | B | Prevent instantiation; the service is static only. |
| `resetSession` | static method | B | Forget which keys were tried this session; for tests. |
| [`ensure`](#ensure) | static method | A | Fetch and store info for one missing sequel, once. |
| [`_run`](#_run) | static method | A | Fetch the page and the cover, build the thumbnail, store the result. |
| `_fetchPage` | static method | B | Read the synopsis and cover URL through `AnimeSearchService.fetchByUrl`. |
| `_download` | static method | B | Download an image with the app's user agent and a 15 s timeout. |
| [`makeThumbnail`](#makethumbnail) | static method | A | Shrink a cover into a small base64 JPEG on a background isolate. |
| `_thumbnail` | static method | B | The isolate body of `makeThumbnail`. |
| [`normalizeSynopsis`](#normalizesynopsis) | static method | A | Clean a database synopsis for display and storage. |

The constants `thumbWidth` (112 px, twice the 56 dp card cover), `thumbQuality` (70),
`thumbMaxBytes` (24 KB) and `synopsisMaxLength` (600 characters), and the test seams `fetchPage` and
`download` (`@visibleForTesting` function fields), carry no `/// Purpose:` comment and are not rows.

## Documentation

### `static Future<SequelInfo?> ensure(String key, AnimeExternalRelation sequel, {SequelInfo? existing})` <a id="ensure"></a>
- **Kind:** static method of `SequelInfoService`
- **Source:** `lib/features/recommendations/services/sequel_info_service.dart` (approx. line 76)
- **Purpose:** Fetch and store info for one missing sequel, once.
- **Inputs:** `key` — the dedupe key; `sequel`; `existing` — what the store already holds.
- **Returns:** `Future<SequelInfo?>` — the stored info, or null when nothing was fetched.
- **Side effects:** At most one page request and one image request; one write of
  `recommendations.json`.
- **Algorithm:** Return `existing` when given. Return null when the sequel has no URL or the key is
  empty. Return the running future when one is in flight for the key. Return null when the key was
  already tried this session; otherwise mark it tried and run [`_run`](#_run).
- **Usage:** `_RecommendationsPageState._fetchSequelInfo` and `_AnimeDetailPageState._load`, both
  under `AppFlavor.isFull`.
- **Notes:** The session set is what keeps a dead or unsupported source from being hit on every
  rebuild; it is memory only, so the next launch tries again. A stored result clears the mark
  (see `_run`), so only failures stay marked. A result with nothing in it is still stored, so it is
  not fetched again on the next launch either.

### `static Future<SequelInfo?> _run(String key, String url)` <a id="_run"></a>
- **Kind:** static method of `SequelInfoService`
- **Source:** `lib/features/recommendations/services/sequel_info_service.dart` (approx. line 98)
- **Purpose:** Fetch the page and the cover, build the thumbnail, store the result.
- **Inputs:** `key`, `url`.
- **Returns:** `Future<SequelInfo?>`.
- **Side effects:** Network; writes the store.
- **Algorithm:** `fetchPage(url)`; null → null. When it reported a cover URL, `download` it and
  `makeThumbnail`. Build a `SequelInfo` from `normalizeSynopsis(summary)`, the cover URL, the
  thumbnail and `fetchedAt` = now (UTC), then `RecommendationStore.putSequelInfo` and return what the
  store holds for the key. When something was stored, clear the key's "tried" mark, so a card whose
  info a refresh deleted and Undo restored can fetch again in the same session.
- **Usage:** `ensure`.
- **Notes:** Any exception reads as null and stores nothing, so a network error is retried next
  session. `putSequelInfo` ignores the write while the card is in the trash, and the return value
  is then null.

### `static Future<String?> makeThumbnail(Uint8List bytes)` <a id="makethumbnail"></a>
- **Kind:** static method of `SequelInfoService`
- **Source:** `lib/features/recommendations/services/sequel_info_service.dart` (approx. line 164)
- **Purpose:** Shrink a cover into a small base64 JPEG.
- **Inputs:** `bytes` — the downloaded image, any format `package:image` decodes.
- **Returns:** `Future<String?>` — base64 text, or null when the image cannot be decoded or the JPEG
  is larger than `thumbMaxBytes`.
- **Side effects:** Runs on a background isolate through `compute`.
- **Algorithm:** Decode; when wider than `thumbWidth`, `copyResize` to that width with average
  interpolation, keeping the aspect ratio; `encodeJpg` at `thumbQuality`; reject above
  `thumbMaxBytes`; base64-encode.
- **Usage:** `_run`; `test/recommendation_pins_test.dart`.
- **Notes:** A typical 2:3 poster comes out at 112 × 168 and a few kilobytes. `package:image` became
  a runtime dependency for this in 1.6.3; it was a dev dependency used only by `tool/`.

### `static String? normalizeSynopsis(String? raw)` <a id="normalizesynopsis"></a>
- **Kind:** static method of `SequelInfoService`
- **Source:** `lib/features/recommendations/services/sequel_info_service.dart` (approx. line 199)
- **Purpose:** Clean a database synopsis for display and storage.
- **Inputs:** `raw`.
- **Returns:** `String?` — null when empty.
- **Side effects:** None.
- **Algorithm:** Remove MyAnimeList's `[Written by …]` and any `(Source: …)` credit, collapse all
  whitespace (paragraph breaks included) to single spaces, trim, and cut to `synopsisMaxLength`
  characters with a trailing `…`.
- **Usage:** `_run`.
- **Notes:** The cards show three lines at most, so paragraphs are not kept. The synopsis is in
  whatever language the database wrote it: English from AniList and MyAnimeList, usually Chinese or
  Japanese from bangumi.tv.
