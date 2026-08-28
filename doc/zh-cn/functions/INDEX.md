# MyAnime `lib/` 函数索引

这是 MyAnime 仓库中 `lib/` 手写函数解释层文档的顶层索引。每行链接到 `doc/en-us/functions/` 下镜像 `lib/` 树的逐源文件页面（`.dart` 换成 `.md`）。

**总计：** 仓库的 `/// Purpose:` 注释数为 **842**（按 `AGENTS.md` 中的函数解释层约定，排除生成的 `lib/l10n/` 代码——见 [l10n/INDEX.md](l10n/INDEX.md)）。下方各行合计 **832** 个已记录声明。

| Tier | 计数 |
|---|---|
| Tier A（完整条目：Purpose/Inputs/Returns/Side effects/Algorithm/Usage/Notes） | 517 |
| Tier B（仅索引行） | 315 |
| **总计** | **832** |

**已知缺口。** 这两个数字并不相等：有 10 个声明在源码中带 `/// Purpose:` 注释但此处没有对应行，因此本索引对 `lib/` 的覆盖少了这么多。该缺口分布不均，且尚未逐文件审计。另有两个文件方向相反，比其源码的 `Purpose:` 注释数多出一行——见下方 `features/` 小节的说明。

这些总计在 1.4.0 中已对照真实源码树重新计算，1.5.0 中再次重算（在四个新文件与五个改动文件中新增 93 个声明），1.5.1 中又一次重算（在五个改动文件中新增 24 个声明），1.5.2 中再次重算（在一个新文件与四个改动文件中新增 15 个声明），1.5.3 中再次重算——本次在三个新文件与六个改动文件中新增 22 个声明。1.4.0 之前的数字（682 个 `Purpose:` 注释与 685 个已记录声明）与源码以及本文件自身的逐文件行都已严重偏离——当时逐文件行合计仅为 615。若要改动这些数字，请测量而不要手工调整：

```bash
find lib -name "*.dart" -not -path "lib/l10n/*" | xargs grep -h '/// Purpose:' | wc -l
```

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
| `lib/features/anime/models/anime.dart` | [features/anime/models/anime.md](features/anime/models/anime.md) | 67 | 55 |
| `lib/features/anime/models/metadata_update.dart` | [features/anime/models/metadata_update.md](features/anime/models/metadata_update.md) | 22 | 9 |
| `lib/features/anime/services/anime_storage.dart` | [features/anime/services/anime_storage.md](features/anime/services/anime_storage.md) | 40 | 32 |
| `lib/features/anime/services/anime_search_service.dart` | [features/anime/services/anime_search_service.md](features/anime/services/anime_search_service.md) | 56 | 36 |
| `lib/features/anime/services/metadata_cache.dart` | [features/anime/services/metadata_cache.md](features/anime/services/metadata_cache.md) | 10 | 7 |
| `lib/features/anime/services/metadata_update_service.dart` | [features/anime/services/metadata_update_service.md](features/anime/services/metadata_update_service.md) | 41 | 24 |
| `lib/features/anime/views/anime_detail_page.dart` | [features/anime/views/anime_detail_page.md](features/anime/views/anime_detail_page.md) | 28 | 11 |
| `lib/features/anime/views/anime_edit_page.dart` | [features/anime/views/anime_edit_page.md](features/anime/views/anime_edit_page.md) | 25 | 9 |
| `lib/features/anime/views/anime_search_dialog.dart` | [features/anime/views/anime_search_dialog.md](features/anime/views/anime_search_dialog.md) | 34 | 17 |
| `lib/features/anime/views/archive_labels.dart` | [features/anime/views/archive_labels.md](features/anime/views/archive_labels.md) | 3 | 3 |
| `lib/features/anime/views/home_page.dart` | [features/anime/views/home_page.md](features/anime/views/home_page.md) | 23 | 9 |
| `lib/features/anime/views/management_page.dart` | [features/anime/views/management_page.md](features/anime/views/management_page.md) | 27 | 12 |
| `lib/features/anime/views/metadata_updates_page.dart` | [features/anime/views/metadata_updates_page.md](features/anime/views/metadata_updates_page.md) | 22 | 8 |
| `lib/features/anime/views/quarter_picker_dialog.dart` | [features/anime/views/quarter_picker_dialog.md](features/anime/views/quarter_picker_dialog.md) | 5 | 1 |
| `lib/features/anime/views/statistics_page.dart` | [features/anime/views/statistics_page.md](features/anime/views/statistics_page.md) | 70 | 29 |

注意：`anime.dart` 和 `anime_search_service.dart` 各比其源码的 `Purpose:` 注释数多一行——`AnimeData` 默认构造函数在源码中完全没有文档注释，而 `searchAnime1` 带的是普通（非 `Purpose:`）注释。两者都是真实、已记录的声明（见各页面自己的说明）。自 1.4.0 起 `_searchAnime1Single` 已有 `Purpose:` 注释，因此不再属于这类情况。

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
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 27 | 19 |

## l10n/

`lib/l10n/` 已在 [l10n/INDEX.md](l10n/INDEX.md) 中记录（生成代码，不属于上面 771 个手写声明）。

## shared/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 17 | 14 |
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 4 | 4 |
| `lib/shared/utils/calendar_preferences.dart` | [shared/utils/calendar_preferences.md](shared/utils/calendar_preferences.md) | 4 | 4 |
| `lib/shared/utils/chinese_convert.dart` | [shared/utils/chinese_convert.md](shared/utils/chinese_convert.md) | 3 | 2 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 3 | 3 |
| `lib/shared/utils/jst_time.dart` | [shared/utils/jst_time.md](shared/utils/jst_time.md) | 5 | 4 |
| `lib/shared/widgets/adaptive_tile_grid.dart` | [shared/widgets/adaptive_tile_grid.md](shared/widgets/adaptive_tile_grid.md) | 3 | 3 |
| `lib/shared/widgets/anime_actions_sheet.dart` | [shared/widgets/anime_actions_sheet.md](shared/widgets/anime_actions_sheet.md) | 1 | 1 |
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
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 44 | 36 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 22 | 12 |

## 区域总计

| 区域 | 文件 | 声明数 | Tier A | Tier B |
|---|---|---|---|---|
| 根（`lib/`） | 1 | 1 | 1 | 0 |
| `app/` | 5 | 18 | 13 | 5 |
| `features/anime/` | 11 | 338 | 198 | 140 |
| `features/kana/` | 1 | 19 | 3 | 16 |
| `features/settings/` | 4 | 45 | 24 | 21 |
| `shared/`（utils/widgets/providers） | 8 | 46 | 31 | 15 |
| `shared/services/` | 14 | 189 | 155 | 34 |
| `shared/views/` | 1 | 22 | 12 | 10 |
| **总计** | **45** | **678** | **437** | **241** |
