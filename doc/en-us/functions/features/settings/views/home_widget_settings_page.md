# lib/features/settings/views/home_widget_settings_page.dart

`HomeWidgetSettingsPage` (1.9.7) is the second-level page behind the single *Home-screen widgets*
row on the first Settings level (Android and iOS only; see [`settings_page.md`](settings_page.md)).
It is pushed full screen on a narrow window and hosted in the Settings detail pane on a wide one
(`_SettingsDetail.widgets`). The page holds one `MyAppsSettingsSection` per widget — *Large widget*
(`settingsWidgetLarge`) and *Strip widget* (`settingsWidgetStrip`) — and each section has the shared
`WidgetTextScaleControl` from `myapps_widget_ui` (*Widget text size* with its description) and a
[`HomeWidgetPreview`](../widgets/home_widget_preview.md) of that one widget. The large section is
bound to `AppSettings.widgetTextScale` / `setWidgetTextScale`, the strip section to
`AppSettings.widgetStripTextScale` / `setWidgetStripTextScale` (see
[`../../../shared/providers/app_settings.md`](../../../shared/providers/app_settings.md)). Before
1.9.7 a single slider on the first Settings level scaled both widgets. See
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `HomeWidgetSettingsPage({super.key})` | constructor (`HomeWidgetSettingsPage`) | B | Create the widget settings page. |
| `createState` | method (widget lifecycle) | B | Create the mutable state object for this widget. |
| [`build`](#build) | method (`_HomeWidgetSettingsPageState`) | A | Build the large widget and strip sections. |

The `_data` field carries no `/// Purpose:` comment and is not a row.

## Documentation

### `Widget build(BuildContext context)` <a id="build"></a>
- **Kind:** method of `_HomeWidgetSettingsPageState`
- **Source:** `lib/features/settings/views/home_widget_settings_page.dart` (approx. line 45)
- **Purpose:** Build the page: a `Scaffold` titled `settingsWidgets` with the large widget and strip
  sections.
- **Inputs:** `context`.
- **Returns:** `Widget` — a `Scaffold` whose body is a `ListView` (24 dp bottom padding) of two
  `MyAppsSettingsSection`s.
- **Side effects:** None while building; the sliders persist their scale and schedule a widget
  refresh through `AppSettingsNotifier`.
- **Algorithm:** Watches `appSettingsProvider`. A local `section(title, kind, scale, onChanged)`
  builds one `MyAppsSettingsSection` holding a `WidgetTextScaleControl` (`settingsWidgetTextSize`,
  `settingsWidgetTextSizeDesc`) and, padded `16, 4, 16, 16`, a
  `HomeWidgetPreview(data: _data, kind: kind, textScale: scale)`. It is called for
  `HomeWidgetPreviewKind.large` with `widgetTextScale` / `setWidgetTextScale` and for
  `HomeWidgetPreviewKind.strip` with `widgetStripTextScale` / `setWidgetStripTextScale`.
- **Usage:** `_SettingsPageState._detailPage(_SettingsDetail.widgets)` in
  [`settings_page.md`](settings_page.md#detailpage).
- **Notes:** `_data` is a `late final` future from `HomeWidgetPreview.load()`, so the library and
  the placed sizes are read once per visit and shared by both previews; moving a slider redraws only
  its own preview and never reloads the library.
