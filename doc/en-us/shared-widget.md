# Shared Widget

## Ownership

MyApps-Widget v0.1.0 is embedded at `packages/myapps_widget` using the relative sibling URL
`../MyApps-Widget.git` (1.9.5). The app depends on
`packages/myapps_widget/packages/myapps_widget` (bridge, Android and iOS plugin) and
`packages/myapps_widget/packages/myapps_widget_ui` (preview surface, text-size control); both pull
in `myapps_widget_core`. Run `git submodule update --init --recursive` before `flutter pub get` in
a fresh checkout. The submodule is excluded from the app's `flutter analyze`; it has its own CI.

The shared package owns the envelope format, its tolerant readers (Dart, Kotlin, Swift), storage
keys, the method channel `com.yuanzhe.myapps_widget/bridge`, the debounce scheduler and the redraw
calls. The envelope is described in the package's own `doc/en-us/envelope.md`.

MyAnime keeps:

- `HomeWidgetService` as the facade, with its public members unchanged: `isSupported`, `init`,
  `notifyDataChanged`, `refresh`, `labelsFor`, `buildSnapshot`, `jstToUtc`, `clampTextScale` and
  the constants. It adds `kind` (`myanime.upNext`) and `appGroupId`.
- The payload (`timeZone`, `airedUnwatched`, `queueSize`, `episodes`, `labels`) and its version
  `pv` (`HomeWidgetService.formatVersion`).
- The native renderers: `UpNextWidgetProvider` and `UpNextStripWidgetProvider` (extending the
  shared `EnvelopeWidgetProvider`), `UpNextState`, the XML layouts and colors, and the
  `UpNextWidget` extension (`UpNextWidget.swift`).
- Wording, the `widgetTextScale` setting and the settings preview `HomeWidgetPreview`.

The license page names MyApps-Widget and its GPL v3 source.

## Behavior

Nothing the user sees changed in 1.9.5: same content, the same 2-second debounce, the same
refresh triggers and the same text-size range. What changed is the transport:

| Before 1.9.5 | Since 1.9.5 |
|---|---|
| `com.yuanzhe.my_anime/home_widget` channel in `MainActivity` and `AppDelegate` | `com.yuanzhe.myapps_widget/bridge`, registered by the plugin |
| Android `WidgetStore` redrew both providers itself | `EnvelopeStore.requestUpdate` broadcasts to the two providers by class name |
| iOS `reloadAllTimelines()` | `reloadTimelines(ofKind: "MyAnimeUpNextWidget")` |
| Flat snapshot under `myanime_widget_snapshot` | Envelope under `envelope.myanime.upNext` (Android) and `myapps_widget.envelope.myanime.upNext` (iOS) |

Both native readers fall back to the old flat snapshot while no envelope exists, so widgets placed
before the update keep their content until the app runs once. An envelope written by a newer
envelope format (`tooNew`) or one that does not parse draws the empty state.

## Verification

Run `flutter analyze` and `test/home_widget_service_test.dart` after facade changes; the test also
checks that `buildSnapshot` produces an envelope the shared reader accepts. The shared package's
own tests cover the contract fixtures in Dart, Kotlin and Swift. The app's CI builds are the first
compile of the Kotlin and Swift adoption; placing widgets and checking the fallback after an update
from 1.9.4 still need a device.
