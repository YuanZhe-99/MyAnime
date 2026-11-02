# lib/features/settings/widgets/home_widget_preview.dart

`HomeWidgetPreview` draws the two home-screen widgets inside Settings › Home-screen widgets (1.9.4,
Android and iOS only), so the *Widget text size* slider can be judged before looking at the home
screen. It builds a snapshot of the real library with
[`HomeWidgetService.buildSnapshot`](../../../shared/services/home_widget_service.md#buildsnapshot),
evaluates it the way the native widgets do, and draws a 2×2 card and a 2×1 strip with the Android
layout text sizes times the chosen scale, in the app's color scheme, on the shared
`WidgetPreviewSurface` from `myapps_widget_ui` (1.9.5). On Android each card lays out at the size the
launcher gives the first placed instance of that widget
([`HomeWidgetService.placedSizes`](../../../shared/services/home_widget_service.md#placedsizes)) and
scales down to fit the page; with none placed, and on iOS, it uses the default 172 × 172 and
172 × 76 sizes. It approximates the native widgets; it is not a pixel copy of either platform, and a
launcher that draws widgets scaled (some shrink the whole widget) still shows them smaller. See
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `HomeWidgetPreview({super.key, required this.textScale})` | constructor (`HomeWidgetPreview`) | B | Create the preview for a text scale. |
| `createState` | method (`HomeWidgetPreview`) | B | Create the state object. |
| [`_load`](#_load) | method (`_HomeWidgetPreviewState`) | A | Build the preview state and read the placed sizes once. |
| [`build`](#build) | method (`_HomeWidgetPreviewState`) | A | Lay out the two preview cards. |
| `HomeWidgetPreviewState(...)` | constructor (`HomeWidgetPreviewState`) | B | Hold one evaluated widget state. |
| [`HomeWidgetPreviewState.evaluate`](#evaluate) | factory constructor (`HomeWidgetPreviewState`) | A | Evaluate a fresh snapshot like the native widgets. |
| [`_airTime`](#_airtime) | top-level function | A | Format an air time like the native widgets. |
| `_SmallWidgetCard(...)` | constructor (`_SmallWidgetCard`) | B | Create the 2×2 preview at a size, with the placed minimum height. |
| [`_SmallWidgetCard.build`](#_smallwidgetcard-build) | method (`_SmallWidgetCard`) | A | Draw the 2×2 widget. |
| `_StripWidgetCard(...)` | constructor (`_StripWidgetCard`) | B | Create the 2×1 preview at a size. |
| [`_StripWidgetCard.build`](#_stripwidgetcard-build) | method (`_StripWidgetCard`) | A | Draw the 2×1 strip. |

## Documentation

### `Future<(HomeWidgetPreviewState, List<PlacedWidgetSize>)> _load()` <a id="_load"></a>
- **Kind:** method of `_HomeWidgetPreviewState`
- **Purpose:** Read the library and calendar time basis once, evaluate a snapshot built now, and
  read the placed widget sizes.
- **Inputs:** None.
- **Returns:** The evaluated state and every placed instance's `PlacedWidgetSize`.
- **Side effects:** Reads `anime_data.json` and `storage_config.json`; on Android asks the launcher
  for placed widget sizes.
- **Algorithm:** `AnimeStorage.load` → time basis → `buildSnapshot` with empty labels →
  [`evaluate`](#evaluate); then `HomeWidgetService.placedSizes`.
- **Usage:** Stored in a `late final` future, so moving the slider never reloads the library.
- **Notes:** Labels come from the widget tree's own `AppLocalizations` instead. Sizes are read once
  per Settings visit, so a widget resized meanwhile shows after reopening Settings.

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `_HomeWidgetPreviewState`
- **Purpose:** Show both cards in a centered `Wrap`.
- **Inputs:** `context`.
- **Returns:** The cards, or a `WidgetPreviewSurface.smallSide` (172-pixel) placeholder until
  `_load` completes.
- **Side effects:** None.
- **Algorithm:** `FutureBuilder` over `_load`; for each card, the first placed instance of its
  provider gives the size (`portrait` or `landscape` by the current orientation), otherwise the
  default; each card sits in a `FittedBox(scaleDown)` and gets `widget.textScale`.
- **Usage:** Settings page, below the slider.
- **Notes:** The cards wrap onto two rows on a narrow window; a card wider than the page shrinks as
  a whole, keeping its layout.

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
- **Returns:** A `WidgetPreviewSurface` of the given size.
- **Side effects:** None.
- **Algorithm:** Sizes from `widget_up_next.xml` (12/11/36 or 20/12/13/12 sp) times the scale.
  Queue rows: with a placed instance, two when its minimum height is 0 or at least 150 dp × scale,
  else one (as `UpNextWidgetProvider.render`); without one, two up to 120% and one above. With an
  empty queue, the next airing episode.
- **Usage:** [`build`](#build).
- **Notes:** Same content choices as `UpNextWidgetProvider.render`.

### `Widget _StripWidgetCard.build(BuildContext context)` <a id="_stripwidgetcard-build"></a>
- **Kind:** method of `_StripWidgetCard`
- **Purpose:** Draw the 2×1 strip: count tile and two lines.
- **Inputs:** `context`.
- **Returns:** A `WidgetPreviewSurface` of the given size.
- **Side effects:** None.
- **Algorithm:** Sizes from `widget_up_next_strip.xml` (18/14/12 sp) times the scale; lines as in
  `UpNextStripWidgetProvider.render`.
- **Usage:** [`build`](#build).
- **Notes:** None.
