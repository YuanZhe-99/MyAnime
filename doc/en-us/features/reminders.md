# Reminder Notifications

`reminder_service.dart` schedules daily "what's airing / what's unwatched" reminders, with
different mechanisms on mobile vs. desktop. Reminder settings themselves live in
`storage_config.json` (see [`../data-formats.md`](../data-formats.md)).

## Mobile (Android/iOS)

- Uses `flutter_local_notifications` with `zonedSchedule()` to schedule per-day **one-shot**
  notifications for the **next 7 days**.
- Each day's notification body is computed from current anime data (airing + unwatched counts);
  days with nothing to watch are **skipped**, so no generic or empty reminder ever fires.
- Schedules are refreshed on: app launch, reminder-settings change, after anime data saves
  (`ReminderService.notifyDataChanged()`, debounced), and app resume.
- The timezone database location is resolved from the OS **IANA zone id** via `flutter_timezone`.
  `DateTime.now().timeZoneName` is deliberately never used for this — it returns an abbreviation
  (e.g. "JST", "PST") that the `tz` package's timezone database cannot look up by name.
- Android requires notification and boot permissions, plus `ScheduledNotificationReceiver` and
  `ScheduledNotificationBootReceiver` in `AndroidManifest.xml`. `SCHEDULE_EXACT_ALARM` is
  intentionally **not** requested, because scheduling uses `inexactAllowWhileIdle`.

## Desktop

- Uses a **60-second periodic check** through `local_notifier` instead of OS-level scheduled
  notifications.
- This in-process check is **desktop-only**, so mobile is never double-notified by both the
  `zonedSchedule` mechanism and a periodic check.
- Fires when `now >= reminder time` and not yet notified today; `lastReminderDate` (persisted in
  `storage_config.json`) prevents duplicate notifications on the same day.

## Reminder content

Reminder counts include today's JST airing episodes and unwatched episodes that have already
aired — note that reminder *time* comparison itself uses local system time, not JST (see
[`../architecture.md`](../architecture.md)'s core architecture rules), even though the underlying
episode air-date calculation is JST-based (see [`anime-tracking.md`](anime-tracking.md)).

## Rescheduling

When reminder settings change, call `ReminderService.startPeriodicCheck()` to reschedule.
