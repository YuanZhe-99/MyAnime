# lib/shared/services/home_widget_service.dart

`HomeWidgetService` feeds the Android and iOS home-screen widgets. It builds a JSON snapshot of
the watch queue, today's episodes and the upcoming week, and hands it to the native side over the
`com.yuanzhe.my_anime/home_widget` method channel. See
[`../../../features/home-screen-widgets.md`](../../../features/home-screen-widgets.md) for the
widgets, the snapshot format and the native readers — this page covers the Dart declarations.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`HomeWidgetService._`](#homewidgetservice-_) | constructor (`HomeWidgetService`) | B | Prevent instantiation; the class is static-only. |
| [`isSupported`](#issupported) | getter (`HomeWidgetService`) | B | Whether the platform has home-screen widgets (Android, iOS). |
| [`clampTextScale`](#clamptextscale) | method (`HomeWidgetService`) | A | Clamp a widget text scale to the supported range (1.9.4). |
| [`init`](#init) | method (`HomeWidgetService`) | A | Subscribe to sync/restore reloads and push the first snapshot. |
| [`notifyDataChanged`](#notifydatachanged) | method (`HomeWidgetService`) | A | Debounce a refresh after data or settings change. |
| [`refresh`](#refresh) | method (`HomeWidgetService`) | A | Rebuild the snapshot from storage and send it to the native widgets. |
| [`labelsFor`](#labelsfor) | method (`HomeWidgetService`) | A | Collect the localized widget strings. |
| [`buildSnapshot`](#buildsnapshot) | method (`HomeWidgetService`) | A | Build the snapshot map for a library at an instant. |
| [`jstToUtc`](#jsttoutc) | method (`HomeWidgetService`) | A | Convert an anime-model Japan wall-clock time to a UTC instant. |
| [`_startOfToday`](#_startoftoday) | method (`HomeWidgetService`) | A | The UTC instant at which "today" starts for a calendar time basis. |
| [`_l10n`](#_l10n) | method (`HomeWidgetService`) | B | Resolve localizations from the saved locale or the platform default. |

Constants: `formatVersion` (1), `lookahead` (8 days), `maxEpisodes` (80), `minTextScale` (0.9) and
`maxTextScale` (1.5), and the private `_channel`.

## Documentation

### `static double clampTextScale(double scale)` <a id="clamptextscale"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Keep a widget text scale within `minTextScale`..`maxTextScale`.
- **Inputs:** `scale`.
- **Returns:** The clamped scale rounded to one decimal; `1.0` for NaN or infinity.
- **Side effects:** None.
- **Algorithm:** `clamp`, then `round(scale * 10) / 10`.
- **Usage:** `AppSettingsNotifier` (load and setter), [`refresh`](#refresh), [`buildSnapshot`](#buildsnapshot).
- **Notes:** Added in 1.9.4. Rounding keeps the slider's 0.1 steps exact. The native readers clamp
  to the same range again.

### `static Future<void> init()` <a id="init"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** One-time startup: register [`notifyDataChanged`](#notifydatachanged) as an
  `AutoSyncService` local-data-changed callback and push the first snapshot.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Adds a sync callback; starts [`refresh`](#refresh) without awaiting it.
- **Algorithm:** Returns at once when [`isSupported`](#issupported) is false.
- **Usage:** Called from `main()` after the reminder service starts.
- **Notes:** The callback covers sync downloads and backup restores, which call
  `notifyLocalDataChangedNow()`.

### `static void notifyDataChanged()` <a id="notifydatachanged"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Schedule a refresh 2 seconds after the last change.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels and restarts a `Timer` that calls [`refresh`](#refresh).
- **Algorithm:** No-op on unsupported platforms.
- **Usage:** `AnimeStorage._writeData`, the `AutoSyncService` resume hook and local-data-changed
  callback, and `AppSettingsNotifier.setLocale` / `setHomeCalendarTimeBasis` / `setWidgetTextScale`.
- **Notes:** Debouncing collapses bursts such as a sync applying many records.

### `static Future<void> refresh()` <a id="refresh"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Rebuild the snapshot and redraw the widgets.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `anime_data.json` (`AnimeStorage.load`) and the `homeCalendarTimeBasis`,
  `widgetTextScale` and locale keys of `storage_config.json`; invokes `update` on the channel, which stores the JSON
  natively and redraws every placed widget.
- **Algorithm:** Load → resolve the time basis (`'local'` or JST) → resolve localizations →
  [`buildSnapshot`](#buildsnapshot) with `DateTime.now().toUtc()`, [`labelsFor`](#labelsfor) and the
  stored text scale →
  `jsonEncode` → `invokeMethod('update', {'snapshot': json})`.
- **Usage:** Through [`notifyDataChanged`](#notifydatachanged) and [`init`](#init).
- **Notes:** Every failure is logged and swallowed; a stale widget is harmless.

### `static Map<String, String> labelsFor(AppLocalizations l10n)` <a id="labelsfor"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Collect the widget wording from the ARB strings.
- **Inputs:** `l10n`.
- **Returns:** Keys `appName`, `toWatch`, `today`, `caughtUp`, `noUpdates`, `next`, `episode`,
  `series`.
- **Side effects:** None.
- **Algorithm:** `widgetEpisode` and `widgetSeriesCount` are called with the literal `{n}`, which
  the native side replaces with a number.
- **Usage:** [`refresh`](#refresh).
- **Notes:** `appName` is always `MyAnime`.

### `static Map<String, dynamic> buildSnapshot(List<Anime> animeList, {required DateTime nowUtc, required HomeCalendarTimeBasis basis, required Map<String, String> labels, double textScale = 1.0})` <a id="buildsnapshot"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Build the version-1 snapshot.
- **Inputs:** `animeList`; `nowUtc`; `basis` — which calendar day counts as today; `labels`;
  `textScale` — the widget text size multiplier (1.9.4).
- **Returns:** A JSON-ready map with `v`, `generatedAt`, `timeZone`, `airedUnwatched`,
  `queueSize`, `episodes`, `labels` and `textScale` (clamped).
- **Side effects:** None.
- **Algorithm:** For every anime, walk `startEpisode..(endEpisode ?? startEpisode)` like the Home
  tab. For each episode with an air time, convert it with [`jstToUtc`](#jsttoutc); count it in
  `airedUnwatched` when unwatched and aired; make the first such episode the anime's queue entry;
  otherwise keep it when it airs between [`_startOfToday`](#_startoftoday) and `now + lookahead`.
  Sort both lists by air time, keep queue entries first up to `maxEpisodes`, then sort the result
  by air time. `w` is true for any status other than unwatched.
- **Usage:** [`refresh`](#refresh); the settings preview (`HomeWidgetPreview`);
  `test/home_widget_service_test.dart`.
- **Notes:** The native recount (`toWatch = airedUnwatched + newly aired unwatched entries`)
  relies on every episode after `generatedAt` up to the lookahead being present.

### `static DateTime jstToUtc(DateTime jst)` <a id="jsttoutc"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Turn a `getEpisodeAirDate` value (Japan wall clock) into a UTC instant.
- **Inputs:** `jst`, whatever its `isUtc` flag.
- **Returns:** `DateTime` in UTC.
- **Side effects:** None.
- **Algorithm:** `DateTime.utc(y, m, d, h - 9, min, s)`.
- **Usage:** [`buildSnapshot`](#buildsnapshot).
- **Notes:** Same arithmetic as `JstTime.toLocal`, without the final local conversion.

### `static DateTime _startOfToday(DateTime nowUtc, HomeCalendarTimeBasis basis)` <a id="_startoftoday"></a>
- **Kind:** static method of `HomeWidgetService`
- **Source:** `lib/shared/services/home_widget_service.dart`
- **Purpose:** Return when "today" began, as a UTC instant.
- **Inputs:** `nowUtc`, `basis`.
- **Returns:** JST midnight for the JST basis, device-local midnight otherwise.
- **Side effects:** None.
- **Algorithm:** JST: shift by +9 h, take the date, build it in UTC, shift back 9 h. Local: take
  the local date and convert to UTC.
- **Usage:** [`buildSnapshot`](#buildsnapshot).
- **Notes:** None.

### Tier B entries

- `HomeWidgetService._` <a id="homewidgetservice-_"></a> — private constructor; static-only class.
- `isSupported` <a id="issupported"></a> — `!kIsWeb && (Android || iOS)`; every public entry point
  returns early otherwise.
- `_l10n` <a id="_l10n"></a> — the reminder service's locale resolution, falling back to English
  if the lookup throws.
