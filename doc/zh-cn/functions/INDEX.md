# MyAnime `lib/` 函数索引

这是 MyAnime 仓库中 `lib/` 手写函数解释层文档的顶层索引。每行链接到 `doc/en-us/functions/` 下镜像 `lib/` 树的逐源文件页面（`.dart` 换成 `.md`）。

**总计：** 仓库的 `/// Purpose:` 注释数为 **1160**（按 `AGENTS.md` 中的函数解释层约定，排除生成的 `lib/l10n/` 代码——见 [l10n/INDEX.md](l10n/INDEX.md)）。下方各行合计 **1142** 个已记录声明。

| Tier | 计数 |
|---|---|
| Tier A（完整条目：Purpose/Inputs/Returns/Side effects/Algorithm/Usage/Notes） | 707 |
| Tier B（仅索引行） | 435 |
| **总计** | **1142** |

**已知缺口。** 这两个数字并不相等：有 18 个声明在源码中带 `/// Purpose:` 注释但此处没有对应行，因此本索引对 `lib/` 的覆盖少了这么多。1.5.7 重新测量时发现，1.5.6 记录的 864 本身已经过时——同一条命令在 1.5.6 的源码树上量到的是 901，因此这个缺口大部分是此前几个版本累积而未被发现的，而不是本次新增的。在 1.5.6 之前这个数是 10：当时发现 `adaptive_layout.dart` 那一行仍写着 `4 | 4`——那是它在 1.5.3 时的计数，彼时该模块还没有从详情页自己的辅助函数长成全应用的策略。它的页面自 1.5.5 起就记录了十二个声明，只有这一行没有跟上。该缺口分布不均，且尚未逐文件审计。另有一个文件方向相反，比其源码的 `Purpose:` 注释数多出一行——见下方 `features/` 小节的说明。

这些总计在 1.4.0 中已对照真实源码树重新计算，1.5.0 中再次重算（在四个新文件与五个改动文件中新增 93 个声明），1.5.1 中又一次重算（在五个改动文件中新增 24 个声明），1.5.2 中再次重算（在一个新文件与四个改动文件中新增 15 个声明），1.5.3 中再次重算（在三个新文件与六个改动文件中新增 22 个声明），1.5.4 中再次重算——本次在三个改动文件中新增 11 个声明，并把另外三行从 Tier B 提升到 Tier A，没有新增任何文件，1.5.5 中再次重算——本次在四个改动文件中新增 9 个声明，并把另外五行从 Tier B 提升到 Tier A，同样没有新增文件，1.5.6 中再次重算——本次在两个改动文件中新增 2 个声明，并把 `adaptive_layout.dart` 那一行长期陈旧的计数从 4 更正为 12，1.5.7 中再次重算——本次在两个新文件与八个改动文件中新增 18 个声明，并把总数从陈旧的 864 校正为实测的 919，1.6.0 中再次重算（M0，可选的假名标签）——本次在三个改动文件中新增 5 个声明，并发现 1.5.7 的源码树实测其实是 918，1.6.0 中再次重算（M1，系列关联）——本次在三个新文件与七个改动文件中新增 56 个声明（已扣除移入 `season_label.dart` 的两个 `Anime1Service` 辅助函数），并顺带为 `anime.dart` 的页面补上自 1.5.7 起缺失的 `_parseCalendarDate` 行，把 `anime_edit_page.dart` 陈旧的 Tier A 计数从 9 更正为其页面早已记录的 13；缺口仍为 18，1.6.0 中再次重算（M3，端侧 AI）——本次在四个新文件与两个改动文件（`app_settings.dart` 和 `anime_storage.dart`；`main.dart` 有改动但没有新增声明）中新增 67 个声明；缺口仍为 18，1.6.0 中再次重算（M2，关联元数据）——本次在四个改动文件（`anime.dart`、`anime_search_service.dart`、`series_service.dart` 和 `anime_detail_page.dart`；`anime_edit_page.dart` 与 `series_widgets.dart` 有改动但没有新增声明）中新增 15 个声明；缺口仍为 18，1.6.0 中再次重算（M4，自动分类）——本次在六个新文件与四个改动文件（`anime_storage.dart`、`app_settings.dart`、`anime_detail_page.dart` 和 `webdav_config_page.dart`；`anime.dart`、`management_page.dart`、`settings_page.dart`、`duplicate_service.dart`、`file_open_service.dart` 与 `main.dart` 有改动但没有新增声明）中新增 48 个声明；缺口仍为 18，1.6.0 中再次重算（M5，推荐）——本次在四个新文件与两个改动文件（`anime_storage.dart` 和 `app_settings.dart`；`router.dart`、`home_page.dart` 与 `settings_page.dart` 有改动但没有新增声明）中新增 37 个声明；缺口仍为 18，1.6.1 中再次重算——本次在六个改动文件（`anime_search_service.dart`——新增七个、移除 `_recentSeasons`——以及 `anime_storage.dart`、`series_service.dart`、`season_label.dart`、`anime_detail_page.dart` 和 `anime_edit_page.dart`；`router.dart`、`anime_search_dialog.dart`、`home_page.dart`、`management_page.dart` 与 `file_open_service.dart` 有改动但没有新增声明）中新增 14 个声明；缺口仍为 18。1.4.0 之前的数字（682 个 `Purpose:` 注释与 685 个已记录声明）与源码以及本文件自身的逐文件行都已严重偏离——当时逐文件行合计仅为 615。若要改动这些数字，请测量而不要手工调整：

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
| `lib/app/router.dart` | [app/router.md](app/router.md) | 1 | 1 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 11 | 11 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 3 | 2 |

`app/router.dart` 有一行，即 `kanaRouteRedirect`（1.6.0）。它的另一个顶层声明（`appRouter`，一个 `GoRouter` 配置值）不带 `/// Purpose:` 注释，落在函数解释层约定（函数/方法/构造函数/getter/setter）之外；详见该页面。

## features/ai/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/ai/services/ai_insights_cache.dart` | [features/ai/services/ai_insights_cache.md](features/ai/services/ai_insights_cache.md) | 10 | 4 |
| `lib/features/ai/services/genai_backend.dart` | [features/ai/services/genai_backend.md](features/ai/services/genai_backend.md) | 25 | 7 |
| `lib/features/ai/services/on_device_ai_service.dart` | [features/ai/services/on_device_ai_service.md](features/ai/services/on_device_ai_service.md) | 24 | 9 |
| `lib/features/ai/services/output_validation.dart` | [features/ai/services/output_validation.md](features/ai/services/output_validation.md) | 6 | 4 |
| `lib/features/ai/services/prompt_templates.dart` | [features/ai/services/prompt_templates.md](features/ai/services/prompt_templates.md) | 4 | 3 |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | [features/ai/widgets/ai_settings_tiles.md](features/ai/widgets/ai_settings_tiles.md) | 6 | 2 |

端侧 AI 层（1.6.0，M3）。`prompt_templates.dart` 和 `ai_insights_cache.dart` 随自动分类（M4）加入。各行包括带 `/// Purpose:` 注释的私有 `_AiJob` 辅助方法和状态类方法。见
[../on-device-ai.md](../on-device-ai.md)。

## features/anime/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/anime/models/anime.dart` | [features/anime/models/anime.md](features/anime/models/anime.md) | 83 | 68 |
| `lib/features/anime/models/anime_category.dart` | [features/anime/models/anime_category.md](features/anime/models/anime_category.md) | 2 | 1 |
| `lib/features/anime/models/metadata_update.dart` | [features/anime/models/metadata_update.md](features/anime/models/metadata_update.md) | 22 | 9 |
| `lib/features/anime/services/anime_storage.dart` | [features/anime/services/anime_storage.md](features/anime/services/anime_storage.md) | 53 | 45 |
| `lib/features/anime/services/anime1_service.dart` | [features/anime/services/anime1_service.md](features/anime/services/anime1_service.md) | 31 | 17 |
| `lib/features/anime/services/anime_search_service.dart` | [features/anime/services/anime_search_service.md](features/anime/services/anime_search_service.md) | 71 | 48 |
| `lib/features/anime/services/metadata_cache.dart` | [features/anime/services/metadata_cache.md](features/anime/services/metadata_cache.md) | 10 | 7 |
| `lib/features/anime/services/metadata_update_service.dart` | [features/anime/services/metadata_update_service.md](features/anime/services/metadata_update_service.md) | 44 | 27 |
| `lib/features/anime/services/series_service.dart` | [features/anime/services/series_service.md](features/anime/services/series_service.md) | 32 | 20 |
| `lib/features/anime/views/anime1_labels.dart` | [features/anime/views/anime1_labels.md](features/anime/views/anime1_labels.md) | 4 | 4 |
| `lib/features/anime/views/anime_detail_page.dart` | [features/anime/views/anime_detail_page.md](features/anime/views/anime_detail_page.md) | 34 | 16 |
| `lib/features/anime/views/anime_edit_page.dart` | [features/anime/views/anime_edit_page.md](features/anime/views/anime_edit_page.md) | 30 | 15 |
| `lib/features/anime/views/anime_search_dialog.dart` | [features/anime/views/anime_search_dialog.md](features/anime/views/anime_search_dialog.md) | 34 | 17 |
| `lib/features/anime/views/archive_labels.dart` | [features/anime/views/archive_labels.md](features/anime/views/archive_labels.md) | 3 | 3 |
| `lib/features/anime/views/category_widgets.dart` | [features/anime/views/category_widgets.md](features/anime/views/category_widgets.md) | 9 | 4 |
| `lib/features/anime/views/home_page.dart` | [features/anime/views/home_page.md](features/anime/views/home_page.md) | 24 | 9 |
| `lib/features/anime/views/management_page.dart` | [features/anime/views/management_page.md](features/anime/views/management_page.md) | 27 | 12 |
| `lib/features/anime/views/metadata_updates_page.dart` | [features/anime/views/metadata_updates_page.md](features/anime/views/metadata_updates_page.md) | 23 | 9 |
| `lib/features/anime/views/quarter_picker_dialog.dart` | [features/anime/views/quarter_picker_dialog.md](features/anime/views/quarter_picker_dialog.md) | 5 | 1 |
| `lib/features/anime/views/series_widgets.dart` | [features/anime/views/series_widgets.md](features/anime/views/series_widgets.md) | 13 | 5 |
| `lib/features/anime/views/statistics_page.dart` | [features/anime/views/statistics_page.md](features/anime/views/statistics_page.md) | 70 | 29 |

注意：`anime.dart` 比其源码的 `Purpose:` 注释数多一行——`AnimeData` 默认构造函数在源码中完全没有文档注释，但它是真实、已记录的声明（见该页面自己的说明）。`anime_search_service.dart` 过去也有这一性质，因为 `searchAnime1` 带的是普通（非 `Purpose:`）注释；该方法在 1.5.7 中带着完整注释块迁到了 `anime1_service.dart`，因此两者现在一致。`chinese_convert_data.dart` 是生成的数据，没有任何属于文档种类的声明，故其行为 `0 | 0`。

## features/categories/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/categories/services/category_service.dart` | [features/categories/services/category_service.md](features/categories/services/category_service.md) | 14 | 10 |
| `lib/features/categories/widgets/categorize_now_tile.dart` | [features/categories/widgets/categorize_now_tile.md](features/categories/widgets/categorize_now_tile.md) | 4 | 1 |

自动分类（1.6.0，M4）。见
[../features/categories-and-recommendations.md](../features/categories-and-recommendations.md)。

## features/kana/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/kana/views/kana_page.dart` | [features/kana/views/kana_page.md](features/kana/views/kana_page.md) | 19 | 3 |

## features/recommendations/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/recommendations/services/ai_reason_service.dart` | [features/recommendations/services/ai_reason_service.md](features/recommendations/services/ai_reason_service.md) | 5 | 3 |
| `lib/features/recommendations/services/reason_prompt.dart` | [features/recommendations/services/reason_prompt.md](features/recommendations/services/reason_prompt.md) | 3 | 2 |
| `lib/features/recommendations/services/recommendation_service.dart` | [features/recommendations/services/recommendation_service.md](features/recommendations/services/recommendation_service.md) | 14 | 6 |
| `lib/features/recommendations/views/recommendations_page.dart` | [features/recommendations/views/recommendations_page.md](features/recommendations/views/recommendations_page.md) | 11 | 7 |

推荐（1.6.0，M5）。见
[../features/categories-and-recommendations.md](../features/categories-and-recommendations.md)。

## features/settings/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 1 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 28 | 20 |

## l10n/

`lib/l10n/` 已在 [l10n/INDEX.md](l10n/INDEX.md) 中记录（生成代码，不属于上面 771 个手写声明）。

## shared/

| 源文件 | 页面 | 声明数 | Tier A 计数 |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 24 | 18 |
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 12 | 12 |
| `lib/shared/utils/calendar_preferences.dart` | [shared/utils/calendar_preferences.md](shared/utils/calendar_preferences.md) | 4 | 4 |
| `lib/shared/utils/chinese_convert.dart` | [shared/utils/chinese_convert.md](shared/utils/chinese_convert.md) | 5 | 4 |
| `lib/shared/utils/chinese_convert_data.dart` | [shared/utils/chinese_convert_data.md](shared/utils/chinese_convert_data.md) | 0 | 0 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 3 | 3 |
| `lib/shared/utils/jst_time.dart` | [shared/utils/jst_time.md](shared/utils/jst_time.md) | 5 | 4 |
| `lib/shared/utils/season_label.dart` | [shared/utils/season_label.md](shared/utils/season_label.md) | 10 | 8 |
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
| `lib/shared/services/file_open_service.dart` | [shared/services/file_open_service.md](shared/services/file_open_service.md) | 18 | 17 |
| `lib/shared/services/reminder_service.dart` | [shared/services/reminder_service.md](shared/services/reminder_service.md) | 9 | 8 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 6 | 4 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 8 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 6 | 6 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 45 | 36 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 24 | 14 |

## 区域总计

| 区域 | 文件 | 声明数 | Tier A | Tier B |
|---|---|---|---|---|
| 根（`lib/`） | 1 | 1 | 1 | 0 |
| `app/` | 5 | 19 | 14 | 5 |
| `features/ai/` | 6 | 75 | 29 | 46 |
| `features/anime/` | 21 | 624 | 366 | 258 |
| `features/categories/` | 2 | 18 | 11 | 7 |
| `features/kana/` | 1 | 19 | 3 | 16 |
| `features/recommendations/` | 4 | 33 | 18 | 15 |
| `features/settings/` | 4 | 49 | 28 | 21 |
| `shared/`（utils、widgets、providers、services、views） | 29 | 304 | 237 | 67 |
| **总计** | **73** | **1142** | **707** | **435** |
