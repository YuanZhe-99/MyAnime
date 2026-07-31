# lib/features/anime/services/anime_storage.dart

纯静态 `AnimeStorage` 类：`anime_data.json`（持久化的 `AnimeData` 列表）和 `storage_config.json`（每个设备本地偏好——主题、语言区域、日历周起始/布局/时间基准、存储路径覆盖等）的唯一磁盘访问点。它解析活动的应用数据目录（默认 vs 自定义路径），执行原子 tmp-重命名写入，并在每次保存后通知 `AutoSyncService`/`ReminderService`。`storage_config.json` 中持久化的完整字段清单和持久化数据清单表见 [`../../../../data-formats.md`](../../../../data-formats.md)，`AutoSyncService` 如何响应 `save()` 见 [`../../../../sync.md`](../../../../sync.md)。本类加载和保存的 `Anime`/`AnimeData` 模型在 [`../models/anime.md`](../models/anime.md) 中记录。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getDefaultAppDir`](#getdefaultappdir) | 静态方法（`AnimeStorage`） | A | 解析（需要时创建）默认的 `Documents/MyAnime` 风格应用目录。 |
| [`_getConfigFile`](#getconfigfile) | 静态方法（`AnimeStorage`） | A | 返回 `storage_config.json`，无论自定义数据路径如何总是在默认位置。 |
| [`_loadConfig`](#loadconfig) | 静态方法（`AnimeStorage`） | A | 每进程一次从配置加载自定义存储路径覆盖。 |
| [`getAppDir`](#getappdir) | 静态方法（`AnimeStorage`） | A | 返回活动的应用数据目录（配置了自定义路径则用它，否则默认）。 |
| [`_getFile`](#getfile) | 静态方法（`AnimeStorage`） | A | 为活动应用目录下的给定文件名构建 `File`。 |
| [`getDataFile`](#getdatafile) | 静态方法（`AnimeStorage`） | A | 返回主 `anime_data.json` 文件，供直接底层访问。 |
| [`getStoragePath`](#getstoragepath) | 静态方法（`AnimeStorage`） | A | 返回活动存储目录路径，供 UI 显示。 |
| [`setStoragePath`](#setstoragepath) | 静态方法（`AnimeStorage`） | A | 更新自定义存储目录并迁移受管数据文件。 |
| [`load`](#load) | 静态方法（`AnimeStorage`） | A | 把 `anime_data.json` 加载进 `AnimeData`。 |
| [`_atomicWrite`](#atomicwrite) | 静态方法（`AnimeStorage`） | A | 通过临时文件-重命名步骤写入文件。 |
| [`save`](#save) | 静态方法（`AnimeStorage`） | A | 持久化 `AnimeData`，然后通知自动同步和提醒。 |
| [`addOrUpdate`](#addorupdate) | 静态方法（`AnimeStorage`） | A | 按 `id` 插入或替换一条动画记录并保存。 |
| [`deleteAnime`](#deleteanime) | 静态方法（`AnimeStorage`） | A | 按 `id` 移除一条动画记录并保存。 |
| [`readConfig`](#readconfig) | 静态方法（`AnimeStorage`） | A | 把 `storage_config.json` 作为原始 JSON 映射读取。 |
| [`writeConfig`](#writeconfig) | 静态方法（`AnimeStorage`） | A | 原子写入 `storage_config.json`。 |
| [`getThemeMode`](#getthememode) | 静态方法（`AnimeStorage`） | A | 读取持久化的主题模式字符串。 |
| [`setThemeMode`](#setthememode) | 静态方法（`AnimeStorage`） | A | 持久化（或清除）主题模式字符串。 |
| [`getLocaleTag`](#getlocaletag) | 静态方法（`AnimeStorage`） | A | 读取持久化的语言区域标签。 |
| [`setLocaleTag`](#setlocaletag) | 静态方法（`AnimeStorage`） | A | 持久化（或清除）语言区域标签。 |
| [`getWeekStartDay`](#getweekstartday) | 静态方法（`AnimeStorage`） | A | 读取持久化的全局日历周起始日。 |
| [`setWeekStartDay`](#setweekstartday) | 静态方法（`AnimeStorage`） | A | 持久化全局日历周起始日。 |
| [`getHomeCalendarLayout`](#gethomecalendarlayout) | 静态方法（`AnimeStorage`） | A | 读取持久化的主页日历日名布局偏好。 |
| [`setHomeCalendarLayout`](#sethomecalendarlayout) | 静态方法（`AnimeStorage`） | A | 持久化主页日历日名布局偏好。 |
| [`getHomeCalendarTimeBasis`](#gethomecalendartimebasis) | 静态方法（`AnimeStorage`） | A | 读取持久化的主页日历 JST-vs-本地时间基准偏好。 |
| [`setHomeCalendarTimeBasis`](#sethomecalendartimebasis) | 静态方法（`AnimeStorage`） | A | 持久化主页日历 JST-vs-本地时间基准偏好。 |

## 文档

### `static Future<Directory> _getDefaultAppDir()` <a id="getdefaultappdir"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 30 行）
- **用途：** 解析默认应用数据目录（`<平台文档目录>/MyAnime`），缺失时创建它。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 可能创建平台文档目录下的 `MyAnime` 子目录。
- **算法：** 解析 `getApplicationDocumentsDirectory()`（来自 `path_provider`），拼接 `'MyAnime'`，不存在时递归创建。
- **用法：**
  ```dart
  return _getDefaultAppDir();
  ```
  （`AnimeStorage.getAppDir`，同一文件，未配置自定义路径时）
- **备注：** `storage_config.json` 本身总是住在这里（见 [`_getConfigFile`](#getconfigfile)），与任何自定义数据路径覆盖无关。

### `static Future<File> _getConfigFile()` <a id="getconfigfile"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 44 行）
- **用途：** 返回 `storage_config.json` 文件，它无论自定义存储路径如何总是位于默认应用目录。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 无直接（委托给 `_getDefaultAppDir`，它可能创建目录）。
- **算法：** `File(p.join((await _getDefaultAppDir()).path, _configFileName))`。
- **用法：**
  ```dart
  static Future<Map<String, dynamic>> readConfig() async {
    final file = await _getConfigFile();
  ```
  （`AnimeStorage.readConfig`，同一文件）
- **备注：** 这正是通过 `setStoragePath` 移动动画数据存储路径时绝不移动 `storage_config.json` 本身的原因——配置文件（和存在其中的自定义路径设置）必须留在固定位置以便被发现。

### `static Future<void> _loadConfig()` <a id="loadconfig"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 54 行）
- **用途：** 每进程恰好一次，把 `storage_config.json` 中的自定义存储路径覆盖加载进内存 `_customPath`。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 设置静态 `_customPath` 和 `_configLoaded` 字段；首次调用读取 `storage_config.json`。
- **算法：** `_configLoaded` 已为 `true` 时无操作。否则读取配置文件（如果存在）并从其 `storagePath` 键设置 `_customPath`；读取/解码期间的任何异常被静默吞掉。此后无条件把 `_configLoaded` 设为 `true`，即使失败。
- **用法：**
  ```dart
  static Future<Directory> getAppDir() async {
    await _loadConfig();
  ```
  （`AnimeStorage.getAppDir`，同一文件）
- **备注：** 因为失败的加载仍标记 `_configLoaded = true`，首次启动的瞬态读取错误会让进程剩余时间（直到重启）永久回退到默认路径，而不是在下一次调用时重试。

### `static Future<Directory> getAppDir()` <a id="getappdir"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 72 行）
- **用途：** 返回应用当前应读写动画数据文件的目录——设置且非空的自定义路径，否则默认的 `Documents/MyAnime` 目录。
- **输入：** 无。
- **返回：** `Future<Directory>`。
- **副作用：** 可能创建解析出的目录（自定义或默认，如果不存在）；触发 `_loadConfig()` 的一次性配置读取。
- **算法：**
  1. `await _loadConfig()`。
  2. `_customPath` 已设置且非空时，解析/创建那个 `Directory` 并返回。
  3. 否则返回 `_getDefaultAppDir()`。
- **用法：**
  ```dart
  final appDir = await AnimeStorage.getAppDir();
  if (Platform.isWindows) {
    await Process.run('explorer', [appDir.path]);
  ```
  （`lib/features/settings/views/settings_page.dart`，`_openDataFolder`——"打开数据文件夹"按钮）
- **备注：** 本类中每个其他文件解析方法（`_getFile`、`getDataFile`、`load`、`save`，以及应用内每个存储逐动画数据或图像的其他服务）都走这个方法，因此 `_customPath` 更新的那一刻，存储路径变更对它们全部生效。

### `static Future<File> _getFile(String name)` <a id="getfile"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 89 行）
- **用途：** 为当前活动应用目录下的给定文件名构建 `File` 句柄。
- **输入：** `name` — 如 `'anime_data.json'`。
- **返回：** `Future<File>`。
- **副作用：** 无直接（委托给 `getAppDir`，它可能创建目录）。
- **算法：** `File(p.join((await getAppDir()).path, name))`。
- **用法：**
  ```dart
  static Future<File> getDataFile() => _getFile(_dataFileName);
  ```
  （`AnimeStorage.getDataFile`，同一文件）
- **备注：** 无。

### `static Future<File> getDataFile()` <a id="getdatafile"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 99 行）
- **用途：** 为需要原始文件/路径而非解析后 `AnimeData` 模型的调用方返回 `anime_data.json` 的 `File` 句柄。
- **输入：** 无。
- **返回：** `Future<File>`。
- **副作用：** 无直接（经 `_getFile`/`getAppDir`，可能创建应用目录）。
- **算法：** `_getFile(_dataFileName)`。
- **用法：** 目前本仓库中没有其他地方调用——其他每个调用方都走 [`load`](#load)/[`save`](#save) 取解析模型。直接使用会是这样：
  ```dart
  final file = await AnimeStorage.getDataFile();
  ```
- **备注：** 保留为公共底层逃生舱（如未来某个功能需要原始文件，比如无需完整 JSON 解析地读取其原始字节/大小），尽管应用目前没有东西用它。

### `static Future<String> getStoragePath()` <a id="getstoragepath"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 106 行）
- **用途：** 把活动存储目录路径作为纯字符串返回，供设置中显示。
- **输入：** 无。
- **返回：** `Future<String>`。
- **副作用：** 无直接（经 `getAppDir`，可能创建目录）。
- **算法：** `(await getAppDir()).path`。
- **用法：**
  ```dart
  Future<void> _loadStoragePath() async {
    final path = await AnimeStorage.getStoragePath();
    if (mounted) setState(() => _storagePath = path);
  }
  ```
  （`lib/features/settings/views/settings_page.dart`）
- **备注：** 无。

### `static Future<bool> setStoragePath(String? newPath)` <a id="setstoragepath"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 116 行）
- **用途：** 更改自定义存储目录（`null` 时重置为默认），并把受管数据文件迁移到新位置。
- **输入：** `newPath` — 绝对路径，或 `null` 重置为默认位置。
- **返回：** `Future<bool>` — 成功为 `true`，任何步骤抛出为 `false`。
- **副作用：** 更新 `_customPath`；读写 `storage_config.json`；可能从旧目录复制-删除 `anime_data.json` 到新目录。
- **算法：**
  1. 经 `getAppDir()` 捕获 `oldDir`（用本次调用*之前*生效的路径）。
  2. 设置 `_customPath = newPath`；在配置映射中更新 `storagePath`（设置它，`newPath` 为 `null` 时 `remove` 它）并经 [`writeConfig`](#writeconfig) 写回配置。
  3. 再经 `getAppDir()` 解析 `newDir`（现在反映新路径）；与 `oldDir` 相同路径时立即返回 `true`（无需迁移）。
  4. 对 `_dataFileNames` 中的每个受管数据文件名（目前只有 `anime_data.json`）：目标文件已存在则不动它（目标胜出）；否则源文件存在则复制到目标并删除源。
  5. 此序列中任何位置的任何异常都被捕获并转为 `false` 返回。
- **用法：**
  ```dart
  final ok = await AnimeStorage.setStoragePath(pathToSet);
  if (ok) {
    await _loadStoragePath();
  ```
  （`lib/features/settings/views/settings_page.dart`，从设置更改存储路径）
- **备注：** 目标处的既有数据总是胜过迁移数据——新路径已存在文件时（如上次会话用过该位置），旧目录的副本被静默留在原地而不是覆盖它。图像和其他非 `_dataFileNames` 文件不被此方法迁移。

### `static Future<AnimeData> load()` <a id="load"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 154 行）
- **用途：** 把 `anime_data.json` 加载并解析进 `AnimeData`。
- **输入：** 无。
- **返回：** `Future<AnimeData>` — 文件缺失或空白时为 `const AnimeData()`（空）。
- **副作用：** 从活动应用目录读取 `anime_data.json`。
- **算法：** 解析数据文件；不存在或修剪后内容为空时返回空 `AnimeData`；否则 `jsonDecode` 并委托给 `AnimeData.fromJson`（见 [`../models/anime.md`](../models/anime.md#animedata-fromjson)）。
- **用法：**
  ```dart
  final data = await AnimeStorage.load();
  if (mounted) setState(() => _allAnime = data.animeList);
  ```
  （`lib/features/anime/views/home_page.dart`）
- **备注：** 格式错误（非空但无效）的 JSON 文件把 `jsonDecode`/`FormatException` 传播给调用方，而不是在这里被捕获——每个直接调用 `load()` 的 UI 调用点都在自己的 `initState`/异步加载流程内，没有针对此失败模式的专门 try/catch。

### `static Future<void> _atomicWrite(File file, String content)` <a id="atomicwrite"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 169 行）
- **用途：** 写入文本到文件，绝不在应用写入中途被杀时留下截断/损坏文件。
- **输入：** `file`、`content`。
- **返回：** 无。
- **副作用：** 写入 `<file>.tmp` 然后重命名覆盖 `file`。
- **算法：** 对同级 `.tmp` 路径 `tmp.writeAsString(content, flush: true)`，然后 `tmp.rename(file.path)`（同一文件系统上原子）。
- **用法：**
  ```dart
  static Future<void> save(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
    await _atomicWrite(file, jsonStr);
  ```
  （`AnimeStorage.save`，同一文件）
- **备注：** 与 `WebDAVService._atomicWrite`（见 [`../../../shared/services/webdav_service.md`](../../../shared/services/webdav_service.md#atomicwrite)）相同的 tmp-重命名形态，但这个不使 tmp 文件名唯一——这里可接受，因为应用同一时刻只有一个进程写入给定的数据/配置路径。

### `static Future<void> save(AnimeData data)` <a id="save"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 182 行）
- **用途：** 把 `AnimeData` 持久化到 `anime_data.json`，并通知依赖数据变更的系统。
- **输入：** `data`。
- **返回：** 无。
- **副作用：** 原子覆盖 `anime_data.json`；调用 `AutoSyncService.instance.notifySaved()`（见 [`../../../../sync.md`](../../../../sync.md)）和 `ReminderService.notifyDataChanged()`，使计划通知正文保持最新。
- **算法：** 解析数据文件，用 `JsonEncoder.withIndent('  ')` 序列化 `data.toJson()`（缩进为什么对同步的未变化文件快速路径承载负载见 [`../../../../data-formats.md`](../../../../data-formats.md)），经 [`_atomicWrite`](#atomicwrite) 写入，然后触发两个通知。
- **用法：**
  ```dart
  await AnimeStorage.save(AnimeData(animes: list));
  ```
  （`lib/shared/services/file_open_service.dart`，批量 `.myanimeitem` 导入后）
- **备注：** 应用中每个变更路径（`addOrUpdate`、`deleteAnime`，以及导入/重复合并/本地 API 代码中的每个直接 `save(AnimeData(...))` 调用）都汇入这一个方法，因此自动同步和提醒永远不需要调用方单独触发。

### `static Future<void> addOrUpdate(Anime anime)` <a id="addorupdate"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 197 行）
- **用途：** 插入一条新动画记录或替换同 `id` 的既有记录，然后持久化。
- **输入：** `anime`。
- **返回：** 无。
- **副作用：** 经 [`load`](#load)/[`save`](#save) 对 `anime_data.json` 做完整读-改-写（带 `save` 的自动同步/提醒通知）。
- **算法：** 加载当前数据，经 `indexWhere` 找 `id` 匹配的既有记录索引；找到则在那里替换，否则追加；保存结果列表。
- **用法：**
  ```dart
  await AnimeStorage.addOrUpdate(updated);
  ```
  （`lib/features/anime/views/anime_edit_page.dart`，保存编辑后的动画）
- **备注：** 对另一个并发的 `addOrUpdate`/`deleteAnime` 调用不并发安全（经典读-改-写竞争）——考虑到应用对每个数据目录是单用户/单进程，可接受。

### `static Future<void> deleteAnime(String id)` <a id="deleteanime"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 214 行）
- **用途：** 按 id 移除一条动画记录并持久化结果。
- **输入：** `id`。
- **返回：** 无。
- **副作用：** 经 `load`/`save` 对 `anime_data.json` 做完整读-改-写。
- **算法：** 加载当前数据，过滤掉 `id` 匹配的任何记录，保存过滤后的列表。
- **用法：**
  ```dart
  await AnimeStorage.deleteAnime(_anime!.id);
  ```
  （`lib/features/anime/views/anime_detail_page.dart`，删除当前查看的动画）
- **备注：** `id` 不匹配任何既有记录时是空操作（不是错误）。

### `static Future<Map<String, dynamic>> readConfig()` <a id="readconfig"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 227 行）
- **用途：** 把 `storage_config.json` 作为原始、无类型 JSON 映射读取——每个设备本地偏好的共享后端存储。
- **输入：** 无。
- **返回：** `Future<Map<String, dynamic>>` — 文件缺失或空白时为 `{}`。
- **副作用：** 读取 `storage_config.json`。
- **算法：** 存在性和空白内容检查提前返回 `{}`；否则 `jsonDecode` 文件内容。
- **用法：**
  ```dart
  final config = await AnimeStorage.readConfig();
  ```
  （`lib/shared/services/tray_service.dart`，读取托盘/开机自启偏好）
- **备注：** 与 `load()` 不同，格式错误（非空、无效 JSON）的配置文件在这里也会传播解码异常——这一层没有针对损坏配置文件的防御性 try/catch。

### `static Future<void> writeConfig(Map<String, dynamic> config)` <a id="writeconfig"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 240 行）
- **用途：** 持久化完整的 `storage_config.json` 映射。
- **输入：** `config` — 要写入的完整映射（本文件每个 getter/setter 对都读取整个映射、改动一个键并全部写回）。
- **返回：** 无。
- **副作用：** 原子覆盖 `storage_config.json`。
- **算法：** 用 `JsonEncoder.withIndent('  ')` 序列化 `config`，经 [`_atomicWrite`](#atomicwrite) 写入。
- **用法：**
  ```dart
  final config = await AnimeStorage.readConfig();
  config['themeMode'] = mode;
  await AnimeStorage.writeConfig(config);
  ```
  （下方每个 `setXxx` 方法使用的模式，`lib/shared/services/tray_service.dart` 也直接用）
- **备注：** 因为每个 setter 都对同一文件做完整读-改-写，来自不同代码路径的两次并发配置写入可能竞争并丢一次变更——在单进程的桌面/移动应用中不是实际问题。

### `static Future<String?> getThemeMode()` <a id="getthememode"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 253 行）
- **用途：** 读取持久化的主题模式偏好。
- **输入：** 无。
- **返回：** `Future<String?>` — `'light'`、`'dark'` 或 `null`（跟随系统）。
- **副作用：** 无（经 `readConfig`，只读文件访问）。
- **算法：** `(await readConfig())['themeMode'] as String?`。
- **用法：**
  ```dart
  final modeStr = await AnimeStorage.getThemeMode();
  ```
  （`lib/shared/providers/app_settings.dart`，`_loadPersisted`）
- **备注：** 无。

### `static Future<void> setThemeMode(String? mode)` <a id="setthememode"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 263 行）
- **用途：** 持久化（或清除）主题模式偏好。
- **输入：** `mode` — `'light'`/`'dark'`，或 `null` 移除键（跟随系统）。
- **返回：** 无。
- **副作用：** 写入 `storage_config.json`。
- **算法：** 读取配置，`mode` 为 `null` 时移除 `themeMode` 否则设置它，写回配置。
- **用法：**
  ```dart
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    AnimeStorage.setThemeMode(str);
  }
  ```
  （`lib/shared/providers/app_settings.dart`）
- **备注：** 无。

### `static Future<String?> getLocaleTag()` <a id="getlocaletag"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 278 行）
- **用途：** 读取持久化的语言区域标签（如 `'en'`、`'zh_TW'`）。
- **输入：** 无。
- **返回：** `Future<String?>` — `null` 表示"使用系统语言区域"。
- **副作用：** 无。
- **算法：** `(await readConfig())['locale'] as String?`。
- **用法：**
  ```dart
  final localeTag = await AnimeStorage.getLocaleTag();
  ```
  （`lib/shared/providers/app_settings.dart`，`_loadPersisted`）
- **备注：** 无。

### `static Future<void> setLocaleTag(String? tag)` <a id="setlocaletag"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 288 行）
- **用途：** 持久化（或清除）语言区域标签。
- **输入：** `tag` — `null` 移除键。
- **返回：** 无。
- **副作用：** 写入 `storage_config.json`。
- **算法：** 读-改-写，与 `setThemeMode` 形态相同。
- **用法：**
  ```dart
  final tag = locale.countryCode != null
      ? '${locale.languageCode}_${locale.countryCode}'
      : locale.languageCode;
  AnimeStorage.setLocaleTag(tag);
  ```
  （`lib/shared/providers/app_settings.dart`，`setLocale`）
- **备注：** 无。

### `static Future<int> getWeekStartDay()` <a id="getweekstartday"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 303 行）
- **用途：** 读取持久化的全局日历周起始日。
- **输入：** 无。
- **返回：** `Future<int>` — 总是规范化的星期值（Dart 的周一=1..周日=7），默认为周日。
- **副作用：** 无。
- **算法：** 从配置读取 `weekStartDay` 并经过 `normalizeWeekStartDay`（在 `lib/shared/utils/calendar_preferences.dart`），后者为缺失/越界值代入 `defaultWeekStartDay`（周日）。
- **用法：**
  ```dart
  final weekStartDay = await AnimeStorage.getWeekStartDay();
  ```
  （`lib/shared/providers/app_settings.dart`，`_loadPersisted`）
- **备注：** 日式主页日历布局激活时忽略此值——见 [`../../../../data-formats.md`](../../../../data-formats.md)。

### `static Future<void> setWeekStartDay(int weekday)` <a id="setweekstartday"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 313 行）
- **用途：** 持久化全局日历周起始日。
- **输入：** `weekday`。
- **返回：** 无。
- **副作用：** 写入 `storage_config.json`。
- **算法：** 经 `normalizeWeekStartDay` 规范化 `weekday`；规范化值等于默认值（周日）时移除 `weekStartDay` 键而不是显式存储；否则存储规范化值。
- **用法：**
  ```dart
  void setWeekStartDay(int weekday) {
    final normalized = normalizeWeekStartDay(weekday);
    state = state.copyWith(weekStartDay: normalized);
    AnimeStorage.setWeekStartDay(normalized);
  }
  ```
  （`lib/shared/providers/app_settings.dart`）
- **备注：** 为默认值存储"无键"意味着从未改过此偏好的配置文件保持逐字节精简，而不是累积默认值。

### `static Future<String?> getHomeCalendarLayout()` <a id="gethomecalendarlayout"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 329 行）
- **用途：** 读取持久化的主页日历日名布局偏好（本地 vs 日式）。
- **输入：** 无。
- **返回：** `Future<String?>` — `null` 表示默认本地布局。
- **副作用：** 无。
- **算法：** `(await readConfig())['homeCalendarLayout'] as String?`。
- **用法：**
  ```dart
  final homeCalendarLayout = _parseHomeCalendarLayout(
    await AnimeStorage.getHomeCalendarLayout(),
  );
  ```
  （`lib/shared/providers/app_settings.dart`，`_loadPersisted`）
- **备注：** 无。

### `static Future<void> setHomeCalendarLayout(String? layout)` <a id="sethomecalendarlayout"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 339 行）
- **用途：** 持久化（或清除）主页日历日名布局偏好。
- **输入：** `layout` — `null` 移除键并恢复默认本地布局。
- **返回：** 无。
- **副作用：** 写入 `storage_config.json`。
- **算法：** 读-改-写，与 `setThemeMode` 形态相同。
- **用法：**
  ```dart
  AnimeStorage.setHomeCalendarLayout(
    layout == HomeCalendarLayout.local ? null : layout.name,
  );
  ```
  （`lib/shared/providers/app_settings.dart`，`setHomeCalendarLayout`）
- **备注：** 无。

### `static Future<String?> getHomeCalendarTimeBasis()` <a id="gethomecalendartimebasis"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 354 行）
- **用途：** 读取持久化的主页日历时间基准偏好（JST vs 本地）。
- **输入：** 无。
- **返回：** `Future<String?>` — `null` 表示默认 JST 基准。
- **副作用：** 无。
- **算法：** `(await readConfig())['homeCalendarTimeBasis'] as String?`。
- **用法：**
  ```dart
  final homeCalendarTimeBasis = _parseHomeCalendarTimeBasis(
    await AnimeStorage.getHomeCalendarTimeBasis(),
  );
  ```
  （`lib/shared/providers/app_settings.dart`，`_loadPersisted`）
- **备注：** 此偏好只影响主页日历的日期网格——动画日程时间戳本身始终基于 JST（见 [`../../../../data-formats.md`](../../../../data-formats.md)）。

### `static Future<void> setHomeCalendarTimeBasis(String? basis)` <a id="sethomecalendartimebasis"></a>
- **种类：** `AnimeStorage` 的静态方法
- **来源：** `lib/features/anime/services/anime_storage.dart`（第 364 行）
- **用途：** 持久化（或清除）主页日历时间基准偏好。
- **输入：** `basis` — `null` 移除键并恢复默认 JST 基准。
- **返回：** 无。
- **副作用：** 写入 `storage_config.json`。
- **算法：** 读-改-写，与 `setThemeMode` 形态相同。
- **用法：**
  ```dart
  AnimeStorage.setHomeCalendarTimeBasis(
    basis == HomeCalendarTimeBasis.jst ? null : basis.name,
  );
  ```
  （`lib/shared/providers/app_settings.dart`，`setHomeCalendarTimeBasis`）
- **备注：** 无。
