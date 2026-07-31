# lib/features/anime/views/home_page.dart

`HomePage` 是应用的默认标签：一个感知 JST 的日历（`table_calendar`），显示所选日期播出哪些剧集，外加跨每部被跟踪动画的已播出但未看剧集的滚动列表。它读取 `AppSettings`（经 `flutter_riverpod`，[`../../../shared/providers/app_settings.md`](../../../shared/providers/app_settings.md)）决定日历布局/时间基准，用 `JstTime`（[`../../../shared/utils/jst_time.md`](../../../shared/utils/jst_time.md)）和 `calendar_preferences.dart`（[`../../../shared/utils/calendar_preferences.md`](../../../shared/utils/calendar_preferences.md)）做日期数学，并经 `AnimeStorage`（[`../services/anime_storage.md`](../services/anime_storage.md)）持久化剧集状态变更。日历/时间基准功能描述见 [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md)，本页消费的底层剧集播出日期逻辑见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `HomePage.new` | 构造函数（`HomePage`） | B | 创建 `HomePage` 实例。 |
| `HomePage.createState` | 方法（`HomePage`） | B | 为此组件创建可变状态对象。 |
| `_HomePageState.initState` | 方法（`_HomePageState`） | B | 注册同步重载回调并触发首次加载。 |
| `_HomePageState.dispose` | 方法（`_HomePageState`） | B | 注销同步重载回调。 |
| [`_load`](#_load) | 方法（`_HomePageState`） | A | 从存储重载所有动画。 |
| [`_getEventsForDay`](#_geteventsforday) | 方法（`_HomePageState`） | A | 收集给定日历日播出的每个剧集。 |
| [`_today`](#_today) | 方法（`_HomePageState`） | A | 在所选主页日历时间基准下返回"今天"。 |
| [`_getEpisodeCalendarDate`](#_getepisodecalendardate) | 方法（`_HomePageState`） | A | 在所选时间基准下解析一集的日历日期。 |
| [`_getEpisodeDisplayAirDate`](#_getepisodedisplayairdate) | 方法（`_HomePageState`） | A | 在所选时间基准下解析一集的显示播出日期/时间。 |
| [`_getUnwatchedEpisodes`](#_getunwatchedepisodes) | 方法（`_HomePageState`） | A | 构建已播出但未看剧集的排序列表，每部动画一条。 |
| [`_countUnwatchedAiredEpisodes`](#_countunwatchedairedepisodes) | 方法（`_HomePageState`） | A | 统计每部动画中所有已播出未看剧集。 |
| [`_toggleWatched`](#_togglewatched) | 方法（`_HomePageState`） | A | 在已看与未看之间切换一集。 |
| [`_showAddOptions`](#_showaddoptions) | 方法（`_HomePageState`） | A | 显示新增/导入选择对话框并打开结果动画。 |
| `_HomePageState.build` | 方法（`_HomePageState`，组件构建） | B | 构建日历、所选日列表和未看列表。 |
| `_calendarDateLocale` | 方法（`_HomePageState`） | B | 选日历月/日期文本使用的语言区域。 |
| `_formatCalendarMonth` | 方法（`_HomePageState`） | B | 格式化日历页头的月份标签。 |
| `_calendarWeekdayLabel` | 方法（`_HomePageState`） | B | 格式化一个星期行标签（日式单字符或本地化）。 |
| `_startingDayOfWeek` | 方法（`_HomePageState`） | B | 把周起始星期转换为 `TableCalendar` 的枚举。 |
| `_calendarTimeNote` | 方法（`_HomePageState`） | B | 本地化当前时间基准的解释性说明。 |
| `_buildEpisodeTile` | 方法（组件辅助） | B | 渲染一个剧集行（封面、标题、播出日期、观看切换）。 |
| `_AiringEpisode.new` | 构造函数（`_AiringEpisode`） | B | 把一部动画与它的一个集编号配对。 |

## 文档

### `Future<void> _load()` <a id="_load"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 73 行）
- **用途：** 把完整动画列表从存储重载进 `_allAnime`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.load()`；`setState` `_allAnime`。
- **算法：** Await `AnimeStorage.load()`；仍 mounted 时 `setState(() => _allAnime = data.animeList)`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnLocalDataChanged(_load);
    _load();
  }
  ```
  （`_HomePageState.initState`，同一文件；也在 `build` 中接成 `RefreshIndicator.onRefresh`，并注册给 `AutoSyncService`，使后台同步/恢复触发重载）
- **备注：** 在 `initState` 中注册给 [`AutoSyncService.addOnLocalDataChanged`](../../../shared/services/auto_sync_service.md#addonlocaldatachanged) 并在 `dispose` 注销，使后台同步或备份恢复替换本地数据后日历自动刷新。

### `List<_AiringEpisode> _getEventsForDay(DateTime day, HomeCalendarTimeBasis timeBasis)` <a id="_geteventsforday"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 83 行）
- **用途：** 收集跨每部被跟踪动画、日历日期（在给定时间基准下）匹配 `day` 的每个剧集。
- **输入：** `day`；`timeBasis` — `HomeCalendarTimeBasis.jst` 或 `.local`。
- **返回：** `List<_AiringEpisode>`。
- **副作用：** 无。
- **算法：**
  1. 把 `day` 规范化为纯日期 `DateTime`。
  2. 对每部动画，从 `startEpisode` 到 `endEpisode ?? startEpisode` 循环每个剧集。
  3. 对每个剧集，经 [`_getEpisodeCalendarDate`](#_getepisodecalendardate) 计算其日历日期；等于 `dayOnly` 时添加 `_AiringEpisode(anime: anime, episode: ep)`。
- **用法：**
  ```dart
  eventLoader: (day) =>
      _getEventsForDay(day, settings.homeCalendarTimeBasis),
  ```
  （`_HomePageState.build`，`TableCalendar.eventLoader`——`selectedEvents` 也直接用）
- **备注：** 对没有 `endEpisode` 的长期连载动画，只扫描 `startEpisode` 本身（循环上界是 `anime.endEpisode ?? anime.startEpisode`），因此开放结局系列的未来剧集在这里绝不出现在日历事件中。

### `DateTime _today(HomeCalendarTimeBasis timeBasis)` <a id="_today"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 106 行）
- **用途：** 返回日历应高亮并默认选中其日期的纯日期"今天"，在所选主页日历时间基准下。
- **输入：** `timeBasis`。
- **返回：** `DateTime`（纯日期）。
- **副作用：** 无。
- **算法：** 对 `timeBasis` 做 `switch`：`jst` → `JstTime.today()`；`local` → `JstTime.localToday()`。
- **用法：**
  ```dart
  final calendarToday = _today(settings.homeCalendarTimeBasis);
  final focusedDay = _focusedDay ?? calendarToday;
  final selectedDay = _selectedDay ?? calendarToday;
  ```
  （`_HomePageState.build`，同一文件）
- **备注：** 这是 [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md) 描述的"日历日期网格默认日本时间，但可以切换到设备本地时区"行为的具体实现。

### `DateTime? _getEpisodeCalendarDate(Anime anime, int episode, HomeCalendarTimeBasis timeBasis)` <a id="_getepisodecalendardate"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 118 行）
- **用途：** 解析一集在日历网格归属中应落在哪个日历日，尊重本地时间切换，同时把一次性放送固定在其 JST 发布日期上。
- **输入：** `anime`；`episode`；`timeBasis`。
- **返回：** `DateTime?`（纯日期），动画日程数据不完整时为 `null`。
- **副作用：** 无。
- **算法：**
  1. `timeBasis` 为 `jst`，或动画的 `effectiveType` 为 `allAtOnce` 时，直接返回 [`anime.getEpisodeCalendarDate(episode)`](../models/anime.md#getepisodecalendardate)（JST 日历日期，不回卷）。
  2. 否则（本地基准、非一次性放送）：经 [`anime.getEpisodeAirDate(episode)`](../models/anime.md#getepisodeairdate) 取 JST 播出时刻；为 `null` 时回退到 JST 日历日期；否则经 `JstTime.toLocal` 转换为本地时间并取其纯日期部分。
- **用法：**
  ```dart
  final calDate = _getEpisodeCalendarDate(anime, ep, timeBasis);
  if (calDate != null && calDate == dayOnly) {
    events.add(_AiringEpisode(anime: anime, episode: ep));
  }
  ```
  （`_getEventsForDay`，同一文件）
- **备注：** 这是"即使切换到本地时间，动画播出时间戳仍按日本时间计算"背后的机制——底层播出*时刻*总是来自模型基于 JST 的逻辑；只有最终的本地/JST 日期转换发生在这里。见 [`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md)。

### `DateTime? _getEpisodeDisplayAirDate(Anime anime, int episode, HomeCalendarTimeBasis timeBasis)` <a id="_getepisodedisplayairdate"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 142 行）
- **用途：** 解析剧集块上作为文本显示的播出日期/时间，遵循与 [`_getEpisodeCalendarDate`](#_getepisodecalendardate) 相同的本地/JST 和一次性放送规则，但在相关时返回完整播出时刻（不只是日期）。
- **输入：** `anime`；`episode`；`timeBasis`。
- **返回：** `DateTime?`。
- **副作用：** 无。
- **算法：**
  1. `effectiveType == allAtOnce` 时返回 JST 日历日期。
  2. 否则经 `getEpisodeAirDate` 取 JST 播出时刻；不可用时返回 `null`。
  3. `timeBasis == local` 时把它转换为本地时间（`JstTime.toLocal`）返回，否则原样返回 JST 时刻。
- **用法：**
  ```dart
  final airDate = _getEpisodeDisplayAirDate(
    ep.anime,
    ep.episode,
    settings.homeCalendarTimeBasis,
  );
  ```
  （`_buildEpisodeTile`，同一文件，格式化显示的播出日期字符串）
- **备注：** 与 [`_getEpisodeCalendarDate`](#_getepisodecalendardate) 不同，这保留完整日内时刻（不只是日期），因为它喂给显示文本而不是日历网格归属。

### `List<_AiringEpisode> _getUnwatchedEpisodes()` <a id="_getunwatchedepisodes"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 163 行）
- **用途：** 构建日历下方显示的"已播出但未看"列表——每部动画最早的一条未看、已播出剧集，按播出日期排序。
- **输入：** 无。
- **返回：** `List<_AiringEpisode>`。
- **副作用：** 无。
- **算法：**
  1. 对每部动画，从 `startEpisode` 向上扫描；找第一条状态为（或默认为）`unwatched` 的剧集。
  2. 该剧集有播出日期（JST，经 `getEpisodeAirDate`）且不晚于 `JstTime.now()`（即已经播出）时，加入结果列表。
  3. 无论是否合格，都在每部动画的第一条未看剧集后 `break`——每部动画只考虑一个候选。
  4. 按播出日期升序排序结果，`null` 播出日期排最后。
- **用法：**
  ```dart
  final unwatched = _getUnwatchedEpisodes();
  ```
  （`_HomePageState.build`，同一文件）
- **备注：** 因为扫描在每部动画的第一条未看剧集处 `break`，第 3 集未看但第 4 集已播出的动画在这里只会浮出第 3 集——更靠后的已播出剧集在更早的一集被解决之前保持隐藏。

### `int _countUnwatchedAiredEpisodes()` <a id="_countunwatchedairedepisodes"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 194 行）
- **用途：** 统计每部动画中所有仍未看的已播出剧集，供未看列表上方的摘要文本使用。
- **输入：** 无。
- **返回：** `int`。
- **副作用：** 无。
- **算法：** 与 [`_getUnwatchedEpisodes`](#_getunwatchedepisodes) 不同，这**不**在每部动画的第一条未看剧集处停下——它扫描每部动画的每个剧集，为每个 `unwatched`（或未设置）且播出日期不晚于现在的剧集增加计数。
- **用法：**
  ```dart
  l10n.homeUnwatched(unwatched.length, unwatchedEpisodeCount),
  ```
  （`_HomePageState.build`，未看小节页头——`unwatched.length` 是来自 `_getUnwatchedEpisodes` 的动画数，`unwatchedEpisodeCount` 是本方法的剧集总数）
- **备注：** 这正是页头能显示比可见行数更大的剧集数的原因——可见列表每部动画上限一行，而这个计数反映每个积压剧集。

### `Future<void> _toggleWatched(_AiringEpisode ep)` <a id="_togglewatched"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 217 行）
- **用途：** 从主页的剧集块在 `watched` 与 `unwatched` 之间切换一集。
- **输入：** `ep` — 被切换的 `_AiringEpisode`（动画 + 集编号）。
- **返回：** `Future<void>`。
- **副作用：** 调用 `AnimeStorage.addOrUpdate`；经 `_load()` 重载。
- **算法：** 翻转该集状态：任何非 `watched` 的变成 `watched`；`watched` 变成 `unwatched`。经 `copyWith(episodeStatuses: ..., modifiedAt: ...)` 持久化并 `_load()`。
- **用法：**
  ```dart
  onPressed: () => _toggleWatched(ep),
  ```
  （`_buildEpisodeTile`，同一文件）
- **备注：** 与详情页的 [`_toggleEpisode`](anime_detail_page.md#_toggleepisode)（循环三种状态）不同，这是普通的二态切换——它绝不可能设置 `skippedThisWeek`。

### `Future<void> _showAddOptions()` <a id="_showaddoptions"></a>
- **种类：** `_HomePageState` 的方法
- **来源：** `lib/features/anime/views/home_page.dart`（约第 237 行）
- **用途：** 显示"创建"vs"导入"选择对话框，然后导航到用户选择的流程并打开结果动画的详情页。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 显示 `SimpleDialog`；经 `context.push` 导航；可能运行导入捆绑流程（文件系统读）；每步经 `_load()` 重载。
- **算法：**
  1. 显示提供"创建"或"导入"的 `SimpleDialog`；未作选择被关闭则返回。
  2. `'create'` 时：push `/anime/edit`，重载，返回新 ID 时 push `/anime/detail/$newId` 并再次重载。
  3. `'import'` 时：运行 `showImportBundleFlow(context)`，重载，导入任何 ID 时 push 第一个导入 ID 的详情页并再次重载。
- **用法：**
  ```dart
  floatingActionButton: FloatingActionButton(
    onPressed: _showAddOptions,
    tooltip: l10n.animeAdd,
    child: const Icon(Icons.add),
  ),
  ```
  （`_HomePageState.build`，同一文件）
- **备注：** 与 `ManagementPage._showAddOptions`（[`management_page.md`](management_page.md#_showaddoptions)）结构相同，只是本页之后不把日历跳到任何特定日期（管理版的跳转到新动画的季度）。
