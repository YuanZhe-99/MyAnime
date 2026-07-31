# lib/shared/services/share_service.dart

`ShareService` 把动画、排名和统计数据渲染成可分享的 PNG"卡片"（用 `dart:ui` 的 `Canvas`/`PictureRecorder` 绘制），并驱动平台特定的分享流程（Android `MethodChannel`、iOS `Share.shareXFiles`、桌面预览对话框）。它还拥有统计视图的 `.myanimeitem` 数据文件和纯文本导出路径，把实际捆绑格式委托给 [`file_open_service.md`](file_open_service.md)。完整功能说明（图像卡片内容、多页拆分、逐平台分享机制）见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md)——本页记录每个函数实际做什么，包括阅读源码时发现的一条疑似死代码路径（见下）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`RankingShareEntry.new`](#rankingshareentry-new) | 构造函数（`RankingShareEntry`） | A | 创建排名分享条目（动画 + 排名 + 分数）。 |
| [`shareAnime`](#shareanime) | 方法（`ShareService`） | A | 询问图像-vs-数据并按此分享单个动画。 |
| [`shareRankingImage`](#sharerankingimage) | 方法（`ShareService`） | A | 生成并分享排名图像（旧的一体化入口）。 |
| [`_shareAnimeData`](#_shareanimedata) | 方法（`ShareService`） | A | 把一部动画导出为 `.myanimeitem` 文件并分享/保存它。 |
| [`_shareAnimeImage`](#_shareanimeimage) | 方法（`ShareService`） | A | 询问 URL 包含选项、生成并分享单动画图像卡片。 |
| [`shareImageBytes`](#shareimagebytes) | 方法（`ShareService`） | A | 公共入口：分享已生成的单页图像字节。 |
| [`shareImageBytesMulti`](#shareimagebytesmulti) | 方法（`ShareService`） | A | 公共入口：分享一个或多个已生成的图像页。 |
| [`generateStatisticsShareBytes`](#generatestatisticssharebytes) | 方法（`ShareService`） | A | 公共入口：不显示分享 UI 地生成统计分享图像字节。 |
| [`generateRankingShareBytes`](#generaterankingsharebytes) | 方法（`ShareService`） | A | 公共入口：不显示分享 UI 地生成排名分享图像字节。 |
| [`_shareImageBytes`](#_shareimagebytes) | 方法（`ShareService`） | A | 把图像字节写入临时文件并分派单文件平台分享流程。 |
| [`_shareImageBytesMulti`](#_shareimagebytesmulti) | 方法（`ShareService`） | A | 把多个图像页写入临时文件并分派多文件平台分享流程。 |
| [`_generateShareImage`](#_generateshareimage) | 方法（`ShareService`） | A | 布局并绘制单动画分享卡片为 PNG 字节。 |
| `_layoutText` | 方法（`ShareService`） | B | 为一段卡片文本构建并布局 `TextPainter`。 |
| [`_generateRankingShareImage`](#_generaterankingshareimage) | 方法（`ShareService`） | A | 布局并绘制（可能多页的）排名分享图像。 |
| `_drawRankingRow` | 方法（`ShareService`） | B | 在画布上绘制一个排名动画行（排名圆、封面、标题、分数）。 |
| `_drawCoverImage` | 方法（`ShareService`） | B | 把封面图像绘制进带中心裁剪缩放的圆角目标矩形。 |
| `_drawWatermark` | 方法（`ShareService`） | B | 绘制右对齐的 `[logo] MyAnime!!!!!` 水印行。 |
| `_formatScore` | 方法（`ShareService`） | B | 格式化分数，去掉尾部 `.0`。 |
| `_typeLabel` | 方法（`ShareService`） | B | `AnimeType` 的本地化标签。 |
| `_dayName` | 方法（`ShareService`） | B | 1–7 星期代码的本地化星期名。 |
| [`_countAiredEpisodes`](#_countairedepisodes) | 方法（`ShareService`） | A | 统计截至今天（JST）已播出的剧集数，供分享卡片的进度条使用。 |
| [`_showDesktopPreview`](#_showdesktoppreview) | 方法（`ShareService`） | A | 显示带复制/另存为操作的桌面单图像预览对话框。 |
| [`_showDesktopPreviewMulti`](#_showdesktoppreviewmulti) | 方法（`ShareService`） | A | 显示带复制首页/全部保存操作的桌面多页预览对话框。 |
| [`_copyImageToClipboard`](#_copyimagetoclipboard) | 方法（`ShareService`） | A | 经平台特定 shell 命令把图像文件复制到操作系统剪贴板。 |
| [`shareStatisticsImage`](#sharestatisticsimage) | 方法（`ShareService`） | A | 生成并分享统计/排名风格图像（条形图可选）。 |
| [`shareStatisticsData`](#sharestatisticsdata) | 方法（`ShareService`） | A | 把可见统计动画列表导出为 `.myanimeitem` 捆绑并分享/保存它。 |
| [`shareStatisticsTxt`](#sharestatisticstxt) | 方法（`ShareService`） | A | 把可见统计动画列表导出为排序的纯文本名称列表。 |
| [`_generateStatisticsShareImage`](#_generatestatisticsshareimage) | 方法（`ShareService`） | A | 布局并绘制（可能多页、可选条形图的）统计分享图像。 |
| [`_drawSummaryBars`](#_drawsummarybars) | 方法（`ShareService`） | A | 绘制已跟踪/已完成/弃看水平条形图。 |
| [`_loadShareCoverImages`](#_loadsharecoverimages) | 方法（`ShareService`） | A | 加载并解码（去重后的）动画列表封面图像，报告进度。 |
| `_drawStatisticsRow` | 方法（`ShareService`） | B | 在画布上绘制一个统计条目行（排名圆、封面、标题、状态/进度）。 |
| [`StatisticsShareEntry.new`](#statisticsshareentry-new) | 构造函数（`StatisticsShareEntry`） | A | 创建统计分享条目（动画 + 排名 + 可选分数/状态/进度标签）。 |
| [`StatisticsShareSummary.new`](#statisticssharesummary-new) | 构造函数（`StatisticsShareSummary`） | A | 创建统计分享摘要（已跟踪/已完成/弃看计数）。 |

## 文档

### `const RankingShareEntry({required this.anime, required this.rank, required this.score})` <a id="rankingshareentry-new"></a>
- **种类：** `RankingShareEntry` 的构造函数
- **来源：** `lib/shared/services/share_service.dart`（约第 29 行）
- **用途：** 为排名分享图像保存一部动画的排名和分数。
- **输入：** `anime`、`rank`（1 基位置）、`score`（排序字段的值）。
- **返回：** 新的 `RankingShareEntry`。
- **副作用：** 无。
- **算法：** 直接字段赋值。
- **用法：** 由 `lib/features/anime/views/statistics_page.dart` 在调用 [`generateRankingShareBytes`](#generaterankingsharebytes) 前从当前排名列表构建。
- **备注：** 无。

### `static Future<void> shareAnime(BuildContext context, Anime anime)` <a id="shareanime"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 66 行）
- **用途：** 分享单个动画的入口：询问用户"图像"vs"数据文件"，然后按此分派。
- **输入：** `context`、`anime`。
- **返回：** `Future<void>`。
- **副作用：** 显示 `SimpleDialog`；进一步副作用见 [`_shareAnimeData`](#_shareanimedata) / [`_shareAnimeImage`](#_shareanimeimage)。
- **算法：** 显示提供 `'image'` 或 `'data'` 的对话框；取消或上下文不再 mounted 时返回；否则调用 `_shareAnimeData` 或 `_shareAnimeImage`。
- **用法：**
  ```dart
  onPressed: () => ShareService.shareAnime(context, anime),
  ```
  （来自 `lib/features/anime/views/anime_detail_page.dart`，动画详情页的分享按钮）
- **备注：** 无。

### `static Future<void> shareRankingImage(BuildContext context, {required List<RankingShareEntry> entries, required String title, required String subtitle, required String sortLabel, required String orderLabel, required AppLocalizations l10n, ValueNotifier<double>? progress})` <a id="sharerankingimage"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 109 行）
- **用途：** 一次调用端到端生成排名分享图像（生成 + 分享）。
- **输入：** `entries`、`title`、`subtitle`、`sortLabel`、`orderLabel`、`l10n`、可选 `progress`。
- **返回：** `Future<void>`。
- **副作用：** 读取封面图像、写临时 PNG、调用平台分享/预览流程。
- **算法：** `entries` 为空时提前返回。经 [`_generateRankingShareImage`](#_generaterankingshareimage) 生成页，然后经 [`shareImageBytesMulti`](#shareimagebytesmulti) 以 `fileNameBase: 'myanime_ranking'` 分享它们；任何异常时显示"分享失败"snackbar。
- **用法：** 目前仓库其他地方不调用。
- **备注：** **疑似死代码** — `lib/features/anime/views/statistics_page.dart` 通过直接调用 [`generateRankingShareBytes`](#generaterankingsharebytes)（包在它自己的进度对话框辅助里）然后再单独调用 [`shareImageBytesMulti`](#shareimagebytesmulti) 来分享排名图像，而不是调用这个一体化方法。`shareRankingImage` 重新实现相同的生成-再-分享序列，但生成期间没有调用方可视的进度对话框。

### `static Future<void> _shareAnimeData(BuildContext context, Anime anime, AppLocalizations l10n)` <a id="_shareanimedata"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 152 行）
- **用途：** 把一部动画导出为 `.myanimeitem` 文件并交给平台分享/保存流程。
- **输入：** `context`、`anime`、`l10n`。
- **返回：** `Future<void>`。
- **副作用：** 调用 [`FileOpenService.exportAnimeItem`](file_open_service.md#exportanimeitem)；Android 上调用 `com.yuanzhe.my_anime/share` `MethodChannel` 的 `shareFile`；iOS 上调用 `Share.shareXFiles`；桌面上显示原生"保存文件"对话框并把文件复制到那里。
- **算法：** 把动画导出到临时 `.myanimeitem` 文件；按平台分支分享或保存它；酌情显示"已保存"/"分享失败"snackbar；任何异常显示"分享失败"。
- **用法：** 用户选择"数据文件"时从 [`shareAnime`](#shareanime) 内部调用。
- **备注：** 无。

### `static Future<void> _shareAnimeImage(BuildContext context, Anime anime, AppLocalizations l10n)` <a id="_shareanimeimage"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 200 行）
- **用途：** 可选询问要作为二维码嵌入哪些 URL（info/watch），生成分享图像，并分派给分享流程。
- **输入：** `context`、`anime`、`l10n`。
- **返回：** `Future<void>`。
- **副作用：** 可能显示 URL 选项对话框；经 [`_generateShareImage`](#_generateshareimage) 生成 PNG；经 [`_shareImageBytes`](#_shareimagebytes) 分享它。
- **算法：** 动画有 info URL 或 watch URL 时，显示 `_showUrlOptionsDialog`，用户取消则退出；否则两个包含标志都默认 `false`。用所选包含标志生成图像，然后作为 `myanime_share.png` 分享它；任何异常显示"分享失败"snackbar。
- **用法：** 用户选择"图像"时从 [`shareAnime`](#shareanime) 内部调用。
- **备注：** 无。

### `static Future<void> shareImageBytes(BuildContext context, Uint8List imageBytes, AppLocalizations l10n, {required String fileName})` <a id="shareimagebytes"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 252 行）
- **用途：** 供已有生成 PNG 字节（如在进度对话框后产生）的调用方使用的公共入口，只需平台分享流程。
- **输入：** `context`、`imageBytes`、`l10n`、`fileName`。
- **返回：** `Future<void>`。
- **副作用：** 写临时文件并调用平台分享/桌面预览（委托给 [`_shareImageBytes`](#_shareimagebytes)）。
- **算法：** 对 `_shareImageBytes` 的薄转发调用。
- **用法：** 目前仓库其他地方不调用（统计/排名分享即使单页结果也走 [`shareImageBytesMulti`](#shareimagebytesmulti)）。
- **备注：** 无。

### `static Future<void> shareImageBytesMulti(BuildContext context, List<Uint8List> pages, AppLocalizations l10n, {required String fileNameBase})` <a id="shareimagebytesmulti"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 269 行）
- **用途：** 分享一个或多个预生成图像页的公共入口（如拆分的超高统计/排名导出），只有一页时复用单文件流程。
- **输入：** `context`、`pages`、`l10n`、`fileNameBase`。
- **返回：** `Future<void>`。
- **副作用：** 每页写一个临时 PNG 并调用平台分享/桌面预览。
- **算法：** `pages` 为空时提前返回。恰好一页时经 [`_shareImageBytes`](#_shareimagebytes) 作为 `"$fileNameBase.png"` 分享；否则委托给 [`_shareImageBytesMulti`](#_shareimagebytesmulti)。
- **用法：**
  ```dart
  await ShareService.shareImageBytesMulti(
    context,
    pages,
    l10n,
    fileNameBase: 'myanime_ranking',
  );
  ```
  （来自 `lib/features/anime/views/statistics_page.dart`，分享生成的排名或统计图像页）
- **备注：** 这是今天统计/排名分享实际使用的调用点（见 [`shareRankingImage`](#sharerankingimage) 的备注中平行的未用一体化路径）。

### `static Future<List<Uint8List>> generateStatisticsShareBytes({required List<StatisticsShareEntry> entries, required String title, required String subtitle, required AppLocalizations l10n, StatisticsShareSummary? summary, ValueNotifier<double>? progress})` <a id="generatestatisticssharebytes"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 297 行）
- **用途：** 不显示任何分享 UI 地生成统计分享图像字节的公共入口，使调用方能把自己的进度对话框包在生成外。
- **输入：** `entries`、`title`、`subtitle`、`l10n`、可选 `summary`（条形图计数）、可选 `progress`。
- **返回：** `Future<List<Uint8List>>` — 一个或多个 PNG 页。
- **副作用：** 从存储读取封面图像；经 `progress`（0..1）报告进度。
- **算法：** `entries` 为空时抛 `StateError`；否则委托给 [`_generateStatisticsShareImage`](#_generatestatisticsshareimage)。
- **用法：**
  ```dart
  generate: (progress) => ShareService.generateStatisticsShareBytes(
    entries: entries,
    title: l10n.statsTitle,
    subtitle: subtitle,
    l10n: l10n,
    summary: summary,
    progress: progress,
  ),
  ```
  （来自 `lib/features/anime/views/statistics_page.dart`，包在它自己的 `_generateImageWithProgress` 进度对话框辅助里，然后经 [`shareImageBytesMulti`](#shareimagebytesmulti) 分享）
- **备注：** 无。

### `static Future<List<Uint8List>> generateRankingShareBytes({required List<RankingShareEntry> entries, required String title, required String subtitle, required String sortLabel, required String orderLabel, required AppLocalizations l10n, ValueNotifier<double>? progress})` <a id="generaterankingsharebytes"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 326 行）
- **用途：** 不显示任何分享 UI 地生成排名分享图像字节的公共入口。
- **输入：** `entries`、`title`、`subtitle`、`sortLabel`、`orderLabel`、`l10n`、可选 `progress`。
- **返回：** `Future<List<Uint8List>>` — 一个或多个 PNG 页。
- **副作用：** 从存储读取封面图像；经 `progress`（0..1）报告进度。
- **算法：** `entries` 为空时抛 `StateError`；否则委托给 [`_generateRankingShareImage`](#_generaterankingshareimage)。
- **用法：**
  ```dart
  generate: (progress) => ShareService.generateRankingShareBytes(
    entries: entries,
    title: l10n.statsRanking,
    subtitle: subtitle,
    sortLabel: _ratingFieldLabel(_rankingSortField, l10n),
    orderLabel: _rankingDescending
        ? l10n.statsRankingDescending
        : l10n.statsRankingAscending,
    l10n: l10n,
    progress: progress,
  ),
  ```
  （来自 `lib/features/anime/views/statistics_page.dart` 的排名分享流程）
- **备注：** 无。

### `static Future<void> _shareImageBytes(BuildContext context, Uint8List imageBytes, AppLocalizations l10n, {required String fileName})` <a id="_shareimagebytes"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 353 行）
- **用途：** 把图像字节写入临时文件，然后分派平台合适的单文件分享流程。
- **输入：** `context`、`imageBytes`、`l10n`、`fileName`。
- **返回：** `Future<void>`。
- **副作用：** 写临时文件；Android 调用 `shareFile` `MethodChannel` 方法；iOS 调用 `Share.shareXFiles`；桌面显示 [`_showDesktopPreview`](#_showdesktoppreview)。
- **算法：** 把字节写入 `<临时目录>/<fileName>`；上下文不再 mounted 时返回；按 `Platform.isAndroid`/`isIOS`/其他（桌面预览）分支。
- **用法：** 从 [`shareImageBytes`](#shareimagebytes)、[`shareImageBytesMulti`](#shareimagebytesmulti)（单页情形）和 [`_shareAnimeImage`](#_shareanimeimage) 内部调用。
- **备注：** Android 侧用 `FLAG_ACTIVITY_NEW_TASK`（原生 `MethodChannel` 实现），使分享目标在 MyAnime 任务栈之外打开——见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md)。

### `static Future<void> _shareImageBytesMulti(BuildContext context, List<Uint8List> pages, AppLocalizations l10n, {required String fileNameBase})` <a id="_shareimagebytesmulti"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 392 行）
- **用途：** 把每页写入自己的临时文件，然后分派平台合适的多文件分享流程。
- **输入：** `context`、`pages`、`l10n`、`fileNameBase`。
- **返回：** `Future<void>`。
- **副作用：** 每页写一个临时 PNG（`"$fileNameBase_N.png"`，1 基）；Android 调用带路径列表的复数 `shareFiles` `MethodChannel` 方法；iOS 带文件列表调用 `Share.shareXFiles`；桌面显示 [`_showDesktopPreviewMulti`](#_showdesktoppreviewmulti)。
- **算法：** 把全部页写入临时文件，然后与 `_shareImageBytes` 完全一样按平台分支，但用复数 API。
- **用法：** 只从 [`shareImageBytesMulti`](#shareimagebytesmulti)（多页情形）内部调用。
- **备注：** Android 的 `shareFiles`（复数）`MethodChannel` 方法与 `_shareImageBytes` 的单数 `shareFile` 不同——两者都是原生实现的（见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md)）。

### `static Future<Uint8List> _generateShareImage(Anime anime, AppLocalizations l10n, {bool includeInfoUrl = false, bool includeWatchUrl = false})` <a id="_generateshareimage"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 486 行）
- **用途：** 布局并渲染单动画分享卡片（封面、标题、日程、进度条、备注、二维码、水印）为 PNG 字节。
- **输入：** `anime`；`l10n`；`includeInfoUrl`/`includeWatchUrl` — 是否各自渲染一行二维码 + URL 文本。
- **返回：** `Future<Uint8List>` — PNG 编码图像字节。
- **副作用：** 从磁盘加载应用 logo 资源和（存在时）动画的封面图像。
- **算法：** 两遍布局-再-绘制，全部在固定宽度（`_cardWidth = 480`）卡片坐标中：
  1. 加载 logo（`assets/icon/app_icon.png`）和封面图像（经 [`ImageService.resolve`](image_service.md#resolve)），静默容忍失败。
  2. 自顶向下计算垂直布局：标题、可选日文标题（只在存在且与主标题不同时显示）、信息行（季+类型、日程、首播日期）、进度文本 + 条、顶部小节高度为 `max(info column height, cover height)`（有封面时）、可选备注（上限 300 字符，进一步被 `TextPainter` 的 `maxLines` 截到 6 行，任一上限截断时带 `...` 指示器）、每个被包含 URL 一行 QR+URL，最后是 `[logo] MyAnime!!!!!` 水印行。
  3. 记录最终 `cardHeight`，创建按 `_pixelRatio`（3.0）缩放的 `PictureRecorder`/`Canvas`，并绘制：背景、边框、强调页头条、封面（存在时经 [`_drawCoverImage`](#_drawcoverimage)）、标题/日文标题/信息行、进度文本 + 轨道 + 填充条（`fillWidth = infoWidth * airedCount / totalEps`）、备注 + 截断省略号、每个二维码（经 `QrPainter`）+ 其 URL 文本，以及水印（经 [`_drawWatermark`](#_drawwatermark)）。
  4. 经 `picture.toImage(...)` + `image.toByteData(format: ui.ImageByteFormat.png)` 把记录的图像编码为 PNG。
- **用法：** 只从 [`_shareAnimeImage`](#_shareanimeimage) 内部调用。
- **备注：** 此函数没有分页逻辑（与排名/统计生成器不同）——单动画卡片被假设总是能放进平台纹理尺寸上限内。

### `static Future<List<Uint8List>> _generateRankingShareImage({required List<RankingShareEntry> entries, required String title, required String subtitle, required String sortLabel, required String orderLabel, required AppLocalizations l10n, ValueNotifier<double>? progress})` <a id="_generaterankingshareimage"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 871 行）
- **用途：** 布局并渲染排名分享图像，单页像素高度会超过平台纹理尺寸上限时拆分为多个 PNG 页。
- **输入：** `entries`、`title`、`subtitle`、`sortLabel`、`orderLabel`、`l10n`、可选 `progress`。
- **返回：** `Future<List<Uint8List>>` — 一个或多个 PNG 页，每页 `_rankingCardWidth`（560）宽。
- **副作用：** 加载应用 logo 资源；经 [`_loadShareCoverImages`](#_loadsharecoverimages) 加载每个不同封面图像（报告 `progress`）。
- **算法：**
  1. 预先加载 logo 和每个条目的封面图像。
  2. 布局一次固定页头：标题、副标题和元信息行（`"<排序字段标签>: <sortLabel> · <orderLabel> · <count>"`）。
  3. 假设每行（`_rankingRowHeight = 86`）加水印块能放下一页，计算 `totalCardHeight`。
  4. 定义本地 `renderPage(start, end, isLast)` 闭包：每页绘制页头 + 边框、经 [`_drawRankingRow`](#_drawrankingrow) 绘制行 `[start, end)`，只在 `isLast` 时绘制水印。
  5. `totalCardHeight * _pixelRatio <= _maxImageDimension`（16000）时，渲染覆盖全部条目的一页。
  6. 否则在纹理上限下计算每页能放多少行（`rowsPerPage = floor(availableForRows / _rankingRowHeight)`，最少 1），并渲染连续页直到覆盖全部条目。
- **用法：** 从 [`shareRankingImage`](#sharerankingimage) 和 [`generateRankingShareBytes`](#generaterankingsharebytes) 内部调用。
- **备注：** 见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md) 的"多页拆分"说明——这是该行为的排名半边；每页重复页头，水印只出现在最后一页。

### `static int _countAiredEpisodes(Anime anime)` <a id="_countairedepisodes"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1284 行）
- **用途：** 统计动画截至今天（JST）已播出的剧集数，供分享卡片的进度条/文本使用。
- **输入：** `anime`。
- **返回：** `int`。
- **副作用：** 无（经 `JstTime.today()` 读取系统时钟）。
- **算法：**
  1. `endEpisode` 为 null（开放结局、总数未知）时返回 0。
  2. `firstAirDate` 为 null 时返回 `totalEpisodes ?? 0`（没有可比较的，假设全部播出）。
  3. 动画有效类型为 `allAtOnce` 时全有或全无：首播日期仍在未来则返回 0，否则返回完整集数。
  4. 否则循环 `startEpisode..endEpisode`，一集的日历日期（经 `getEpisodeCalendarDate`）为 null 或不晚于今天时计为已播出。
- **用法：** 只从 [`_generateShareImage`](#_generateshareimage) 内部调用。
- **备注：** 用 [`JstTime.today()`](../utils/jst_time.md#jsttime-today)（JST，不是设备本地时间）——与应用中其他所有剧集播出日期逻辑基于 JST 的方式一致。

### `static Future<void> _showDesktopPreview(BuildContext context, Uint8List imageBytes, String tempPath, AppLocalizations l10n, {required String fileName})` <a id="_showdesktoppreview"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1314 行）
- **用途：** 显示桌面单图像分享预览对话框，带"复制到剪贴板"和"另存为"操作。
- **输入：** `context`、`imageBytes`、`tempPath`（复制操作的源文件）、`l10n`、`fileName`（建议的另存为名称）。
- **返回：** `Future<void>`。
- **副作用：** 显示模态 `Dialog`；"复制"调用 [`_copyImageToClipboard`](#_copyimagetoclipboard)；"另存为"打开原生保存对话框并把 `imageBytes` 写到所选路径。
- **算法：** 用 `Image.memory` 渲染图像，加一行两个按钮：复制（把 `tempPath` 复制到剪贴板、关闭对话框、显示"已复制"snackbar）和另存为（提示目标、写字节、关闭对话框、显示"已保存"snackbar）。
- **用法：** 从 [`_shareImageBytes`](#_shareimagebytes)（桌面分支）和 [`shareStatisticsData`](#sharestatisticsdata)（桌面 `.myanimeitem` 预览）内部调用。
- **备注：** 无。

### `static Future<void> _showDesktopPreviewMulti(BuildContext context, List<Uint8List> pages, List<String> tempPaths, AppLocalizations l10n, {required String fileNameBase})` <a id="_showdesktoppreviewmulti"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1391 行）
- **用途：** 为多个图像页显示可滚动的桌面预览对话框，带"复制首页"和"全部保存"操作。
- **输入：** `context`、`pages`、`tempPaths`、`l10n`、`fileNameBase`。
- **返回：** `Future<void>`。
- **副作用：** 显示带 `ListView.builder` 页列表的模态 `Dialog`；"复制"只复制 `tempPaths.first`；"全部保存"提示目标目录并把每页写为 `"<fileNameBase>_<n>.png"`。
- **算法：** 渲染所有页图像的可滚动列表，加显示页数的页头（`l10n.sharePagesLabel`）；全部保存操作循环 `pages`，用 [`_shareImageBytesMulti`](#_shareimagebytesmulti) 使用的相同 `_N` 命名约定写每页。
- **用法：** 只从 [`_shareImageBytesMulti`](#_shareimagebytesmulti)（桌面分支）内部调用。
- **备注：** 只有第一页能复制到剪贴板——多页对话框中没有逐页复制操作。

### `static Future<void> _copyImageToClipboard(String imagePath)` <a id="_copyimagetoclipboard"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1482 行）
- **用途：** 把 PNG 文件作为图像复制到操作系统剪贴板，用平台特定的外部进程，因为 Flutter 在桌面上没有内置的图像剪贴板 API。
- **输入：** `imagePath` — 要复制的 PNG 文件路径。
- **返回：** `Future<void>`。
- **副作用：** 派生子进程：Windows 上 PowerShell（`System.Windows.Forms.Clipboard`）、macOS 上 `osascript`、Linux 上 `xclip`。
- **算法：** 按 `Platform.isWindows`/`isMacOS`/`isLinux` 分支，经 `Process.run` 运行对应外部命令，图像路径嵌入命令/脚本。
- **用法：** 从 [`_showDesktopPreview`](#_showdesktoppreview) 和 [`_showDesktopPreviewMulti`](#_showdesktoppreviewmulti) 的"复制"操作内部调用。
- **备注：** Linux 上要求安装 `xclip`——缺失时没有回退或浮出给用户的错误（这里的 `Process.run` 失败不被 await/检查）。

### `static Future<void> shareStatisticsImage(BuildContext context, {required List<StatisticsShareEntry> entries, required String title, required String subtitle, required AppLocalizations l10n, StatisticsShareSummary? summary, ValueNotifier<double>? progress})` <a id="sharestatisticsimage"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1519 行）
- **用途：** 一次调用端到端生成并分享统计图像（生成 + 分享）；给 `summary` 时顶部渲染条形图，否则普通排名列表。
- **输入：** `context`、`entries`、`title`、`subtitle`、`l10n`、可选 `summary`、可选 `progress`。
- **返回：** `Future<void>`。
- **副作用：** 显示对话框、生成图像、分享文件。
- **算法：** `entries` 为空时提前返回。经 [`_generateStatisticsShareImage`](#_generatestatisticsshareimage) 生成页，然后经 [`shareImageBytesMulti`](#shareimagebytesmulti) 用 `fileNameBase: 'myanime_stats'`（给 `summary` 时）或 `'myanime_ranking'`（否则）分享；异常时显示"分享失败"snackbar。
- **用法：** 目前仓库其他地方不调用——与 [`shareRankingImage`](#sharerankingimage) 一样，`statistics_page.dart` 直接调用 [`generateStatisticsShareBytes`](#generatestatisticssharebytes)（在它自己的进度对话框之后）然后再单独调用 [`shareImageBytesMulti`](#shareimagebytesmulti)，而不是这个一体化包装器。
- **备注：** 与 `shareRankingImage` 相同的疑似死代码情形——保留作参考，因为它是没有调用方可视进度对话框的有效、更简单的替代调用模式。

### `static Future<void> shareStatisticsData(BuildContext context, {required List<Anime> animes, required String displayName, required AppLocalizations l10n})` <a id="sharestatisticsdata"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1560 行）
- **用途：** 把当前可见的统计动画列表导出为 `.myanimeitem` 多动画捆绑，并交给平台分享/预览流程。
- **输入：** `context`、`animes`、`displayName`（同时用于导出文件名和 `.myanimeitem` 名）、`l10n`。
- **返回：** `Future<void>`。
- **副作用：** 调用 [`FileOpenService.exportAnimeBundle`](file_open_service.md#exportanimebundle)；Android/iOS 直接分享文件；桌面用原始字节显示 [`_showDesktopPreview`](#_showdesktoppreview)（复用图像预览对话框显示/保存非图像文件）。
- **算法：** `animes` 为空时提前返回。导出捆绑；按平台分支分享（Android/iOS）或预览（桌面，先把文件读回字节）；任何异常显示"分享失败"snackbar。
- **用法：**
  ```dart
  await ShareService.shareStatisticsData(
    context,
    animes: animes,
    displayName: displayName,
    l10n: l10n,
  );
  ```
  （来自 `lib/features/anime/views/statistics_page.dart`，统计分享对话框中的"分享为数据"选项）
- **备注：** 桌面上这复用为预览 PNG 设计的 `_showDesktopPreview`——`Image.memory` 在非图像字节上通常会失败，但既然这里的"预览"真的只是复制/另存为按钮的载体，图像渲染静默失败可以容忍（视觉上预览区域只会显示一个破图图标）。

### `static Future<void> shareStatisticsTxt(BuildContext context, {required List<Anime> animes, required String displayName, required AppLocalizations l10n})` <a id="sharestatisticstxt"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1611 行）
- **用途：** 把当前可见的统计动画列表导出为纯文本显示名文件，每行一个，按字典序排序。
- **输入：** `context`、`animes`、`displayName`、`l10n`。
- **返回：** `Future<void>`。
- **副作用：** 写临时 `.txt` 文件；经平台流程分享/保存它；成功、失败或列表为空时显示 snackbar。
- **算法：** `animes` 为空时显示"空"snackbar 并返回。按 `displayTitle` 排序 `animes` 的副本，每行写一个名称到临时文件，然后分享（Android/iOS）或提供另存为对话框（桌面）；任何异常显示"分享失败"。
- **用法：**
  ```dart
  await ShareService.shareStatisticsTxt(
    context,
    animes: animes,
    displayName: displayName,
    l10n: l10n,
  );
  ```
  （来自 `lib/features/anime/views/statistics_page.dart`，"分享为 TXT"选项）
- **备注：** 不含个人观看数据——只有显示名，与 [`../../../features/share-and-import.md`](../../../features/share-and-import.md) 对此导出的描述一致。

### `static Future<List<Uint8List>> _generateStatisticsShareImage({required List<StatisticsShareEntry> entries, required String title, required String subtitle, required AppLocalizations l10n, StatisticsShareSummary? summary, ValueNotifier<double>? progress})` <a id="_generatestatisticsshareimage"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1685 行）
- **用途：** 布局并渲染统计分享图像——可选第 1 页带摘要条形图——需要时拆分为多个 PNG 页。
- **输入：** `entries`、`title`、`subtitle`、`l10n`、可选 `summary`、可选 `progress`。
- **返回：** `Future<List<Uint8List>>` — 一个或多个 PNG 页。
- **副作用：** 加载应用 logo；经 [`_loadShareCoverImages`](#_loadsharecoverimages) 加载每个不同封面图像（报告 `progress`）。
- **算法：** 结构上是 [`_generateRankingShareImage`](#_generaterankingshareimage) 的统计对应物，多一个细节：
  1. 布局标题 + 副标题作为共享页头。
  2. `summary != null` 时，在页头正下方为 3 条图（`chartHeight`）预留空间——**仅第一页**。
  3. 跟踪两个不同的"首行 Y"值：`firstPagePreRowsY`（页头 + 图，第 1 页用）和 `subsequentPreRowsY`（仅页头，后续页用）——后续页因为跳过图而有更多垂直行空间。
  4. `renderPage(start, end, isFirst, isLast)` 每页绘制页头、只在 `isFirst && summary != null` 时绘制条形图（经 [`_drawSummaryBars`](#_drawsummarybars)）、经 [`_drawStatisticsRow`](#_drawstatisticsrow) 绘制行 `[start, end)`、只在 `isLast` 时绘制水印。
  5. 一切能放下一页（`totalCardHeight * _pixelRatio <= _maxImageDimension`）时渲染一页。否则独立计算 `firstPageRows`/`laterRows`（因为图的存在它们的可用行空间不同）并相应分页。
- **用法：** 从 [`shareStatisticsImage`](#sharestatisticsimage) 和 [`generateStatisticsShareBytes`](#generatestatisticssharebytes) 内部调用。
- **备注：** 见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md) 的"多页拆分"说明——摘要条形图只出现在第 1 页、页头每页重复，是排名生成器更简单方案之上的统计特有细节。

### `static void _drawSummaryBars(Canvas canvas, double y, double contentWidth, StatisticsShareSummary summary, AppLocalizations l10n, {required double barH, required double barGap})` <a id="_drawsummarybars"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1885 行）
- **用途：** 绘制构成统计分享图像摘要图的三条水平条（已跟踪、已完成、弃看）。
- **输入：** `canvas`、`y`（图顶部）、`contentWidth`、`summary`、`l10n`、`barH`、`barGap`。
- **返回：** 无。
- **副作用：** 无（纯画布绘制）。
- **算法：**
  1. 构建 `(label, value, color)` 三元组：已跟踪（强调色）、已完成（绿）、弃看（红），并找三个中的 `maxVal`。
  2. 按顺序对每条：绘制其 `"<label>: <count>"` 文本，然后圆角轨道矩形，然后宽度为 `contentWidth * value / maxVal`（与三个计数中最大的成比例，因此至少一条总是达到全宽）的圆角填充矩形——`maxVal` 为 0 时跳过。
- **用法：** 提供 `summary` 时从 [`_generateStatisticsShareImage`](#_generatestatisticsshareimage)（仅第一页）内部调用。
- **备注：** 条按**三个值中最大者**缩放，不是固定总数——因此如"已跟踪"远大于"已完成"/"弃看"时，那两条会显得相对较小，而不是各自凑成固定宽度。

### `static Future<Map<String, ui.Image>> _loadShareCoverImages(List<Anime> animes, ValueNotifier<double>? progress)` <a id="_loadsharecoverimages"></a>
- **种类：** `ShareService` 的静态方法
- **来源：** `lib/shared/services/share_service.dart`（约第 1940 行）
- **用途：** 加载并解码动画列表引用的每个不同封面图像，报告加载进度，供排名/统计图像生成器使用。
- **输入：** `animes` — 应加载其 `coverImage` 的动画；`progress` — 可选 `ValueNotifier`，封面加载时更新为 0..1 分数（完成时强制为 1）。
- **返回：** `Future<Map<String, ui.Image>>`，以动画的 `coverImage` 相对路径为键。
- **副作用：** 从 `<应用目录>/images/` 读取图像文件（经 [`ImageService.resolve`](image_service.md#resolve)）；提供时修改 `progress.value`。
- **算法：**
  1. 构建要加载的封面路径去重列表（跳过无封面的动画，跳过已入队或已加载的路径）。
  2. 没有要加载的时，设 `progress` 为 1 并立即返回空映射。
  3. 对每个封面路径，解析它，文件存在时经 `ui.instantiateImageCodec` 读取 + 解码；单个封面失败被静默吞掉（该条目只是不在结果映射中），使一张坏封面不会中止整个导出。
  4. 每张封面后更新 `progress.value` 为 `(i + 1) / coversToLoad.length`；结束时无论如何设为 1。
- **用法：** 从 [`_generateRankingShareImage`](#_generaterankingshareimage) 和 [`_generateStatisticsShareImage`](#_generatestatisticsshareimage) 内部调用。
- **备注：** 去重意味着共享同一 `coverImage` 路径的两部动画（如来自合并）只付出一次解码成本。

### `const StatisticsShareEntry({required this.anime, required this.rank, this.score, this.statusLabel, this.progressLabel})` <a id="statisticsshareentry-new"></a>
- **种类：** `StatisticsShareEntry` 的构造函数
- **来源：** `lib/shared/services/share_service.dart`（约第 2130 行）
- **用途：** 为统计分享图像行保存一部动画的排名加可选分数/状态/进度标签。
- **输入：** `anime`、`rank`；可选 `score`、`statusLabel`、`progressLabel`。
- **返回：** 新的 `StatisticsShareEntry`。
- **副作用：** 无。
- **算法：** 直接字段赋值。
- **用法：** 由 `lib/features/anime/views/statistics_page.dart` 在调用 [`generateStatisticsShareBytes`](#generatestatisticssharebytes) 前从当前过滤/分组动画列表构建。
- **备注：** 与 `RankingShareEntry` 不同，这里的 `score` 可空——统计行可能有也可能没有评分，而排名行总是有排序字段的分数。

### `const StatisticsShareSummary({required this.tracked, required this.completed, required this.dropped})` <a id="statisticssharesummary-new"></a>
- **种类：** `StatisticsShareSummary` 的构造函数
- **来源：** `lib/shared/services/share_service.dart`（约第 2150 行）
- **用途：** 保存统计分享图像摘要条形图绘制的三个计数。
- **输入：** `tracked`、`completed`、`dropped`。
- **返回：** 新的 `StatisticsShareSummary`。
- **副作用：** 无。
- **算法：** 直接字段赋值。
- **用法：** 用户选择条形图图像变体时作为 `summary` 参数传给 [`generateStatisticsShareBytes`](#generatestatisticssharebytes) / [`shareStatisticsImage`](#sharestatisticsimage)。
- **备注：** 无。
