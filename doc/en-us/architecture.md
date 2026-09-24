# Architecture

This page describes the app shell, state management approach, navigation, localization, and the
repository layout, plus the cross-cutting architectural rules from `AGENTS.md`'s "Core
Architecture" section. See [`data-formats.md`](data-formats.md) for the data model and
[`sync.md`](sync.md) for the sync subsystem built on top of this shell.

## App shell

- `lib/main.dart` — app entry point.
- `lib/app/app.dart` — root `MaterialApp`/`App` widget wiring.
- `lib/app/router.dart` — navigation, built on `go_router`. The router uses a `ShellRoute` wrapping
  the navigation tabs — rendered as a bottom `NavigationBar` on a narrow window and a side
  `NavigationRail` from 600 logical pixels up, see [`adaptive-layout.md`](adaptive-layout.md):
  - Home (`/home`, `home_page.dart`)
  - Manage (`/manage`, `management_page.dart`)
  - Stats (`/stats`, `statistics_page.dart`)
  - Kana (`/kana`, `kana_page.dart`) — only while **Settings › General › Kana quick reference** is
    on; off by default since 1.6.0, when `/kana` redirects to `/home` (see
    [`features/kana-reference.md`](features/kana-reference.md))
  - Settings (`/settings`, `settings_page.dart`)

  Non-tab routes (anime detail, anime edit/add, metadata-update review, duplicate-check) are
  declared alongside the shell route and pushed on top of it (e.g. `/anime/detail/:id`,
  `/anime/edit`, `/anime/edit/:id`, `/metadata-updates`, `/duplicate-check`).
- `lib/app/theme.dart` — the visual system, built on Material 3 via `flex_color_scheme`.
- `lib/app/flavor.dart` — build flavor logic (see below).

## Build flavors

Flavor logic lives in `lib/app/flavor.dart` and gates which features are reachable depending on
distribution channel:

| Flavor | Dart define | Online search | Distribution |
| --- | --- | --- | --- |
| `full` | `--dart-define=FLAVOR=full` | Enabled | GitHub Releases, sideload builds, direct APK, desktop installers |
| `store` | `--dart-define=FLAVOR=store` | Disabled in store-facing UI | Google Play and App Store builds |

Online anime search must stay hidden from store builds. UI gates use `AppFlavor.isFull` (see
`anime_edit_page.dart`). `AnimeSearchService` itself does **not** enforce flavor gating — it's a
shared utility — so every new store-reachable caller must gate access explicitly. The desktop
local API server (see [`platform-notes.md`](platform-notes.md)) can call
`AnimeSearchService.searchAll()` because it's a desktop-only feature, not a store/mobile surface.
See [`features/multi-source-search.md`](features/multi-source-search.md) for the search sources
themselves.

## State management

State management uses `flutter_riverpod` throughout. Provider and Bloc are not used, and should
not be introduced for normal changes.

## Localization (l10n)

- Supported languages: English, Japanese, Simplified Chinese, Traditional Chinese.
- The ARB template is `lib/l10n/app_en.arb`.
- Generated localization files live under `lib/l10n/`.

## Repository structure

```text
lib/
  main.dart
  app/
    app.dart
    flavor.dart
    router.dart
    theme.dart
  features/
    ai/                       # on-device AI layer (1.6.0)
      services/
        genai_backend.dart
        on_device_ai_service.dart
        output_validation.dart
      widgets/ai_settings_tiles.dart
    anime/
      models/anime.dart
      services/
        anime_search_service.dart
        anime_storage.dart
        series_service.dart     # series grouping and curation (1.6.0)
      views/
        home_page.dart
        management_page.dart
        statistics_page.dart
        quarter_picker_dialog.dart
        anime_detail_page.dart
        anime_edit_page.dart
        anime_search_dialog.dart
        series_widgets.dart     # series card and manage sheet (1.6.0)
    kana/views/kana_page.dart
    settings/views/
      backup_page.dart
      license_page.dart
      privacy_policy_page.dart
      settings_page.dart
  shared/
    providers/app_settings.dart
    services/
      auto_sync_service.dart
      backup_service.dart
      duplicate_service.dart
      file_open_service.dart
      image_service.dart
      import_export_service.dart
      local_api_server.dart
      reminder_service.dart
      share_service.dart
      sync_merge.dart
      sync_progress.dart
      sync_wake_lock.dart
      tray_service.dart
      webdav_service.dart
    utils/
      chinese_convert.dart
      chinese_convert_data.dart
      jst_time.dart
      season_label.dart       # season ordinals, markers, next label (1.6.0)
    views/webdav_config_page.dart
    widgets/
      duplicate_check_page.dart
      import_bundle_dialog.dart
  l10n/
```

Primary tests (mirroring the structure above where relevant):

- `test/anime_json_test.dart` — unknown JSON preservation and auto-resolved sync merge behavior.
- `test/backup_service_test.dart` — backup format v2 blob dedup, reference-counted blob GC, legacy
  inline-image restore, image-name sanitization, restore validation, corrupt-bundle detection.
- `test/audit_fixes_test.dart` — identical-content conflict suppression and forward-snapped
  episode air dates.
- `test/duplicate_service_test.dart` — duplicate detection (same-id, same-url,
  same-title-season), transitive grouping, and merge semantics.
- `test/bundle_import_test.dart` — `.myanimeitem` v1 backward compatibility, v2 multi-anime bundle
  format, and export personal-data stripping.
- `test/local_archive_ui_test.dart` — Local Archive section rendering, the archived switch, the
  source dropdown, and the archive enum label helpers.
- `test/widget_test.dart` — basic widget smoke coverage.
- `test/on_device_ai_test.dart` and `test/ai_settings_tiles_ui_test.dart` — the on-device AI gate,
  status mapping, queue, pacing and output parsing against a fake backend, and the Settings rows per
  platform (1.6.0).

`tool/` contains ad hoc scripts (icon generation, search-source validation, the Chinese
conversion-table generator) that are not part of
the release-critical path. The exception is `tool/check_weak_link.sh`, which the iOS and macOS CI
jobs run (see [`ci-cd.md`](ci-cd.md)).

Outside `lib/`, the repo carries two local Dart packages under `packages/`, both path dependencies
in `pubspec.yaml`: `packages/myapps_data`, the shared engine submodule described below, and
`packages/on_device_ai_apple` (1.6.0), a tracked local Flutter plugin that bridges Apple's
Foundation Models framework on iOS and macOS. The Android counterpart is
`android/app/src/main/kotlin/com/yuanzhe/my_anime/GenAiChannel.kt`. See
[`on-device-ai.md`](on-device-ai.md) and [`platform-notes.md`](platform-notes.md).

## Shared package (`myapps_data`)

The WebDAV sync engine, backup engine, ZIP transfer engine, and auto-sync scheduler are **not in this
repo**. They live in the shared `myapps_data` package, embedded at `packages/myapps_data` as a git
submodule and consumed as a pub path dependency. MyAnime, MyDay, and MyDevice all use it, which is
what keeps their wire format, backup format, and lock semantics interoperable.

- **What stays here:** all models, `AnimeStorage`, the `mergeAnimeData` wrapper, the Markdown export,
  and every page.
- **What moved:** the transport, lock lifecycle, merge pipeline, `.sync_base` snapshots, image sync,
  backup bundle and blob store, ZIP allowlist, and sync scheduling.
- **The seam:** [`functions/app/data_modules.md`](functions/app/data_modules.md) declares the
  `StorageAdapter` over `AnimeStorage` plus the `DataModule` describing `anime_data.json`. It is the
  single source of truth for the data-file name and backup module key.
- **The facades:** `WebDAVService`, `BackupService`, `ImportExportService`, and `AutoSyncService`
  keep their previous public APIs and delegate to the package. Their shapes are deliberately frozen
  so call sites and tests keep working; behavior changes belong in the package.

`.gitmodules` uses the relative URL `../MyApps-DATA.git`, so it resolves against whichever remote a
clone tracks — Gitea clones fetch from Gitea, GitHub clones from GitHub, and no host name is ever
committed. Fresh clones need `git clone --recurse-submodules` or `git submodule update --init`.

## Core architectural rules

These rules apply across the whole codebase and are worth internalizing before reading any single
feature area:

- **State management:** `flutter_riverpod`; no Provider or Bloc for normal changes.
- **Navigation:** `go_router` with a `ShellRoute` and the four or five tabs listed above.
- **Visual system:** Material 3 via `flex_color_scheme`.
- **Responsive layout:** one shared rule decides when the UI may split into panes or columns, and
  how many columns a list gets; a second, width-only rule decides whether navigation sits at the
  side or along the bottom. Both live in `shared/utils/adaptive_layout.dart` and are derived in
  [`adaptive-layout.md`](adaptive-layout.md). **Do not add a new inline width breakpoint** — as of
  1.5.4 there is not a single one left in `lib/`. Measure capacity against `shellContentWidth`,
  never the raw screen width, because the navigation rail is not the page's to spend.
- **File I/O:** should go through `AnimeStorage.getAppDir()` so custom storage paths (see
  `storage_config.json` in [`data-formats.md`](data-formats.md)) work consistently.
- **JSON formatting:** output is pretty-printed with `JsonEncoder.withIndent('  ')` everywhere data
  is written to disk — this matters for sync, since it lets an unchanged file hit a raw-equality
  fast path (see [`sync.md`](sync.md)).
- **Timestamps:** the anime model's timestamps use UTC, usually `DateTime.now().toUtc()`.
  Local-time `modifiedAt` values would break sync conflict detection, since three-way merge
  compares `modifiedAt` across devices in different timezones.
- **Calendar/airing logic:** JST-aware, through `shared/utils/jst_time.dart`. Reminder time
  comparison, by contrast, uses local system time, not JST — see
  [`features/reminders.md`](features/reminders.md).
- **Unknown JSON fields:** preserved via the `extraJson` pattern (see
  [`data-formats.md`](data-formats.md)) so older app versions don't delete newer fields during
  normal saves, imports, or sync merges.
