# lib/shared/providers/app_settings.dart

设备本地应用偏好的 `flutter_riverpod` provider：主题模式、语言区域、日历周起始日，以及主页日历布局/时间基准对。`AppSettingsNotifier` 在构造时从 `AnimeStorage`（`lib/features/anime/services/anime_storage.dart`）加载持久化值，并把每个 setter 调用持久化回它。`AppSettings` 是经 `appSettingsProvider` 暴露的不可变状态类。状态管理约定（Riverpod、不用 Provider/Bloc）见 [../../../architecture.md](../../../architecture.md)，这些值在 `storage_config.json` 中的位置见 [../../../data-formats.md](../../../data-formats.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_parseHomeCalendarLayout`](#parsehomecalendarlayout) | 顶层函数 | A | 解析存储的主页日历布局字符串。 |
| [`_parseHomeCalendarTimeBasis`](#parsehomecalendartimebasis) | 顶层函数 | A | 解析存储的主页日历时间基准字符串。 |
| [`AppSettingsNotifier.new`](#appsettingsnotifier-new) | 构造函数（`AppSettingsNotifier`） | A | 创建 `AppSettingsNotifier` 并触发加载持久化设置。 |
| [`AppSettingsNotifier._loadPersisted`](#appsettingsnotifier_loadpersisted) | 方法（`AppSettingsNotifier`） | A | 把持久化设置从存储加载进状态。 |
| [`AppSettingsNotifier.setThemeMode`](#appsettingsnotifier-setthememode) | 方法（`AppSettingsNotifier`） | A | 更新主题模式并持久化它。 |
| [`AppSettingsNotifier.setLocale`](#appsettingsnotifier-setlocale) | 方法（`AppSettingsNotifier`） | A | 更新语言区域并持久化它。 |
| [`AppSettingsNotifier.setWeekStartDay`](#appsettingsnotifier-setweekstartday) | 方法（`AppSettingsNotifier`） | A | 更新应用级日历周起始日并持久化它。 |
| [`AppSettingsNotifier.setHomeCalendarLayout`](#appsettingsnotifier-sethomecalendarlayout) | 方法（`AppSettingsNotifier`） | A | 更新主页日历日名布局并持久化它。 |
| [`AppSettingsNotifier.setHomeCalendarTimeBasis`](#appsettingsnotifier-sethomecalendartimebasis) | 方法（`AppSettingsNotifier`） | A | 更新主页日历日期网格使用 JST 还是本地日期，并持久化它。 |
| [`AppSettings.new`](#appsettings-new) | 构造函数（`AppSettings`） | A | 创建 `AppSettings` 实例。 |
| [`AppSettings.effectiveWeekStartDay`](#appsettings-effectiveweekstartday) | getter（`AppSettings`） | A | 返回应应用于日历的周起始日。 |
| [`AppSettings.copyWith`](#appsettings-copywith) | 方法（`AppSettings`） | A | 用所选字段创建副本。 |

`AppSettings` 的五个字段（`themeMode`、`locale`、`weekStartDay`、`homeCalendarLayout`、`homeCalendarTimeBasis`）和顶层 `appSettingsProvider` 是源码中没有 `/// Purpose:` 注释的普通字段/provider 声明，不作为单独行索引。

## 文档

### `HomeCalendarLayout _parseHomeCalendarLayout(String? value)` <a id="parsehomecalendarlayout"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/providers/app_settings.dart`（约第 12 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 24 行）
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

### `AppSettingsNotifier()` <a id="appsettingsnotifier-new"></a>
- **种类：** `AppSettingsNotifier` 的构造函数（一个 `StateNotifier<AppSettings>`）
- **来源：** `lib/shared/providers/app_settings.dart`（约第 37 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 46 行）
- **用途：** 从 `AnimeStorage` 读取每个持久化偏好，并用完全填充的 `AppSettings` 替换 `state`。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `AnimeStorage.getThemeMode()`、`getLocaleTag()`、`getWeekStartDay()`、`getHomeCalendarLayout()` 和 `getHomeCalendarTimeBasis()`；替换 `state`。
- **算法：**
  1. Await 五个 `AnimeStorage` getter（主题模式字符串、语言区域标签、周起始日、主页日历布局字符串、主页日历时间基准字符串）。
  2. 经 `_parseHomeCalendarLayout`/`_parseHomeCalendarTimeBasis` 解析布局/时间基准字符串。
  3. 经 `switch` 表达式把主题模式字符串（`'light'`/`'dark'`/其他任何东西）映射为 `ThemeMode.light`/`.dark`/`.system`。
  4. 存在语言区域标签时按 `_` 拆分；带 country code 部分的标签（如 `zh_TW`）变成 `Locale('zh', 'TW')`，否则普通 `Locale(languageCode)`。
  5. 用从解析值构建的新 `AppSettings(...)` 替换 `state`。
- **用法：** 只在 `AppSettingsNotifier()` 的构造函数中调用；不是公共 API 的一部分。
- **备注：** 有多个 `_` 的格式错误语言区域标签（如 `en_US_extra`）只用前两部分；除此之外没有显式校验。

### `void setThemeMode(ThemeMode mode)` <a id="appsettingsnotifier-setthememode"></a>
- **种类：** `AppSettingsNotifier` 的方法
- **来源：** `lib/shared/providers/app_settings.dart`（约第 83 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 98 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 115 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 126 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 138 行）
- **用途：** 更新主页日历日期网格使用 JST 还是本地日期，并持久化它。
- **输入：** `basis` — 新的 `HomeCalendarTimeBasis`。
- **返回：** 无。
- **副作用：** 更新 `state`；调用 `AnimeStorage.setHomeCalendarTimeBasis(...)`。
- **算法：** 1) `state = state.copyWith(homeCalendarTimeBasis: basis)`。2) `basis == HomeCalendarTimeBasis.jst`（默认）时持久化 `null`，否则持久化 `basis.name`（即 `'local'`）。
- **用法：** 接到与 `setHomeCalendarLayout` 类似的设置页控件上（见 `lib/features/settings/views/settings_page.dart`，主页日历时间基准小节）。
- **备注：** 此设置只改变主页日历网格显示哪些日期；动画播出时间戳本身始终基于 JST，按 `AGENTS.md`。

### `const AppSettings({...})` <a id="appsettings-new"></a>
- **种类：** `AppSettings` 的构造函数
- **来源：** `lib/shared/providers/app_settings.dart`（约第 158 行）
- **用途：** 构造每个字段都带默认值的不可变设置快照。
- **输入：** `themeMode`（默认 `ThemeMode.system`）、`locale`（默认 `null`）、`weekStartDay`（默认 `defaultWeekStartDay`，即周日）、`homeCalendarLayout`（默认 `HomeCalendarLayout.local`）、`homeCalendarTimeBasis`（默认 `HomeCalendarTimeBasis.jst`）。
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 171 行）
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
- **来源：** `lib/shared/providers/app_settings.dart`（约第 181 行）
- **用途：** 产生 `AppSettings` 实例的修改副本，未指定的字段默认当前值。
- **输入：** 全部五个字段的可选覆盖，外加 `clearLocale`（默认 `false`），强制 `locale` 为 `null`，尽管 `locale` 本身默认"不变"。
- **返回：** 新的 `AppSettings`。
- **副作用：** 无。
- **算法：** 对 `themeMode`、`weekStartDay`、`homeCalendarLayout` 和 `homeCalendarTimeBasis` 用标准 `??`-回退复制。`locale` 特判：`clearLocale` 为 `true` 时结果是 `null`；否则 `locale ?? this.locale`。
- **用法：**
  ```dart
  state = state.copyWith(themeMode: mode);
  ```
  （来自 `AppSettingsNotifier.setThemeMode`，同一文件）
- **备注：** 意图是清除语言区域时，总是把 `clearLocale: true` 与 `locale: null` 一起传——只传 `locale: null` 在 `??` 模式下与"无变更"无法区分。
