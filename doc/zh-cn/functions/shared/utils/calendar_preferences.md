# lib/shared/utils/calendar_preferences.dart

日历偏好与主页日历几何的小型共享工具模块：`HomeCalendarLayout` 和 `HomeCalendarTimeBasis` 枚举、`defaultWeekStartDay` 和 `homeCalendarMaxWidth` 常量，以及四个被 `AppSettings`/`AppSettingsNotifier`（见 [../providers/app_settings.md](../providers/app_settings.md)）、`AnimeStorage`、`home_page.dart` 和 `settings_page.dart` 用于规范化和枚举星期顺序、并按当前视口和文本缩放为主页日历定尺寸的纯辅助函数。

本模块刻意只依赖 `dart:core`——不含任何 Flutter 或 `table_calendar` 导入——因此每个辅助函数都可直接单元测试（`test/calendar_preferences_test.dart`）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`normalizeWeekStartDay`](#normalizeweekstartday) | 顶层函数 | A | 返回可用作应用日历周起始的有效星期。 |
| [`homeCalendarDaysOfWeekHeight`](#homecalendardaysofweekheight) | 顶层函数 | A | 返回容得下标签文本的主页日历星期表头高度。 |
| [`homeCalendarRowHeight`](#homecalendarrowheight) | 顶层函数 | A | 返回当前视口下主页日历的日期格行高。 |
| [`weekdaySequence`](#weekdaysequence) | 顶层函数 | A | 返回从配置的周起始开始排序的星期。 |

`HomeCalendarLayout` 枚举、`HomeCalendarTimeBasis` 枚举以及 `defaultWeekStartDay` 和 `homeCalendarMaxWidth` 常量是没有 `/// Purpose:` 注释的普通类型/常量声明，不作为单独行索引。`homeCalendarMaxWidth`（560.0）是主页日历网格允许达到的最大宽度，因此正方形、横向、平板和桌面窗口会把网格居中，而不是把日期格拉伸到铺满整个窗口。

## 文档

### `int normalizeWeekStartDay(int? weekday)` <a id="normalizeweekstartday"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/calendar_preferences.dart`（约第 14 行）
- **用途：** 把可能无效或缺失的星期值钳制为有效的应用日历周起始日。
- **输入：** `weekday` — 用 Dart 的周一=1…周日=7 编号的候选星期，或 `null`。
- **返回：** `int` — `weekday` 在 `[DateTime.monday, DateTime.sunday]` 内则原样，否则 `defaultWeekStartDay`（周日）。
- **副作用：** 无。
- **算法：** 单个守卫：`weekday` 为 `null` 或超出有效 Dart 星期范围时返回 `defaultWeekStartDay`；否则原样返回 `weekday`。
- **用法：**
  ```dart
  final normalized = normalizeWeekStartDay(weekday);
  ```
  （来自 `AppSettingsNotifier.setWeekStartDay`，`lib/shared/providers/app_settings.dart`；`AnimeStorage`（`lib/features/anime/services/anime_storage.dart`）和 `lib/features/anime/views/home_page.dart` 映射到 `table_calendar` 的 `StartingDayOfWeek` 时也使用）
- **备注：** 这是"什么算有效周起始日"的唯一事实来源；代码库中其他每个存储或读取周起始偏好的地方都经它路由，而不是独立校验。

### `double homeCalendarDaysOfWeekHeight(double labelLineHeight)` <a id="homecalendardaysofweekheight"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/calendar_preferences.dart`（约第 29 行）
- **用途：** 给主页日历的星期表头行足够高度，使其标签绝不会被纵向裁切。
- **输入：** `labelLineHeight` — 单个星期标签经字体缩放后的行高，即 `MediaQuery.textScalerOf(context).scale(style.fontSize) * style.height`。
- **返回：** `double` — `labelLineHeight + 8`，钳制到 `[24.0, 64.0]`。
- **副作用：** 无。
- **算法：** 在实测行高上加 8 逻辑像素的余量，再钳制，使该行既不会塌缩到难以辨认，也不会在极端文本缩放下失控。
- **用法：**
  ```dart
  final daysOfWeekHeight = homeCalendarDaysOfWeekHeight(labelLineHeight);
  ```
  （来自 `lib/features/anime/views/home_page.dart` 的 `_buildCalendarSection`，直接喂给 `TableCalendar.daysOfWeekHeight`）
- **备注：** 它存在是因为 `table_calendar` 把 `daysOfWeekHeight` 默认成 `16.0`，并把每个星期格包进正好那么高的 `SizedBox`（`calendar_core.dart`）。Material `bodySmall` 标签在常规缩放下约排版到 16 px，在较大的系统字体设置下超过 20 px，`RenderParagraph` 会裁掉溢出部分——这切掉了 日月火水木金土 标签的上下笔画。24.0 的下限使该行在任何文本缩放下都高于那个默认值。

### `double homeCalendarRowHeight(double viewportHeight, double daysOfWeekHeight)` <a id="homecalendarrowheight"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/calendar_preferences.dart`（约第 39 行）
- **用途：** 选一个日期格行高，使六周的整月网格在短视口下仍可用，同时不缩小普通竖屏上的日历。
- **输入：** `viewportHeight` — 以逻辑像素计的窗口高度（`MediaQuery.sizeOf(context).height`）；`daysOfWeekHeight` — 已预留的表头高度。
- **返回：** `double` — `((viewportHeight * 0.55) - daysOfWeekHeight) / 6`，钳制到 `[34.0, 52.0]`。
- **副作用：** 无。
- **算法：** 给日历区块划出约 55% 的窗口预算，减去星期表头，再除以最高月份的六行，然后钳制。上限就是 `table_calendar` 自己的 52.0 默认值，因此约 640 dp 竖屏手机及以上都保持不变；短的横向和正方形窗口则向 34.0 滑落。
- **用法：**
  ```dart
  final rowHeight = homeCalendarRowHeight(
    MediaQuery.sizeOf(context).height,
    daysOfWeekHeight,
  );
  ```
  （来自 `lib/features/anime/views/home_page.dart` 的 `_buildCalendarSection`）
- **备注：** `home_page.dart` 把低于 48.0 的结果视为"紧凑"，并相应收紧格边距和标记圆点，使播出剧集的圆点不会与日期数字碰撞。

### `List<int> weekdaySequence(int weekStartDay)` <a id="weekdaysequence"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/calendar_preferences.dart`（约第 49 行）
- **用途：** 产生按显示顺序、从配置的周起始日开始排列的 7 个星期。
- **输入：** `weekStartDay` — 周一=1…周日=7；无需已规范化。
- **返回：** 长度 7 的 `List<int>`，每个是 Dart 星期数字，从规范化的 `weekStartDay` 开始并回卷。
- **副作用：** 无。
- **算法：**
  1. 经 `normalizeWeekStartDay` 规范化 `weekStartDay`。
  2. 对 `offset` 从 0 到 6，计算 `((start - 1 + offset) % 7) + 1`——这旋转 1..7 星期编号，使序列从 `start` 开始并从 7 回卷到 1。
- **用法：**
  ```dart
  for (final weekday in weekdaySequence(defaultWeekStartDay))
    DropdownMenuItem(
      value: weekday,
      child: Text(_weekdayLabel(weekday, l10n)),
    ),
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，周起始日下拉选项）
- **备注：** 调用方在这里专门传 `defaultWeekStartDay`，使选项总是以固定的周日优先顺序为下拉列表枚举，独立于当前所选偏好——*所选值*单独来自 `settings.effectiveWeekStartDay`。
