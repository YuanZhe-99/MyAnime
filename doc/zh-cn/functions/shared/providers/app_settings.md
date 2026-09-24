# lib/shared/providers/app_settings.dart

设备本地应用偏好的 `flutter_riverpod` provider：主题模式、语言区域、日历周起始日，以及主页日历布局/时间基准/视图格式三项。`AppSettingsNotifier` 在构造时从 `AnimeStorage`（`lib/features/anime/services/anime_storage.dart`）加载持久化值，并把每个 setter 调用持久化回它。`AppSettings` 是经 `appSettingsProvider` 暴露的不可变状态类。状态管理约定（Riverpod、不用 Provider/Bloc）见 [../../../architecture.md](../../../architecture.md)，这些值在 `storage_config.json` 中的位置见 [../../../data-formats.md](../../../data-formats.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_parseHomeCalendarLayout`](#parsehomecalendarlayout) | 顶层函数 | A | 解析存储的主页日历布局字符串。 |
| [`_parseHomeCalendarTimeBasis`](#parsehomecalendartimebasis) | 顶层函数 | A | 解析存储的主页日历时间基准字符串。 |
| [`_parseHomeCalendarFormat`](#parsehomecalendarformat) | 顶层函数 | A | 解析存储的主页日历视图格式字符串。 |
| [`AppSettingsNotifier.new`](#appsettingsnotifier-new) | 构造函数（`AppSettingsNotifier`） | A | 创建 `AppSettingsNotifier` 并触发加载持久化设置。 |
| `AppSettingsNotifier.fixed` | 构造函数（`AppSettingsNotifier`） | B | 创建一个从固定设置开始、不读取磁盘的通知器；供覆盖 `appSettingsProvider` 的测试使用。 |
| [`AppSettingsNotifier._loadPersisted`](#appsettingsnotifier_loadpersisted) | 方法（`AppSettingsNotifier`） | A | 把持久化设置从存储加载进状态。 |
| [`AppSettingsNotifier.setThemeMode`](#appsettingsnotifier-setthememode) | 方法（`AppSettingsNotifier`） | A | 更新主题模式并持久化它。 |
| [`AppSettingsNotifier.setLocale`](#appsettingsnotifier-setlocale) | 方法（`AppSettingsNotifier`） | A | 更新语言区域并持久化它。 |
| [`AppSettingsNotifier.setWeekStartDay`](#appsettingsnotifier-setweekstartday) | 方法（`AppSettingsNotifier`） | A | 更新应用级日历周起始日并持久化它。 |
| [`AppSettingsNotifier.setHomeCalendarLayout`](#appsettingsnotifier-sethomecalendarlayout) | 方法（`AppSettingsNotifier`） | A | 更新主页日历日名布局并持久化它。 |
| [`AppSettingsNotifier.setHomeCalendarTimeBasis`](#appsettingsnotifier-sethomecalendartimebasis) | 方法（`AppSettingsNotifier`） | A | 更新主页日历日期网格使用 JST 还是本地日期，并持久化它。 |
| [`AppSettingsNotifier.setHomeCalendarFormat`](#appsettingsnotifier-sethomecalendarformat) | 方法（`AppSettingsNotifier`） | A | 更新记住的主页日历视图格式并持久化它。 |
| `AppSettingsNotifier.setHomeListColumns` | 方法（`AppSettingsNotifier`） | B | 更新并持久化记住的首页列表列数偏好。 |
| `AppSettingsNotifier.setManageListColumns` | 方法（`AppSettingsNotifier`） | B | 更新并持久化记住的管理列表列数偏好。 |
| `AppSettingsNotifier.setStatsListColumns` | 方法（`AppSettingsNotifier`） | B | 更新并持久化记住的统计列表列数偏好。 |
| `AppSettingsNotifier.setKanaTabEnabled` | 方法（`AppSettingsNotifier`） | B | 显示或隐藏假名标签并持久化该选择。 |
| [`AppSettingsNotifier.setOnDeviceAiEnabled`](#appsettingsnotifier-setondeviceaienabled) | 方法（`AppSettingsNotifier`） | A | 开启或关闭端侧 AI，持久化该选择，并切换 `OnDeviceAiService`。 |
| `AppSettingsNotifier.setOnDeviceAiPreferFast` | 方法（`AppSettingsNotifier`） | B | 在设备同时提供两种尺寸时优先使用更快的端侧模型；持久化该选择并告知 `OnDeviceAiService`。 |
| [`AppSettingsNotifier.setAutoCategoriesEnabled`](#appsettingsnotifier-setautocategoriesenabled) | 方法（`AppSettingsNotifier`） | A | 开启或关闭自动分类，持久化该选择并切换 `CategoryClassifier`。 |
| [`AppSettingsNotifier.setRecommendationsEnabled`](#appsettingsnotifier-setrecommendationsenabled) | 方法（`AppSettingsNotifier`） | A | 开启或关闭推荐并持久化该选择。 |
| [`AppSettingsNotifier._dropAiIfUnused`](#appsettingsnotifier_dropaiifunused) | 方法（`AppSettingsNotifier`） | A | 在没有功能使用端侧 AI 时将其关闭。 |
| [`AppSettings.new`](#appsettings-new) | 构造函数（`AppSettings`） | A | 创建 `AppSettings` 实例。 |
| [`AppSettings.effectiveWeekStartDay`](#appsettings-effectiveweekstartday) | getter（`AppSettings`） | A | 返回应应用于日历的周起始日。 |
| [`AppSettings.copyWith`](#appsettings-copywith) | 方法（`AppSettings`） | A | 用所选字段创建副本。 |

`AppSettings` 的六个字段（`themeMode`、`locale`、`weekStartDay`、`homeCalendarLayout`、`homeCalendarTimeBasis`、`homeCalendarFormat`）和顶层 `appSettingsProvider` 是源码中没有 `/// Purpose:` 注释的普通字段/provider 声明，不作为单独行索引。

## 文档

### `HomeCalendarLayout _parseHomeCalendarLayout(String? value)` <a id="parsehomecalendarlayout"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/providers/app_settings.dart`（约第 13 行）
- **用途：** 把持久化的主页日历布局 `storage_config.json` 字符串转换为 `HomeCalendarLayout` 枚举。
- **输入：** `value` — 原始存储字符串，或 `null`。
- **返回：** `value == 'japanese'` 时为 `HomeCalendarLayout.japanese`，否则 `HomeCalendarLayout.local`。
- **副作用：** 无。
- **算法：** 单个 `switch` 表达式：`'japanese'` 映射到 `HomeCalendarLayout.japanese`；其他每个值（含 `null` 和任何不可识别字符串）落入 `HomeCalendarLayout.local`。
- **用法：**
  ```dart
  final homeCalendarLayout = _parseHomeCalendarLayout(
    await AnimeStorage.getHomeCalendarLayout(),
  );
  ```
  （来自 `AppSettingsNotifier._loadPersisted`，同一文件）
- **备注：** 未知/损坏的存储值静默默认 `local` 而不是抛出。

### `HomeCalendarTimeBasis _parseHomeCalendarTimeBasis(String? value)` <a id="parsehomecalendartimebasis"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/providers/app_settings.dart`（约第 25 行）
- **用途：** 把持久化的主页日历时间基准 `storage_config.json` 字符串转换为 `HomeCalendarTimeBasis` 枚举。
- **输入：** `value` — 原始存储字符串，或 `null`。
- **返回：** `value == 'local'` 时为 `HomeCalendarTimeBasis.local`，否则 `HomeCalendarTimeBasis.jst`。
- **副作用：** 无。
- **算法：** 单个 `switch` 表达式：`'local'` 映射到 `HomeCalendarTimeBasis.local`；其他一切（含 `null`）默认 `HomeCalendarTimeBasis.jst`。
- **用法：**
  ```dart
  final homeCalendarTimeBasis = _parseHomeCalendarTimeBasis(
    await AnimeStorage.getHomeCalendarTimeBasis(),
  );
  ```
  （来自 `AppSettingsNotifier._loadPersisted`，同一文件）
- **备注：** JST 是默认/回退基准，匹配应用 JST 优先的动画排程模型（见 `shared/utils/jst_time.dart`）。

### `CalendarFormat _parseHomeCalendarFormat(String? value)` <a id="parsehomecalendarformat"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/providers/app_settings.dart`（约第 37 行）
- **用途：** 把持久化的主页日历视图格式 `storage_config.json` 字符串转换为 `table_calendar` 的 `CalendarFormat` 枚举。
- **输入：** `value` — 原始存储字符串，或 `null`。
- **返回：** `'twoWeeks'` 为 `CalendarFormat.twoWeeks`，`'week'` 为 `CalendarFormat.week`，否则 `CalendarFormat.month`。
- **副作用：** 无。
- **算法：** 对两个非默认枚举名的单个 `switch` 表达式；其他一切（包括 `null`）默认为 `CalendarFormat.month`。
- **用法：**
  ```dart
  final homeCalendarFormat = _parseHomeCalendarFormat(
    await AnimeStorage.getHomeCalendarFormat(),
  );
  ```
  （来自 `AppSettingsNotifier._loadPersisted`，同一文件）
- **备注：** 这是设置层唯一依赖 `table_calendar` 的地方。复用该枚举而不是在 `calendar_preferences.dart` 里镜像一份，使调用点不需要任何格式映射；持久化的字符串就是枚举自己的 `name` 值。

### `AppSettingsNotifier()` <a id="appsettingsnotifier-new"></a>
- **种类：** `AppSettingsNotifier` 的构造函数（一个 `StateNotifier<AppSettings>`）
- **来源：** `lib/shared/providers/app_settings.dart`（约第 51 行）
- **用途：** 用默认 `AppSettings` 初始化 notifier，并启动加载持久化值。
- **输入：** 无。
- **返回：** 新的 `AppSettingsNotifier` 实例。
- **副作用：** 调用 `super(const AppSettings())` 然后触发 `_loadPersisted()`（即发即忘——构造函数不 await 它）。
- **算法：** 1) 把状态初始化为 `const AppSettings()`（全默认）。2) 不 await 地调用 `_loadPersisted()`，使 notifier 立即以默认值可用，并在存储被读取后异步更新。
- **用法：**
  ```dart
  final appSettingsProvider =
      StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier(),
      );
  ```
  （来自同一文件，provider 定义）
- **备注：** 因为加载是异步的且不被 await，在第一帧读取 `appSettingsProvider` 的 UI 代码可能短暂看到默认值，然后持久化值生效并触发重建。

### `Future<void> _loadPersisted()` <a id="appsettingsnotifier_loadpersisted"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 60 行）
- **用途：** 从 `AnimeStorage` 读取每个持久化偏好，并用完全填充的 `AppSettings` 替换 `state`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `AnimeStorage.getThemeMode()`、`getLocaleTag()`、`getWeekStartDay()`、`getHomeCalendarLayout()`、`getHomeCalendarTimeBasis()` 和 `getHomeCalendarFormat()`（以及本页末尾所述的列表列数、假名标签、端侧 AI 和自动分类 getter）；替换 `state`；设置 `CategoryClassifier.instance.enabled`；用加载到的值调用 `OnDeviceAiService.instance.setPreferFast` 和 `setEnabled`；随后启动一次分类细流，不 await。
- **算法：**
  1. Await 六个 `AnimeStorage` getter（主题模式字符串、语言区域标签、周起始日、主页日历布局字符串、主页日历时间基准字符串、主页日历格式字符串）。
  2. 经 `_parseHomeCalendarLayout`/`_parseHomeCalendarTimeBasis`/`_parseHomeCalendarFormat` 解析布局/时间基准/格式字符串。
  3. 经 `switch` 表达式把主题模式字符串（`'light'`/`'dark'`/其他任何东西）映射为 `ThemeMode.light`/`.dark`/`.system`。
  4. 存在语言区域标签时按 `_` 拆分；带 country code 部分的标签（如 `zh_TW`）变成 `Locale('zh', 'TW')`，否则普通 `Locale(languageCode)`。
  5. 用从解析值构建的新 `AppSettings(...)` 替换 `state`。
  6. 先把加载到的尺寸偏好、再把加载到的开关告知 `OnDeviceAiService.instance` —— 该服务自身不保存任何偏好。
     开关关闭时 `setEnabled(false)` 是无操作，因此默认启动不会调用平台的任何东西。
  7. 在第 6 步之前，把加载到的自动分类开关交给 `CategoryClassifier.instance.enabled`；在其之后，不 await 地调用
     `CategoryClassifier.instance.trickle()`。除非自动分类开启且模型可以生成，细流会立即返回，因此默认启动不做任何工作。
- **用法：** 只在 `AppSettingsNotifier()` 的构造函数中调用；不是公共 API 的一部分。
- **备注：** 有多个 `_` 的格式错误语言区域标签（如 `en_US_extra`）只用前两部分；除此之外没有显式校验。

### `void setThemeMode(ThemeMode mode)` <a id="appsettingsnotifier-setthememode"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 101 行）
- **用途：** 更新内存中的主题模式并持久化该选择。
- **输入：** `mode` — 新的 `ThemeMode`。
- **返回：** 无。
- **副作用：** 经 `copyWith` 更新 `state`；调用 `AnimeStorage.setThemeMode(str)`（即发即忘）。
- **算法：** 1) `state = state.copyWith(themeMode: mode)`。2) 经 `switch` 把 `mode` 映射为可空存储字符串（`'light'`、`'dark'` 或 `ThemeMode.system` 的 `null`）。3) 不 await 地调用 `AnimeStorage.setThemeMode(str)`。
- **用法：**
  ```dart
  onSelectionChanged: (s) => notifier.setThemeMode(s.first),
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，主题 `SegmentedButton`）
- **备注：** `ThemeMode.system` 存储为 `null` 而不是字符串 `'system'`——`_loadPersisted`/`switch` 中的解析器把任何非 `'light'`/`'dark'` 值（含 `null`）当作 `ThemeMode.system`。

### `void setLocale(Locale? locale)` <a id="appsettingsnotifier-setlocale"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 116 行）
- **用途：** 更新内存中的语言区域并持久化该选择（或清除它以跟随系统）。
- **输入：** `locale` — 新的 `Locale`，或 `null` 跟随系统语言区域。
- **返回：** 无。
- **副作用：** 经 `copyWith(locale: locale, clearLocale: locale == null)` 更新 `state`；调用 `AnimeStorage.setLocaleTag(...)`。
- **算法：** 1) 更新状态，`locale` 为 `null` 时显式发出 `clearLocale` 信号（`copyWith` 的可选字段模式否则无法区分"保持不变"与"设为 null"）。2) `locale` 为 `null` 时持久化 `null`。否则构建存储标签——有 country code 时为 `'<languageCode>_<countryCode>'`，否则只用 `languageCode`——并经 `AnimeStorage.setLocaleTag` 持久化它。
- **用法：**
  ```dart
  onChanged: (locale) => notifier.setLocale(locale),
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，语言 `DropdownButton`）
- **备注：** `copyWith` 上的 `clearLocale` 标志存在，正是为了让 `setLocale(null)` 能真正清空语言区域，而不是被其他字段使用的 `??` 回退模式忽略。

### `void setWeekStartDay(int weekday)` <a id="appsettingsnotifier-setweekstartday"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 133 行）
- **用途：** 更新应用级日历周起始日并持久化它。
- **输入：** `weekday` — Dart 星期编号（周一=1 … 周日=7）。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `AnimeStorage.setWeekStartDay(normalized)`。
- **算法：** 1) 经 [`normalizeWeekStartDay`](../utils/calendar_preferences.md#normalizeweekstartday) 规范化 `weekday`（越界值回退周日）。2) `state = state.copyWith(weekStartDay: normalized)`。3) 持久化规范化值。
- **用法：**
  ```dart
  onChanged: usesJapaneseCalendar
      ? null
      : (weekday) {
          if (weekday != null) notifier.setWeekStartDay(weekday);
        },
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，周起始日 `DropdownButton`）
- **备注：** 此设置只影响使用本地布局的日历；日式主页日历布局把*有效*周起始锁定为周日，无论此存储值如何（见 `AppSettings.effectiveWeekStartDay`）。

### `void setHomeCalendarLayout(HomeCalendarLayout layout)` <a id="appsettingsnotifier-sethomecalendarlayout"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 144 行）
- **用途：** 更新主页日历日名布局（本地 vs 日式）并持久化它。
- **输入：** `layout` — 新的 `HomeCalendarLayout`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `AnimeStorage.setHomeCalendarLayout(...)`。
- **算法：** 1) `state = state.copyWith(homeCalendarLayout: layout)`。2) `layout == HomeCalendarLayout.local`（默认）时持久化 `null`，否则持久化 `layout.name`（即 `'japanese'`）。
- **用法：**
  ```dart
  onChanged: (layout) {
    if (layout != null) notifier.setHomeCalendarLayout(layout);
  },
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，主页日历布局 `DropdownButton`）
- **备注：** 为默认（`local`）存储 `null` 使从未碰过此设置的用户的 `storage_config.json` 保持干净。

### `void setHomeCalendarTimeBasis(HomeCalendarTimeBasis basis)` <a id="appsettingsnotifier-sethomecalendartimebasis"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 156 行）
- **用途：** 更新主页日历日期网格使用 JST 还是本地日期，并持久化它。
- **输入：** `basis` — 新的 `HomeCalendarTimeBasis`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `AnimeStorage.setHomeCalendarTimeBasis(...)`。
- **算法：** 1) `state = state.copyWith(homeCalendarTimeBasis: basis)`。2) `basis == HomeCalendarTimeBasis.jst`（默认）时持久化 `null`，否则持久化 `basis.name`（即 `'local'`）。
- **用法：** 接到与 `setHomeCalendarLayout` 类似的设置页控件上（见 `lib/features/settings/views/settings_page.dart`，主页日历时间基准小节）。
- **备注：** 此设置只改变主页日历网格显示哪些日期；动画播出时间戳本身始终基于 JST，按 `AGENTS.md`。

### `void setHomeCalendarFormat(CalendarFormat format)` <a id="appsettingsnotifier-sethomecalendarformat"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 168 行）
- **用途：** 记住用户上次选择的主页日历视图（整月、两周或单周）。
- **输入：** `format` — 新选择的 `CalendarFormat`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `AnimeStorage.setHomeCalendarFormat(...)`。
- **算法：** 1) `state = state.copyWith(homeCalendarFormat: format)`。2) `format == CalendarFormat.month`（默认）时持久化 `null`，否则持久化 `format.name`（`'twoWeeks'` 或 `'week'`）。
- **用法：**
  ```dart
  onFormatChanged: (format) {
    ref.read(appSettingsProvider.notifier).setHomeCalendarFormat(format);
  },
  ```
  （来自 `lib/features/anime/views/home_page.dart` 的 `_buildCalendarSection`）
- **备注：** 它没有设置页控件——日历自己的格式按钮和纵向滑动手势是仅有的调用方，两者都经 `onFormatChanged` 路由。把格式放在这里而不是 `_HomePageState`，正是它能挺过底部导航标签切换的原因，因为标签切换会经 `go_router` 外壳重建 `HomePage`。

### `void setOnDeviceAiEnabled(bool enabled)` <a id="appsettingsnotifier-setondeviceaienabled"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 248 行）
- **用途：** 开启或关闭端侧 AI。
- **输入：** `enabled`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `AnimeStorage.setOnDeviceAiEnabled(enabled)` 和
  `OnDeviceAiService.instance.setEnabled(enabled)`，两者都不 await；后者完成后调用
  `CategoryClassifier.instance.trickle()`。
- **算法：** 1) `state = state.copyWith(onDeviceAiEnabled: enabled)`。2) 持久化。3) 切换服务：开启时探测模型，
  关闭时取消正在运行的一切。4) 完成后启动一次分类细流（1.6.0，M4），这样开启 AI 后无需等到下次回到前台就会填补
  分类空缺；关闭后细流是无操作。
- **用法：**
  ```dart
  onChanged: widget.featuresOn || settings.onDeviceAiEnabled
      ? notifier.setOnDeviceAiEnabled
      : null,
  ```
  （来自 `lib/features/ai/widgets/ai_settings_tiles.dart` 的「使用端侧 AI」开关）
- **备注：** 默认关闭。`setOnDeviceAiPreferFast` 形态相同，并在开启期间让服务重新探测。

### `void setAutoCategoriesEnabled(bool enabled)` <a id="appsettingsnotifier-setautocategoriesenabled"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 283 行）
- **用途：** 开启或关闭自动分类。
- **输入：** `enabled`。
- **返回：** 无。
- **副作用：** 更新 `state`；不 await 地调用 `AnimeStorage.setAutoCategoriesEnabled(enabled)`；设置
  `CategoryClassifier.instance.enabled`；可能启动一次细流或关闭端侧 AI。
- **算法：** 1) `state = state.copyWith(autoCategoriesEnabled: enabled)`。2) 持久化。3) 设置
  `CategoryClassifier.instance.enabled`。4) 开启时不 await 地启动 `CategoryClassifier.instance.trickle()`；关闭时调用
  [`_dropAiIfUnused`](#appsettingsnotifier_dropaiifunused)。
- **用法：**
  ```dart
  SwitchListTile(
    title: Text(l10n.settingsAutoCategories),
    value: settings.autoCategoriesEnabled,
    onChanged: notifier.setAutoCategoriesEnabled,
  )
  ```
  （来自 `lib/features/settings/views/settings_page.dart` 的「分类与推荐」分区）
- **备注：** 默认关闭。若推荐也已关闭，关闭它也会关闭端侧 AI，因为一个无事可做的 AI 开关只是噪音（1.6.0，M5；M5 之前总会关闭）。

### `void setRecommendationsEnabled(bool enabled)` <a id="appsettingsnotifier-setrecommendationsenabled"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 300 行）
- **用途：** 开启或关闭推荐。
- **输入：** `enabled`。
- **返回：** 无。
- **副作用：** 更新 `state`；不 await 地调用 `AnimeStorage.setRecommendationsEnabled(enabled)`；可能关闭端侧 AI。
- **算法：** 1) `state = state.copyWith(recommendationsEnabled: enabled)`。2) 持久化。3) 关闭时调用
  [`_dropAiIfUnused`](#appsettingsnotifier_dropaiifunused)。
- **用法：**
  ```dart
  SwitchListTile(
    title: Text(l10n.settingsRecommendations),
    value: settings.recommendationsEnabled,
    onChanged: notifier.setRecommendationsEnabled,
  )
  ```
  （来自 `lib/features/settings/views/settings_page.dart` 的「分类与推荐」分区）
- **备注：** 1.6.0（M5）新增。默认关闭。只有开启时，首页才显示推荐操作按钮。见
  [`../../../features/categories-and-recommendations.md`](../../../features/categories-and-recommendations.md)。

### `void _dropAiIfUnused()` <a id="appsettingsnotifier_dropaiifunused"></a>
- **种类：** `AppSettingsNotifier` 的方法（私有）
- **来源：** `lib/shared/providers/app_settings.dart`（约第 312 行）
- **用途：** 在没有功能使用端侧 AI 时将其关闭。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 可能调用 `setOnDeviceAiEnabled(false)`，由它持久化并切换服务。
- **算法：** 当 `onDeviceAiEnabled` 开着，且 `autoCategoriesEnabled` 和 `recommendationsEnabled` 都关闭时，调用
  `setOnDeviceAiEnabled(false)`。
- **用法：** `setAutoCategoriesEnabled(false)` 和 `setRecommendationsEnabled(false)`。
- **备注：** 1.6.0（M5）新增。与 `AiSettingsTiles` 一致：只有任一功能开启时，AI 开关才可用。

### `const AppSettings({...})` <a id="appsettings-new"></a>
- **种类：** `AppSettings` 的构造函数
- **来源：** `lib/shared/providers/app_settings.dart`（约第 189 行）
- **用途：** 构造每个字段都带默认值的不可变设置快照。
- **输入：** `themeMode`（默认 `ThemeMode.system`）、`locale`（默认 `null`）、`weekStartDay`（默认 `defaultWeekStartDay`，即周日）、`homeCalendarLayout`（默认 `HomeCalendarLayout.local`）、`homeCalendarTimeBasis`（默认 `HomeCalendarTimeBasis.jst`）、`homeCalendarFormat`（默认 `CalendarFormat.month`）。
- **返回：** 新的 `AppSettings` 实例。
- **副作用：** 无。
- **算法：** 从命名参数直接 `const` 字段赋值，全部带默认值，使单独的 `const AppSettings()` 产出应用的出厂默认偏好。
- **用法：**
  ```dart
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadPersisted();
  }
  ```
  （来自同一文件，`AppSettingsNotifier` 的构造函数）
- **备注：** 无。

### `int get effectiveWeekStartDay` <a id="appsettings-effectiveweekstartday"></a>
- **种类：** `AppSettings` 的 getter
- **来源：** `lib/shared/providers/app_settings.dart`（约第 203 行）
- **用途：** 返回日历组件实际应使用的周起始日，考虑日式日历布局覆盖。
- **输入：** 无。
- **返回：** `int` — `homeCalendarLayout == HomeCalendarLayout.japanese` 时为 `DateTime.sunday`，否则存储的 `weekStartDay`。
- **副作用：** 无。
- **算法：** 三元：日式布局总是锁定周日；本地布局使用当前存储的 `weekStartDay`。
- **用法：**
  ```dart
  trailing: DropdownButton<int>(
    value: settings.effectiveWeekStartDay,
    ...
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，周起始日显示）
- **备注：** 这是 UI 代码为显示/布局目的应读取的字段；`weekStartDay` 本身是原始存储偏好，不反映日式布局覆盖。

### `AppSettings copyWith({...})` <a id="appsettings-copywith"></a>
- **种类：** `AppSettings` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 213 行）
- **用途：** 产生 `AppSettings` 实例的修改副本，未指定的字段默认当前值。
- **输入：** 全部六个字段的可选覆盖，外加 `clearLocale`（默认 `false`），强制 `locale` 为 `null`，尽管 `locale` 本身默认"不变"。
- **返回：** 新的 `AppSettings`。
- **副作用：** 无。
- **算法：** 对 `themeMode`、`weekStartDay`、`homeCalendarLayout`、`homeCalendarTimeBasis` 和 `homeCalendarFormat` 用标准 `??`-回退复制。`locale` 特判：`clearLocale` 为 `true` 时结果是 `null`；否则 `locale ?? this.locale`。
- **用法：**
  ```dart
  state = state.copyWith(themeMode: mode);
  ```
  （来自 `AppSettingsNotifier.setThemeMode`，同一文件）
- **备注：** 意图是清除语言区域时，总是把 `clearLocale: true` 与 `locale: null` 一起传——只传 `locale: null` 在 `??` 模式下与"无变更"无法区分。

## 列表列数偏好

`AppSettings` 在 1.5.3 中新增了三个字段——`homeListColumns`、`manageListColumns` 和 `statsListColumns`——每个
数据浏览模块一个，均为 `int`，默认值 `listColumnsAuto`（`0`，意为"填满宽度所允许的列数"）。它们遵循与
`homeCalendarFormat` 相同的形态：在 `_loadPersisted` 中加载，通过 `AnimeStorage` 以发后不理的方式写入，并且没有
设置页控件——各模块应用栏上的列数按钮是唯一的写入方。

它们是带 `0` 哨兵值的普通非空 `int` 而非可空字段，因此 `copyWith` 不需要 `locale` 所需的那种 `clearX` 逃生舱。
存储的值永远只是用户所选；把它钳制到当前宽度所能容纳的范围发生在渲染时的
[`listColumnCount`](../utils/adaptive_layout.md#listcolumncount) 中，因此在桌面端设定的偏好能在被带到折叠状态
的手机上存活下来。见 [`../../../adaptive-layout.md`](../../../adaptive-layout.md)。

## 假名标签偏好

1.6.0 新增 `kanaTabEnabled`，一个默认 `false` 的 `bool`。它在 `_loadPersisted` 中通过
`AnimeStorage.getKanaTabEnabled()` 加载，由 `setKanaTabEnabled` 写入，后者由设置 › 通用中的开关调用。
`ShellScaffold` 监听它以显示四个或五个目的地，`router.dart` 中的 `kanaRouteRedirect` 读取它，在关闭时让
`/kana` 无法到达。见 [`../../../features/kana-reference.md`](../../../features/kana-reference.md)。

同时新增的 `AppSettingsNotifier.fixed(settings)` 从给定设置开始并跳过 `_loadPersisted`，因此组件测试可以用
`overrideWithValue(AppSettingsNotifier.fixed(...))` 覆盖 `appSettingsProvider` 而不触及存储。它的 setter 仍会
持久化。

## 端侧 AI 偏好

1.6.0（M3）新增 `onDeviceAiEnabled` 和 `onDeviceAiPreferFast`，两者都是默认 `false` 的 `bool`。它们在
`_loadPersisted` 中通过 `AnimeStorage.getOnDeviceAiEnabled()` 和 `getOnDeviceAiPreferFast()` 加载，由
`setOnDeviceAiEnabled` 和 `setOnDeviceAiPreferFast` 写入。每个写入方法同时告知 `OnDeviceAiService.instance`，
该服务自身不保存任何偏好；构造函数和 `copyWith` 都接受这两个字段。唯一的界面是
[`AiSettingsTiles`](../../features/ai/widgets/ai_settings_tiles.md)，位于设置的「分类与推荐」分区。见
[`../../../on-device-ai.md`](../../../on-device-ai.md)。

## 自动分类偏好

1.6.0（M4）新增 `autoCategoriesEnabled`，一个默认 `false` 的 `bool`，在 `_loadPersisted` 中通过
`AnimeStorage.getAutoCategoriesEnabled()` 加载，由 `setAutoCategoriesEnabled` 写入。构造函数和 `copyWith` 都接受它。
加载方法和写入方法都会告知 `CategoryClassifier.instance`，它只保存这一个开关。管理页读取它来提供分类筛选；
详情页自己读取存储的键。见
[`../../../features/categories-and-recommendations.md`](../../../features/categories-and-recommendations.md)。

## 推荐偏好

1.6.0（M5）新增 `recommendationsEnabled`，一个默认 `false` 的 `bool`，在 `_loadPersisted` 中通过
`AnimeStorage.getRecommendationsEnabled()` 加载，由 `setRecommendationsEnabled` 写入。构造函数和 `copyWith` 都接受它。
`HomePage` 监听它以显示推荐应用栏操作，设置页把 `autoCategoriesEnabled || recommendationsEnabled` 作为 `featuresOn`
传给 `AiSettingsTiles`。关闭任一功能都会调用 `_dropAiIfUnused`，因此只有两者都关闭时端侧 AI 才会关闭。见
[`../../../features/categories-and-recommendations.md`](../../../features/categories-and-recommendations.md)。
