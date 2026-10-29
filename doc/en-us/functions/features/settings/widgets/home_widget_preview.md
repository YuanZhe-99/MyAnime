# lib/features/settings/widgets/home_widget_preview.dart

`HomeWidgetPreview` draws the two home-screen widgets inside Settings › Home-screen widgets (1.9.4,
Android and iOS only), so the *Widget text size* slider can be judged before looking at the home
screen. It builds a snapshot of the real library with
[`HomeWidgetService.buildSnapshot`](../../../shared/services/home_widget_service.md#buildsnapshot),
evaluates it the way the native widgets do, and draws a 2×2 card and a 2×1 strip with the Android
layout text sizes times the chosen scale, in the app's color scheme, on the shared
`WidgetPreviewSurface` from `myapps_widget_ui` (1.9.5). It approximates the native widgets; it is
not a pixel copy of either platform. See
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `HomeWidgetPreview({super.key, required this.textScale})` | constructor (`HomeWidgetPreview`) | B | Create the preview for a text scale. |
| `createState` | method (`HomeWidgetPreview`) | B | Create the state object. |
| [`_load`](#_load) | method (`_HomeWidgetPreviewState`) | A | Build the preview state from the stored library once. |
| [`build`](#build) | method (`_HomeWidgetPreviewState`) | A | Lay out the two preview cards. |
| `HomeWidgetPreviewState(...)` | constructor (`HomeWidgetPreviewState`) | B | Hold one evaluated widget state. |
| [`HomeWidgetPreviewState.evaluate`](#evaluate) | factory constructor (`HomeWidgetPreviewState`) | A | Evaluate a fresh snapshot like the native widgets. |
| [`_airTime`](#_airtime) | top-level function | A | Format an air time like the native widgets. |
| `_SmallWidgetCard(...)` | constructor (`_SmallWidgetCard`) | B | Create the 2×2 preview. |
| [`_SmallWidgetCard.build`](#_smallwidgetcard-build) | method (`_SmallWidgetCard`) | A | Draw the 2×2 widget. |
| `_StripWidgetCard(...)` | constructor (`_StripWidgetCard`) | B | Create the 2×1 preview. |
| [`_StripWidgetCard.build`](#_stripwidgetcard-build) | method (`_StripWidgetCard`) | A | Draw the 2×1 strip. |

## Documentation

### `Future<HomeWidgetPreviewState> _load()` <a id="_load"></a>
- **Kind:** method of `_HomeWidgetPreviewState`
- **Purpose:** Read the library and calendar time basis once and evaluate a snapshot built now.
- **Inputs:** None.
- **Returns:** `Future<HomeWidgetPreviewState>`.
- **Side effects:** Reads `anime_data.json` and `storage_config.json`.
- **Algorithm:** `AnimeStorage.load` → time basis → `buildSnapshot` with empty labels →
  [`evaluate`](#evaluate).
- **Usage:** Stored in a `late final` future, so moving the slider never reloads the library.
- **Notes:** Labels come from the widget tree's own `AppLocalizations` instead.

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `_HomeWidgetPreviewState`
- **Purpose:** Show both cards in a centered `Wrap`.
- **Inputs:** `context`.
- **Returns:** The cards, or a `WidgetPreviewSurface.smallSide` (172-pixel) placeholder until
  `_load` completes.
- **Side effects:** None.
- **Algorithm:** `FutureBuilder` over `_load`; passes `widget.textScale` to both cards.
- **Usage:** Settings page, below the slider.
- **Notes:** The cards wrap onto two rows on a narrow window.

### `factory HomeWidgetPreviewState.evaluate(Map<String, dynamic> snapshot, DateTime nowUtc)` <a id="evaluate"></a>
- **Kind:** factory constructor of `HomeWidgetPreviewState`
- **Purpose:** Mirror the native `UpNextState` evaluation for a snapshot built at `nowUtc`.
- **Inputs:** `snapshot` — the envelope map from `buildSnapshot`; `nowUtc`.
- **Returns:** `toWatch`, `queue`, `todayCount`, `nextUp`.
- **Side effects:** None.
- **Algorithm:** Reads the envelope's `payload`. `toWatch = airedUnwatched` (nothing aired after
  `generatedAt`); `queue` = the first
  unwatched aired entry per anime; `todayCount` = entries whose date in the snapshot zone (JST, or
  the device zone) is today; `nextUp` = the first unwatched entry after now.
- **Usage:** [`_load`](#_load); `test/home_widget_service_test.dart`.
- **Notes:** Public so the test can check it against the native formula.

### `String _airTime(BuildContext context, int ms)` <a id="_airtime"></a>
- **Kind:** top-level function
- **Purpose:** Format `HH:mm` (24-hour), prefixed by a narrow weekday when not today.
- **Inputs:** `context`, `ms` epoch milliseconds.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** `MaterialLocalizations.formatTimeOfDay` and `narrowWeekdays`.
- **Usage:** Both card `build` methods.
- **Notes:** Uses device-local time, which is close enough for a preview.

### `Widget _SmallWidgetCard.build(BuildContext context)` <a id="_smallwidgetcard-build"></a>
- **Kind:** method of `_SmallWidgetCard`
- **Purpose:** Draw the 2×2 widget: header with today pill, count or *All caught up*, label, rows.
- **Inputs:** `context`.
- **Returns:** A 172 × 172 `WidgetPreviewSurface`.
- **Side effects:** None.
- **Algorithm:** Sizes from `widget_up_next.xml` (12/11/36 or 20/12/13/12 sp) times the scale; two
  queue rows up to 120%, one above; with an empty queue, the next airing episode.
- **Usage:** [`build`](#build).
- **Notes:** Same content choices as `UpNextWidgetProvider.render`.

### `Widget _StripWidgetCard.build(BuildContext context)` <a id="_stripwidgetcard-build"></a>
- **Kind:** method of `_StripWidgetCard`
- **Purpose:** Draw the 2×1 strip: count tile and two lines.
- **Inputs:** `context`.
- **Returns:** A 172 × 76 `WidgetPreviewSurface`.
- **Side effects:** None.
- **Algorithm:** Sizes from `widget_up_next_strip.xml` (18/14/12 sp) times the scale; lines as in
  `UpNextStripWidgetProvider.render`.
- **Usage:** [`build`](#build).
- **Notes:** None.
