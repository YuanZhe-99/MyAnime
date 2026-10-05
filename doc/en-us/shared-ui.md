# Shared UI foundations

MyApps-UI `v0.1.1` is embedded at `packages/myapps_ui`, with relative URL
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

Profile extraction remains P3; data formats are unchanged.
