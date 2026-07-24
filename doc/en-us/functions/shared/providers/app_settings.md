# lib/shared/providers/app_settings.dart

The `flutter_riverpod` provider for device-local app preferences: theme mode, locale, calendar week
start day, and the home-calendar layout/time-basis pair. `AppSettingsNotifier` loads persisted
values from `AnimeStorage` (`lib/features/anime/services/anime_storage.dart`) on construction and
persists every setter call back through it. `AppSettings` is the immutable state class exposed via
`appSettingsProvider`. See [../../../architecture.md](../../../architecture.md) for state
management conventions (Riverpod, no Provider/Bloc) and
[../../../data-formats.md](../../../data-formats.md) for where these values live in
`storage_config.json`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_parseHomeCalendarLayout`](#parsehomecalendarlayout) | top-level function | A | Parse a stored home calendar layout string. |
| [`_parseHomeCalendarTimeBasis`](#parsehomecalendartimebasis) | top-level function | A | Parse a stored home calendar time basis string. |
| [`AppSettingsNotifier.new`](#appsettingsnotifier-new) | constructor (`AppSettingsNotifier`) | A | Create an `AppSettingsNotifier` and trigger loading persisted settings. |
| [`AppSettingsNotifier._loadPersisted`](#appsettingsnotifier_loadpersisted) | method (`AppSettingsNotifier`) | A | Load persisted settings from storage into state. |
| [`AppSettingsNotifier.setThemeMode`](#appsettingsnotifier-setthememode) | method (`AppSettingsNotifier`) | A | Update theme mode and persist it. |
| [`AppSettingsNotifier.setLocale`](#appsettingsnotifier-setlocale) | method (`AppSettingsNotifier`) | A | Update locale and persist it. |
| [`AppSettingsNotifier.setWeekStartDay`](#appsettingsnotifier-setweekstartday) | method (`AppSettingsNotifier`) | A | Update the app-wide calendar week start day and persist it. |
| [`AppSettingsNotifier.setHomeCalendarLayout`](#appsettingsnotifier-sethomecalendarlayout) | method (`AppSettingsNotifier`) | A | Update the home calendar day-name layout and persist it. |
| [`AppSettingsNotifier.setHomeCalendarTimeBasis`](#appsettingsnotifier-sethomecalendartimebasis) | method (`AppSettingsNotifier`) | A | Update whether the home calendar date grid uses JST or local dates, and persist it. |
| [`AppSettings.new`](#appsettings-new) | constructor (`AppSettings`) | A | Create an `AppSettings` instance. |
| [`AppSettings.effectiveWeekStartDay`](#appsettings-effectiveweekstartday) | getter (`AppSettings`) | A | Return the week start day that should be applied to calendars. |
| [`AppSettings.copyWith`](#appsettings-copywith) | method (`AppSettings`) | A | Create a copy with selected fields replaced. |

`AppSettings`'s five fields (`themeMode`, `locale`, `weekStartDay`, `homeCalendarLayout`,
`homeCalendarTimeBasis`) and the top-level `appSettingsProvider` are plain field/provider
declarations without `/// Purpose:` comments in the source and are not indexed as separate rows.

## Documentation

### `HomeCalendarLayout _parseHomeCalendarLayout(String? value)` <a id="parsehomecalendarlayout"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 12)
- **Purpose:** Convert the persisted `storage_config.json` string for home calendar layout into the
  `HomeCalendarLayout` enum.
- **Inputs:** `value` — the raw stored string, or `null`.
- **Returns:** `HomeCalendarLayout.japanese` when `value == 'japanese'`, otherwise
  `HomeCalendarLayout.local`.
- **Side effects:** None.
- **Algorithm:** A single `switch` expression: `'japanese'` maps to `HomeCalendarLayout.japanese`;
  every other value (including `null` and any unrecognized string) falls through to
  `HomeCalendarLayout.local`.
- **Usage:**
  ```dart
  final homeCalendarLayout = _parseHomeCalendarLayout(
    await AnimeStorage.getHomeCalendarLayout(),
  );
  ```
  (from `AppSettingsNotifier._loadPersisted`, same file)
- **Notes:** Unknown/corrupt stored values silently default to `local` rather than throwing.

### `HomeCalendarTimeBasis _parseHomeCalendarTimeBasis(String? value)` <a id="parsehomecalendartimebasis"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 24)
- **Purpose:** Convert the persisted `storage_config.json` string for home calendar time basis into
  the `HomeCalendarTimeBasis` enum.
- **Inputs:** `value` — the raw stored string, or `null`.
- **Returns:** `HomeCalendarTimeBasis.local` when `value == 'local'`, otherwise
  `HomeCalendarTimeBasis.jst`.
- **Side effects:** None.
- **Algorithm:** A single `switch` expression: `'local'` maps to `HomeCalendarTimeBasis.local`;
  everything else (including `null`) defaults to `HomeCalendarTimeBasis.jst`.
- **Usage:**
  ```dart
  final homeCalendarTimeBasis = _parseHomeCalendarTimeBasis(
    await AnimeStorage.getHomeCalendarTimeBasis(),
  );
  ```
  (from `AppSettingsNotifier._loadPersisted`, same file)
- **Notes:** JST is the default/fallback basis, matching the app's JST-first anime scheduling model
  (see `shared/utils/jst_time.dart`).

### `AppSettingsNotifier()` <a id="appsettingsnotifier-new"></a>
- **Kind:** constructor of `AppSettingsNotifier` (a `StateNotifier<AppSettings>`)
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 37)
- **Purpose:** Initialize the notifier with default `AppSettings` and kick off loading persisted
  values.
- **Inputs:** None.
- **Returns:** A new `AppSettingsNotifier` instance.
- **Side effects:** Calls `super(const AppSettings())` then fires `_loadPersisted()`
  (fire-and-forget — not awaited by the constructor).
- **Algorithm:** 1) Initialize state to `const AppSettings()` (all defaults). 2) Call
  `_loadPersisted()` without awaiting it, so the notifier is immediately usable with defaults and
  updates asynchronously once storage has been read.
- **Usage:**
  ```dart
  final appSettingsProvider =
      StateNotifierProvider<AppSettingsNotifier, AppSettings>(
        (ref) => AppSettingsNotifier(),
      );
  ```
  (from the same file, the provider definition)
- **Notes:** Because loading is asynchronous and not awaited, UI code that reads
  `appSettingsProvider` on the very first frame may briefly see default values before the persisted
  ones apply and trigger a rebuild.

### `Future<void> _loadPersisted()` <a id="appsettingsnotifier_loadpersisted"></a>
- **Kind:** method of `AppSettingsNotifier`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 46)
- **Purpose:** Read every persisted preference from `AnimeStorage` and replace `state` with the
  fully-populated `AppSettings`.
- **Inputs:** None.
- **Returns:** `Future<void>`.
- **Side effects:** Reads `AnimeStorage.getThemeMode()`, `getLocaleTag()`, `getWeekStartDay()`,
  `getHomeCalendarLayout()`, and `getHomeCalendarTimeBasis()`; replaces `state`.
- **Algorithm:**
  1. Await the five `AnimeStorage` getters (theme mode string, locale tag, week start day, home
     calendar layout string, home calendar time basis string).
  2. Parse the layout/time-basis strings via `_parseHomeCalendarLayout`/`_parseHomeCalendarTimeBasis`.
  3. Map the theme mode string (`'light'`/`'dark'`/anything else) to `ThemeMode.light`/`.dark`/
     `.system` via a `switch` expression.
  4. If a locale tag is present, split it on `_`; a tag with a country-code part (e.g. `zh_TW`)
     becomes `Locale('zh', 'TW')`, otherwise a plain `Locale(languageCode)`.
  5. Replace `state` with a new `AppSettings(...)` built from the parsed values.
- **Usage:** Called only from `AppSettingsNotifier()`'s constructor; not part of the public API.
- **Notes:** A malformed locale tag with more than one `_` (e.g. `en_US_extra`) only uses the first
  two parts; there is no explicit validation beyond that.

### `void setThemeMode(ThemeMode mode)` <a id="appsettingsnotifier-setthememode"></a>
- **Kind:** method of `AppSettingsNotifier`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 83)
- **Purpose:** Update the in-memory theme mode and persist the choice.
- **Inputs:** `mode` — the new `ThemeMode`.
- **Returns:** None.
- **Side effects:** Updates `state` via `copyWith`; calls `AnimeStorage.setThemeMode(str)`
  (fire-and-forget).
- **Algorithm:** 1) `state = state.copyWith(themeMode: mode)`. 2) Map `mode` to a nullable storage
  string (`'light'`, `'dark'`, or `null` for `ThemeMode.system`) via `switch`. 3) Call
  `AnimeStorage.setThemeMode(str)` without awaiting.
- **Usage:**
  ```dart
  onSelectionChanged: (s) => notifier.setThemeMode(s.first),
  ```
  (from `lib/features/settings/views/settings_page.dart`, theme `SegmentedButton`)
- **Notes:** `ThemeMode.system` is stored as `null` rather than the string `'system'` — the parser
  in `_loadPersisted`/`switch` treats any non-`'light'`/`'dark'` value (including `null`) as
  `ThemeMode.system`.

### `void setLocale(Locale? locale)` <a id="appsettingsnotifier-setlocale"></a>
- **Kind:** method of `AppSettingsNotifier`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 98)
- **Purpose:** Update the in-memory locale and persist the choice (or clear it for system default).
- **Inputs:** `locale` — the new `Locale`, or `null` to follow the system locale.
- **Returns:** None.
- **Side effects:** Updates `state` via `copyWith(locale: locale, clearLocale: locale == null)`;
  calls `AnimeStorage.setLocaleTag(...)`.
- **Algorithm:** 1) Update state, explicitly signaling `clearLocale` when `locale` is `null`
  (`copyWith`'s optional-field pattern otherwise can't distinguish "leave unchanged" from
  "set to null"). 2) If `locale` is `null`, persist `null`. Otherwise build a storage tag —
  `'<languageCode>_<countryCode>'` if a country code is present, else just `languageCode` — and
  persist it via `AnimeStorage.setLocaleTag`.
- **Usage:**
  ```dart
  onChanged: (locale) => notifier.setLocale(locale),
  ```
  (from `lib/features/settings/views/settings_page.dart`, language `DropdownButton`)
- **Notes:** The `clearLocale` flag on `copyWith` exists specifically so `setLocale(null)` can
  actually null out the locale instead of being ignored by the `??` fallback pattern used for the
  other fields.

### `void setWeekStartDay(int weekday)` <a id="appsettingsnotifier-setweekstartday"></a>
- **Kind:** method of `AppSettingsNotifier`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 115)
- **Purpose:** Update the app-wide calendar week start day and persist it.
- **Inputs:** `weekday` — Dart weekday numbering (Monday=1 … Sunday=7).
- **Returns:** None.
- **Side effects:** Updates `state`; calls `AnimeStorage.setWeekStartDay(normalized)`.
- **Algorithm:** 1) Normalize `weekday` via
  [`normalizeWeekStartDay`](../utils/calendar_preferences.md#normalizeweekstartday) (out-of-range
  values fall back to Sunday). 2) `state = state.copyWith(weekStartDay: normalized)`. 3) Persist the
  normalized value.
- **Usage:**
  ```dart
  onChanged: usesJapaneseCalendar
      ? null
      : (weekday) {
          if (weekday != null) notifier.setWeekStartDay(weekday);
        },
  ```
  (from `lib/features/settings/views/settings_page.dart`, week-start-day `DropdownButton`)
- **Notes:** This setting only affects calendars using the local layout; Japanese home calendar
  layout locks the *effective* week start to Sunday regardless of this stored value (see
  `AppSettings.effectiveWeekStartDay`).

### `void setHomeCalendarLayout(HomeCalendarLayout layout)` <a id="appsettingsnotifier-sethomecalendarlayout"></a>
- **Kind:** method of `AppSettingsNotifier`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 126)
- **Purpose:** Update the home calendar day-name layout (local vs. Japanese) and persist it.
- **Inputs:** `layout` — the new `HomeCalendarLayout`.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `AnimeStorage.setHomeCalendarLayout(...)`.
- **Algorithm:** 1) `state = state.copyWith(homeCalendarLayout: layout)`. 2) Persist `null` when
  `layout == HomeCalendarLayout.local` (the default), otherwise persist `layout.name` (i.e.
  `'japanese'`).
- **Usage:**
  ```dart
  onChanged: (layout) {
    if (layout != null) notifier.setHomeCalendarLayout(layout);
  },
  ```
  (from `lib/features/settings/views/settings_page.dart`, home-calendar-layout `DropdownButton`)
- **Notes:** Storing `null` for the default (`local`) keeps `storage_config.json` clean for users
  who never touch this setting.

### `void setHomeCalendarTimeBasis(HomeCalendarTimeBasis basis)` <a id="appsettingsnotifier-sethomecalendartimebasis"></a>
- **Kind:** method of `AppSettingsNotifier`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 138)
- **Purpose:** Update whether the home calendar date grid uses JST or local dates, and persist it.
- **Inputs:** `basis` — the new `HomeCalendarTimeBasis`.
- **Returns:** None.
- **Side effects:** Updates `state`; calls `AnimeStorage.setHomeCalendarTimeBasis(...)`.
- **Algorithm:** 1) `state = state.copyWith(homeCalendarTimeBasis: basis)`. 2) Persist `null` when
  `basis == HomeCalendarTimeBasis.jst` (the default), otherwise persist `basis.name` (i.e.
  `'local'`).
- **Usage:** Wired to a settings-page control analogous to `setHomeCalendarLayout` (see
  `lib/features/settings/views/settings_page.dart`, home-calendar-time-basis section).
- **Notes:** This setting only changes which dates are shown in the home calendar grid; anime
  airing timestamps themselves remain JST-based regardless, per `AGENTS.md`.

### `const AppSettings({...})` <a id="appsettings-new"></a>
- **Kind:** constructor of `AppSettings`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 158)
- **Purpose:** Construct an immutable settings snapshot with defaults for every field.
- **Inputs:** `themeMode` (default `ThemeMode.system`), `locale` (default `null`), `weekStartDay`
  (default `defaultWeekStartDay`, i.e. Sunday), `homeCalendarLayout` (default
  `HomeCalendarLayout.local`), `homeCalendarTimeBasis` (default `HomeCalendarTimeBasis.jst`).
- **Returns:** A new `AppSettings` instance.
- **Side effects:** None.
- **Algorithm:** Straight `const` field assignment from named parameters, all with defaults so
  `const AppSettings()` alone yields the app's factory-default preferences.
- **Usage:**
  ```dart
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadPersisted();
  }
  ```
  (from the same file, `AppSettingsNotifier`'s constructor)
- **Notes:** None.

### `int get effectiveWeekStartDay` <a id="appsettings-effectiveweekstartday"></a>
- **Kind:** getter of `AppSettings`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 171)
- **Purpose:** Return the week start day that calendar widgets should actually use, accounting for
  the Japanese calendar layout override.
- **Inputs:** None.
- **Returns:** `int` — `DateTime.sunday` when `homeCalendarLayout == HomeCalendarLayout.japanese`,
  otherwise the stored `weekStartDay`.
- **Side effects:** None.
- **Algorithm:** A ternary: Japanese layout always locks to Sunday; local layout uses whatever
  `weekStartDay` is currently stored.
- **Usage:**
  ```dart
  trailing: DropdownButton<int>(
    value: settings.effectiveWeekStartDay,
    ...
  ```
  (from `lib/features/settings/views/settings_page.dart`, week-start-day display)
- **Notes:** This is the field UI code should read for display/layout purposes; `weekStartDay`
  itself is the raw stored preference and does not reflect the Japanese-layout override.

### `AppSettings copyWith({...})` <a id="appsettings-copywith"></a>
- **Kind:** method of `AppSettings`
- **Source:** `lib/shared/providers/app_settings.dart` (approx. line 181)
- **Purpose:** Produce a modified copy of an `AppSettings` instance, defaulting unspecified fields
  to the current values.
- **Inputs:** Optional overrides for all five fields, plus `clearLocale` (default `false`) to force
  `locale` to `null` even though `locale` itself defaults to "unchanged".
- **Returns:** A new `AppSettings`.
- **Side effects:** None.
- **Algorithm:** Standard `??`-fallback copy for `themeMode`, `weekStartDay`,
  `homeCalendarLayout`, and `homeCalendarTimeBasis`. `locale` is special-cased: if `clearLocale` is
  `true`, the result is `null`; otherwise it's `locale ?? this.locale`.
- **Usage:**
  ```dart
  state = state.copyWith(themeMode: mode);
  ```
  (from `AppSettingsNotifier.setThemeMode`, same file)
- **Notes:** Always pass `clearLocale: true` alongside `locale: null` when the intent is to clear
  the locale — passing only `locale: null` is indistinguishable from "no change" under the `??`
  pattern.
