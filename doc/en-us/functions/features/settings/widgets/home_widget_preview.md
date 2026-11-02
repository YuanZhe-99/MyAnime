# lib/features/settings/widgets/home_widget_preview.dart

`HomeWidgetPreview` draws one home-screen widget on the widget settings page (1.9.4, Android and
iOS only; one widget per preview since 1.9.7, see
[`../views/home_widget_settings_page.md`](../views/home_widget_settings_page.md)), so that widget's
*Widget text size* slider can be judged before looking at the home screen. Since 1.9.7 it is a
`StatelessWidget`: `HomeWidgetPreviewKind` (`large`, `strip`) picks the widget, and the page calls
the static `load()` once and passes the same `Future<HomeWidgetPreviewData>` (a typedef for the
record of `HomeWidgetPreviewState` and the placed sizes) to both previews. It builds a snapshot of
the real library with
[`HomeWidgetService.buildSnapshot`](../../../shared/services/home_widget_service.md#buildsnapshot),
evaluates it the way the native widgets do, and draws the large card or the strip with the Android
layout text sizes times the chosen scale, in the app's color scheme, on the shared
`WidgetPreviewSurface` from `myapps_widget_ui` (1.9.5). On Android the card lays out at the size the
launcher gives the first placed instance of that widget
([`HomeWidgetService.placedSizes`](../../../shared/services/home_widget_service.md#placedsizes));
with none placed, and on iOS, it uses [`defaultSize`](#defaultsize): 3×2 cells for the large widget
and 3×1 for the strip, where `cell` is 86 dp (half of `WidgetPreviewSurface.smallSide`) and the strip
keeps `WidgetPreviewSurface.stripHeight` (76). The card is then drawn at `displayScale` (0.75) and
shrinks further only to fit the page. It approximates the native widgets; it is not a pixel copy of
either platform, and a launcher that draws widgets scaled (some shrink the whole widget) still shows
them smaller. See
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `HomeWidgetPreview({super.key, required this.data, required this.kind, required this.textScale})` | constructor (`HomeWidgetPreview`) | B | Create the preview of one widget from shared data at a text scale. |
| [`defaultSize`](#defaultsize) | static method (`HomeWidgetPreview`) | A | Return the size used when no instance is placed. |
| [`load`](#load) | static method (`HomeWidgetPreview`) | A | Build the preview state and read the placed sizes. |
| [`build`](#build) | method (`HomeWidgetPreview`) | A | Lay out the one preview card. |
| `HomeWidgetPreviewState(...)` | constructor (`HomeWidgetPreviewState`) | B | Hold one evaluated widget state. |
| [`HomeWidgetPreviewState.evaluate`](#evaluate) | factory constructor (`HomeWidgetPreviewState`) | A | Evaluate a fresh snapshot like the native widgets. |
| [`_airTime`](#_airtime) | top-level function | A | Format an air time like the native widgets. |
| `_SmallWidgetCard(...)` | constructor (`_SmallWidgetCard`) | B | Create the large widget preview at a size, with the placed minimum height. |
| [`_SmallWidgetCard.build`](#_smallwidgetcard-build) | method (`_SmallWidgetCard`) | A | Draw the large widget. |
| `_StripWidgetCard(...)` | constructor (`_StripWidgetCard`) | B | Create the strip preview at a size. |
| [`_StripWidgetCard.build`](#_stripwidgetcard-build) | method (`_StripWidgetCard`) | A | Draw the strip. |

The `HomeWidgetPreviewKind` enum, the `HomeWidgetPreviewData` typedef, the `data`, `kind` and
`textScale` fields and the `cell` and `displayScale` constants carry no `/// Purpose:` comment and
are not rows. `createState` and `_HomeWidgetPreviewState` were removed in 1.9.7.

## Documentation

### `static Size defaultSize(HomeWidgetPreviewKind kind)` <a id="defaultsize"></a>
- **Kind:** static method of `HomeWidgetPreview`
- **Purpose:** Return the size a preview uses when no instance of its widget is placed.
- **Inputs:** `kind`.
- **Returns:** `Size(3 × cell, 2 × cell)` (258 × 172 dp) for `large`; `Size(3 × cell,
  WidgetPreviewSurface.stripHeight)` (258 × 76 dp) for `strip`.
- **Side effects:** None.
- **Algorithm:** A `switch` on `kind`.
- **Usage:** [`build`](#build), for the size and for the loading placeholder's height.
- **Notes:** The strip keeps the shared strip height rather than a full cell. Before 1.9.7 the
  defaults were 172 × 172 and 172 × 76.

### `static Future<HomeWidgetPreviewData> load()` <a id="load"></a>
- **Kind:** static method of `HomeWidgetPreview`
- **Purpose:** Read the library and calendar time basis, evaluate a snapshot built now, and read
  the placed widget sizes.
- **Inputs:** None.
- **Returns:** The evaluated state and every placed instance's `PlacedWidgetSize`.
- **Side effects:** Reads `anime_data.json` and `storage_config.json`; on Android asks the launcher
  for placed widget sizes.
- **Algorithm:** `AnimeStorage.load` → time basis → `buildSnapshot` with empty labels →
  [`evaluate`](#evaluate); then `HomeWidgetService.placedSizes`.
- **Usage:** `HomeWidgetSettingsPage` stores it in a `late final` future and passes it to both
  previews, so moving a slider never reloads the library.
- **Notes:** Labels come from the widget tree's own `AppLocalizations` instead. Sizes are read once
  per visit, so a widget resized meanwhile shows after reopening the page. Was the private
  `_load` of the state class until 1.9.6.

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `HomeWidgetPreview`
- **Purpose:** Show the card for `kind`, centered.
- **Inputs:** `context`.
- **Returns:** The card, or a placeholder of `defaultSize(kind).height × displayScale` until `data`
  completes.
- **Side effects:** None.
- **Algorithm:** `FutureBuilder` over `data`; the provider for `kind`
  (`HomeWidgetService.smallProvider` or `stripProvider`) picks the first placed instance, whose
  `portrait` or `landscape` size (by the current orientation) is used, otherwise
  [`defaultSize`](#defaultsize). The card (`_SmallWidgetCard` with the instance's `minHeight`, or
  `_StripWidgetCard`) gets `textScale` and is fitted into a box of `size × displayScale`, inside a
  `FittedBox(scaleDown)` in a `Center`.
- **Usage:** `HomeWidgetSettingsPage`, below each slider.
- **Notes:** With several placed instances of the widget, the first one is shown. A card wider than
  the page shrinks as a whole, keeping its layout. Until 1.9.6 one stateful preview drew both cards
  in a `Wrap` at full size.

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
- **Usage:** [`load`](#load); `test/home_widget_service_test.dart`.
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
- **Purpose:** Draw the large widget: header with today pill, count or *All caught up*, label, rows.
- **Inputs:** `context`.
- **Returns:** A `WidgetPreviewSurface` of the given size.
- **Side effects:** None.
- **Algorithm:** Sizes from `widget_up_next.xml` (12/11/36 or 20/12/13/12 sp) times the scale.
  Queue rows: with `h` = the placed instance's minimum height, or the card's height when none is
  placed, two when `h` is 0 or at least 150 dp × scale, else one (as `UpNextWidgetProvider.render`).
  With an empty queue, the next airing episode.
- **Usage:** [`build`](#build).
- **Notes:** Same content choices as `UpNextWidgetProvider.render`. Until 1.9.6, without a placed
  instance it showed two rows up to 120% and one above.

### `Widget _StripWidgetCard.build(BuildContext context)` <a id="_stripwidgetcard-build"></a>
- **Kind:** method of `_StripWidgetCard`
- **Purpose:** Draw the strip: count tile and two lines.
- **Inputs:** `context`.
- **Returns:** A `WidgetPreviewSurface` of the given size.
- **Side effects:** None.
- **Algorithm:** Sizes from `widget_up_next_strip.xml` (18/14/12 sp) times the scale; lines as in
  `UpNextStripWidgetProvider.render`.
- **Usage:** [`build`](#build).
- **Notes:** None.
