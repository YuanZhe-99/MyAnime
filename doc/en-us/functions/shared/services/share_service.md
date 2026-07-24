# lib/shared/services/share_service.dart

`ShareService` renders anime, ranking, and statistics data into shareable PNG "cards" (drawn with
`dart:ui`'s `Canvas`/`PictureRecorder`) and drives the platform-specific share flow (Android
`MethodChannel`, iOS `Share.shareXFiles`, desktop preview dialog). It also owns the statistics
view's `.myanimeitem` data-file and plain-text export paths, delegating the actual bundle format to
[`file_open_service.md`](file_open_service.md). See
[`../../../features/share-and-import.md`](../../../features/share-and-import.md) for the full
feature write-up (image card contents, multi-page splitting, per-platform share mechanism) — this
page documents what each function actually does, including one likely-dead code path found while
reading the source (noted below).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`RankingShareEntry.new`](#rankingshareentry-new) | constructor (`RankingShareEntry`) | A | Create a ranking share entry (anime + rank + score). |
| [`shareAnime`](#shareanime) | method (`ShareService`) | A | Ask image-vs-data and share a single anime accordingly. |
| [`shareRankingImage`](#sharerankingimage) | method (`ShareService`) | A | Generate and share a ranking image (legacy all-in-one entry point). |
| [`_shareAnimeData`](#_shareanimedata) | method (`ShareService`) | A | Export one anime as a `.myanimeitem` file and share/save it. |
| [`_shareAnimeImage`](#_shareanimeimage) | method (`ShareService`) | A | Ask URL-inclusion options, generate, and share a single-anime image card. |
| [`shareImageBytes`](#shareimagebytes) | method (`ShareService`) | A | Public entry point: share already-generated single-page image bytes. |
| [`shareImageBytesMulti`](#shareimagebytesmulti) | method (`ShareService`) | A | Public entry point: share one or more already-generated image pages. |
| [`generateStatisticsShareBytes`](#generatestatisticssharebytes) | method (`ShareService`) | A | Public entry point: generate statistics share image bytes without showing share UI. |
| [`generateRankingShareBytes`](#generaterankingsharebytes) | method (`ShareService`) | A | Public entry point: generate ranking share image bytes without showing share UI. |
| [`_shareImageBytes`](#_shareimagebytes) | method (`ShareService`) | A | Write image bytes to a temp file and dispatch the single-file platform share flow. |
| [`_shareImageBytesMulti`](#_shareimagebytesmulti) | method (`ShareService`) | A | Write multiple image pages to temp files and dispatch the multi-file platform share flow. |
| [`_generateShareImage`](#_generateshareimage) | method (`ShareService`) | A | Lay out and draw the single-anime share card to PNG bytes. |
| `_layoutText` | method (`ShareService`) | B | Build and lay out a `TextPainter` for a piece of card text. |
| [`_generateRankingShareImage`](#_generaterankingshareimage) | method (`ShareService`) | A | Lay out and draw the (possibly multi-page) ranking share image. |
| `_drawRankingRow` | method (`ShareService`) | B | Draw one ranked-anime row (rank circle, cover, title, score) onto a canvas. |
| `_drawCoverImage` | method (`ShareService`) | B | Draw a cover image into a rounded destination rect with center-crop scaling. |
| `_drawWatermark` | method (`ShareService`) | B | Draw the right-aligned `[logo] MyAnime!!!!!` watermark row. |
| `_formatScore` | method (`ShareService`) | B | Format a score, dropping a trailing `.0`. |
| `_typeLabel` | method (`ShareService`) | B | Localized label for an `AnimeType`. |
| `_dayName` | method (`ShareService`) | B | Localized weekday name for a 1–7 day-of-week code. |
| [`_countAiredEpisodes`](#_countairedepisodes) | method (`ShareService`) | A | Count episodes aired as of today (JST) for the share card's progress bar. |
| [`_showDesktopPreview`](#_showdesktoppreview) | method (`ShareService`) | A | Show the desktop single-image preview dialog with copy/save-as actions. |
| [`_showDesktopPreviewMulti`](#_showdesktoppreviewmulti) | method (`ShareService`) | A | Show the desktop multi-page preview dialog with copy-first-page/save-all actions. |
| [`_copyImageToClipboard`](#_copyimagetoclipboard) | method (`ShareService`) | A | Copy an image file to the OS clipboard via a platform-specific shell command. |
| [`shareStatisticsImage`](#sharestatisticsimage) | method (`ShareService`) | A | Generate and share the statistics/ranking-style image (bar chart optional). |
| [`shareStatisticsData`](#sharestatisticsdata) | method (`ShareService`) | A | Export the visible statistics anime list as a `.myanimeitem` bundle and share/save it. |
| [`shareStatisticsTxt`](#sharestatisticstxt) | method (`ShareService`) | A | Export the visible statistics anime list as a sorted plain-text name list. |
| [`_generateStatisticsShareImage`](#_generatestatisticsshareimage) | method (`ShareService`) | A | Lay out and draw the (possibly multi-page, optionally bar-charted) statistics share image. |
| [`_drawSummaryBars`](#_drawsummarybars) | method (`ShareService`) | A | Draw the tracked/completed/dropped horizontal bar chart. |
| [`_loadShareCoverImages`](#_loadsharecoverimages) | method (`ShareService`) | A | Load and decode (deduplicated) cover images for a list of anime, reporting progress. |
| `_drawStatisticsRow` | method (`ShareService`) | B | Draw one statistics-entry row (rank circle, cover, title, status/progress) onto a canvas. |
| [`StatisticsShareEntry.new`](#statisticsshareentry-new) | constructor (`StatisticsShareEntry`) | A | Create a statistics share entry (anime + rank + optional score/status/progress labels). |
| [`StatisticsShareSummary.new`](#statisticssharesummary-new) | constructor (`StatisticsShareSummary`) | A | Create a statistics share summary (tracked/completed/dropped counts). |

## Documentation

### `const RankingShareEntry({required this.anime, required this.rank, required this.score})` <a id="rankingshareentry-new"></a>
- **Kind:** constructor of `RankingShareEntry`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 29)
- **Purpose:** Hold one anime's rank and score for a ranking share image.
- **Inputs:** `anime`, `rank` (1-based position), `score` (the sort field's value).
- **Returns:** A new `RankingShareEntry`.
- **Side effects:** None.
- **Algorithm:** Direct field assignment.
- **Usage:** Built by `lib/features/anime/views/statistics_page.dart` from the current ranking
  list before calling [`generateRankingShareBytes`](#generaterankingsharebytes).
- **Notes:** None.

### `static Future<void> shareAnime(BuildContext context, Anime anime)` <a id="shareanime"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 66)
- **Purpose:** Entry point for sharing a single anime: ask the user "image" vs. "data file", then
  dispatch accordingly.
- **Inputs:** `context`, `anime`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a `SimpleDialog`; see [`_shareAnimeData`](#_shareanimedata) /
  [`_shareAnimeImage`](#_shareanimeimage) for further effects.
- **Algorithm:** Show a dialog offering `'image'` or `'data'`; if cancelled or the context is no
  longer mounted, return; otherwise call `_shareAnimeData` or `_shareAnimeImage`.
- **Usage:**
  ```dart
  onPressed: () => ShareService.shareAnime(context, anime),
  ```
  (from `lib/features/anime/views/anime_detail_page.dart`, the anime detail page's share button)
- **Notes:** None.

### `static Future<void> shareRankingImage(BuildContext context, {required List<RankingShareEntry> entries, required String title, required String subtitle, required String sortLabel, required String orderLabel, required AppLocalizations l10n, ValueNotifier<double>? progress})` <a id="sharerankingimage"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 109)
- **Purpose:** Generate a ranking share image end-to-end (generate + share) in one call.
- **Inputs:** `entries`, `title`, `subtitle`, `sortLabel`, `orderLabel`, `l10n`, optional `progress`.
- **Returns:** `Future<void>`.
- **Side effects:** Reads cover images, writes temp PNG(s), invokes the platform share/preview flow.
- **Algorithm:** Return early if `entries` is empty. Generate pages via
  [`_generateRankingShareImage`](#_generaterankingshareimage), then share them via
  [`shareImageBytesMulti`](#shareimagebytesmulti) with `fileNameBase: 'myanime_ranking'`; on any
  exception, show a "share failed" snackbar.
- **Usage:** Not currently called elsewhere in the repo.
- **Notes:** **Likely dead code** — `lib/features/anime/views/statistics_page.dart` shares ranking
  images by calling [`generateRankingShareBytes`](#generaterankingsharebytes) directly (wrapped in
  its own progress-dialog helper) and then [`shareImageBytesMulti`](#shareimagebytesmulti)
  separately, rather than calling this all-in-one method. `shareRankingImage` reimplements the same
  generate-then-share sequence but without a caller-visible progress dialog while generating.

### `static Future<void> _shareAnimeData(BuildContext context, Anime anime, AppLocalizations l10n)` <a id="_shareanimedata"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 152)
- **Purpose:** Export one anime as a `.myanimeitem` file and hand it to the platform share/save
  flow.
- **Inputs:** `context`, `anime`, `l10n`.
- **Returns:** `Future<void>`.
- **Side effects:** Calls [`FileOpenService.exportAnimeItem`](file_open_service.md#exportanimeitem);
  on Android invokes the `com.yuanzhe.my_anime/share` `MethodChannel`'s `shareFile`; on iOS calls
  `Share.shareXFiles`; on desktop shows a native "save file" dialog and copies the file there.
- **Algorithm:** Export the anime to a temp `.myanimeitem` file; branch by platform to share or
  save it; show a "saved"/"share failed" snackbar as appropriate; any exception shows "share
  failed".
- **Usage:** Called internally from [`shareAnime`](#shareanime) when the user picks "data file".
- **Notes:** None.

### `static Future<void> _shareAnimeImage(BuildContext context, Anime anime, AppLocalizations l10n)` <a id="_shareanimeimage"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 200)
- **Purpose:** Optionally ask which URLs (info/watch) to embed as QR codes, generate the share
  image, and dispatch it to the share flow.
- **Inputs:** `context`, `anime`, `l10n`.
- **Returns:** `Future<void>`.
- **Side effects:** May show a URL-options dialog; generates a PNG via
  [`_generateShareImage`](#_generateshareimage); shares it via
  [`_shareImageBytes`](#_shareimagebytes).
- **Algorithm:** If the anime has an info URL or watch URL, show `_showUrlOptionsDialog` and bail
  out if the user cancels; otherwise default both inclusion flags to `false`. Generate the image
  with the chosen inclusion flags, then share it as `myanime_share.png`; any exception shows a
  "share failed" snackbar.
- **Usage:** Called internally from [`shareAnime`](#shareanime) when the user picks "image".
- **Notes:** None.

### `static Future<void> shareImageBytes(BuildContext context, Uint8List imageBytes, AppLocalizations l10n, {required String fileName})` <a id="shareimagebytes"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 252)
- **Purpose:** Public entry point for callers that already have generated PNG bytes (e.g. produced
  behind a progress dialog) and just need the platform share flow.
- **Inputs:** `context`, `imageBytes`, `l10n`, `fileName`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes a temp file and invokes platform share / desktop preview (delegates to
  [`_shareImageBytes`](#_shareimagebytes)).
- **Algorithm:** Thin forwarding call to `_shareImageBytes`.
- **Usage:** Not currently called elsewhere in the repo (statistics/ranking sharing goes through
  [`shareImageBytesMulti`](#shareimagebytesmulti) instead, even for single-page results).
- **Notes:** None.

### `static Future<void> shareImageBytesMulti(BuildContext context, List<Uint8List> pages, AppLocalizations l10n, {required String fileNameBase})` <a id="shareimagebytesmulti"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 269)
- **Purpose:** Public entry point for sharing one or more pre-generated image pages (e.g. a split
  tall statistics/ranking export), reusing the single-file flow when there's only one page.
- **Inputs:** `context`, `pages`, `l10n`, `fileNameBase`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes a temp PNG per page and invokes platform share / desktop preview.
- **Algorithm:** Return early if `pages` is empty. If exactly one page, share it as
  `"$fileNameBase.png"` via [`_shareImageBytes`](#_shareimagebytes); otherwise delegate to
  [`_shareImageBytesMulti`](#_shareimagebytesmulti).
- **Usage:**
  ```dart
  await ShareService.shareImageBytesMulti(
    context,
    pages,
    l10n,
    fileNameBase: 'myanime_ranking',
  );
  ```
  (from `lib/features/anime/views/statistics_page.dart`, sharing the generated ranking or
  statistics image pages)
- **Notes:** This is the actual call site statistics/ranking sharing uses today (see
  [`shareRankingImage`](#sharerankingimage)'s Notes for the parallel unused all-in-one path).

### `static Future<List<Uint8List>> generateStatisticsShareBytes({required List<StatisticsShareEntry> entries, required String title, required String subtitle, required AppLocalizations l10n, StatisticsShareSummary? summary, ValueNotifier<double>? progress})` <a id="generatestatisticssharebytes"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 297)
- **Purpose:** Public entry point to generate statistics share image bytes without showing any
  share UI, so callers can wrap generation in their own progress dialog.
- **Inputs:** `entries`, `title`, `subtitle`, `l10n`, optional `summary` (bar-chart counts), optional
  `progress`.
- **Returns:** `Future<List<Uint8List>>` — one or more PNG pages.
- **Side effects:** Reads cover images from storage; reports progress via `progress` (0..1).
- **Algorithm:** Throw `StateError` if `entries` is empty; otherwise delegate to
  [`_generateStatisticsShareImage`](#_generatestatisticsshareimage).
- **Usage:**
  ```dart
  generate: (progress) => ShareService.generateStatisticsShareBytes(
    entries: entries,
    title: l10n.statsTitle,
    subtitle: subtitle,
    l10n: l10n,
    summary: summary,
    progress: progress,
  ),
  ```
  (from `lib/features/anime/views/statistics_page.dart`, wrapped in its own
  `_generateImageWithProgress` progress-dialog helper, then shared via
  [`shareImageBytesMulti`](#shareimagebytesmulti))
- **Notes:** None.

### `static Future<List<Uint8List>> generateRankingShareBytes({required List<RankingShareEntry> entries, required String title, required String subtitle, required String sortLabel, required String orderLabel, required AppLocalizations l10n, ValueNotifier<double>? progress})` <a id="generaterankingsharebytes"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 326)
- **Purpose:** Public entry point to generate ranking share image bytes without showing any share
  UI.
- **Inputs:** `entries`, `title`, `subtitle`, `sortLabel`, `orderLabel`, `l10n`, optional `progress`.
- **Returns:** `Future<List<Uint8List>>` — one or more PNG pages.
- **Side effects:** Reads cover images from storage; reports progress via `progress` (0..1).
- **Algorithm:** Throw `StateError` if `entries` is empty; otherwise delegate to
  [`_generateRankingShareImage`](#_generaterankingshareimage).
- **Usage:**
  ```dart
  generate: (progress) => ShareService.generateRankingShareBytes(
    entries: entries,
    title: l10n.statsRanking,
    subtitle: subtitle,
    sortLabel: _ratingFieldLabel(_rankingSortField, l10n),
    orderLabel: _rankingDescending
        ? l10n.statsRankingDescending
        : l10n.statsRankingAscending,
    l10n: l10n,
    progress: progress,
  ),
  ```
  (from `lib/features/anime/views/statistics_page.dart`'s ranking share flow)
- **Notes:** None.

### `static Future<void> _shareImageBytes(BuildContext context, Uint8List imageBytes, AppLocalizations l10n, {required String fileName})` <a id="_shareimagebytes"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 353)
- **Purpose:** Write image bytes to a temp file, then dispatch the platform-appropriate single-file
  share flow.
- **Inputs:** `context`, `imageBytes`, `l10n`, `fileName`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes a temp file; Android invokes the `shareFile` `MethodChannel` method; iOS
  calls `Share.shareXFiles`; desktop shows [`_showDesktopPreview`](#_showdesktoppreview).
- **Algorithm:** Write bytes to `<temp dir>/<fileName>`; if the context is no longer mounted,
  return; branch on `Platform.isAndroid`/`isIOS`/else (desktop preview).
- **Usage:** Called internally from [`shareImageBytes`](#shareimagebytes),
  [`shareImageBytesMulti`](#shareimagebytesmulti) (single-page case), and
  [`_shareAnimeImage`](#_shareanimeimage).
- **Notes:** Uses `FLAG_ACTIVITY_NEW_TASK` on the Android side (native `MethodChannel`
  implementation) so the share target opens outside the MyAnime task stack — see
  [`../../../features/share-and-import.md`](../../../features/share-and-import.md).

### `static Future<void> _shareImageBytesMulti(BuildContext context, List<Uint8List> pages, AppLocalizations l10n, {required String fileNameBase})` <a id="_shareimagebytesmulti"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 392)
- **Purpose:** Write every page to its own temp file, then dispatch the platform-appropriate
  multi-file share flow.
- **Inputs:** `context`, `pages`, `l10n`, `fileNameBase`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes one temp PNG per page (`"$fileNameBase_N.png"`, 1-based); Android
  invokes the plural `shareFiles` `MethodChannel` method with a path list; iOS calls
  `Share.shareXFiles` with a file list; desktop shows
  [`_showDesktopPreviewMulti`](#_showdesktoppreviewmulti).
- **Algorithm:** Write all pages to temp files, then branch by platform exactly like
  `_shareImageBytes` but with the plural APIs.
- **Usage:** Called internally from [`shareImageBytesMulti`](#shareimagebytesmulti) (multi-page
  case) only.
- **Notes:** Android's `shareFiles` (plural) `MethodChannel` method is distinct from
  `_shareImageBytes`'s singular `shareFile` — both are implemented natively (see
  [`../../../features/share-and-import.md`](../../../features/share-and-import.md)).

### `static Future<Uint8List> _generateShareImage(Anime anime, AppLocalizations l10n, {bool includeInfoUrl = false, bool includeWatchUrl = false})` <a id="_generateshareimage"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 486)
- **Purpose:** Lay out and render the single-anime share card (cover, titles, schedule, progress
  bar, notes, QR codes, watermark) to PNG bytes.
- **Inputs:** `anime`; `l10n`; `includeInfoUrl`/`includeWatchUrl` — whether to render a QR code +
  URL text row for each.
- **Returns:** `Future<Uint8List>` — PNG-encoded image bytes.
- **Side effects:** Loads the app logo asset and (if present) the anime's cover image from disk.
- **Algorithm:** Two-pass layout-then-draw, all in fixed-width (`_cardWidth = 480`) card
  coordinates:
  1. Load the logo (`assets/icon/app_icon.png`) and cover image (via
     [`ImageService.resolve`](image_service.md#resolve)), tolerating failures silently.
  2. Compute the vertical layout top-to-bottom: title, optional Japanese title (shown only when it
     exists and differs from the main title), info lines (season+type, schedule, first air date),
     progress text + bar, top-section height as `max(info column height, cover height)` when a
     cover exists, optional notes (capped at 300 characters, further clipped to 6 lines by
     `TextPainter`'s `maxLines`, with an `...` indicator if either cap truncated it), one QR+URL row
     per included URL, and finally the `[logo] MyAnime!!!!!` watermark row.
  3. Record the final `cardHeight`, create a `PictureRecorder`/`Canvas` scaled by `_pixelRatio`
     (3.0), and draw: background, border, accent header bar, cover (via
     [`_drawCoverImage`](#_drawcoverimage) if present), title/Japanese title/info lines, progress
     text + track + filled bar (`fillWidth = infoWidth * airedCount / totalEps`), notes + truncation
     ellipsis, each QR code (via `QrPainter`) + its URL text, and the watermark (via
     [`_drawWatermark`](#_drawwatermark)).
  4. Encode the recorded picture to PNG via `picture.toImage(...)` +
     `image.toByteData(format: ui.ImageByteFormat.png)`.
- **Usage:** Called internally from [`_shareAnimeImage`](#_shareanimeimage) only.
- **Notes:** This function has no page-splitting logic (unlike the ranking/statistics generators) —
  a single anime's card is assumed to always fit within the platform texture dimension cap.

### `static Future<List<Uint8List>> _generateRankingShareImage({required List<RankingShareEntry> entries, required String title, required String subtitle, required String sortLabel, required String orderLabel, required AppLocalizations l10n, ValueNotifier<double>? progress})` <a id="_generaterankingshareimage"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 871)
- **Purpose:** Lay out and render the ranking share image, splitting across multiple PNG pages when
  the single-page pixel height would exceed the platform texture dimension cap.
- **Inputs:** `entries`, `title`, `subtitle`, `sortLabel`, `orderLabel`, `l10n`, optional `progress`.
- **Returns:** `Future<List<Uint8List>>` — one or more PNG pages, each `_rankingCardWidth` (560)
  wide.
- **Side effects:** Loads the app logo asset; loads every distinct cover image via
  [`_loadShareCoverImages`](#_loadsharecoverimages) (reports `progress`).
- **Algorithm:**
  1. Load the logo and every entry's cover image up front.
  2. Lay out the fixed header once: title, subtitle, and a meta line
     (`"<sort field label>: <sortLabel> · <orderLabel> · <count>"`).
  3. Compute `totalCardHeight` assuming every row (`_rankingRowHeight = 86`) plus the watermark
     block fit on one page.
  4. Define a local `renderPage(start, end, isLast)` closure that draws the header + border on
     every page, rows `[start, end)` via [`_drawRankingRow`](#_drawrankingrow), and the watermark
     only when `isLast`.
  5. If `totalCardHeight * _pixelRatio <= _maxImageDimension` (16000), render one page covering all
     entries.
  6. Otherwise compute how many rows fit per page given the texture cap
     (`rowsPerPage = floor(availableForRows / _rankingRowHeight)`, minimum 1) and render successive
     pages until all entries are covered.
- **Usage:** Called internally from [`shareRankingImage`](#sharerankingimage) and
  [`generateRankingShareBytes`](#generaterankingsharebytes).
- **Notes:** See [`../../../features/share-and-import.md`](../../../features/share-and-import.md)'s
  "Multi-page splitting" note — this is the ranking half of that behavior; every page repeats the
  header, and the watermark appears only on the final page.

### `static int _countAiredEpisodes(Anime anime)` <a id="_countairedepisodes"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1284)
- **Purpose:** Count how many of an anime's episodes have aired as of today (JST), for the share
  card's progress bar/text.
- **Inputs:** `anime`.
- **Returns:** `int`.
- **Side effects:** None (reads the system clock via `JstTime.today()`).
- **Algorithm:**
  1. If `endEpisode` is null (open-ended, unknown total), return 0.
  2. If `firstAirDate` is null, return `totalEpisodes ?? 0` (nothing to compare against, assume
     fully aired).
  3. If the anime's effective type is `allAtOnce`, it's all-or-nothing: return 0 if the first air
     date is still in the future, else the full episode count.
  4. Otherwise loop `startEpisode..endEpisode`, counting an episode as aired when its calendar date
     (via `getEpisodeCalendarDate`) is null or not after today.
- **Usage:** Called internally from [`_generateShareImage`](#_generateshareimage) only.
- **Notes:** Uses [`JstTime.today()`](../utils/jst_time.md#jsttime-today) (JST, not device local time) —
  consistent with how all other episode air-date logic in the app is JST-based.

### `static Future<void> _showDesktopPreview(BuildContext context, Uint8List imageBytes, String tempPath, AppLocalizations l10n, {required String fileName})` <a id="_showdesktoppreview"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1314)
- **Purpose:** Show the desktop single-image share preview dialog, with "copy to clipboard" and
  "save as" actions.
- **Inputs:** `context`, `imageBytes`, `tempPath` (source file for the copy action), `l10n`,
  `fileName` (suggested save-as name).
- **Returns:** `Future<void>`.
- **Side effects:** Shows a modal `Dialog`; "Copy" calls
  [`_copyImageToClipboard`](#_copyimagetoclipboard); "Save as" opens the native save dialog and
  writes `imageBytes` to the chosen path.
- **Algorithm:** Render the image with `Image.memory`, plus a row of two buttons: copy (copies
  `tempPath` to clipboard, closes the dialog, shows a "copied" snackbar) and save-as (prompts for a
  destination, writes the bytes, closes the dialog, shows a "saved" snackbar).
- **Usage:** Called internally from [`_shareImageBytes`](#_shareimagebytes) (desktop branch) and
  [`shareStatisticsData`](#sharestatisticsdata) (desktop `.myanimeitem` preview).
- **Notes:** None.

### `static Future<void> _showDesktopPreviewMulti(BuildContext context, List<Uint8List> pages, List<String> tempPaths, AppLocalizations l10n, {required String fileNameBase})` <a id="_showdesktoppreviewmulti"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1391)
- **Purpose:** Show a scrollable desktop preview dialog for multiple image pages, with "copy first
  page" and "save all" actions.
- **Inputs:** `context`, `pages`, `tempPaths`, `l10n`, `fileNameBase`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows a modal `Dialog` with a `ListView.builder` of pages; "Copy" copies only
  `tempPaths.first`; "Save all" prompts for a destination directory and writes every page as
  `"<fileNameBase>_<n>.png"`.
- **Algorithm:** Render a scrollable list of all page images, plus a header showing the page count
  (`l10n.sharePagesLabel`); the save-all action loops over `pages`, writing each with the same
  `_N` naming convention used by [`_shareImageBytesMulti`](#_shareimagebytesmulti).
- **Usage:** Called internally from [`_shareImageBytesMulti`](#_shareimagebytesmulti) (desktop
  branch) only.
- **Notes:** Only the first page can be copied to the clipboard — there is no per-page copy action
  in the multi-page dialog.

### `static Future<void> _copyImageToClipboard(String imagePath)` <a id="_copyimagetoclipboard"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1482)
- **Purpose:** Copy a PNG file to the OS clipboard as an image, using a platform-specific external
  process since Flutter has no built-in image-clipboard API on desktop.
- **Inputs:** `imagePath` — path to the PNG file to copy.
- **Returns:** `Future<void>`.
- **Side effects:** Spawns a child process: PowerShell (`System.Windows.Forms.Clipboard`) on
  Windows, `osascript` on macOS, `xclip` on Linux.
- **Algorithm:** Branch on `Platform.isWindows`/`isMacOS`/`isLinux` and run the corresponding
  external command via `Process.run` with the image path embedded in the command/script.
- **Usage:** Called internally from [`_showDesktopPreview`](#_showdesktoppreview) and
  [`_showDesktopPreviewMulti`](#_showdesktoppreviewmulti)'s "Copy" actions.
- **Notes:** Requires `xclip` to be installed on Linux — there is no fallback or error surfaced to
  the user if it is missing (`Process.run` failure is not awaited/checked here).

### `static Future<void> shareStatisticsImage(BuildContext context, {required List<StatisticsShareEntry> entries, required String title, required String subtitle, required AppLocalizations l10n, StatisticsShareSummary? summary, ValueNotifier<double>? progress})` <a id="sharestatisticsimage"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1519)
- **Purpose:** Generate and share the statistics image end-to-end (generate + share) in one call;
  renders a bar chart at the top when `summary` is given, otherwise a plain ranked list.
- **Inputs:** `context`, `entries`, `title`, `subtitle`, `l10n`, optional `summary`, optional
  `progress`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows dialogs, generates images, shares files.
- **Algorithm:** Return early if `entries` is empty. Generate pages via
  [`_generateStatisticsShareImage`](#_generatestatisticsshareimage), then share via
  [`shareImageBytesMulti`](#shareimagebytesmulti) using `fileNameBase: 'myanime_stats'` (when
  `summary` is given) or `'myanime_ranking'` (otherwise); on exception, show a "share failed"
  snackbar.
- **Usage:** Not currently called elsewhere in the repo — like
  [`shareRankingImage`](#sharerankingimage), `statistics_page.dart` calls
  [`generateStatisticsShareBytes`](#generatestatisticssharebytes) directly (behind its own progress
  dialog) and then [`shareImageBytesMulti`](#shareimagebytesmulti) separately, rather than this
  all-in-one wrapper.
- **Notes:** Same likely-dead-code situation as `shareRankingImage` — kept for reference since it
  is a valid, simpler alternative call pattern without a caller-visible progress dialog.

### `static Future<void> shareStatisticsData(BuildContext context, {required List<Anime> animes, required String displayName, required AppLocalizations l10n})` <a id="sharestatisticsdata"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1560)
- **Purpose:** Export the currently visible statistics anime list as a `.myanimeitem` multi-anime
  bundle and hand it to the platform share/preview flow.
- **Inputs:** `context`, `animes`, `displayName` (used for both the export filename and the
  `.myanimeitem` name), `l10n`.
- **Returns:** `Future<void>`.
- **Side effects:** Calls
  [`FileOpenService.exportAnimeBundle`](file_open_service.md#exportanimebundle); Android/iOS share
  the file directly; desktop shows [`_showDesktopPreview`](#_showdesktoppreview) with the raw bytes
  (reusing the image-preview dialog to display/save a non-image file).
- **Algorithm:** Return early if `animes` is empty. Export the bundle; branch by platform to share
  (Android/iOS) or preview (desktop, reading the file back into bytes first); any exception shows a
  "share failed" snackbar.
- **Usage:**
  ```dart
  await ShareService.shareStatisticsData(
    context,
    animes: animes,
    displayName: displayName,
    l10n: l10n,
  );
  ```
  (from `lib/features/anime/views/statistics_page.dart`, the "share as data" option in the
  statistics share dialog)
- **Notes:** On desktop this reuses `_showDesktopPreview`, which was designed to preview a PNG —
  `Image.memory` on non-image bytes would normally fail, but since the "preview" is really just a
  vehicle for the copy/save-as buttons here the image rendering failing silently is tolerated
  (visually the preview area will just show a broken-image icon).

### `static Future<void> shareStatisticsTxt(BuildContext context, {required List<Anime> animes, required String displayName, required AppLocalizations l10n})` <a id="sharestatisticstxt"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1611)
- **Purpose:** Export the currently visible statistics anime list as a plain-text file of display
  names, one per line, sorted in dictionary order.
- **Inputs:** `context`, `animes`, `displayName`, `l10n`.
- **Returns:** `Future<void>`.
- **Side effects:** Writes a temp `.txt` file; shares/saves it via the platform flow; shows a
  snackbar on success, failure, or when the list is empty.
- **Algorithm:** If `animes` is empty, show an "empty" snackbar and return. Sort a copy of `animes`
  by `displayTitle`, write one name per line to a temp file, then share (Android/iOS) or offer a
  save-as dialog (desktop); any exception shows "share failed".
- **Usage:**
  ```dart
  await ShareService.shareStatisticsTxt(
    context,
    animes: animes,
    displayName: displayName,
    l10n: l10n,
  );
  ```
  (from `lib/features/anime/views/statistics_page.dart`, the "share as TXT" option)
- **Notes:** Contains no personal viewing data — just display names, matching
  [`../../../features/share-and-import.md`](../../../features/share-and-import.md)'s description of
  this export.

### `static Future<List<Uint8List>> _generateStatisticsShareImage({required List<StatisticsShareEntry> entries, required String title, required String subtitle, required AppLocalizations l10n, StatisticsShareSummary? summary, ValueNotifier<double>? progress})` <a id="_generatestatisticsshareimage"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1685)
- **Purpose:** Lay out and render the statistics share image — optionally with a summary bar chart
  on page 1 — splitting across multiple PNG pages when needed.
- **Inputs:** `entries`, `title`, `subtitle`, `l10n`, optional `summary`, optional `progress`.
- **Returns:** `Future<List<Uint8List>>` — one or more PNG pages.
- **Side effects:** Loads the app logo; loads every distinct cover image via
  [`_loadShareCoverImages`](#_loadsharecoverimages) (reports `progress`).
- **Algorithm:** Structurally the statistics counterpart to
  [`_generateRankingShareImage`](#_generaterankingshareimage), with one added wrinkle:
  1. Lay out title + subtitle as the shared header.
  2. If `summary != null`, reserve space for a 3-bar chart (`chartHeight`) directly below the
     header — **first page only**.
  3. Track two different "first row Y" values: `firstPagePreRowsY` (header + chart, for page 1) and
     `subsequentPreRowsY` (header only, for later pages) — later pages have more vertical room for
     rows since they skip the chart.
  4. `renderPage(start, end, isFirst, isLast)` draws the header on every page, the bar chart (via
     [`_drawSummaryBars`](#_drawsummarybars)) only when `isFirst && summary != null`, rows `[start,
     end)` via [`_drawStatisticsRow`](#_drawstatisticsrow), and the watermark only when `isLast`.
  5. If everything fits in one page (`totalCardHeight * _pixelRatio <= _maxImageDimension`), render
     one page. Otherwise compute `firstPageRows`/`laterRows` independently (since their available
     row space differs because of the chart) and paginate accordingly.
- **Usage:** Called internally from [`shareStatisticsImage`](#sharestatisticsimage) and
  [`generateStatisticsShareBytes`](#generatestatisticssharebytes).
- **Notes:** See
  [`../../../features/share-and-import.md`](../../../features/share-and-import.md)'s "Multi-page
  splitting" note — the summary bar chart appearing on page 1 only, while the header repeats on
  every page, is the statistics-specific nuance on top of the ranking generator's simpler scheme.

### `static void _drawSummaryBars(Canvas canvas, double y, double contentWidth, StatisticsShareSummary summary, AppLocalizations l10n, {required double barH, required double barGap})` <a id="_drawsummarybars"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1885)
- **Purpose:** Draw the three horizontal bars (tracked, completed, dropped) that make up the
  statistics share image's summary chart.
- **Inputs:** `canvas`, `y` (top of the chart), `contentWidth`, `summary`, `l10n`, `barH`, `barGap`.
- **Returns:** None.
- **Side effects:** None (pure canvas drawing).
- **Algorithm:**
  1. Build a `(label, value, color)` triple for tracked (accent color), completed (green), and
     dropped (red), and find `maxVal` across the three.
  2. For each bar in order: draw its `"<label>: <count>"` text, then a rounded track rectangle, then
     a rounded fill rectangle whose width is `contentWidth * value / maxVal` (proportional to the
     largest of the three counts, so at least one bar always reaches full width) — skipped when
     `maxVal` is 0.
- **Usage:** Called internally from
  [`_generateStatisticsShareImage`](#_generatestatisticsshareimage) (first page only) when a
  `summary` is provided.
- **Notes:** Bars are scaled relative to the **largest of the three values**, not a fixed total —
  so e.g. if "tracked" is much larger than "completed"/"dropped", those two bars will appear small
  relative to it rather than each summing to a fixed width.

### `static Future<Map<String, ui.Image>> _loadShareCoverImages(List<Anime> animes, ValueNotifier<double>? progress)` <a id="_loadsharecoverimages"></a>
- **Kind:** static method of `ShareService`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 1940)
- **Purpose:** Load and decode every distinct cover image referenced by a list of anime, reporting
  load progress, for use by the ranking/statistics image generators.
- **Inputs:** `animes` — anime whose `coverImage` should be loaded; `progress` — optional
  `ValueNotifier` updated to a 0..1 fraction as covers load (and forced to 1 when done).
- **Returns:** `Future<Map<String, ui.Image>>` keyed by the anime's `coverImage` relative path.
- **Side effects:** Reads image files from `<app dir>/images/` (via
  [`ImageService.resolve`](image_service.md#resolve)); mutates `progress.value` if provided.
- **Algorithm:**
  1. Build a deduplicated list of cover paths to load (skip anime with no cover, and skip paths
     already queued or already loaded).
  2. If there's nothing to load, set `progress` to 1 and return an empty map immediately.
  3. For each cover path, resolve it, and if the file exists, read + decode it via
     `ui.instantiateImageCodec`; any failure for one cover is swallowed silently (that entry is just
     absent from the result map) so one bad cover doesn't abort the whole export.
  4. Update `progress.value` to `(i + 1) / coversToLoad.length` after each cover; set it to 1 at the
     end regardless.
- **Usage:** Called internally from [`_generateRankingShareImage`](#_generaterankingshareimage) and
  [`_generateStatisticsShareImage`](#_generatestatisticsshareimage).
- **Notes:** Deduplication means two anime sharing the same `coverImage` path (e.g. from a merge)
  only pay the decode cost once.

### `const StatisticsShareEntry({required this.anime, required this.rank, this.score, this.statusLabel, this.progressLabel})` <a id="statisticsshareentry-new"></a>
- **Kind:** constructor of `StatisticsShareEntry`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 2130)
- **Purpose:** Hold one anime's rank plus optional score/status/progress labels for a statistics
  share image row.
- **Inputs:** `anime`, `rank`; optional `score`, `statusLabel`, `progressLabel`.
- **Returns:** A new `StatisticsShareEntry`.
- **Side effects:** None.
- **Algorithm:** Direct field assignment.
- **Usage:** Built by `lib/features/anime/views/statistics_page.dart` from the currently filtered/
  grouped anime list before calling
  [`generateStatisticsShareBytes`](#generatestatisticssharebytes).
- **Notes:** Unlike `RankingShareEntry`, `score` is nullable here — statistics rows may or may not
  have a rating, whereas ranking rows always have the sort field's score.

### `const StatisticsShareSummary({required this.tracked, required this.completed, required this.dropped})` <a id="statisticssharesummary-new"></a>
- **Kind:** constructor of `StatisticsShareSummary`
- **Source:** `lib/shared/services/share_service.dart` (approx. line 2150)
- **Purpose:** Hold the three counts drawn by the statistics share image's summary bar chart.
- **Inputs:** `tracked`, `completed`, `dropped`.
- **Returns:** A new `StatisticsShareSummary`.
- **Side effects:** None.
- **Algorithm:** Direct field assignment.
- **Usage:** Passed as the `summary` argument to
  [`generateStatisticsShareBytes`](#generatestatisticssharebytes) /
  [`shareStatisticsImage`](#sharestatisticsimage) when the user opts into the bar-chart image
  variant.
- **Notes:** None.
