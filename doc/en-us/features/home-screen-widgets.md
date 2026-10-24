# Home-Screen Widgets

Two "Up next" widgets put the Home tab's two questions on the home screen — *what aired today* and
*what is still left to watch* — without opening the app. They exist on Android and iOS only; the
desktop builds have no widget surface.

| Size | Android | iOS |
|---|---|---|
| 2×2 | `UpNextWidgetProvider` (home screen, 2 × 2 cells, resizable) | `systemSmall` home-screen widget |
| 2×1 strip | `UpNextStripWidgetProvider` (home screen, 2 × 1 cells, resizable) | `accessoryRectangular` lock-screen / StandBy widget (iOS 16+) |

iOS has no 2×1 home-screen size, so the compact strip maps to the rectangular lock-screen widget,
which is the same shape and density.

## What they show

Counts follow the Home tab's definitions exactly (see
[`home-management-statistics.md`](home-management-statistics.md)): an episode is **to watch** when
its status is unwatched and its air time (Japan time, blank air time = 23:59 JST) has passed.

**2×2**

- Header: the app mark and name, and a pill with **today's update count** — every episode whose air
  date is today, watched or not.
- A large **to-watch episode count**, with the number of series behind it.
- Up to two rows of the **watch queue**: per anime, its earliest unwatched aired episode, oldest air
  time first — the same rows as the Home tab's *Unwatched* list. Android shows the second row only
  when the widget is at least 150 dp tall.
- When nothing is left to watch, the count becomes *All caught up* and the row shows the next
  airing episode with its time (today: `HH:mm`; later: weekday + `HH:mm`).

**2×1 strip**

- A tonal tile with the to-watch count (a check mark when it is zero).
- The first queued title, and its episode plus today's update count; when caught up, the next
  airing episode or *Nothing airs today*.

Tapping either widget opens the app.

"Today" uses the Home calendar's time basis: Japan time by default, the device's local day when
**Settings › Home Calendar Time › Local Time** is chosen. Displayed air times use the same zone.

## Design

Both platforms use their current system idiom rather than a shared drawing:

- **Android** — RemoteViews layouts with Material 3 shapes: the launcher's own widget corner
  radius (`system_app_widget_background_radius`) and wallpaper-derived **Material You** colors
  (`system_accent1/2`, `system_neutral1/2`) on Android 12+, falling back to Material 3 tones of the
  app seed `#673AB7` on Android 8–11. Light and dark palettes follow the system theme. Widget-picker
  previews use the layouts themselves (`previewLayout`), and `targetCellWidth/Height` give the
  Android 12+ default cell sizes.
- **iOS** — SwiftUI WidgetKit views: a rounded-design count, an SF Symbol mark, a soft brand
  gradient over the system background, `containerBackground` on iOS 17+, and `widgetAccentable`
  parts so tinted home screens and the lock screen render correctly.

## Data flow

The widgets never read the library. The app computes a small snapshot and hands it to the native
side, which stores it and redraws:

1. `HomeWidgetService.refresh()` (`lib/shared/services/home_widget_service.dart`) loads
   `anime_data.json`, the calendar time basis and the UI language, and builds the snapshot.
2. It sends the JSON over the `com.yuanzhe.my_anime/home_widget` method channel (`update`).
3. Android (`MainActivity` → `WidgetStore.push`) writes it to the private `MyAnimeWidget` shared
   preferences and redraws every placed instance. iOS (`AppDelegate`) writes it to the
   `group.com.yuanzhe.myAnime` App Group `UserDefaults` and calls
   `WidgetCenter.reloadAllTimelines()`.

`HomeWidgetService.notifyDataChanged()` schedules a refresh 2 seconds after the last of:

- any library save (`AnimeStorage._writeData`),
- a sync download or backup restore (the `AutoSyncService` local-data-changed callback),
- the app resuming,
- a change of UI language or calendar time basis.

### Staying correct while the app is closed

The snapshot carries upcoming episodes, not just totals, so the native side can recount at any
moment within an 8-day lookahead:

```text
toWatch = airedUnwatched + count(entries where !w and generatedAt < at <= now)
queue   = per anime, the earliest entry with !w and at <= now, by air time
today   = entries whose air date (in the snapshot's zone) is today
nextUp  = the earliest entry with !w and at > now
```

- **Android** recomputes on every redraw; the system redraws at least every 30 minutes
  (`updatePeriodMillis`).
- **iOS** builds a timeline with an entry at every air time in the next 24 hours plus the next
  midnight, and asks for a new timeline after the last entry (at least one hour out).

### Snapshot format (version 1)

```json
{
  "v": 1,
  "generatedAt": 1769605200000,
  "timeZone": "Asia/Tokyo",
  "airedUnwatched": 2,
  "queueSize": 1,
  "episodes": [
    { "id": "…", "t": "Title", "e": 3, "at": 1768568400000, "w": false }
  ],
  "labels": {
    "appName": "MyAnime", "toWatch": "…", "today": "…", "caughtUp": "…",
    "noUpdates": "…", "next": "…", "episode": "EP {n}", "series": "{n} series"
  }
}
```

- `generatedAt`, `at` — epoch milliseconds (UTC instants).
- `timeZone` — `Asia/Tokyo` for the JST calendar, empty for the device zone.
- `airedUnwatched` — the to-watch count at `generatedAt`.
- `episodes` — per anime its earliest unwatched aired episode (the queue entry), plus every episode
  from the start of today to 8 days ahead; at most 80 entries, queue entries first. `w` is true for
  watched or skipped episodes.
- `labels` — the widget wording, resolved from the ARB files in the app's language; `{n}` is
  replaced natively. Only the widget-picker name and description live in native resources
  (`res/values*/widget_strings.xml` on Android, `galleryText` in the Swift file on iOS).

The format is private to the app and its own widgets: it is device-local, never synced, never
backed up and never shared. Changing it means bumping `v` together with both native readers.

## Platform setup

- **Android** — two `<receiver>` entries in `AndroidManifest.xml`; the Kotlin lives in
  `android/app/src/main/kotlin/com/yuanzhe/my_anime/widget/`. No extra Gradle dependency.
- **iOS** — the `UpNextWidget` app-extension target (`ios/UpNextWidget/`, deployment target iOS 14)
  is embedded in Runner. Runner and the extension both carry the
  `group.com.yuanzhe.myAnime` App Group entitlement, which must be enabled on both App IDs before a
  signed build. Runner (iOS 13) weak-links WidgetKit. See
  [`../platform-notes.md`](../platform-notes.md#ios).

## Privacy

The widgets show anime titles, which become visible on the home screen and — for the iOS
rectangular widget — on the lock screen. Nothing appears until the user adds a widget, and removing
it stops the display; the snapshot itself never leaves the device.
