# 提醒通知

`reminder_service.dart` 调度每日"在播什么 / 未看什么"提醒，移动端与桌面端机制不同。提醒设置本身位于 `storage_config.json`（见 [`../data-formats.md`](../data-formats.md)）。

## 移动端（Android/iOS）

- 使用带 `zonedSchedule()` 的 `flutter_local_notifications`，为**未来 7 天**调度按天**一次性**通知。
- 每天的提醒正文从当前动画数据（在播 + 未看计数）计算；无事可看的天**跳过**，因此永远不会发出通用或空的提醒。
- 日程在以下时机刷新：应用启动、提醒设置变更、动画数据保存后（`ReminderService.notifyDataChanged()`，防抖）、应用恢复。
- 时区数据库位置通过 `flutter_timezone` 从操作系统 **IANA zone id** 解析。这里刻意绝不用 `DateTime.now().timeZoneName`——它返回缩写（如 "JST"、"PST"），`tz` 包的时区数据库无法按名称查找。
- Android 需要通知和开机权限，外加 `AndroidManifest.xml` 中的 `ScheduledNotificationReceiver` 和 `ScheduledNotificationBootReceiver`。`SCHEDULE_EXACT_ALARM` 刻意**不**请求，因为调度使用 `inexactAllowWhileIdle`。

## 桌面

- 通过 `local_notifier` 使用 **60 秒周期检查**，而不是操作系统级调度通知。
- 这个进程内检查**仅桌面**，因此移动端绝不会被 `zonedSchedule` 机制和周期检查双重通知。
- 在 `now >= 提醒时间` 且今天尚未通知时触发；`lastReminderDate`（持久化在 `storage_config.json`）防止同一天重复通知。

## 提醒内容

提醒计数包括今天 JST 在播的剧集和已经播出的未看剧集——注意提醒*时间*比较本身使用本地系统时间，不是 JST（见 [`../architecture.md`](../architecture.md) 的核心架构规则），尽管底层剧集播出日期计算基于 JST（见 [`anime-tracking.md`](anime-tracking.md)）。

## 重新调度

提醒设置变更时，调用 `ReminderService.startPeriodicCheck()` 重新调度。
