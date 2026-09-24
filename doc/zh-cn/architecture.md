# 架构

本页描述应用外壳、状态管理方式、导航、本地化和仓库布局，外加 `AGENTS.md` 的"核心架构"一节中跨领域架构规则。数据模型见 [`data-formats.md`](data-formats.md)，构建在此外壳之上的同步子系统见 [`sync.md`](sync.md)。

## 应用外壳

- `lib/main.dart` — 应用入口点。
- `lib/app/app.dart` — 根 `MaterialApp`/`App` 组件接线。
- `lib/app/router.dart` — 基于 `go_router` 的导航。路由器使用一个 `ShellRoute` 包住各导航标签——在窄窗口上渲染为底部 `NavigationBar`，从 600 逻辑像素起渲染为侧边 `NavigationRail`，见 [`adaptive-layout.md`](adaptive-layout.md)：
  - 主页（`/home`，`home_page.dart`）
  - 管理（`/manage`，`management_page.dart`）
  - 统计（`/stats`，`statistics_page.dart`）
  - 假名（`/kana`，`kana_page.dart`）——仅当**设置 › 通用 › 五十音速查**开启时出现；自 1.6.0 起默认关闭，关闭时 `/kana` 重定向到 `/home`（见 [`features/kana-reference.md`](features/kana-reference.md)）
  - 设置（`/settings`，`settings_page.dart`）

  非标签路由（动画详情、动画编辑/新增、元数据更新审阅、重复检查）与外壳路由一起声明，并压栈在它之上（如 `/anime/detail/:id`、`/anime/edit`、`/anime/edit/:id`、`/metadata-updates`、`/duplicate-check`）。
- `lib/app/theme.dart` — 基于 `flex_color_scheme` 的 Material 3 视觉体系。
- `lib/app/flavor.dart` — 构建风味逻辑（见下文）。

## 构建风味

风味逻辑位于 `lib/app/flavor.dart`，根据分发渠道控制哪些功能可达：

| 风味 | Dart define | 在线搜索 | 分发渠道 |
| --- | --- | --- | --- |
| `full` | `--dart-define=FLAVOR=full` | 启用 | GitHub Releases、侧载构建、直接 APK、桌面安装包 |
| `store` | `--dart-define=FLAVOR=store` | 在面向商店的 UI 中禁用 | Google Play 和 App Store 构建 |

在线动画搜索必须对商店构建保持隐藏。UI 门控使用 `AppFlavor.isFull`（见 `anime_edit_page.dart`）。`AnimeSearchService` 本身**不**强制风味门控——它是共享工具——因此每个新的商店可达调用方都必须显式门控访问。桌面本地 API 服务器（见 [`platform-notes.md`](platform-notes.md)）可以调用 `AnimeSearchService.searchAll()`，因为它是纯桌面功能，不是商店/移动端表面。搜索源本身见 [`features/multi-source-search.md`](features/multi-source-search.md)。

## 状态管理

状态管理全程使用 `flutter_riverpod`。不使用 Provider 和 Bloc，常规变更不应引入它们。

## 本地化（l10n）

- 支持语言：英语、日语、简体中文、繁体中文。
- ARB 模板是 `lib/l10n/app_en.arb`。
- 生成的本地化文件位于 `lib/l10n/` 下。

## 仓库结构

```text
lib/
  main.dart
  app/
    app.dart
    flavor.dart
    router.dart
    theme.dart
  features/
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

主要测试（在相关处镜像上述结构）：

- `test/anime_json_test.dart` — 未知 JSON 保留和自动解决的同步合并行为。
- `test/backup_service_test.dart` — 备份格式 v2 blob 去重、引用计数 blob GC、旧内联图像恢复、图像名净化、恢复校验、损坏捆绑检测。
- `test/audit_fixes_test.dart` — 相同内容冲突抑制和前向吸附的剧集播出日期。
- `test/duplicate_service_test.dart` — 重复检测（同 id、同 URL、同标题-季度）、传递性分组和合并语义。
- `test/bundle_import_test.dart` — `.myanimeitem` v1 向后兼容、v2 多动画捆绑格式，以及导出个人数据剥离。
- `test/local_archive_ui_test.dart` — 本地存档小节的渲染、archived 开关、片源下拉框，以及存档枚举标签辅助函数。
- `test/widget_test.dart` — 基础组件冒烟覆盖。

`tool/` 包含临时脚本（图标生成、搜索源校验、中文转换表生成器），不在发布关键路径上。

## 共享包（`myapps_data`）

WebDAV 同步引擎、备份引擎、ZIP 传输引擎和自动同步调度器**不在此仓库**。它们位于共享的 `myapps_data` 包中，作为 git 子模块嵌入在 `packages/myapps_data`，并作为 pub 路径依赖被消费。MyAnime、MyDay 和 MyDevice 都使用它，这正是它们的线上格式、备份格式和锁语义保持互通的原因。

- **留在这里的内容：** 所有模型、`AnimeStorage`、`mergeAnimeData` 包装器、Markdown 导出，以及每个页面。
- **移走的内容：** 传输、锁生命周期、合并流水线、`.sync_base` 快照、图像同步、备份捆绑与 blob 存储、ZIP 允许列表和同步调度。
- **接缝：** [`functions/app/data_modules.md`](functions/app/data_modules.md) 声明了基于 `AnimeStorage` 的 `StorageAdapter`，以及描述 `anime_data.json` 的 `DataModule`。它是数据文件名和备份模块键的唯一真实来源。
- **门面：** `WebDAVService`、`BackupService`、`ImportExportService` 和 `AutoSyncService` 保留它们此前的公共 API 并委托给该包。它们的形态被刻意冻结，使调用点和测试继续工作；行为变更属于该包。

`.gitmodules` 使用相对 URL `../MyApps-DATA.git`，因此它按克隆所跟踪的远程解析——Gitea 克隆从 Gitea 拉取，GitHub 克隆从 GitHub 拉取，而且任何主机名都不会被提交。全新克隆需要 `git clone --recurse-submodules` 或 `git submodule update --init`。

## 核心架构规则

这些规则适用于整个代码库，在阅读任何单个功能区域之前值得先内化：

- **状态管理：** `flutter_riverpod`；常规变更不用 Provider 或 Bloc。
- **导航：** `go_router`，带 `ShellRoute` 和上面列出的四个或五个标签。
- **视觉体系：** 基于 `flex_color_scheme` 的 Material 3。
- **响应式布局：** 一条共享规则决定界面何时可以拆成分栏或多列，以及列表分成几列；另有一条只看宽度的规则
  决定导航放在侧边还是底部。两者都位于 `shared/utils/adaptive_layout.dart`，推导见
  [`adaptive-layout.md`](adaptive-layout.md)。**不要新增内联的宽度断点**——截至 1.5.4，`lib/` 中一个
  也不剩了。容量请对 `shellContentWidth` 测量而非原始屏幕宽度，因为侧边导航栏并不归页面支配。
- **文件 I/O：** 应通过 `AnimeStorage.getAppDir()`，使自定义存储路径（见 [`data-formats.md`](data-formats.md) 中的 `storage_config.json`）一致工作。
- **JSON 格式化：** 所有写入磁盘的数据都用 `JsonEncoder.withIndent('  ')` 美化打印——这对同步很重要，因为它让未变化的文件命中原始相等快速路径（见 [`sync.md`](sync.md)）。
- **时间戳：** 动画模型的时间戳使用 UTC，通常为 `DateTime.now().toUtc()`。本地时间的 `modifiedAt` 值会破坏同步冲突检测，因为三方合并要跨不同时区的设备比较 `modifiedAt`。
- **日历/播出逻辑：** 通过 `shared/utils/jst_time.dart` 感知 JST。相比之下，提醒时间比较使用本地系统时间，不是 JST——见 [`features/reminders.md`](features/reminders.md)。
- **未知 JSON 字段：** 通过 `extraJson` 模式保留（见 [`data-formats.md`](data-formats.md)），使旧版应用在常规保存、导入或同步合并中不会删除新字段。
