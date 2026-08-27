# MyAnime `lib/` Function Index

This is the top-level index of the hand-written Function Explanation Layer documentation for
`lib/` in the MyAnime repo. Each row links to a per-source-file page under `doc/en-us/functions/`
mirroring the `lib/` tree (with `.dart` replaced by `.md`).

**Totals:** the repo's `/// Purpose:` comment count is **781** (per the Function Explanation Layer
convention in `AGENTS.md`, excluding generated `lib/l10n/` code — see [l10n/INDEX.md](l10n/INDEX.md)).
The rows below sum to **771** documented declarations.

| Tier | Count |
|---|---|
| Tier A (full entry: Purpose/Inputs/Returns/Side effects/Algorithm/Usage/Notes) | 489 |
| Tier B (index row only) | 282 |
| **Total** | **771** |

**Known gap.** These two numbers do not match: 10 declarations carry a `/// Purpose:` comment in
source but have no row here, so the index under-covers `lib/` by that much. The gap is not evenly
distributed and has not been audited file by file. Two individual files go the *other* way and
carry one more row than their source's `Purpose:` count — see the note under the `features/`
section below.

These totals were recomputed against the actual source tree in 1.4.0 and again in 1.5.0, which
added 93 declarations across four new files and five changed ones. The pre-1.4.0 figures (682
`Purpose:` comments and 685 documented declarations) had drifted far from both the source and this
file's own per-file rows, which summed to 615 at the time. If you change these numbers, measure
them rather than adjusting them by hand:

```bash
find lib -name "*.dart" -not -path "lib/l10n/*" | xargs grep -h '/// Purpose:' | wc -l
```

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
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 11 | 11 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 3 | 2 |

`app/router.dart` has zero rows because its only top-level declaration (`appRouter`, a `GoRouter`
config value) carries no `/// Purpose:` comment and falls outside the Function Explanation Layer
convention (function/method/constructor/getter/setter); see that page for detail.

## features/anime/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/anime/models/anime.dart` | [features/anime/models/anime.md](features/anime/models/anime.md) | 63 | 52 |
| `lib/features/anime/models/metadata_update.dart` | [features/anime/models/metadata_update.md](features/anime/models/metadata_update.md) | 19 | 8 |
| `lib/features/anime/services/anime_storage.dart` | [features/anime/services/anime_storage.md](features/anime/services/anime_storage.md) | 32 | 32 |
| `lib/features/anime/services/anime_search_service.dart` | [features/anime/services/anime_search_service.md](features/anime/services/anime_search_service.md) | 51 | 35 |
| `lib/features/anime/services/metadata_cache.dart` | [features/anime/services/metadata_cache.md](features/anime/services/metadata_cache.md) | 10 | 7 |
| `lib/features/anime/services/metadata_update_service.dart` | [features/anime/services/metadata_update_service.md](features/anime/services/metadata_update_service.md) | 32 | 18 |
| `lib/features/anime/views/anime_detail_page.dart` | [features/anime/views/anime_detail_page.md](features/anime/views/anime_detail_page.md) | 24 | 11 |
| `lib/features/anime/views/anime_edit_page.dart` | [features/anime/views/anime_edit_page.md](features/anime/views/anime_edit_page.md) | 25 | 9 |
| `lib/features/anime/views/anime_search_dialog.dart` | [features/anime/views/anime_search_dialog.md](features/anime/views/anime_search_dialog.md) | 32 | 16 |
| `lib/features/anime/views/archive_labels.dart` | [features/anime/views/archive_labels.md](features/anime/views/archive_labels.md) | 3 | 3 |
| `lib/features/anime/views/home_page.dart` | [features/anime/views/home_page.md](features/anime/views/home_page.md) | 22 | 9 |
| `lib/features/anime/views/management_page.dart` | [features/anime/views/management_page.md](features/anime/views/management_page.md) | 26 | 12 |
| `lib/features/anime/views/metadata_updates_page.dart` | [features/anime/views/metadata_updates_page.md](features/anime/views/metadata_updates_page.md) | 17 | 6 |
| `lib/features/anime/views/quarter_picker_dialog.dart` | [features/anime/views/quarter_picker_dialog.md](features/anime/views/quarter_picker_dialog.md) | 5 | 1 |
| `lib/features/anime/views/statistics_page.dart` | [features/anime/views/statistics_page.md](features/anime/views/statistics_page.md) | 66 | 27 |

Note: `anime.dart` and `anime_search_service.dart` each have one more row than their source's
`Purpose:` comment count — the `AnimeData` default constructor has no doc comment at all in
source, and `searchAnime1` carries a plain (non-`Purpose:`) one. Both are real, documented
declarations (see each page's own note). As of 1.4.0 `_searchAnime1Single` does have a
`Purpose:` comment, so it is no longer one of these cases.

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
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 27 | 19 |

## l10n/

`lib/l10n/` is already documented at [l10n/INDEX.md](l10n/INDEX.md) (generated code, not part of
the 771 hand-documented declarations above).

## shared/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 14 | 14 |
| `lib/shared/utils/calendar_preferences.dart` | [shared/utils/calendar_preferences.md](shared/utils/calendar_preferences.md) | 4 | 4 |
| `lib/shared/utils/chinese_convert.dart` | [shared/utils/chinese_convert.md](shared/utils/chinese_convert.md) | 3 | 2 |
| `lib/shared/utils/jst_time.dart` | [shared/utils/jst_time.md](shared/utils/jst_time.md) | 5 | 4 |
| `lib/shared/widgets/delete_confirm.dart` | [shared/widgets/delete_confirm.md](shared/widgets/delete_confirm.md) | 1 | 1 |
| `lib/shared/widgets/duplicate_check_page.dart` | [shared/widgets/duplicate_check_page.md](shared/widgets/duplicate_check_page.md) | 10 | 3 |
| `lib/shared/widgets/import_bundle_dialog.dart` | [shared/widgets/import_bundle_dialog.md](shared/widgets/import_bundle_dialog.md) | 6 | 2 |
| `lib/shared/widgets/shell_scaffold.dart` | [shared/widgets/shell_scaffold.md](shared/widgets/shell_scaffold.md) | 3 | 1 |
| `lib/shared/services/webdav_service.dart` | [shared/services/webdav_service.md](shared/services/webdav_service.md) | 12 | 12 |
| `lib/shared/services/sync_merge.dart` | [shared/services/sync_merge.md](shared/services/sync_merge.md) | 4 | 4 |
| `lib/shared/services/sync_progress.dart` | [shared/services/sync_progress.md](shared/services/sync_progress.md) | 0 | 0 |
| `lib/shared/services/sync_wake_lock.dart` | [shared/services/sync_wake_lock.md](shared/services/sync_wake_lock.md) | 0 | 0 |
| `lib/shared/services/auto_sync_service.dart` | [shared/services/auto_sync_service.md](shared/services/auto_sync_service.md) | 15 | 15 |
| `lib/shared/services/backup_service.dart` | [shared/services/backup_service.md](shared/services/backup_service.md) | 12 | 12 |
| `lib/shared/services/share_service.dart` | [shared/services/share_service.md](shared/services/share_service.md) | 33 | 25 |
| `lib/shared/services/duplicate_service.dart` | [shared/services/duplicate_service.md](shared/services/duplicate_service.md) | 17 | 12 |
| `lib/shared/services/file_open_service.dart` | [shared/services/file_open_service.md](shared/services/file_open_service.md) | 17 | 15 |
| `lib/shared/services/reminder_service.dart` | [shared/services/reminder_service.md](shared/services/reminder_service.md) | 9 | 8 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 6 | 4 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 8 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 6 | 6 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 43 | 35 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 22 | 12 |

## Area totals

| Area | Files | Declarations | Tier A | Tier B |
|---|---|---|---|---|
| Root (`lib/`) | 1 | 1 | 1 | 0 |
| `app/` | 5 | 18 | 13 | 5 |
| `features/anime/` | 11 | 338 | 198 | 140 |
| `features/kana/` | 1 | 19 | 3 | 16 |
| `features/settings/` | 4 | 45 | 24 | 21 |
| `shared/` (utils/widgets/providers) | 8 | 46 | 31 | 15 |
| `shared/services/` | 14 | 189 | 155 | 34 |
| `shared/views/` | 1 | 22 | 12 | 10 |
| **Total** | **45** | **678** | **437** | **241** |
