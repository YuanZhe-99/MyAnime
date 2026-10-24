# lib/shared/services/home_widget_service.dart

`HomeWidgetService` 为 Android 和 iOS 桌面小组件提供数据。它构建一份包含观看队列、今天的剧集和未来一周的 JSON 快照，并通过 `com.yuanzhe.my_anime/home_widget` method channel 交给原生端。小组件、快照格式和原生读取端见 [`../../../features/home-screen-widgets.md`](../../../features/home-screen-widgets.md)——本页介绍 Dart 声明。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`HomeWidgetService._`](#homewidgetservice-_) | 构造函数（`HomeWidgetService`） | B | 阻止实例化；该类纯静态。 |
| [`isSupported`](#issupported) | getter（`HomeWidgetService`） | B | 平台是否有桌面小组件（Android、iOS）。 |
| [`init`](#init) | 方法（`HomeWidgetService`） | A | 订阅同步/恢复重载并推送第一份快照。 |
| [`notifyDataChanged`](#notifydatachanged) | 方法（`HomeWidgetService`） | A | 数据或设置变更后防抖地安排刷新。 |
| [`refresh`](#refresh) | 方法（`HomeWidgetService`） | A | 从存储重建快照并发送给原生小组件。 |
| [`labelsFor`](#labelsfor) | 方法（`HomeWidgetService`） | A | 收集本地化的小组件字符串。 |
| [`buildSnapshot`](#buildsnapshot) | 方法（`HomeWidgetService`） | A | 为某一时刻的资料库构建快照 map。 |
| [`jstToUtc`](#jsttoutc) | 方法（`HomeWidgetService`） | A | 把动画模型的日本挂钟时间转换为 UTC 时刻。 |
| [`_startOfToday`](#_startoftoday) | 方法（`HomeWidgetService`） | A | 给定日历时间基准下「今天」开始的 UTC 时刻。 |
| [`_l10n`](#_l10n) | 方法（`HomeWidgetService`） | B | 从保存的语言区域或平台默认值解析本地化。 |

常量：`formatVersion`（1）、`lookahead`（8 天）、`maxEpisodes`（80），以及私有的 `_channel`。

## 文档

### `static Future<void> init()` <a id="init"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 一次性启动：把 [`notifyDataChanged`](#notifydatachanged) 注册为 `AutoSyncService` 的本地数据变更回调，并推送第一份快照。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 添加一个同步回调；启动 [`refresh`](#refresh)，不 await。
- **算法：** [`isSupported`](#issupported) 为 false 时立即返回。
- **用法：** 在 提醒服务启动之后从 `main()` 调用。
- **备注：** 该回调覆盖同步下载和备份恢复，它们会调用 `notifyLocalDataChangedNow()`。

### `static void notifyDataChanged()` <a id="notifydatachanged"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 在最后一次变更后 2 秒安排一次刷新。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 取消并重新启动一个调用 [`refresh`](#refresh) 的 `Timer`。
- **算法：** 在不支持的平台上为空操作。
- **用法：** `AnimeStorage._writeData`、`AutoSyncService` 的恢复钩子与本地数据变更回调，以及 `AppSettingsNotifier.setLocale` / `setHomeCalendarTimeBasis`。
- **备注：** 防抖把突发变更（例如一次同步应用大量记录）合并为一次。

### `static Future<void> refresh()` <a id="refresh"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 重建快照并重绘小组件。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `anime_data.json`（`AnimeStorage.load`）以及 `storage_config.json` 的 `homeCalendarTimeBasis` 和语言区域键；在通道上调用 `update`，由原生端保存 JSON 并重绘每个已放置的小组件。
- **算法：** 加载 → 解析时间基准（`'local'` 或 JST）→ 解析本地化 → 以 `DateTime.now().toUtc()` 和 [`labelsFor`](#labelsfor) 调用 [`buildSnapshot`](#buildsnapshot) → `jsonEncode` → `invokeMethod('update', {'snapshot': json})`。
- **用法：** 经 [`notifyDataChanged`](#notifydatachanged) 和 [`init`](#init) 调用。
- **备注：** 每个失败都被记录并吞掉；过时的小组件无害。

### `static Map<String, String> labelsFor(AppLocalizations l10n)` <a id="labelsfor"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 从 ARB 字符串收集小组件文案。
- **输入：** `l10n`。
- **返回：** 键 `appName`、`toWatch`、`today`、`caughtUp`、`noUpdates`、`next`、`episode`、`series`。
- **副作用：** 无。
- **算法：** 以字面量 `{n}` 调用 `widgetEpisode` 和 `widgetSeriesCount`，由原生端替换为数字。
- **用法：** [`refresh`](#refresh)。
- **备注：** `appName` 始终为 `MyAnime`。

### `static Map<String, dynamic> buildSnapshot(List<Anime> animeList, {required DateTime nowUtc, required HomeCalendarTimeBasis basis, required Map<String, String> labels})` <a id="buildsnapshot"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 构建第 1 版快照。
- **输入：** `animeList`；`nowUtc`；`basis` — 哪个日历日算作今天；`labels`。
- **返回：** 一个可直接序列化为 JSON 的 map，包含 `v`、`generatedAt`、`timeZone`、`airedUnwatched`、`queueSize`、`episodes` 和 `labels`。
- **副作用：** 无。
- **算法：** 对每部动画，像首页一样遍历 `startEpisode..(endEpisode ?? startEpisode)`。对每个有播出时间的剧集，用 [`jstToUtc`](#jsttoutc) 转换；未看且已播出时计入 `airedUnwatched`；第一个这样的剧集作为该动画的队列条目；否则当它在 [`_startOfToday`](#_startoftoday) 与 `now + lookahead` 之间播出时保留。两个列表都按播出时间排序，队列条目在前，最多保留 `maxEpisodes` 个，然后把结果按播出时间排序。状态不是未看的任何剧集 `w` 都为 true。
- **用法：** [`refresh`](#refresh)；`test/home_widget_service_test.dart`。
- **备注：** 原生端的重新计数（`toWatch = airedUnwatched + newly aired unwatched entries`）依赖于 `generatedAt` 之后直到前瞻窗口结束的每一集都在快照中。

### `static DateTime jstToUtc(DateTime jst)` <a id="jsttoutc"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 把 `getEpisodeAirDate` 的值（日本挂钟时间）转换为 UTC 时刻。
- **输入：** `jst`，无论其 `isUtc` 标志如何。
- **返回：** UTC 的 `DateTime`。
- **副作用：** 无。
- **算法：** `DateTime.utc(y, m, d, h - 9, min, s)`。
- **用法：** [`buildSnapshot`](#buildsnapshot)。
- **备注：** 与 `JstTime.toLocal` 的算术相同，只是没有最后的本地转换。

### `static DateTime _startOfToday(DateTime nowUtc, HomeCalendarTimeBasis basis)` <a id="_startoftoday"></a>
- **种类：** `HomeWidgetService` 的静态方法
- **来源：** `lib/shared/services/home_widget_service.dart`
- **用途：** 以 UTC 时刻返回「今天」开始的时间。
- **输入：** `nowUtc`、`basis`。
- **返回：** JST 基准下为 JST 午夜，否则为设备本地午夜。
- **副作用：** 无。
- **算法：** JST：平移 +9 小时，取日期，以 UTC 构建，再平移回 9 小时。本地：取本地日期并转换为 UTC。
- **用法：** [`buildSnapshot`](#buildsnapshot)。
- **备注：** 无。

### Tier B 条目

- `HomeWidgetService._` <a id="homewidgetservice-_"></a> — 私有构造函数；纯静态类。
- `isSupported` <a id="issupported"></a> — `!kIsWeb && (Android || iOS)`；否则每个公开入口都提前返回。
- `_l10n` <a id="_l10n"></a> — 沿用 提醒服务的语言区域解析，查找抛出时回退为英文。
