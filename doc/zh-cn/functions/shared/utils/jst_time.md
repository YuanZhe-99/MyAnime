# lib/shared/utils/jst_time.dart

纯静态 `JstTime` 工具，提供日本标准时间（UTC+9、无夏令时）辅助，贯穿动画排程/日历/提醒/API 代码。JST 没有夏令时，因此整个类可以用固定 +9 小时偏移，而不是真实时区数据库。`AGENTS.md` 的"日历和播出逻辑感知 JST"备注和 [../../../architecture.md](../../../architecture.md) 描述了它如何支撑主页日历和本地 API 服务器。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `JstTime._` | 构造函数（`JstTime`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`JstTime.now`](#jsttime-now) | 方法（`JstTime`） | A | 返回转换为日本标准时间的当前时间。 |
| [`JstTime.today`](#jsttime-today) | 方法（`JstTime`） | A | 返回今天的 JST 日历日期，时间清零。 |
| [`JstTime.localToday`](#jsttime-localtoday) | 方法（`JstTime`） | A | 返回今天的本地日历日期，时间清零。 |
| [`JstTime.toLocal`](#jsttime-tolocal) | 方法（`JstTime`） | A | 把日本时间 `DateTime` 转换为设备本地时区。 |

## 文档

### `static DateTime now()` <a id="jsttime-now"></a>
- **种类：** `JstTime` 的静态方法
- **来源：** `lib/shared/utils/jst_time.dart`（约第 15 行）
- **用途：** 返回日本标准时间的当前挂钟时间。
- **输入：** 无。
- **返回：** `DateTime` — 表示当前 JST 时刻的朴素（非 UTC 标志）`DateTime`。
- **副作用：** 无（读取系统时钟但不修改任何东西）。
- **算法：** 取 `DateTime.now().toUtc()`，然后构造一个年/月/日相同、`hour + 9`（JST 是 UTC+9、无夏令时）的新 `DateTime`，保留分/秒/毫秒。
- **用法：**
  ```dart
  final now = JstTime.now();
  ```
  （来自 `lib/features/anime/views/home_page.dart`，检查一集是否已播出；`lib/shared/services/local_api_server.dart` 和 `lib/shared/services/share_service.dart` 也反复使用）
- **备注：** 返回的 `DateTime` 经本地（非 UTC）`DateTime()` 构造函数构造，因此即使值代表 JST 而非设备本地时间，其 `.isUtc` 也是 `false`——调用方不得把这个值传给假设"非 UTC"即"设备本地时间"的 API。`hour + 9` 可以合法滚入 ≥ 24 的值；Dart 的 `DateTime` 构造函数自动规范化溢出的字段值，因此无需额外进位逻辑。

### `static DateTime today()` <a id="jsttime-today"></a>
- **种类：** `JstTime` 的静态方法
- **来源：** `lib/shared/utils/jst_time.dart`（约第 33 行）
- **用途：** 返回 JST 中今天的日历日期，日内时间清零。
- **输入：** 无。
- **返回：** 使用 JST 日历日期的午夜 `DateTime`。
- **副作用：** 无。
- **算法：** 调用 `now()`，然后只用其日期分量构造新 `DateTime(year, month, day)`，丢弃时间。
- **用法：**
  ```dart
  HomeCalendarTimeBasis.jst => JstTime.today(),
  ```
  （来自 `lib/features/anime/views/home_page.dart`，按配置的时间基准选择主页日历的"今天"参考日期；`lib/shared/services/share_service.dart` 也使用）
- **备注：** 这是 `localToday()` 的 JST 基准对应物——用哪个取决于用户的 `HomeCalendarTimeBasis` 偏好（见 [../providers/app_settings.md](../providers/app_settings.md)）。

### `static DateTime localToday()` <a id="jsttime-localtoday"></a>
- **种类：** `JstTime` 的静态方法
- **来源：** `lib/shared/utils/jst_time.dart`（约第 43 行）
- **用途：** 返回设备本地时区中今天的日历日期，时间清零。
- **输入：** 无。
- **返回：** 设备当前日期的本地午夜 `DateTime`。
- **副作用：** 无。
- **算法：** 调用 `DateTime.now()`（设备本地时间，不是 JST），然后只用其日期分量构造新 `DateTime(year, month, day)`。
- **用法：**
  ```dart
  HomeCalendarTimeBasis.local => JstTime.localToday(),
  ```
  （来自 `lib/features/anime/views/home_page.dart`，用户选择本地时间基准时主页日历的"今天"参考日期）
- **备注：** 尽管住在 `JstTime` 上，此方法刻意*不*应用 JST 偏移——它存在是为了让主页日历在 JST 与设备本地时间之间切换日期网格基准，同时仍经由一个类路由。动画播出时间戳本身不受此选择影响，按 `AGENTS.md` 保持基于 JST。

### `static DateTime toLocal(DateTime jstTime)` <a id="jsttime-tolocal"></a>
- **种类：** `JstTime` 的静态方法
- **来源：** `lib/shared/utils/jst_time.dart`（约第 53 行）
- **用途：** 把表示日本时间挂钟时刻的 `DateTime` 转换为设备本地时区的等价时刻。
- **输入：** `jstTime` — 字段被解释为 JST 挂钟时间的 `DateTime`，无论其自身 `isUtc` 标志如何。
- **返回：** 设备本地时区的 `DateTime`（已 `.toLocal()`）。
- **副作用：** 无。
- **算法：**
  1. 经 `DateTime.utc(...)` 把 `jstTime` 的字段重建为真正的 UTC `DateTime`，从小时字段减去 9 小时（撤销 JST 偏移以恢复真实 UTC 时刻）。
  2. 对该 UTC 时刻调用 `.toLocal()` 转换为设备本地时区。
- **用法：**
  ```dart
  final local = JstTime.toLocal(airDate);
  ```
  （来自 `lib/features/anime/views/home_page.dart`，把动画的 JST 播出日期/时间转换为在本地时区日历网格上显示）
- **备注：** 输入的 `.isUtc` 标志被忽略——函数总是把字段值当作 JST 挂钟时间，因此误传已是 UTC 或已本地化的 `DateTime` 会静默产生错误结果而不是抛出。`hour - 9` 可能变负；与 `now()` 一样，这依赖 `DateTime.utc` 的自动字段规范化（从日借位），而不是手动进位逻辑。
