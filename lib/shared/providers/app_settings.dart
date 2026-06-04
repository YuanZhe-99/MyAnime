import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/anime/services/anime_storage.dart';
import '../utils/calendar_preferences.dart';

/// Purpose: Parse a stored home calendar layout string.
/// Inputs: `value`.
/// Returns: `HomeCalendarLayout`.
/// Side effects: None.
/// Notes: Unknown values fall back to the local calendar layout.
HomeCalendarLayout _parseHomeCalendarLayout(String? value) {
  return switch (value) {
    'japanese' => HomeCalendarLayout.japanese,
    _ => HomeCalendarLayout.local,
  };
}

/// Purpose: Parse a stored home calendar time basis string.
/// Inputs: `value`.
/// Returns: `HomeCalendarTimeBasis`.
/// Side effects: None.
/// Notes: Unknown values fall back to Japan Standard Time.
HomeCalendarTimeBasis _parseHomeCalendarTimeBasis(String? value) {
  return switch (value) {
    'local' => HomeCalendarTimeBasis.local,
    _ => HomeCalendarTimeBasis.jst,
  };
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  /// Purpose: Create a app settings notifier instance.
  /// Inputs: None.
  /// Returns: A new `AppSettingsNotifier` instance.
  /// Side effects: None.
  /// Notes: None.
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadPersisted();
  }

  /// Purpose: Provide the internal load persisted helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadPersisted() async {
    final modeStr = await AnimeStorage.getThemeMode();
    final localeTag = await AnimeStorage.getLocaleTag();
    final weekStartDay = await AnimeStorage.getWeekStartDay();
    final homeCalendarLayout = _parseHomeCalendarLayout(
      await AnimeStorage.getHomeCalendarLayout(),
    );
    final homeCalendarTimeBasis = _parseHomeCalendarTimeBasis(
      await AnimeStorage.getHomeCalendarTimeBasis(),
    );

    final themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    Locale? locale;
    if (localeTag != null) {
      final parts = localeTag.split('_');
      locale = parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
    }

    state = AppSettings(
      themeMode: themeMode,
      locale: locale,
      weekStartDay: weekStartDay,
      homeCalendarLayout: homeCalendarLayout,
      homeCalendarTimeBasis: homeCalendarTimeBasis,
    );
  }

  /// Purpose: Update theme mode with the provided value.
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: Persists the selected theme mode.
  /// Notes: None.
  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    final str = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => null,
    };
    AnimeStorage.setThemeMode(str);
  }

  /// Purpose: Update locale with the provided value.
  /// Inputs: `locale`.
  /// Returns: None.
  /// Side effects: Persists the selected locale.
  /// Notes: None.
  void setLocale(Locale? locale) {
    state = state.copyWith(locale: locale, clearLocale: locale == null);
    if (locale == null) {
      AnimeStorage.setLocaleTag(null);
    } else {
      final tag = locale.countryCode != null
          ? '${locale.languageCode}_${locale.countryCode}'
          : locale.languageCode;
      AnimeStorage.setLocaleTag(tag);
    }
  }

  /// Purpose: Update the app-wide calendar week start day.
  /// Inputs: `weekday`.
  /// Returns: None.
  /// Side effects: Persists the selected weekday.
  /// Notes: Weekday values use Dart's Monday=1 through Sunday=7 numbering.
  void setWeekStartDay(int weekday) {
    final normalized = normalizeWeekStartDay(weekday);
    state = state.copyWith(weekStartDay: normalized);
    AnimeStorage.setWeekStartDay(normalized);
  }

  /// Purpose: Update the home calendar day-name layout.
  /// Inputs: `layout`.
  /// Returns: None.
  /// Side effects: Persists the selected calendar layout.
  /// Notes: Japanese layout locks the effective week start to Sunday.
  void setHomeCalendarLayout(HomeCalendarLayout layout) {
    state = state.copyWith(homeCalendarLayout: layout);
    AnimeStorage.setHomeCalendarLayout(
      layout == HomeCalendarLayout.local ? null : layout.name,
    );
  }

  /// Purpose: Update whether the home calendar date grid uses JST or local dates.
  /// Inputs: `basis`.
  /// Returns: None.
  /// Side effects: Persists the selected home calendar time basis.
  /// Notes: Anime broadcast timestamps remain Japan-time based regardless of this setting.
  void setHomeCalendarTimeBasis(HomeCalendarTimeBasis basis) {
    state = state.copyWith(homeCalendarTimeBasis: basis);
    AnimeStorage.setHomeCalendarTimeBasis(
      basis == HomeCalendarTimeBasis.jst ? null : basis.name,
    );
  }
}

class AppSettings {
  final ThemeMode themeMode;
  final Locale? locale;
  final int weekStartDay;
  final HomeCalendarLayout homeCalendarLayout;
  final HomeCalendarTimeBasis homeCalendarTimeBasis;

  /// Purpose: Create a app settings instance.
  /// Inputs: `themeMode`, `locale`, `weekStartDay`, `homeCalendarLayout`, `homeCalendarTimeBasis`.
  /// Returns: A new `AppSettings` instance.
  /// Side effects: None.
  /// Notes: `weekStartDay` stores the local-calendar preference; Japanese layout uses Sunday effectively.
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.weekStartDay = defaultWeekStartDay,
    this.homeCalendarLayout = HomeCalendarLayout.local,
    this.homeCalendarTimeBasis = HomeCalendarTimeBasis.jst,
  });

  /// Purpose: Return the week start day that should be applied to calendars.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: Japanese calendar layout always starts from Sunday.
  int get effectiveWeekStartDay =>
      homeCalendarLayout == HomeCalendarLayout.japanese
      ? DateTime.sunday
      : weekStartDay;

  /// Purpose: Create a copy with selected fields replaced.
  /// Inputs: `themeMode`, `locale`, `weekStartDay`, `homeCalendarLayout`, `homeCalendarTimeBasis`, `clearLocale`.
  /// Returns: `AppSettings`.
  /// Side effects: None.
  /// Notes: None.
  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    int? weekStartDay,
    HomeCalendarLayout? homeCalendarLayout,
    HomeCalendarTimeBasis? homeCalendarTimeBasis,
    bool clearLocale = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      weekStartDay: weekStartDay ?? this.weekStartDay,
      homeCalendarLayout: homeCalendarLayout ?? this.homeCalendarLayout,
      homeCalendarTimeBasis:
          homeCalendarTimeBasis ?? this.homeCalendarTimeBasis,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
      (ref) => AppSettingsNotifier(),
    );
