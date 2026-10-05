# Shared UI foundations

MyApps-UI v0.1.6 owns appearance/navigation row layout, full-width choices and
scaled-text fallback. MyApps-DATA v1.0.4 owns common data actions and backup
preferences; MyApps-AI v0.4.2 owns AI presentation. Values, labels and callbacks
remain application-owned.

## P5 region policies and attribution

MyApps-UI v0.1.5 provides automatic and selected column resolution and designed
pane layouts. Existing list preferences remain app-owned and capacity-clamped.
Settings uses MyAppsPaneBody to avoid separating features while retaining the
window split gate and primary-width policy. LicensePage explicitly names all three
consumed packages, source URL and GNU GPL v3. Other page designs remain app-owned.

## Settings and common catalogs

The app pins MyApps-UI v0.1.4. Settings sections and segmented controls delegate
to shared widgets; callbacks still use AppSettingsNotifier. Common appearance and
navigation ARB values are maintained in the library and checked by shared_l10n_test.
App-specific strings, localization delegates, routes and persistence remain here.
The extraction is complete; library concept docs replace the completed roadmap.

MyApps-UI `v0.1.2` is embedded at `packages/myapps_ui`, with relative URL
`../MyApps-UI.git`. Initialize submodules recursively after cloning.

`lib/app/theme.dart` delegates to `myapps_ui` while retaining the existing API
and purple `0xFF673AB7` seed. Shared enums preserve stored names and defaults.
Android-only dynamic color remains controlled by the application root.

`lib/shared/utils/adaptive_layout.dart` re-exports the common thresholds and
`canSplitLayout`, `useNavigationRail`, `columnCapacity`, `listRowCount` from
`myapps_adaptive`. Anime tiles, ranking controls, statistics panes and episode
constraints stay app-owned.
## Updating

Publish the library to both remotes first, pin its tagged commit, then validate
and commit the app's pointer. Library docs own shared behavior and declarations;
app docs own brand configuration, business constraints and integration.

## P2 navigation and actual space

The application now delegates navigation rendering to `MyAppsNavigationShell`.
App-side shells retain routes, destination filtering, selection persistence and reminder
callbacks. Each page passes `context` to its width and bottom-inset helpers: measured
shell content width is used once, and full-window routes subtract no rail. The legacy
context-free helper remains for callers that explicitly request the old calculation.
The stable content slot preserves page state across resize, style and rail-side changes.
MyVidComp retains classic navigation, extended rails and review badges.

Profile extraction is complete in P3; data formats are unchanged.

## P3 profile and avatar

The five profile-bearing apps consume `myapps_profile`. Profile model, merge,
image processing, repository, avatar rendering, editor and header view are shared.
App ProfileStore supplies active storage root, atomic writer and sync notification;
image-service resolution/deletion remains injected. Existing imports are re-export
shims. App Riverpod providers, data-module registry, picker and localized edit dialog
remain adapters. JSON, module order, image naming and field-merge behavior are unchanged.
