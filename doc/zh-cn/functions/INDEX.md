# MyAnime `lib/` 函数索引

这是 MyAnime 仓库中 `lib/` 手写函数解释层文档的顶层索引。每行链接到 `doc/en-us/functions/` 下镜像 `lib/` 树的逐源文件页面（`.dart` 换成 `.md`）。

**总计：** 仓库的 `/// Purpose:` 注释数为 **660**（按 `AGENTS.md` 中的函数解释层约定，排除生成的 `lib/l10n/` 代码——见 [l10n/INDEX.md](l10n/INDEX.md)）。本索引记录 **663** 个声明——比 660 多 3 个——因为三个真实声明（`anime.dart` 中 `AnimeData` 的默认构造函数；`anime_search_service.dart` 中的 `_searchAnime1Single`；以及那些页面上的一个另行说明的情况）在源码中完全没有 `///` 文档注释，但仍是真实、已记录的声明。每个这种情况都在其文件页面和下方的 `features/` 小节中明确说明；没有任何东西被静默编造来凑整。

| Tier | 计数 |
|---|---|
| Tier A（完整条目：Purpose/Inputs/Returns/Side effects/Algorithm/Usage/Notes） | 435 |
| Tier B（仅索引行） | 228 |
| **总计** | **663** |

## 根（`lib/`）

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 3 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 1 | 0 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 0 | 0 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 11 | 11 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 3 | 2 |

`app/router.dart` 为零行，因为它唯一的顶层声明（`appRouter`，一个 `GoRouter` 配置值）不带 `/// Purpose:` 注释，落在函数解释层约定（函数/方法/构造函数/getter/setter）之外；详见该页面。

## features/anime/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
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

注意：`anime.dart` 和 `anime_search_service.dart` 各比其源码的 `Purpose:` 注释数多一行——`AnimeData` 默认构造函数和 `_searchAnime1Single` 在源码中分别没有文档注释，但仍是真实、已记录的声明（见各页面自己的说明）。

## features/kana/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/kana/views/kana_page.dart` | [features/kana/views/kana_page.md](features/kana/views/kana_page.md) | 19 | 3 |

## features/settings/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 1 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 24 | 16 |

## l10n/

`lib/l10n/` 已在 [l10n/INDEX.md](l10n/INDEX.md) 中记录（生成代码，不属于上面 660/663 个手写声明）。

## shared/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 12 | 12 |
| `lib/shared/utils/calendar_preferences.dart` | [shared/utils/calendar_preferences.md](shared/utils/calendar_preferences.md) | 2 | 2 |
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
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 5 | 5 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 43 | 35 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 22 | 12 |

## 区域总计

| 区域 | 文件 | 声明数 | Tier A | Tier B |
|---|---|---|---|---|
| 根（`lib/`） | 1 | 1 | 1 | 0 |
| `app/` | 4 | 7 | 2 | 5 |
| `features/anime/` | 10 | 257 | 144 | 113 |
| `features/kana/` | 1 | 19 | 3 | 16 |
| `features/settings/` | 4 | 45 | 24 | 21 |
| `shared/`（utils/widgets/providers） | 8 | 42 | 27 | 15 |
| `shared/services/` | 14 | 270 | 222 | 48 |
| `shared/views/` | 1 | 22 | 12 | 10 |
| **总计** | **43** | **663** | **435** | **228** |
