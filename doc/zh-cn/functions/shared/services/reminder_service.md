# lib/shared/services/reminder_service.dart

`ReminderService` 是每日"在播什么 / 未看什么"提醒通知服务，按平台有两种完全不同的投递机制：Android/iOS 上为未来 7 天做操作系统级 `zonedSchedule()` 一次性通知，桌面端则是用 `local_notifier` 的进程内 60 秒周期检查。完整的移动-vs-桌面设计说明（包括为什么绝不用 `DateTime.now().timeZoneName` 做时区查找）见 [`../../../features/reminders.md`](../../../features/reminders.md)——本页聚焦每个函数实际做什么。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ReminderService._`](#reminderservice-_) | 构造函数（`ReminderService`） | B | 阻止实例化；该类纯静态。 |
| [`_getL10n`](#_getl10n) | 方法（`ReminderService`） | A | 为保存的语言区域（或平台默认）解析本地化字符串。 |
| [`init`](#init) | 方法（`ReminderService`） | A | 为当前平台初始化通知插件/时区数据库。 |
| [`_scheduleMobileNotification`](#_schedulemobilenotification) | 方法（`ReminderService`） | A | 为未来 7 天调度按天操作系统通知（移动端）。 |
| [`_buildReminderBody`](#_buildreminderbody) | 方法（`ReminderService`） | A | 为给定时刻计算提醒的本地化正文文本，无事可报则为 null。 |
| [`startPeriodicCheck`](#startperiodiccheck) | 方法（`ReminderService`） | A | 为当前平台启动（或重新调度）提醒投递。 |
| [`notifyDataChanged`](#notifydatachanged) | 方法（`ReminderService`） | A | 动画数据变更后防抖地重新调度移动通知。 |
| [`checkAndNotify`](#checkandnotify) | 方法（`ReminderService`） | A | 仅桌面：检查是否到提醒时间，是则显示通知。 |
| [`_show`](#_show) | 方法（`ReminderService`） | A | 经平台合适机制显示通知。 |

## 文档

### `static Future<AppLocalizations> _getL10n()` <a id="_getl10n"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 55 行）
- **用途：** 基于用户保存的语言区域偏好（未保存则平台默认）解析通知文本使用的 `AppLocalizations` 实例。
- **输入：** 无。
- **返回：** `Future<AppLocalizations>`。
- **副作用：** 经 `AnimeStorage.getLocaleTag()` 读取保存的语言区域标签。
- **算法：** 保存了语言区域标签时按 `_` 拆分为语言（+国家）并构建 `Locale`；否则用 `PlatformDispatcher.instance.locale`。经 `lookupAppLocalizations` 查找并返回匹配的 `AppLocalizations`。
- **用法：** 从 [`_scheduleMobileNotification`](#_schedulemobilenotification) 和 [`checkAndNotify`](#checkandnotify) 内部调用，使通知文本匹配应用配置的语言，尽管服务运行在任何组件的 `BuildContext` 之外。
- **备注：** 无。

### `static Future<void> init()` <a id="init"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 72 行）
- **用途：** 一次性平台设置：桌面上初始化 `local_notifier`；移动端初始化时区数据库和通知插件，并请求通知权限。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 设置 `local_notifier`（桌面）或 `flutter_local_notifications` 加 `timezone` 包的 IANA 数据库（移动端）；在 Android 13+ 和 iOS 上请求操作系统通知权限。
- **算法：**
  1. Web 上空操作。
  2. Windows/macOS/Linux 上：设 `_isDesktop = true`，调用 `localNotifier.setup(appName: 'MyAnime!!!!!', shortcutPolicy: ShortcutPolicy.ignore)`，提前返回。
  3. 否则（移动端）：设 `_isMobile = true`。初始化 `tz` 时区数据库，然后经 `FlutterTimezone.getLocalTimezone()` 解析本地 IANA zone id 并 `tz.setLocalLocation(...)`。抛出时，回退为把设备的 UTC 偏移与 `tz.timeZoneDatabase.locations` 匹配并选第一个匹配。
  4. 用 Android/iOS 初始化设置初始化 `FlutterLocalNotificationsPlugin`。
  5. Android 上请求 Android 13+ 通知权限；iOS 上请求 alert/badge/sound 权限。
- **用法：**
  ```dart
  await ReminderService.init();
  ```
  （来自 `lib/main.dart`，启动期间）
- **备注：** IANA zone id 解析刻意避开 `DateTime.now().timeZoneName`（像 `"JST"`/`"PST"` 的缩写，`tz` 数据库无法按名称查找）——见 [`../../../features/reminders.md`](../../../features/reminders.md)。

### `static Future<void> _scheduleMobileNotification()` <a id="_schedulemobilenotification"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 149 行）
- **用途：** 取消并重建未来 7 天的操作系统调度按日提醒通知，基于当前设置和动画数据。
- **输入：** 无（内部读取配置/数据）。
- **返回：** `Future<void>`。
- **副作用：** 取消通知 id `100..106`；经 `_plugin.zonedSchedule` 重新调度其中一部分；读取配置和动画数据。
- **算法：**
  1. 不在移动端时空操作。
  2. 从配置读取 `reminderEnabled`/`reminderTime`。
  3. 取消此前调度的 `_scheduledDays`（7）个通知 id（`_scheduledNotificationId + i`）。
  4. 提醒禁用时在此停止（保持全部取消）。
  5. 对未来 7 天中的每一天（用 `tz.TZDateTime.now(tz.local)` 作锚点），计算当天在配置小时/分钟的触发时间；跳过触发时间已过的天。
  6. 经 [`_buildReminderBody`](#_buildreminderbody) 计算当天正文；它返回 `null` 的天跳过（无事在播、无事未看）——因此绝不会发出通用或空通知。
  7. 用 `_plugin.zonedSchedule(..., androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle)` 调度剩余天。
- **用法：** 从 [`startPeriodicCheck`](#startperiodiccheck) 和 [`notifyDataChanged`](#notifydatachanged) 内部调用；UI 代码绝不直接调用。
- **备注：** 刻意用 `inexactAllowWhileIdle`，因此 Android 上不需要 `SCHEDULE_EXACT_ALARM`——见 [`../../../features/reminders.md`](../../../features/reminders.md)。

### `static String? _buildReminderBody(AnimeData data, AppLocalizations l10n, DateTime atLocal)` <a id="_buildreminderbody"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 211 行）
- **用途：** 为给定本地触发时刻计算本地化通知正文，统计今天（JST）在播的剧集和已播出的未看剧集。
- **输入：** `data` — 当前动画数据；`l10n`；`atLocal` — 通知触发时刻的本地挂钟时间。
- **返回：** `String?` — 本地化的 `" · "` 连接摘要行，无事在播且无事未看时为 `null`（因此调用方应完全跳过这天的通知）。
- **副作用：** 无。
- **算法：**
  1. 把 `atLocal` 转换为 UTC，再转换为 JST 挂钟等价（`utc.hour + 9`，与 `JstTime` 相同模式）得到 `jstNow`/`jstDate`。
  2. 对每部动画的每个剧集：其日历日期等于 `jstDate` 时计为今天在播；其状态为 `unwatched` 且播出日期已过 `jstNow` 时计为已播出未看剧集。
  3. 两个计数都为零时返回 `null`。
  4. 否则构建最多两行本地化文本（`reminderAiringToday`、`reminderUnwatched`，各给动画计数和剧集计数）并用 `" · "` 连接。
- **用法：** 从 [`_scheduleMobileNotification`](#_schedulemobilenotification)（每个即将到来的天一次）和 [`checkAndNotify`](#checkandnotify)（对"现在"）内部调用。
- **备注：** 今天在播使用*JST 日历日期*，但提醒*时间*比较本身使用本地系统时间（经调用方提供的 `atLocal`）——该区别见 [`../../../features/reminders.md`](../../../features/reminders.md) 的说明。

### `static void startPeriodicCheck()` <a id="startperiodiccheck"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 276 行）
- **用途：** 为当前平台启动提醒投递：移动端（重新）调度操作系统通知，桌面端启动 60 秒周期 `Timer`。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 移动端调用 [`_scheduleMobileNotification`](#_schedulemobilenotification)。桌面端取消任何既有周期 `Timer` 并启动每 60 秒调用 [`checkAndNotify`](#checkandnotify) 的新计时器，外加一次立即检查。
- **算法：** 移动端完全委托给 `_scheduleMobileNotification` 并返回。否则取消已设置的 `_timer`，创建 `Timer.periodic(Duration(seconds: 60), (_) => checkAndNotify())`，并立即调用一次 `checkAndNotify()`。
- **用法：**
  ```dart
  ReminderService.startPeriodicCheck();
  ```
  （来自 `lib/main.dart` 启动时，以及 `lib/features/settings/views/settings_page.dart` 在用户更改提醒设置后——见 [`../../../features/reminders.md`](../../../features/reminders.md) 的"重新调度"说明）
- **备注：** 多次调用安全——先取消任何先前的桌面 `Timer`，移动调度本身幂等（取消-再-调度）。

### `static void notifyDataChanged()` <a id="notifydatachanged"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 296 行）
- **用途：** 动画数据变更后防抖地重新调度移动按日通知，使调度正文与最新在播/已看状态保持同步。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 取消任何挂起的防抖 `Timer` 并启动调用 [`_scheduleMobileNotification`](#_schedulemobilenotification) 的新 5 秒计时器。
- **算法：** Web 或非移动端空操作。否则取消挂起的 `_rescheduleDebounce` 并启动重新调度的新 5 秒 `Timer`。
- **用法：**
  ```dart
  ReminderService.notifyDataChanged();
  ```
  （来自 `lib/features/anime/services/anime_storage.dart` 每次动画数据保存后，以及 `lib/shared/services/auto_sync_service.dart` 和 `lib/features/settings/views/backup_page.dart` 在同步/恢复后）
- **备注：** 桌面上空操作，那里 60 秒周期检查每个周期已读取新鲜数据——此防抖纯粹为了不在每次按键级数据写入时重新调度移动通知。

### `static Future<void> checkAndNotify()` <a id="checkandnotify"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 311 行）
- **用途：** 仅桌面的进程内检查：已过配置的提醒时间且今天的提醒尚未触发时，显示通知。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 可能经 [`_show`](#_show) 显示通知；触发后把 `lastReminderDate` 写入配置。
- **算法：**
  1. 不在桌面端空操作。
  2. 从配置读取 `reminderEnabled`/`reminderTime`；禁用则返回。
  3. 在本地时间配置小时/分钟计算今天的提醒 `DateTime`；`now` 尚未到达则返回。
  4. `lastReminderDate`（持久化）已等于今天的日期字符串时返回（去重）。
  5. 经 [`_buildReminderBody`](#_buildreminderbody) 构建今天的正文；为 `null` 则返回。
  6. 经 `_show` 显示通知，然后把今天的日期持久化为 `lastReminderDate`。
  7. 任何异常被捕获并经 `debugPrint` 记录，绝不重新抛出。
- **用法：** 每 60 秒由 [`startPeriodicCheck`](#startperiodiccheck) 启动的 `Timer.periodic` 调用；通常不直接调用。
- **备注：** 这条仅桌面路径正是防止双重通知的东西——移动端完全由 `_scheduleMobileNotification` 的操作系统调度通知覆盖，因此 `checkAndNotify` 在那里立即返回。

### `static Future<void> _show(String title, String body)` <a id="_show"></a>
- **种类：** `ReminderService` 的静态方法
- **来源：** `lib/shared/services/reminder_service.dart`（约第 364 行）
- **用途：** 用适用于当前平台的插件显示单条通知。
- **输入：** `title`、`body`。
- **返回：** `Future<void>`。
- **副作用：** 显示操作系统通知（桌面上 `local_notifier`，移动端 `flutter_local_notifications`）。
- **算法：** 桌面上构建并 `.show()` 一个 `LocalNotification`。移动端调用带高重要性 Android 详情的 `_plugin.show(_showCounter++, title, body, ...)`；既非桌面也非移动（如 web）时空操作。
- **用法：** 只从 [`checkAndNotify`](#checkandnotify) 内部调用——`_scheduleMobileNotification` 中的移动 `zonedSchedule` 路径完全绕过 `_show`，因为操作系统本身会在调度时间显示那些通知。
- **备注：** `_showCounter` 每次调用递增，使每条临时移动通知得到不同的 id，与调度按日通知使用的 `100..106` id 分开。
