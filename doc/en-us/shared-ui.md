# Shared UI foundations

MyApps-UI `v0.1.0` is embedded at `packages/myapps_ui`, with relative URL
`../MyApps-UI.git`. Initialize submodules recursively after cloning.

`lib/app/theme.dart` delegates to `myapps_ui` while retaining the existing API
and purple `0xFF673AB7` seed. Shared enums preserve stored names and defaults.
Android-only dynamic color remains controlled by the application root.

`lib/shared/utils/adaptive_layout.dart` re-exports the common thresholds and
`canSplitLayout`, `useNavigationRail`, `columnCapacity`, `listRowCount` from
`myapps_adaptive`. Anime tiles, ranking controls, statistics panes and episode
constraints stay app-owned. Existing content-width prediction is unchanged.
Navigation components and profile extraction are later stages; data formats do not change.

## Updating

Publish the library to both remotes first, pin its tagged commit, then validate
and commit the app's pointer. Library docs own shared behavior and declarations;
app docs own brand configuration, business constraints and integration.
