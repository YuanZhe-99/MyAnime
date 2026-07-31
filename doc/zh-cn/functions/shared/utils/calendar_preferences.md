# lib/shared/utils/calendar_preferences.dart

日历周起始日处理的小型共享工具模块：`HomeCalendarLayout` 和 `HomeCalendarTimeBasis` 枚举、`defaultWeekStartDay` 常量，以及两个被 `AppSettings`/`AppSettingsNotifier`（见 [../providers/app_settings.md](../providers/app_settings.md)）、`AnimeStorage`、`home_page.dart` 和 `settings_page.dart` 用于规范化和枚举星期顺序的纯辅助函数。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`normalizeWeekStartDay`](#normalizeweekstartday) | 顶层函数 | A | 返回可用作应用日历周起始的有效星期。 |
| [`weekdaySequence`](#weekdaysequence) | 顶层函数 | A | 返回从配置的周起始开始排序的星期。 |

`HomeCalendarLayout` 枚举、`HomeCalendarTimeBasis` 枚举和 `defaultWeekStartDay` 常量是没有 `/// Purpose:` 注释的普通类型/常量声明，不作为单独行索引。

## 文档

### `int normalizeWeekStartDay(int? weekday)` <a id="normalizeweekstartday"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/calendar_preferences.dart`（约第 12 行）
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

### `List<int> weekdaySequence(int weekStartDay)` <a id="weekdaysequence"></a>
- **种类：** 顶层函数
- **来源：** `lib/shared/utils/calendar_preferences.dart`（约第 26 行）
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
