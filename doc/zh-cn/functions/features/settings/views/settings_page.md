# lib/features/settings/views/settings_page.dart

`SettingsPage` 是应用的主设置屏：主题/语言区域/日历偏好（由 `shared/providers/app_settings.dart` 支撑）、提醒开关、数据操作（WebDAV 同步入口、备份入口、ZIP/Markdown 导出/导入、重复检查、存储位置）、纯桌面托盘/开机自启/本地 API 服务器控件，以及关于小节（版本、隐私政策、许可证）。它是一个 `ConsumerStatefulWidget`（Riverpod），也监听 `AutoSyncService.addOnStatusChanged`，使 WebDAV 行的错误/冲突副标题无需导航离开就保持实时。与 `license_page.dart`/`privacy_policy_page.dart` 不同，它大多数非 `build` 方法都是真实操作处理器——读写 `AnimeStorage` 的 JSON 配置、调用 `ImportExportService`、`LocalApiServer`、`ReminderService`、`TrayService` 和 `launch_at_startup`——因此这个"视图"文件有巨大的 Tier A 表面。

自 1.5.4 起它同时也是一个列表-详情布局。在全应用拆分规则允许的窗口上，一级列表留在左边，它所通向的二级
页面填满右边，与系统设置应用的行为一致；在更窄的窗口上，每一行仍与从前完全一样全屏推入。私有的
`_SettingsDetail` 枚举点名了参与其中的五行——WebDAV 同步、备份、查重、隐私政策与许可证——而 `_open` 是
决定一次点击做这两件事中哪一件的唯一去处。页面上其余的东西要么是内联控件、要么是对话框，两者都不是页面。
见 [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md)。这些处理器配置的纯桌面 API 服务器/托盘行为见 [`../../../platform-notes.md`](../../../../platform-notes.md)，WebDAV/备份入口通向哪里（`../../../shared/views/webdav_config_page.md`、同目录的 `backup_page.md`）见 [`../../../sync.md`](../../../../sync.md) / [`../../../backup-restore.md`](../../../../backup-restore.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `SettingsPage({super.key})` | 构造函数（`SettingsPage`） | B | 创建设置页实例。 |
| `createState` | 方法（组件生命周期） | B | 为此组件创建可变状态对象。 |
| `initState` | 方法（组件生命周期） | B | 启动版本/存储路径/提醒加载并注册同步状态监听器。 |
| `dispose` | 方法（组件生命周期） | B | 移除同步状态监听器。 |
| `_refreshSyncStatus` | 方法（组件辅助） | B | 后台同步状态变化时重建页面。 |
| [`_loadVersion`](#loadversion) | 方法（`_SettingsPageState`） | A | 加载并存储应用的版本/构建号字符串。 |
| [`_detailPage`](#detailpage) | 方法（组件辅助） | A | 构建某个设置行所通向的二级页面。 |
| [`_open`](#open) | 方法（`_SettingsPageState`） | A | 按当前布局所要求的方式打开一个二级页面。 |
| [`_buildDetailPane`](#builddetailpane) | 方法（组件辅助） | A | 构建两栏设置布局的右栏。 |
| [`_buildSettingsList`](#buildsettingslist) | 方法（组件辅助） | A | 构建一级设置列表。 |
| `_buildSection` | 方法（组件辅助） | B | 渲染一个带标题的设置小节。 |
| [`_calendarLayoutLabel`](#calendarlayoutlabel) | 方法（`_SettingsPageState`） | A | 把 `HomeCalendarLayout` 值映射为其本地化标签。 |
| [`_homeCalendarTimeBasisLabel`](#homecalendartimebasislabel) | 方法（`_SettingsPageState`） | A | 把 `HomeCalendarTimeBasis` 值映射为其本地化标签。 |
| [`_loadMetadataSettings`](#loadmetadatasettings) | 方法（`_SettingsPageState`） | A | 加载后台资料更新偏好。 |
| [`_setMetadataPolicy`](#setmetadatapolicy) | 方法（`_SettingsPageState`） | A | 持久化新策略并启动或停止服务。 |
| [`_metadataPolicyLabel`](#metadatapolicylabel) | 方法（`_SettingsPageState`） | A | 本地化后台更新策略选项。 |
| [`_weekdayLabel`](#weekdaylabel) | 方法（`_SettingsPageState`） | A | 把星期数字映射为其本地化短标签。 |
| `_isDesktop` | getter（`_SettingsPageState`） | B | 报告应用是否运行在桌面平台。 |
| [`_exportData`](#exportdata) | 方法（`_SettingsPageState`） | A | 把动画数据导出为 ZIP 或 Markdown 文件到用户选择的文件夹。 |
| [`_importData`](#importdata) | 方法（`_SettingsPageState`） | A | 确认并导入先前导出的 ZIP 捆绑。 |
| [`_openDataFolder`](#opendatafolder) | 方法（`_SettingsPageState`） | A | 在操作系统文件资源管理器中打开应用数据文件夹。 |
| [`_loadStoragePath`](#loadstoragepath) | 方法（`_SettingsPageState`） | A | 加载并存储当前数据存储路径。 |
| [`_loadReminder`](#loadreminder) | 方法（`_SettingsPageState`） | A | 加载并解析持久化的提醒启用标志和时间。 |
| [`_loadTraySettings`](#loadtraysettings) | 方法（`_SettingsPageState`） | A | 加载并存储持久化的最小化/关闭到托盘标志。 |
| [`_loadAutoStartStatus`](#loadautostartstatus) | 方法（`_SettingsPageState`） | A | 查询并存储开机自启是否启用。 |
| [`_loadApiSettings`](#loadapisettings) | 方法（`_SettingsPageState`） | A | 加载并存储持久化的本地 API 服务器设置。 |
| [`_showApiSettingsDialog`](#showapisettingsdialog) | 方法（`_SettingsPageState`） | A | 编辑、持久化并应用本地 API 服务器的地址/端口/凭据。 |
| [`_setReminderEnabled`](#setreminderenabled) | 方法（`_SettingsPageState`） | A | 持久化提醒开/关标志并重启周期检查。 |
| [`_pickReminderTime`](#pickremindertime) | 方法（`_SettingsPageState`） | A | 让用户选择新的每日提醒时间并持久化它。 |
| [`_showStoragePathDialog`](#showstoragepathdialog) | 方法（`_SettingsPageState`） | A | 编辑并应用自定义（或重置为默认）数据存储路径。 |
| `build` | 方法（组件构建） | B | 为当前状态/平台渲染完整设置列表。 |

## 文档

### `Widget _detailPage(_SettingsDetail detail)` <a id="detailpage"></a>
- **种类：** `_SettingsPageState` 的方法（组件辅助）
- **来源：** `lib/features/settings/views/settings_page.dart`（约第 140 行）
- **用途：** 构建某个设置行所通向的二级页面。
- **输入：** `detail`——五者之一。
- **返回：** `Widget`——该页面，其本身是一个带自己应用栏的 `Scaffold`。
- **副作用：** 除构建控件外无。
- **算法：** 从枚举到 `WebDAVConfigPage`、`BackupPage`、`DuplicateCheckPage`、`PrivacyPolicyPage` 或
  `app_license.LicensePage` 的一个 `switch`。
- **用法：**
  ```dart
  Navigator.of(context, rootNavigator: true)
      .push(MaterialPageRoute(builder: (_) => _detailPage(detail)));
  ```
  （出自同一文件的 `_open`）
- **备注：** 同一个控件服务于两种模式——窄窗口上全屏推入，宽窗口上寄宿于详情栏。**这五个页面没有一个需要改动
  才能被嵌入**，因为详情栏把它们包进了一个只持有单条路由的嵌套 `Navigator`，它报告 `canPop == false`，于是
  它们的应用栏不会长出返回箭头。

  刻意不在此列：调用 Flutter 自带 `showLicensePage` 的开源许可证一行。那个页面本身已经包含自己的主从结构，
  嵌套它会让屏幕上出现三栏。

### `void _open(_SettingsDetail detail)` <a id="open"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（约第 157 行）
- **用途：** 按当前布局所要求的方式打开一个二级页面。
- **输入：** `detail`。
- **返回：** 无。
- **副作用：** 要么选中详情栏的页面（`setState`），要么在根导航器上推入一条路由。
- **算法：** `_twoPane` 时执行 `setState(() => _detail = detail)`；否则在根导航器上推入
  `_detailPage(detail)`，与 1.5.4 之前这些行各自所做的完全一致。
- **用法：**
  ```dart
  onTap: () => _open(_SettingsDetail.webdav),
  ```
  （出自同一文件的 `_buildSettingsList`）
- **备注：** 五行全部经由此处，因此两种模式不可能彼此走样。`_twoPane` 是在 `build` 期间缓存的而非在此重新
  计算，这样一次点击所做的事情永远与它发生时屏幕上的样子相符。

### `Widget _buildDetailPane(AppLocalizations l10n)` <a id="builddetailpane"></a>
- **种类：** `_SettingsPageState` 的方法（组件辅助）
- **来源：** `lib/features/settings/views/settings_page.dart`（约第 177 行）
- **用途：** 构建两栏设置布局的右栏。
- **输入：** `l10n`——用于占位提示的文案。
- **返回：** `Widget`。
- **副作用：** 除构建控件外无。
- **算法：** 未选中任何项时，是居中的 `Icons.tune_outlined` 加其下的 `l10n.settingsSelectItem`。否则是一个以
  当前选择为 key 的 `Navigator`，其 `onGenerateRoute` 返回 `_detailPage(_detail!)`。
- **用法：**
  ```dart
  Expanded(child: _buildDetailPane(l10n)),
  ```
  （出自同一文件的 `_SettingsPageState.build`）
- **备注：** 嵌套 `Navigator` 正是给寄宿页面一条真实路由的手段，这使其内部的 `Navigator.pop` 仍有意义，也让
  它的应用栏不带前导控件。以当前选择为 key 会在每次切换时销毁并重建，这对那三个挂载时异步加载的页面而言是
  正确的。

  缩到门控之下——把设备合上——会让 `_detail` 保留但不被使用，于是列表回来，展开时选择也随之恢复。这与列表列数
  偏好被钳制而非改写是同一个道理。

### `Widget _buildSettingsList(AppLocalizations l10n, AppSettings settings, AppSettingsNotifier notifier, bool usesJapaneseCalendar)` <a id="buildsettingslist"></a>
- **种类：** `_SettingsPageState` 的方法（组件辅助）
- **来源：** `lib/features/settings/views/settings_page.dart`（约第 806 行）
- **用途：** 构建一级设置列表。
- **输入：** `l10n`；供 Riverpod 支撑的控件使用的 `settings` 与 `notifier`；以及会禁用每周起始日一行的
  `usesJapaneseCalendar`。
- **返回：** `Widget`——由各小节组成的滚动 `ListView`。
- **副作用：** 除构建控件外无；各行自身的回调有其各自的副作用。
- **算法：** 与 `build` 从前直接返回的内容一致：通用、数据、Debug、桌面与关于各小节。
- **用法：**
  ```dart
  final list = _buildSettingsList(l10n, settings, notifier, usesJapaneseCalendar);
  if (!_twoPane) return list;
  ```
  （出自同一文件的 `_SettingsPageState.build`）
- **备注：** 1.5.4 中抽出，好让同一份列表既能在窄窗口上充当整个页身、又能在宽窗口上充当左栏，而不必写两遍。
  那五个带 `›` 的行带有 `selected: _twoPane && _detail == ...`，因此当前所在的那一栏会被高亮，与系统设置应用
  的做法一致。

  它那些尾部的 `DropdownButton` 以及它们的选项都设置了 `alignment: AlignmentDirectional.centerEnd`。两半都
  是必需的：菜单弹出时会以选中项覆盖在按钮之上，因此只对齐按钮会让标签在菜单打开的瞬间横向跳动。

### `Future<void> _loadVersion()` <a id="loadversion"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 105 行）
- **用途：** 读取应用的包版本/构建号并存储供关于小节显示。
- **输入：** 无。
- **返回：** 无（设置 `_version` 字段）。
- **副作用：** 调用 `PackageInfo.fromPlatform()`（平台通道调用）。
- **算法：** Await `PackageInfo.fromPlatform()`；仍 `mounted` 时，`setState` 把 `_version` 字段设为 `'${info.version}+${info.buildNumber}'`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    _loadVersion();
    ...
  }
  ```
- **备注：** 无。

### `String _calendarLayoutLabel(HomeCalendarLayout layout, AppLocalizations l10n)` <a id="calendarlayoutlabel"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 140 行）
- **用途：** 把 `HomeCalendarLayout` 枚举值翻译为其本地化显示标签，供主页日历布局下拉框使用。
- **输入：** `layout` — `HomeCalendarLayout.local` 或 `.japanese`；`l10n` — 当前 `AppLocalizations`。
- **返回：** 匹配的本地化 `String`。
- **副作用：** 无。
- **算法：** `switch` 表达式：`local` -> `l10n.settingsHomeCalendarLayoutLocal`，`japanese` -> `l10n.settingsHomeCalendarLayoutJapanese`。
- **用法：**
  ```dart
  for (final layout in HomeCalendarLayout.values)
    DropdownMenuItem(
      value: layout,
      child: Text(_calendarLayoutLabel(layout, l10n)),
    ),
  ```
- **备注：** 无。

### `String _homeCalendarTimeBasisLabel(HomeCalendarTimeBasis basis, AppLocalizations l10n)` <a id="homecalendartimebasislabel"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 155 行）
- **用途：** 把 `HomeCalendarTimeBasis` 枚举值翻译为其本地化显示标签，供主页日历时间基准下拉框使用。
- **输入：** `basis` — `HomeCalendarTimeBasis.jst` 或 `.local`；`l10n` — 当前 `AppLocalizations`。
- **返回：** 匹配的本地化 `String`。
- **副作用：** 无。
- **算法：** `switch` 表达式：`jst` -> `l10n.settingsHomeCalendarTimeBasisJst`，`local` -> `l10n.settingsHomeCalendarTimeBasisLocal`。
- **用法：**
  ```dart
  for (final basis in HomeCalendarTimeBasis.values)
    DropdownMenuItem(
      value: basis,
      child: Text(_homeCalendarTimeBasisLabel(basis, l10n)),
    ),
  ```
- **备注：** 无。

### `Future<void> _loadMetadataSettings()` <a id="loadmetadatasettings"></a>
- **种类：** `_SettingsPageState` 的方法
- **用途：** 加载后台资料更新策略与封面预取开关。
- **副作用：** 读取 `storage_config.json` 并重建。
- **备注：** 走 `MetadataUpdateService.effectivePolicy` 而不是直接读原始字符串，因此控件显示的是实际
  生效的行为 —— 未存储时为平台默认，而不是一个固定值。仅在 `AppFlavor.isFull` 下调用。

### `Future<void> _setMetadataPolicy(MetadataUpdatePolicy policy)` <a id="setmetadatapolicy"></a>
- **种类：** `_SettingsPageState` 的方法
- **副作用：** 写入 `storage_config.json`，然后启动或停止后台服务。
- **备注：** 在这里启停，正是让改动立即生效而不是等到下次启动的原因。

### `String _metadataPolicyLabel(MetadataUpdatePolicy policy, AppLocalizations l10n)` <a id="metadatapolicylabel"></a>
- **种类：** `_SettingsPageState` 的方法
- **备注：** `noCellular` 的文案写作「不使用蜂窝数据」而非「仅 Wi-Fi」，因为该检查在有线桌面连接下同样
  放行 —— 也因为它检测的是链路类型，而不是链路是否计费。见
  [`../../../../platform-notes.md`](../../../../platform-notes.md)。

### `String _weekdayLabel(int weekday, AppLocalizations l10n)` <a id="weekdaylabel"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 170 行）
- **用途：** 把 Dart 星期数字翻译为其本地化短标签，供周起始日下拉框使用。
- **输入：** `weekday` — Dart 的 `1`（周一）到 `7`（周日）；`l10n` — 当前 `AppLocalizations`。
- **返回：** 匹配的本地化短星期名，`weekday` 越界且钳制后仍落在未使用的索引 0 槽位时为 `''`。
- **副作用：** 无。
- **算法：**
  1. 构建固定 8 条目列表 `['', dayMon, dayTue, dayWed, dayThu, dayFri, daySat, daySun]`（索引 0 是未使用的占位符，使索引 `1..7` 与 Dart 的周一=1..周日=7 对齐）。
  2. 返回 `days[weekday.clamp(1, 7)]`。
- **用法：**
  ```dart
  for (final weekday in weekdaySequence(defaultWeekStartDay))
    DropdownMenuItem(
      value: weekday,
      child: Text(_weekdayLabel(weekday, l10n)),
    ),
  ```
  （`weekdaySequence`/`defaultWeekStartDay` 来自 [`../../../shared/utils/calendar_preferences.md`](../../../shared/utils/calendar_preferences.md)。）
- **备注：** 此方法上的文档注释显式点出周一=1..周日=7 编号约定；`clamp(1, 7)` 防止越界输入到达占位索引 0。

### `Future<void> _exportData()` <a id="exportdata"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 197 行）
- **用途：** 让用户把动画数据导出为 ZIP 捆绑或 Markdown 摘要到他们选择的文件夹。
- **输入：** 无（读取 `context`）。
- **返回：** 无。
- **副作用：** 打开格式选择对话框和目录选择器；经 `ImportExportService` 写入新文件到磁盘；显示成功 snackbar。
- **算法：**
  1. 显示提供 `'zip'` 或 `'markdown'` 的 `SimpleDialog`；被关闭则停止。
  2. 经 `FilePicker.platform.getDirectoryPath()` 提示目标目录；取消则停止。
  3. 选择是 `'markdown'` 时，调用 `ImportExportService.exportMarkdown(dir)`（[`../../../shared/services/import_export_service.md#exportmarkdown`](../../../shared/services/import_export_service.md#exportmarkdown)）；否则调用 `ImportExportService.exportZIP(dir)`（[`#exportzip`](../../../shared/services/import_export_service.md#exportzip)）。
  4. 返回非 null 路径时，显示 `exportSuccess` snackbar。
- **用法：**
  ```dart
  ListTile(
    leading: const Icon(Icons.file_upload_outlined),
    title: Text(l10n.exportData),
    onTap: _exportData,
  ),
  ```
- **备注：** 返回的 `null` 路径（导出失败）静默不报告——与 `_importData` 不同，这里没有失败 snackbar 分支。

### `Future<void> _importData()` <a id="importdata"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 257 行）
- **用途：** 让用户选择先前导出的 ZIP 捆绑、确认并导入它。
- **输入：** 无（读取 `context`）。
- **返回：** 无。
- **副作用：** 打开文件选择器和确认对话框；可能经 `ImportExportService.importZIP` 覆盖本地 `anime_data.json`/图像；显示成功/失败 snackbar。
- **算法：**
  1. `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip'])`；未选文件则停止。
  2. 显示 `AlertDialog` 确认；未确认则停止。
  3. 调用 `ImportExportService.importZIP(path)`（[`../../../shared/services/import_export_service.md#importzip`](../../../shared/services/import_export_service.md#importzip)）。
  4. 按返回的 `bool` 显示 `importSuccess` 或 `importFailed`。
- **用法：**
  ```dart
  ListTile(
    leading: const Icon(Icons.file_download_outlined),
    title: Text(l10n.importData),
    onTap: _importData,
  ),
  ```
- **备注：** 导入在 `ImportExportService.importZIP` 内部强制自己的路径穿越保护（见 [`../../../backup-restore.md`](../../../../backup-restore.md)）；此方法只驱动选择器和确认 UI。

### `Future<void> _openDataFolder()` <a id="opendatafolder"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 298 行）
- **用途：** 在宿主操作系统的文件资源管理器中打开应用数据目录（仅桌面）。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 派生子进程（`explorer`、`open` 或 `xdg-open`）。
- **算法：**
  1. 经 `AnimeStorage.getAppDir()`（[`../../../features/anime/services/anime_storage.md#getappdir`](../../../features/anime/services/anime_storage.md#getappdir)）取应用目录。
  2. 按平台分支：Windows -> `Process.run('explorer', [appDir.path])`；macOS -> `Process.run('open', [appDir.path])`；Linux -> 把路径转换为 `file:` URI 并 `Process.run('xdg-open', [uri.toFilePath()])`。
- **用法：**
  ```dart
  if (_isDesktop)
    ListTile(
      leading: const Icon(Icons.folder_open_outlined),
      title: Text(l10n.dataMigration),
      subtitle: Text(l10n.dataMigrationDesc),
      onTap: _openDataFolder,
    ),
  ```
- **备注：** 平台不是 Windows/macOS/Linux（如移动端）时没有显式处理——调用它的 `ListTile` 本身只在 `if (_isDesktop)` 下显示，因此那种情况在调用点被过滤掉，而不是在此方法内。

### `Future<void> _loadStoragePath()` <a id="loadstoragepath"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 315 行）
- **用途：** 加载并显示当前数据存储路径（桌面可配置）。
- **输入：** 无。
- **返回：** 无（设置 `_storagePath`）。
- **副作用：** 经 `AnimeStorage.getStoragePath()` 读取存储路径配置。
- **算法：** Await `AnimeStorage.getStoragePath()`（[`../../../features/anime/services/anime_storage.md#getstoragepath`](../../../features/anime/services/anime_storage.md#getstoragepath)）；`mounted` 时 `setState` 路径。
- **用法：** 从 `initState` 调用，并在 `_showStoragePathDialog` 成功应用新路径后再次调用。
- **备注：** 无。

### `Future<void> _loadReminder()` <a id="loadreminder"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 325 行）
- **用途：** 加载持久化的提醒启用标志和时间，把存储的 `"HH:MM"` 字符串解析为 `TimeOfDay`。
- **输入：** 无。
- **返回：** 无（设置 `_reminderEnabled`/`_reminderTime`）。
- **副作用：** 经 `AnimeStorage.readConfig()` 读取应用配置。
- **算法：**
  1. Await `AnimeStorage.readConfig()`（[`../../../features/anime/services/anime_storage.md#readconfig`](../../../features/anime/services/anime_storage.md#readconfig)）。
  2. 把 `config['reminderEnabled']` 作为 `bool?` 读取，默认为 `false`。
  3. `config['reminderTime']` 是非 null 字符串时，按 `':'` 拆分并 `int.tryParse` 每一半，解析失败时默认为小时 `18`/分钟 `0`，并构建 `TimeOfDay`。
- **用法：** 从 `initState` 调用。
- **备注：** 少于两个 `:` 分隔部分的格式错误 `reminderTime` 字符串会在 `p[1]` 抛 `RangeError`——代码假设持久化格式总是良构的，因为它只被 [`_pickReminderTime`](#pickremindertime) 以相同的 `"HH:MM"` 形态写入。

### `Future<void> _loadTraySettings()` <a id="loadtraysettings"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 346 行）
- **用途：** 加载持久化的最小化到托盘和关闭到托盘标志（仅桌面）。
- **输入：** 无。
- **返回：** 无（设置 `_minimizeToTray`/`_closeToTray`）。
- **副作用：** 经 `AnimeStorage.readConfig()` 读取应用配置。
- **算法：** Await `AnimeStorage.readConfig()`；把 `minimizeToTray`/`closeToTray` 作为 `bool?` 读取，两者都默认为 `false`。
- **用法：** 从 `initState` 调用，受 `if (_isDesktop)` 守卫。
- **备注：** 无。

### `Future<void> _loadAutoStartStatus()` <a id="loadautostartstatus"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 360 行）
- **用途：** 查询操作系统级开机自启注册状态（仅桌面）。
- **输入：** 无。
- **返回：** 无（设置 `_autoStart`）。
- **副作用：** 调用 `launchAtStartup.isEnabled()`（`launch_at_startup` 包）。
- **算法：** Await `launchAtStartup.isEnabled()`；`mounted` 时 `setState` `_autoStart`。
- **用法：** 从 `initState` 调用，受 `if (_isDesktop)` 守卫。
- **备注：** `launch_at_startup` 如何处理桌面自动启动见 [`../../../platform-notes.md`](../../../../platform-notes.md)。

### `Future<void> _loadApiSettings()` <a id="loadapisettings"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 371 行）
- **用途：** 加载持久化的本地 API 服务器设置（启用标志、端口、监听地址、用户名、密码）（仅桌面）。
- **输入：** 无。
- **返回：** 无（设置 `_apiEnabled`/`_apiPort`/`_apiListenAddress`/`_apiUsername`/`_apiPassword`）。
- **副作用：** 经 `AnimeStorage.readConfig()` 读取应用配置。
- **算法：** Await `AnimeStorage.readConfig()`；读取五个 `api*` 键各一，带默认值（`apiEnabled: false`、`apiPort: 7788`、`apiListenAddress: 'localhost'`、`apiUsername`/`apiPassword: ''`）。
- **用法：** 从 `initState` 调用，受 `if (_isDesktop)` 守卫。
- **备注：** `7788` 默认值和 `'localhost'` 默认值与 [`../../../platform-notes.md`](../../../../platform-notes.md) 中记录的默认值一致。

### `Future<void> _showApiSettingsDialog()` <a id="showapisettingsdialog"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 388 行）
- **用途：** 让用户编辑本地 API 服务器的监听地址、端口、用户名和密码，持久化变更，并重启服务器使生效。
- **输入：** 无（读取当前 `_api*` 字段预填对话框的 `TextEditingController`）。
- **返回：** 无。
- **副作用：** 经 `AnimeStorage.writeConfig` 写四个配置键；经 `LocalApiServer.restart()` 重启本地 API 服务器；显示带结果端口的 snackbar。
- **算法：**
  1. 显示带四个从当前设置预填的 `TextField` 的 `AlertDialog`。
  2. 未保存（对话框关闭）或之后已卸载时停止。
  3. 用 `int.tryParse(...) ?? 7788` 解析端口；修剪地址，修剪后为空则默认 `'localhost'`；修剪用户名/密码。
  4. 读取当前配置，覆盖 `apiPort`/`apiListenAddress`/`apiUsername`/`apiPassword`（空用户名/密码存储为 `null`，不是 `''`），并 `AnimeStorage.writeConfig(config)`（[`../../../features/anime/services/anime_storage.md#writeconfig`](../../../features/anime/services/anime_storage.md#writeconfig)）。
  5. `setState` 四个本地字段为新值。
  6. Await `LocalApiServer.restart()`（[`../../../shared/services/local_api_server.md#restart`](../../../shared/services/local_api_server.md#restart)），使运行中的服务器（如有）拾取新地址/端口/凭据。
  7. `mounted` 时显示 `settingsApiRestarted(LocalApiServer.port)`。
- **用法：**
  ```dart
  ListTile(
    leading: const Icon(Icons.settings_outlined),
    title: Text(l10n.settingsApiServer),
    trailing: const Icon(Icons.chevron_right),
    enabled: _apiEnabled,
    onTap: _apiEnabled ? _showApiSettingsDialog : null,
  ),
  ```
- **备注：** 只在 `_apiEnabled` 为 true 时可达（否则 `ListTile` 的 `onTap` 为 `null`）。按 [`../../../platform-notes.md`](../../../../platform-notes.md)，无凭据的非回环监听地址在服务器层被拒绝，不在这里校验——此对话框会乐意保存不安全的组合，让 `LocalApiServer.restart()`/`start()` 拒绝它。

### `Future<void> _setReminderEnabled(bool v)` <a id="setreminderenabled"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 472 行）
- **用途：** 打开或关闭每日观看提醒并持久化变更。
- **输入：** `v` — 新的开关状态。
- **返回：** 无。
- **副作用：** 把 `reminderEnabled` 写入应用配置；重启 `ReminderService` 的周期检查。
- **算法：**
  1. `setState` 立即更新 `_reminderEnabled`。
  2. 读取配置，设 `config['reminderEnabled'] = v`，`AnimeStorage.writeConfig(config)`。
  3. 无条件调用 `ReminderService.startPeriodicCheck()`（[`../../../shared/services/reminder_service.md`](../../../shared/services/reminder_service.md)）（即使关闭提醒时）。
- **用法：**
  ```dart
  SwitchListTile(
    secondary: const Icon(Icons.notifications_outlined),
    title: Text(l10n.settingsReminder),
    value: _reminderEnabled,
    onChanged: _setReminderEnabled,
  ),
  ```
- **备注：** `ReminderService.startPeriodicCheck()` 无论新值如何都被调用；服务本身大概负责在提醒禁用时空操作。

### `Future<void> _pickReminderTime()` <a id="pickremindertime"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 485 行）
- **用途：** 让用户选择新的每日提醒时间并持久化它，重置"今天已提醒"跟踪，使新时间立即生效。
- **输入：** 无（用当前 `_reminderTime` 作为选择器的初始值）。
- **返回：** 无。
- **副作用：** 把 `reminderTime`（并移除 `lastReminderDate`）写入应用配置；有条件地重启 `ReminderService` 的周期检查。
- **算法：**
  1. 以 `_reminderTime` 为种子的 `showTimePicker`；取消则停止。
  2. `setState` 新 `_reminderTime`。
  3. 读取配置，把所选时间格式化为零填充 `"HH:MM"`，存为 `config['reminderTime']`，并 `config.remove('lastReminderDate')`，使今天不被当作旧时间下已处理。
  4. `AnimeStorage.writeConfig(config)`。
  5. `_reminderEnabled` 时调用 `ReminderService.startPeriodicCheck()`。
- **用法：**
  ```dart
  ListTile(
    leading: const SizedBox(width: 24),
    title: Text(l10n.settingsReminderTime),
    trailing: TextButton(
      onPressed: _pickReminderTime,
      child: Text(_reminderTime.format(context)),
    ),
  ),
  ```
- **备注：** 移除 `lastReminderDate`（而不是留着它）正是让当天的时间变更立即生效、而不是等到明天的方式。

### `Future<void> _showStoragePathDialog()` <a id="showstoragepathdialog"></a>
- **种类：** `_SettingsPageState` 的方法
- **来源：** `lib/features/settings/views/settings_page.dart`（第 506 行）
- **用途：** 让用户设置自定义数据存储路径，或重置为默认位置（仅桌面）。
- **输入：** 无（用当前 `_storagePath` 预填对话框的文本字段）。
- **返回：** 无。
- **副作用：** 可能经 `AnimeStorage.setStoragePath` 移动应用的数据目录；显示结果 snackbar。
- **算法：**
  1. 显示带文本字段（预填 `_storagePath`）和三个操作的 `AlertDialog`：取消（`null`）、"重置默认"（空字符串 `''`）、确认（修剪后的文本字段值）。
  2. 对话框返回 `null`（取消）时停止。
  3. 调用 `AnimeStorage.setStoragePath(pathToSet)`（[`../../../features/anime/services/anime_storage.md#setstoragepath`](../../../features/anime/services/anime_storage.md#setstoragepath)）时把空结果字符串当作 `null`（重置为默认）。
  4. 返回 `true` 时，调用 [`_loadStoragePath`](#loadstoragepath) 刷新显示的路径，并按路径是重置还是设置显示 `settingsResetDefaultLocation` 或 `settingsStoragePathUpdated`。
- **用法：**
  ```dart
  if (_isDesktop)
    ListTile(
      leading: const Icon(Icons.folder_outlined),
      title: Text(l10n.settingsStorageLocation),
      subtitle: Text(_storagePath, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: _showStoragePathDialog,
    ),
  ```
- **备注：** `AnimeStorage.setStoragePath` 返回 `false` 时（如新路径无效或移动失败），此方法完全不显示失败反馈——对话框只是关闭，显示的路径不变。
