# lib/shared/services/file_open_service.dart

`FileOpenService` 实现单动画（v1）和多动画捆绑（v2）格式的 `.myanimeitem` 导出/导入，并经 `MethodChannel`（移动端）和命令行参数（桌面冷启动）接线操作系统级"用 MyAnime 打开"流程。它是 [`share_service.md`](share_service.md)（导出）和 `lib/shared/widgets/import_bundle_dialog.dart`（带冲突解决的导入，用 [`duplicate_service.md`](duplicate_service.md) 的分组逻辑）使用的入口。更高级的流程见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md)，精确 v1/v2 JSON 形态见 [`../../../data-formats.md`](../../../data-formats.md)，各平台如何注册 `.myanimeitem` 文件关联见 [`../../../platform-notes.md`](../../../platform-notes.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`init`](#init) | 方法（`FileOpenService`） | A | 注册移动端文件打开 `MethodChannel` 处理器。 |
| `setPendingFile` | 方法（`FileOpenService`） | B | 记住应用完成启动前打开的文件路径。 |
| [`processPendingFile`](#processpendingfile) | 方法（`FileOpenService`） | A | 导入并导航到先前记住的待处理文件。 |
| [`handleFile`](#handlefile) | 方法（`FileOpenService`） | A | 直接把 `.myanimeitem` 文件（v1 或 v2）导入存储。 |
| [`_importOne`](#_importone) | 方法（`FileOpenService`） | A | 从解析的 JSON 构建全新 `Anime`（新 UUID、解码封面图像）。 |
| [`parseBundle`](#parsebundle) | 方法（`FileOpenService`） | A | 把 `.myanimeitem` 文件解析为 `ImportBundle`，不写存储。 |
| [`pickAndParseBundle`](#pickandparsebundle) | 方法（`FileOpenService`） | A | 让用户选择 `.myanimeitem` 文件并解析为捆绑。 |
| [`applyBundle`](#applybundle) | 方法（`FileOpenService`） | A | 把已解析捆绑的所选子集持久化到存储。 |
| [`replaceAnime`](#replaceanime) | 方法（`FileOpenService`） | A | 按 id 替换（或新增）本地动画记录。 |
| [`deleteAnimeByIds`](#deleteanimebyids) | 方法（`FileOpenService`） | A | 按 id 从存储删除动画记录。 |
| [`importFromPicker`](#importfrompicker) | 方法（`FileOpenService`） | A | 让用户选择并直接导入 `.myanimeitem` 文件。 |
| [`exportAnimeItem`](#exportanimeitem) | 方法（`FileOpenService`） | A | 把一部动画导出为 v1 `.myanimeitem` JSON 文件。 |
| [`exportAnimeBundle`](#exportanimebundle) | 方法（`FileOpenService`） | A | 把动画集合导出为 v2 多动画 `.myanimeitem` 文件。 |
| `_stripPersonalData` | 方法（`FileOpenService`） | B | 从导出 JSON 中移除 `episodeStatuses`/`episodeWeekOffsets`。 |
| [`_readCoverBase64`](#_readcoverbase64) | 方法（`FileOpenService`） | A | 读取动画的封面图像文件并 base64 编码。 |
| [`_writeBundleFile`](#_writebundlefile) | 方法（`FileOpenService`） | A | 把 JSON 捆绑写入临时 `.myanimeitem` 文件。 |
| [`_sanitizeFileName`](#_sanitizefilename) | 方法（`FileOpenService`） | A | 净化显示名用作跨平台文件名。 |

## 文档

### `static void init()` <a id="init"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 24 行）
- **用途：** 注册 `com.yuanzhe.my_anime/file_open` `MethodChannel` 处理器，使原生代码（Android/iOS 文件关联）能把打开的文件路径交给 Dart。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 在共享 `MethodChannel` 上设置方法调用处理器；`'openFile'` 时导入文件并把应用路由器导航到新动画的详情页。
- **算法：** `'openFile'` 时用给定路径调用 [`handleFile`](#handlefile)；返回非 null 动画 id 时调用 `appRouter.go('/anime/detail/$id')`。
- **用法：**
  ```dart
  FileOpenService.init();
  ```
  （来自 `lib/main.dart`，启动期间，注册提醒/托盘服务后）
- **备注：** 无。

### `static Future<void> processPendingFile()` <a id="processpendingfile"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 48 行）
- **用途：** 导入在组件树存在前经 `setPendingFile` 捕获的 `.myanimeitem` 文件路径，然后导航到它。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 清除 `_pendingFile`；把文件导入存储；导航路由器。
- **算法：** `_pendingFile` 已设置时，清除它，调用 [`handleFile`](#handlefile)，返回 id 时导航到 `/anime/detail/$id`。
- **用法：**
  ```dart
  WidgetsBinding.instance.addPostFrameCallback((_) {
    FileOpenService.processPendingFile();
  });
  ```
  （来自 `lib/main.dart`，第一帧后，用于经 `args.where((a) => a.endsWith('.myanimeitem'))` 的桌面冷启动）
- **备注：** 设计为在第一帧后运行，使 `appRouter.go` 有有效的 `Navigator` 可指向。

### `static Future<String?> handleFile(String path)` <a id="handlefile"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 64 行）
- **用途：** 向后兼容地把 `.myanimeitem` 文件直接导入存储——支持 v1（单动画）和 v2（多动画捆绑），无任何冲突 UI。
- **输入：** `path` — 文件的绝对路径。
- **返回：** `Future<String?>` — 导入动画的 id（v1）或*最后*导入动画的 id（v2），任何失败（文件缺失、JSON 坏、版本不识别）为 `null`。
- **副作用：** 写入 `AnimeStorage`（每条导入记录一次 `addOrUpdate`）；可能经 [`_importOne`](#_importone) 把解码的封面图像写入 `<应用目录>/images/`。
- **算法：**
  1. 文件不存在时返回 `null`。
  2. 解码 JSON。`version == 1` 且存在 `anime` 时，经 [`_importOne`](#_importone) 和 `AnimeStorage.addOrUpdate` 导入那一条记录。
  3. 否则 `version == 2` 且 `items` 是列表时，用同样方式导入每个条目，跟踪最后导入的 id。
  4. 任何其他形态（或上面任何位置的异常）返回 `null`。
- **用法：**
  ```dart
  final id = await handleFile(path);
  ```
  （来自 [`init`](#init) 和 [`processPendingFile`](#processpendingfile)，两条文件关联冷启动路径；`importFromPicker` 也调用）
- **备注：** 总是给每条导入记录分配**新 UUID**，绝不覆盖既有动画——这是文件关联打开使用的"无冲突 UI"快速路径；需要冲突解决时用 [`parseBundle`](#parsebundle) + [`applyBundle`](#applybundle)。

### `static Future<Anime> _importOne(Anime parsed, Map<String, dynamic> itemJson)` <a id="_importone"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 106 行）
- **用途：** 把一条解析的 `.myanimeitem` 记录变成全新的本地 `Anime`，把任何嵌入的 base64 封面图像解码为磁盘文件。
- **输入：** `parsed` — 从条目的 `anime` JSON 解码的 `Anime`；`itemJson` — 原始条目映射，用于 `coverImage`/`coverImageExt`。
- **返回：** `Future<Anime>` — 带新 UUID、当前 UTC `createdAt`/`modifiedAt` 和（存在时）本地保存封面路径的新记录。
- **副作用：** `itemJson['coverImage']` 存在时，base64 解码并写入 `<应用目录>/images/<uuid><ext>`（需要时创建目录）。
- **算法：**
  1. `itemJson['coverImage']` 存在时，解码并以新 UUID 文件名写入（用 `coverImageExt` 或 `.jpg` 作扩展名）。
  2. 构造新 `Anime`，从 `parsed` 复制每个字段，唯独 `id`（新 UUID）、`coverImage`（刚写的本地路径，或没有嵌入图像时的 `parsed.coverImage`）和 `createdAt`/`modifiedAt`（都设为现在）不同。
- **用法：** 从 [`handleFile`](#handlefile) 和 [`parseBundle`](#parsebundle) 内部调用。
- **备注：** 个人观看字段（`episodeStatuses`、`episodeWeekOffsets`）从 `parsed` 原样带过——剥离只在导出时发生（见 `_stripPersonalData`），不在导入时。

### `static Future<ImportBundle?> parseBundle(String path)` <a id="parsebundle"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 154 行）
- **用途：** 把 `.myanimeitem` 文件（v1 或 v2）解析为 `ImportBundle`，检测与当前本地数据的冲突，*还*不写任何东西到存储。
- **输入：** `path` — 文件的绝对路径。
- **返回：** `Future<ImportBundle?>` — 任何解析失败或捆绑不含有效记录时为 `null`。
- **副作用：** 把任何嵌入的 base64 封面图像写入 `<应用目录>/images/`（经 [`_importOne`](#_importone)）；经 `AnimeStorage.load()` 读取当前本地动画。
- **算法：**
  1. 读取并 JSON 解码文件；不存在或 JSON 解析失败时返回 `null`。
  2. 收集逐条目 JSON 映射：v1 为单个顶层对象；v2 为 `items` 的每个元素。
  3. 把每个条目经 [`_importOne`](#_importone)（新 UUID + 封面解码）运行以构建候选 `Anime` 列表；没有一个解析成功时返回 `null`。
  4. 加载当前本地动画，对每个候选调用 [`DuplicateService.findConflict`](duplicate_service.md#findconflict)——找到时记录其捆绑索引和匹配本地记录。
  5. 返回 `ImportBundle(animes: parsed, conflictIndices: ..., localVersions: ...)`。
- **用法：**
  ```dart
  final bundle = await FileOpenService.pickAndParseBundle();
  ```
  （来自 `lib/shared/widgets/import_bundle_dialog.dart` 的 `showImportBundleFlow`，它在调用 [`applyBundle`](#applybundle)/[`replaceAnime`](#replaceanime) 前驱动逐冲突对话框）
- **备注：** 每个候选在用户解决冲突之前就已分配新 UUID（经 `_importOne`）——记录最终保留哪个 UUID 由用户选"使用导入"（新 UUID）还是"合并"（保留本地 id，经 [`DuplicateService.merge`](duplicate_service.md#merge)）决定。

### `static Future<ImportBundle?> pickAndParseBundle()` <a id="pickandparsebundle"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 210 行）
- **用途：** 打开文件选择器（任意文件类型）并把所选文件解析为捆绑。
- **输入：** 无。
- **返回：** `Future<ImportBundle?>` — 用户取消或路径无效时为 `null`。
- **副作用：** 显示操作系统文件选择器；进一步副作用见 [`parseBundle`](#parsebundle)。
- **算法：** `FilePicker.platform.pickFiles(type: FileType.any)`，然后带所选路径委托给 [`parseBundle`](#parsebundle)。
- **用法：**
  ```dart
  final bundle = await FileOpenService.pickAndParseBundle();
  ```
  （来自 `lib/shared/widgets/import_bundle_dialog.dart` 的 `showImportBundleFlow`，用户发起的"导入"入口）
- **备注：** 用 `FileType.any` 而不是 `.myanimeitem` 过滤器，因为有些平台不能可靠过滤自定义扩展名。

### `static Future<int> applyBundle(ImportBundle bundle, {Set<int> skipIndices = const {}})` <a id="applybundle"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 224 行）
- **用途：** 把已解析捆绑的未跳过记录作为新动画持久化。
- **输入：** `bundle` — 先前解析的 `ImportBundle`；`skipIndices` — 要排除的捆绑索引（如用户选择保留本地的冲突，或将单独合并的）。
- **返回：** `Future<int>` — 实际新增的记录数。
- **副作用：** 向 `AnimeStorage` 追加记录（一次批量 `save`，不是逐记录 `addOrUpdate`）。
- **算法：** 加载当前数据，把不在 `skipIndices` 中的每个 `bundle.animes[i]` 追加进列表，一次性保存合并列表，返回新增计数。
- **用法：**
  ```dart
  final added = await FileOpenService.applyBundle(
    bundle,
    skipIndices: {...skipIndices, ...mergeIndices},
  );
  ```
  （来自 `lib/shared/widgets/import_bundle_dialog.dart`，用户解决完每个冲突后——合并绑定的索引在这里被排除，因为它们经 [`replaceAnime`](#replaceanime) 单独应用）
- **备注：** 对整个批次一次 `AnimeStorage.save()` 调用，不同于 `handleFile` 的逐记录 `addOrUpdate`——对多动画捆绑更高效。

### `static Future<void> replaceAnime(String localId, Anime replacement)` <a id="replaceanime"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 246 行）
- **用途：** 用合并或原样导入版本替换既有本地动画（id 不知何故不再存在时新增）。
- **输入：** `localId` — 要替换的既有记录 id；`replacement` — 新记录。
- **返回：** `Future<void>`。
- **副作用：** 更新（或追加到）`AnimeStorage`。
- **算法：** 加载当前数据；找 `localId` 的索引；找到则原地覆盖，否则追加 `replacement`；保存。
- **用法：**
  ```dart
  final merged = DuplicateService.merge(local, [imported]);
  await FileOpenService.replaceAnime(local.id, merged);
  ```
  （来自 `lib/shared/widgets/import_bundle_dialog.dart`，应用用户对导入冲突的"合并"选择）
- **备注：** 无。

### `static Future<void> deleteAnimeByIds(Iterable<String> ids)` <a id="deleteanimebyids"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 264 行）
- **用途：** 按 id 删除一组动画记录，通常是重复合并后留下的冗余副本。
- **输入：** `ids` — 要移除的 id。
- **返回：** `Future<void>`。
- **副作用：** 重写 `AnimeStorage`，移除匹配记录。
- **算法：** 加载当前数据，过滤掉 `id` 在给定集合中的任何动画，保存过滤后的列表。
- **用法：**
  ```dart
  await FileOpenService.deleteAnimeByIds(others.map((a) => a.id));
  ```
  （来自 `lib/shared/widgets/duplicate_check_page.dart` 的 `_resolveGroup`，可选合并后移除重复组的未保留成员）
- **备注：** 无。

### `static Future<String?> importFromPicker()` <a id="importfrompicker"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 276 行）
- **用途：** 打开文件选择器并直接导入所选 `.myanimeitem` 文件（无冲突 UI），返回导入动画的 id。
- **输入：** 无。
- **返回：** `Future<String?>` — 导入动画 id，取消/失败为 `null`。
- **副作用：** 显示文件选择器；进一步副作用见 [`handleFile`](#handlefile)。
- **算法：** `FilePicker.platform.pickFiles(type: FileType.any)`，然后委托给 [`handleFile`](#handlefile)。
- **用法：** 目前仓库其他地方不调用；"导入"UI 实际使用带冲突感知的 [`pickAndParseBundle`](#pickandparsebundle) + [`applyBundle`](#applybundle) 路径。
- **备注：** 与 `handleFile` 相同的"总是新 UUID、绝不覆盖"行为。

### `static Future<String?> exportAnimeItem(Anime anime)` <a id="exportanimeitem"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 289 行）
- **用途：** 把单部动画导出为 v1 `.myanimeitem` JSON 文件，个人观看数据被剥离。
- **输入：** `anime` — 要导出的记录。
- **返回：** `Future<String?>` — 写入文件的临时路径，失败为 `null`。
- **副作用：** 读取封面图像文件（如有）并 base64 编码；在系统临时目录下写临时 `.myanimeitem` 文件。
- **算法：** 经 `_stripPersonalData` 剥离个人字段；构建 `{version: 1, anime: <stripped json>, coverImage: <base64 or null>}`（有封面时加 `coverImageExt`）；经 [`_writeBundleFile`](#_writebundlefile) 用来自 `anime.displayTitle` 的净化文件名写入。
- **用法：**
  ```dart
  final filePath = await FileOpenService.exportAnimeItem(anime);
  ```
  （来自 [`share_service.md`](share_service.md) 的 `_shareAnimeData`，把单部动画作为数据文件分享）
- **备注：** 无。

### `static Future<String?> exportAnimeBundle(List<Anime> animes, {String displayName = 'myanime_collection'})` <a id="exportanimebundle"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 313 行）
- **用途：** 把动画集合导出为 v2 多动画 `.myanimeitem` 捆绑，每条记录的个人观看数据被剥离。
- **输入：** `animes` — 要导出的记录；`displayName` — 基础文件名（净化）。
- **返回：** `Future<String?>` — 写入文件的临时路径，失败为 `null`。
- **副作用：** 读取每部动画的封面图像（如有）；写一个临时 `.myanimeitem` 文件。
- **算法：** 对每部动画，剥离个人字段并构建条目映射（`anime` json + base64 `coverImage`/`coverImageExt`）；把全部条目包装为 `{version: 2, items: [...]}`；经 [`_writeBundleFile`](#_writebundlefile) 写入。
- **用法：**
  ```dart
  final filePath = await FileOpenService.exportAnimeBundle(
    animes,
    displayName: displayName,
  );
  ```
  （来自 [`share_service.md`](share_service.md) 的 `shareStatisticsData`，把当前统计视图的动画列表作为数据文件分享）
- **备注：** 专门用捆绑版本 2，使单动画 v1 文件保持为不同的、向后兼容的格式。

### `static Future<String?> _readCoverBase64(Anime anime)` <a id="_readcoverbase64"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 356 行）
- **用途：** 读取动画的封面图像文件并返回 base64，用于嵌入导出的 `.myanimeitem` 文件。
- **输入：** `anime`。
- **返回：** `Future<String?>` — base64 字符串，没有封面、文件缺失或读取失败时为 `null`。
- **副作用：** 从 `<应用目录>/images/` 读取文件。
- **算法：** `anime.coverImage` 为 null 时返回 `null`；否则解析应用相对路径，文件存在时读取并 base64 编码其字节（任何异常被吞掉，返回 `null`）。
- **用法：** 从 [`exportAnimeItem`](#exportanimeitem) 和 [`exportAnimeBundle`](#exportanimebundle) 内部调用。
- **备注：** 失败按设计静默——缺失/损坏的封面图像不应阻止导出动画的其余数据。

### `static Future<String?> _writeBundleFile(String safeName, Map<String, dynamic> json)` <a id="_writebundlefile"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 374 行）
- **用途：** 把 JSON 捆绑（已组装）写入临时 `.myanimeitem` 文件。
- **输入：** `safeName` — 文件系统安全的基础名（无扩展名）；`json` — 捆绑负载。
- **返回：** `Future<String?>` — 写入文件的绝对路径。
- **副作用：** 在 `getTemporaryDirectory()` 下写美化打印（`JsonEncoder.withIndent('  ')`）的 JSON 文件。
- **算法：** 把临时目录与 `"$safeName.myanimeitem"` 拼接，写 `json` 的缩进 JSON 编码，返回路径。
- **用法：** 从 [`exportAnimeItem`](#exportanimeitem) 和 [`exportAnimeBundle`](#exportanimebundle) 内部调用。
- **备注：** 写入临时目录（不是应用存储）是刻意的——这些文件意在立即交给平台分享面板或另存为对话框，不保留。

### `static String _sanitizeFileName(String name)` <a id="_sanitizefilename"></a>
- **种类：** `FileOpenService` 的静态方法
- **来源：** `lib/shared/services/file_open_service.dart`（约第 391 行）
- **用途：** 净化动画/集合显示名，使其在 Windows、macOS 和 Linux 上安全用作文件名。
- **输入：** `name` — 原始显示名。
- **返回：** `String` — 文件系统安全名，绝不为空，上限 100 字符。
- **副作用：** 无。
- **算法：** 经正则剥离 Windows/macOS/Linux 文件系统非法的字符（`/ \ : * ? " < > |`）和 ASCII 控制字符；修剪；结果为空时回退 `'anime'`；截断到 100 字符。
- **用法：** 从 [`exportAnimeItem`](#exportanimeitem) 和 [`exportAnimeBundle`](#exportanimebundle) 内部调用。
- **备注：** CJK、带变音符和其他 Unicode 字母被刻意保留——只剥离文件系统非法的 ASCII 标点和控制字符。
