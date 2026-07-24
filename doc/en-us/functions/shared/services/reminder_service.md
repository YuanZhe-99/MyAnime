# lib/shared/services/reminder_service.dart

`ReminderService` is the daily "what's airing / what's unwatched" reminder notification service,
with two entirely different delivery mechanisms depending on platform: OS-level `zonedSchedule()`
one-shot notifications for the next 7 days on Android/iOS, versus an in-process 60-second periodic
check with `local_notifier` on desktop. See
[`../../../features/reminders.md`](../../../features/reminders.md) for the full mobile-vs-desktop
design write-up (including why `DateTime.now().timeZoneName` is never used for timezone lookup) —
this page focuses on what each function actually does.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`ReminderService._`](#reminderservice-_) | constructor (`ReminderService`) | B | Prevent instantiation; the class is static-only. |
| [`_getL10n`](#_getl10n) | method (`ReminderService`) | A | Resolve the localized strings for the saved locale (or platform default). |
| [`init`](#init) | method (`ReminderService`) | A | Initialize the notification plugin/timezone database for the current platform. |
| [`_scheduleMobileNotification`](#_schedulemobilenotification) | method (`ReminderService`) | A | Schedule per-day OS notifications for the next 7 days (mobile). |
| [`_buildReminderBody`](#_buildreminderbody) | method (`ReminderService`) | A | Compute a reminder's localized body text for a given moment, or null if there's nothing to report. |
| [`startPeriodicCheck`](#startperiodiccheck) | method (`ReminderService`) | A | Start (or reschedule) reminder delivery for the current platform. |
| [`notifyDataChanged`](#notifydatachanged) | method (`ReminderService`) | A | Debounce-reschedule mobile notifications after anime data changes. |
| [`checkAndNotify`](#checkandnotify) | method (`ReminderService`) | A | Desktop-only: check whether it's reminder time and show a notification if so. |
| [`_show`](#_show) | method (`ReminderService`) | A | Display a notification through the platform-appropriate mechanism. |

## Documentation

### `static Future<AppLocalizations> _getL10n()` <a id="_getl10n"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 55)
- **Purpose:** Resolve the `AppLocalizations` instance to use for notification text, based on the
  user's saved locale preference (or the platform default if none is saved).
- **Inputs:** None.
- **Returns:** `Future<AppLocalizations>`.
- **Side effects:** Reads the saved locale tag via `AnimeStorage.getLocaleTag()`.
- **Algorithm:** If a locale tag is saved, split it on `_` into language(+country) and build a
  `Locale`; otherwise use `PlatformDispatcher.instance.locale`. Look up and return the matching
  `AppLocalizations` via `lookupAppLocalizations`.
- **Usage:** Called internally from [`_scheduleMobileNotification`](#_schedulemobilenotification)
  and [`checkAndNotify`](#checkandnotify) so notification text matches the app's configured
  language even though the service runs outside any widget's `BuildContext`.
- **Notes:** None.

### `static Future<void> init()` <a id="init"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 72)
- **Purpose:** One-time platform setup: on desktop, initialize `local_notifier`; on mobile,
  initialize the timezone database and the notification plugin, and request notification
  permissions.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Sets up `local_notifier` (desktop) or `flutter_local_notifications` plus the
  `timezone` package's IANA database (mobile); requests OS notification permission on Android 13+
  and iOS.
- **Algorithm:**
  1. No-op on web.
  2. On Windows/macOS/Linux: set `_isDesktop = true`, call `localNotifier.setup(appName:
     'MyAnime!!!!!', shortcutPolicy: ShortcutPolicy.ignore)`, and return early.
  3. Otherwise (mobile): set `_isMobile = true`. Initialize the `tz` timezone database, then resolve
     the local IANA zone id via `FlutterTimezone.getLocalTimezone()` and `tz.setLocalLocation(...)`.
     If that throws, fall back to matching the device's UTC offset against
     `tz.timeZoneDatabase.locations` and pick the first match.
  4. Initialize `FlutterLocalNotificationsPlugin` with Android/iOS init settings.
  5. On Android, request the Android 13+ notification permission; on iOS, request
     alert/badge/sound permission.
- **Usage:**
  ```dart
  await ReminderService.init();
  ```
  (from `lib/main.dart`, during startup)
- **Notes:** The IANA-zone-id resolution deliberately avoids
  `DateTime.now().timeZoneName` (an abbreviation like `"JST"`/`"PST"` that the `tz` database cannot
  look up by name) — see [`../../../features/reminders.md`](../../../features/reminders.md).

### `static Future<void> _scheduleMobileNotification()` <a id="_schedulemobilenotification"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 149)
- **Purpose:** Cancel and re-create the next 7 days' worth of OS-scheduled per-day reminder
  notifications, based on current settings and anime data.
- **Inputs:** None (reads config/data internally).
- **Returns:** `Future<void>`.
- **Side effects:** Cancels notification ids `100..106`; re-schedules a subset of them via
  `_plugin.zonedSchedule`; reads config and anime data.
- **Algorithm:**
  1. No-op if not on mobile.
  2. Read `reminderEnabled`/`reminderTime` from config.
  3. Cancel all `_scheduledDays` (7) previously scheduled notification ids
     (`_scheduledNotificationId + i`).
  4. If reminders are disabled, stop here (leaving everything cancelled).
  5. For each of the next 7 days (using `tz.TZDateTime.now(tz.local)` as the anchor), compute that
     day's fire time at the configured hour/minute; skip days whose fire time has already passed.
  6. Compute that day's body via [`_buildReminderBody`](#_buildreminderbody); skip days where it
     returns `null` (nothing airing, nothing unwatched) — so no generic/empty notification ever
     fires.
  7. Schedule the remaining days with `_plugin.zonedSchedule(...,
     androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle)`.
- **Usage:** Called internally from [`startPeriodicCheck`](#startperiodiccheck) and
  [`notifyDataChanged`](#notifydatachanged); never called directly by UI code.
- **Notes:** Uses `inexactAllowWhileIdle` deliberately, so `SCHEDULE_EXACT_ALARM` is not required on
  Android — see [`../../../features/reminders.md`](../../../features/reminders.md).

### `static String? _buildReminderBody(AnimeData data, AppLocalizations l10n, DateTime atLocal)` <a id="_buildreminderbody"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 211)
- **Purpose:** Compute the localized notification body for a given local fire moment, counting
  today's (JST) airing episodes and already-aired unwatched episodes.
- **Inputs:** `data` — current anime data; `l10n`; `atLocal` — the local wall-clock moment the
  notification would fire at.
- **Returns:** `String?` — a localized, `" · "`-joined summary line, or `null` when there is nothing
  airing and nothing unwatched (so the caller should skip this day's notification entirely).
- **Side effects:** None.
- **Algorithm:**
  1. Convert `atLocal` to UTC, then to the JST wall-clock equivalent (`utc.hour + 9`, same pattern
     as `JstTime`) to get `jstNow`/`jstDate`.
  2. For every episode of every anime: if its calendar date equals `jstDate`, count it as airing
     today; if its status is `unwatched` and its air date has already passed `jstNow`, count it as
     an aired-unwatched episode.
  3. If both counts are zero, return `null`.
  4. Otherwise build up to two localized lines (`reminderAiringToday`, `reminderUnwatched`, each
     given anime-count and episode-count) and join them with `" · "`.
- **Usage:** Called internally from [`_scheduleMobileNotification`](#_schedulemobilenotification)
  (once per upcoming day) and [`checkAndNotify`](#checkandnotify) (for "now").
- **Notes:** Airing-today uses the *JST calendar date*, but the reminder *time* comparison itself
  uses local system time (via the caller-supplied `atLocal`) — see
  [`../../../features/reminders.md`](../../../features/reminders.md)'s note on this distinction.

### `static void startPeriodicCheck()` <a id="startperiodiccheck"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 276)
- **Purpose:** Start reminder delivery for the current platform: (re)schedule OS notifications on
  mobile, or start the 60-second periodic `Timer` on desktop.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** On mobile, calls [`_scheduleMobileNotification`](#_schedulemobilenotification).
  On desktop, cancels any existing periodic `Timer` and starts a new one that calls
  [`checkAndNotify`](#checkandnotify) every 60 seconds, plus one immediate check.
- **Algorithm:** If mobile, delegate entirely to `_scheduleMobileNotification` and return. Otherwise
  cancel `_timer` if set, create `Timer.periodic(Duration(seconds: 60), (_) => checkAndNotify())`,
  and call `checkAndNotify()` once immediately.
- **Usage:**
  ```dart
  ReminderService.startPeriodicCheck();
  ```
  (from `lib/main.dart` at startup, and from `lib/features/settings/views/settings_page.dart` after
  the user changes reminder settings — see
  [`../../../features/reminders.md`](../../../features/reminders.md)'s "Rescheduling" note)
- **Notes:** Safe to call multiple times — cancels any previous desktop `Timer` first, and mobile
  scheduling is itself idempotent (cancel-then-reschedule).

### `static void notifyDataChanged()` <a id="notifydatachanged"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 296)
- **Purpose:** Debounce-reschedule the mobile per-day notifications after anime data changes, so
  scheduled bodies stay in sync with the latest airing/watched state.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Cancels any pending debounce `Timer` and starts a new 5-second one that calls
  [`_scheduleMobileNotification`](#_schedulemobilenotification).
- **Algorithm:** No-op on web or non-mobile. Otherwise cancel `_rescheduleDebounce` if pending and
  start a new 5-second `Timer` that reschedules.
- **Usage:**
  ```dart
  ReminderService.notifyDataChanged();
  ```
  (from `lib/features/anime/services/anime_storage.dart` after every anime data save, and from
  `lib/shared/services/auto_sync_service.dart` and
  `lib/features/settings/views/backup_page.dart` after a sync/restore)
- **Notes:** No-op on desktop, where the 60-second periodic check already reads fresh data every
  cycle — this debounce exists purely to avoid rescheduling mobile notifications on every single
  keystroke-level data write.

### `static Future<void> checkAndNotify()` <a id="checkandnotify"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 311)
- **Purpose:** Desktop-only in-process check: if it's past the configured reminder time and today's
  reminder hasn't fired yet, show a notification.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** May show a notification via [`_show`](#_show); writes `lastReminderDate` to
  config after firing.
- **Algorithm:**
  1. No-op if not desktop.
  2. Read `reminderEnabled`/`reminderTime` from config; return if disabled.
  3. Compute today's reminder `DateTime` at the configured hour/minute in local time; return if
     `now` hasn't reached it yet.
  4. Return if `lastReminderDate` (persisted) already equals today's date string (dedup).
  5. Build today's body via [`_buildReminderBody`](#_buildreminderbody); return if `null`.
  6. Show the notification via `_show`, then persist today's date as `lastReminderDate`.
  7. Any exception is caught and logged via `debugPrint`, never rethrown.
- **Usage:** Invoked every 60 seconds by the `Timer.periodic` started in
  [`startPeriodicCheck`](#startperiodiccheck); not normally called directly.
- **Notes:** This desktop-only path is what prevents double-notifying — mobile is covered entirely
  by OS-scheduled notifications from `_scheduleMobileNotification`, so `checkAndNotify` returns
  immediately there.

### `static Future<void> _show(String title, String body)` <a id="_show"></a>
- **Kind:** static method of `ReminderService`
- **Source:** `lib/shared/services/reminder_service.dart` (approx. line 364)
- **Purpose:** Display a single notification using whichever plugin applies to the current
  platform.
- **Inputs:** `title`, `body`.
- **Returns:** `Future<void>`.
- **Side effects:** Shows an OS notification (`local_notifier` on desktop,
  `flutter_local_notifications` on mobile).
- **Algorithm:** On desktop, build and `.show()` a `LocalNotification`. On mobile, call
  `_plugin.show(_showCounter++, title, body, ...)` with high-importance Android details; no-op if
  neither desktop nor mobile (e.g. web).
- **Usage:** Called internally from [`checkAndNotify`](#checkandnotify) only — the mobile
  `zonedSchedule` path in `_scheduleMobileNotification` bypasses `_show` entirely since the OS
  itself displays those notifications at their scheduled time.
- **Notes:** `_showCounter` increments per call so each ad-hoc mobile notification gets a distinct
  id, separate from the `100..106` ids used by scheduled per-day notifications.
