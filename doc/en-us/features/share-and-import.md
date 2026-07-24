# Share and File Import

`share_service.dart` and `file_open_service.dart` cover the app's outbound (share/export) and
inbound (file open/import) flows. See [`../data-formats.md`](../data-formats.md) for the
`.myanimeitem` JSON format itself and [`duplicate-detection.md`](duplicate-detection.md) for the
conflict-resolution logic reused during import.

## `share_service.dart`

Supports sharing an anime as an image card, exporting/sharing the current statistics ranking as an
image, and exporting/sharing the current statistics summary view as an image or data file.

- The share flow first asks whether to share as an **image**, a **data file**, or a **TXT** name
  list.
- **Image cards** include cover art, titles, season/type/schedule, broadcast progress, notes,
  selected info/watch URLs as QR codes, the app logo, and the MyAnime!!!!! watermark.
- **Ranking image exports** include the current ranking filters, sort/order, ranked anime rows
  with cover thumbnails and scores, the app logo, and the watermark. Ranking export is image-only
  — it does not create `.myanimeitem` data files. When more than 50 ranking rows would be
  rendered, the user is warned that generation may take time and may set a row limit; limited
  ranking exports keep the current ranking order and take the first N rows.
- **Statistics summary image exports** include a horizontal bar chart at the top showing tracked,
  completed, and dropped counts, followed by anime rows with cover thumbnails, status labels,
  progress, and optional scores. Before generation, the user can choose which derived statuses to
  include (completed, watching, dropped, not-started — all selected by default), and the bar chart
  reflects the final rendered rows. When more than 50 summary rows would be rendered, the user is
  warned and may set a row limit with first-air-date recent/oldest priority; image generation
  shows a progress dialog while covers load.
- **Multi-page splitting:** statistics and ranking image exports are split across multiple PNG
  pages when the single-page pixel height would exceed the platform texture dimension cap
  (`_maxImageDimension = 16000` in `share_service.dart`), so tall lists (e.g. 200+ anime) are no
  longer cut off at the right/bottom edges. Each page repeats the header (the summary bar chart
  appears on page 1 only); the watermark appears only on the final page. Multi-page sharing uses:
  - Android `ACTION_SEND_MULTIPLE` via the `shareFiles` `MethodChannel`.
  - iOS multi-file `Share.shareXFiles`.
  - A desktop scrollable multi-page preview with a save-all action.
- **Statistics data file exports** create a `.myanimeitem` multi-anime bundle (v2 format —
  [`../data-formats.md`](../data-formats.md)) containing the visible anime list, with personal
  viewing data stripped.
- **Statistics TXT exports** write one anime display name per line, sorted in dictionary order,
  with no personal viewing data. Available from the same statistics share dialog as image and
  data-file exports.
- **Android** uses a custom `MethodChannel` named `com.yuanzhe.my_anime/share` and
  `FLAG_ACTIVITY_NEW_TASK`, so share targets open outside the MyAnime task stack.
- **iOS** uses the system share sheet.
- **Desktop** shows a preview dialog and can copy or save the generated image.

## `file_open_service.dart`

Supports `.myanimeitem` export/import for both single-anime (v1) and multi-anime bundle (v2)
formats — see [`../data-formats.md`](../data-formats.md) for the exact JSON shape of each version.

- Export strips personal viewing data (`episodeStatuses`, `episodeWeekOffsets`) from every
  exported record.
- Import always creates a new UUID for the incoming record and never overwrites an existing anime.
- Multi-anime bundle imports detect conflicts with existing local records (reusing
  [`duplicate-detection.md`](duplicate-detection.md)'s grouping logic) and show a per-conflict
  dialog offering keep-local, use-imported, or merge.
- Platform file association is configured on Android, iOS, macOS, and Windows — see
  [`../platform-notes.md`](../platform-notes.md) for the exact per-platform registration details
  (Windows registration in particular lives in `installer.iss`).
