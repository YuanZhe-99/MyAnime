# MyAnime `lib/` Function Index

This is the top-level index of the hand-written Function Explanation Layer documentation for
`lib/` in the MyAnime repo. Each row links to a per-source-file page under `doc/en-us/functions/`
mirroring the `lib/` tree (with `.dart` replaced by `.md`).

**Totals:** the repo's `/// Purpose:` comment count is **660** (per the Function Explanation Layer
convention in `AGENTS.md`, excluding generated `lib/l10n/` code — see [l10n/INDEX.md](l10n/INDEX.md)).
This index documents **663** declarations — 3 more than 660 — because three real declarations
(`AnimeData`'s default constructor in `anime.dart`; `_searchAnime1Single` in
`anime_search_service.dart`; and one further case noted on those pages) have no `///` doc comment
in source at all but are still real, documented declarations. Every such case is called out
explicitly on its file page and in the `features/` section below; nothing is silently invented to
force a round number.

| Tier | Count |
|---|---|
| Tier A (full entry: Purpose/Inputs/Returns/Side effects/Algorithm/Usage/Notes) | 435 |
| Tier B (index row only) | 228 |
| **Total** | **663** |

## Root (`lib/`)

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 3 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 1 | 0 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 0 | 0 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 3 | 2 |

`app/router.dart` has zero rows because its only top-level declaration (`appRouter`, a `GoRouter`
config value) carries no `/// Purpose:` comment and falls outside the Function Explanation Layer
convention (function/method/constructor/getter/setter); see that page for detail.

## features/anime/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/anime/models/anime.dart` | [features/anime/models/anime.md](features/anime/models/anime.md) | 41 | 36 |
| `lib/features/anime/services/anime_storage.dart` | [features/anime/services/anime_storage.md](features/anime/services/anime_storage.md) | 25 | 25 |
| `lib/features/anime/services/anime_search_service.dart` | [features/anime/services/anime_search_service.md](features/anime/services/anime_search_service.md) | 16 | 16 |
| `lib/features/anime/views/anime_detail_page.dart` | [features/anime/views/anime_detail_page.md](features/anime/views/anime_detail_page.md) | 20 | 8 |
| `lib/features/anime/views/anime_edit_page.dart` | [features/anime/views/anime_edit_page.md](features/anime/views/anime_edit_page.md) | 24 | 8 |
| `lib/features/anime/views/anime_search_dialog.dart` | [features/anime/views/anime_search_dialog.md](features/anime/views/anime_search_dialog.md) | 19 | 5 |
| `lib/features/anime/views/home_page.dart` | [features/anime/views/home_page.md](features/anime/views/home_page.md) | 21 | 9 |
| `lib/features/anime/views/management_page.dart` | [features/anime/views/management_page.md](features/anime/views/management_page.md) | 20 | 9 |
| `lib/features/anime/views/quarter_picker_dialog.dart` | [features/anime/views/quarter_picker_dialog.md](features/anime/views/quarter_picker_dialog.md) | 5 | 1 |
| `lib/features/anime/views/statistics_page.dart` | [features/anime/views/statistics_page.md](features/anime/views/statistics_page.md) | 66 | 27 |

Note: `anime.dart` and `anime_search_service.dart` each have one more row than their source's
`Purpose:` comment count — the `AnimeData` default constructor and `_searchAnime1Single`
respectively have no doc comment at all in source, but are still real, documented declarations
(see each page's own note).

## features/kana/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/kana/views/kana_page.dart` | [features/kana/views/kana_page.md](features/kana/views/kana_page.md) | 19 | 3 |

## features/settings/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 1 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 24 | 16 |

## l10n/

`lib/l10n/` is already documented at [l10n/INDEX.md](l10n/INDEX.md) (generated code, not part of
the 660/663 hand-documented declarations above).

## shared/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 12 | 12 |
| `lib/shared/utils/calendar_preferences.dart` | [shared/utils/calendar_preferences.md](shared/utils/calendar_preferences.md) | 2 | 2 |
| `lib/shared/utils/chinese_convert.dart` | [shared/utils/chinese_convert.md](shared/utils/chinese_convert.md) | 3 | 2 |
| `lib/shared/utils/jst_time.dart` | [shared/utils/jst_time.md](shared/utils/jst_time.md) | 5 | 4 |
| `lib/shared/widgets/delete_confirm.dart` | [shared/widgets/delete_confirm.md](shared/widgets/delete_confirm.md) | 1 | 1 |
| `lib/shared/widgets/duplicate_check_page.dart` | [shared/widgets/duplicate_check_page.md](shared/widgets/duplicate_check_page.md) | 10 | 3 |
| `lib/shared/widgets/import_bundle_dialog.dart` | [shared/widgets/import_bundle_dialog.md](shared/widgets/import_bundle_dialog.md) | 6 | 2 |
| `lib/shared/widgets/shell_scaffold.dart` | [shared/widgets/shell_scaffold.md](shared/widgets/shell_scaffold.md) | 3 | 1 |
| `lib/shared/services/webdav_service.dart` | [shared/services/webdav_service.md](shared/services/webdav_service.md) | 68 | 62 |
| `lib/shared/services/sync_merge.dart` | [shared/services/sync_merge.md](shared/services/sync_merge.md) | 6 | 5 |
| `lib/shared/services/sync_progress.dart` | [shared/services/sync_progress.md](shared/services/sync_progress.md) | 4 | 4 |
| `lib/shared/services/sync_wake_lock.dart` | [shared/services/sync_wake_lock.md](shared/services/sync_wake_lock.md) | 4 | 3 |
| `lib/shared/services/auto_sync_service.dart` | [shared/services/auto_sync_service.md](shared/services/auto_sync_service.md) | 22 | 17 |
| `lib/shared/services/backup_service.dart` | [shared/services/backup_service.md](shared/services/backup_service.md) | 20 | 19 |
| `lib/shared/services/share_service.dart` | [shared/services/share_service.md](shared/services/share_service.md) | 33 | 25 |
| `lib/shared/services/duplicate_service.dart` | [shared/services/duplicate_service.md](shared/services/duplicate_service.md) | 17 | 12 |
| `lib/shared/services/file_open_service.dart` | [shared/services/file_open_service.md](shared/services/file_open_service.md) | 17 | 15 |
| `lib/shared/services/reminder_service.dart` | [shared/services/reminder_service.md](shared/services/reminder_service.md) | 9 | 8 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 6 | 4 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 8 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 5 | 5 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 43 | 35 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 22 | 12 |

## Area totals

| Area | Files | Declarations | Tier A | Tier B |
|---|---|---|---|---|
| Root (`lib/`) | 1 | 1 | 1 | 0 |
| `app/` | 4 | 7 | 2 | 5 |
| `features/anime/` | 10 | 257 | 144 | 113 |
| `features/kana/` | 1 | 19 | 3 | 16 |
| `features/settings/` | 4 | 45 | 24 | 21 |
| `shared/` (utils/widgets/providers) | 8 | 42 | 27 | 15 |
| `shared/services/` | 14 | 270 | 222 | 48 |
| `shared/views/` | 1 | 22 | 12 | 10 |
| **Total** | **43** | **663** | **435** | **228** |
