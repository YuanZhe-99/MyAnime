import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../features/ai/services/on_device_ai_service.dart';
import '../../features/anime/services/anime_storage.dart';
import '../../features/anime/services/manage_grouping.dart';
import '../../features/categories/services/category_service.dart';
import '../utils/adaptive_layout.dart';
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

/// Purpose: Parse a stored home calendar view format string.
/// Inputs: `value`.
/// Returns: `CalendarFormat`.
/// Side effects: None.
/// Notes: Unknown values fall back to the full-month view.
CalendarFormat _parseHomeCalendarFormat(String? value) {
  return switch (value) {
    'twoWeeks' => CalendarFormat.twoWeeks,
    'week' => CalendarFormat.week,
    _ => CalendarFormat.month,
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

  /// Purpose: Create a notifier that starts from fixed settings.
  /// Inputs: `settings`.
  /// Returns: A new `AppSettingsNotifier` instance.
  /// Side effects: None; nothing is read from disk.
  /// Notes: For tests that override `appSettingsProvider`. Setters still
  /// persist through `AnimeStorage`.
  AppSettingsNotifier.fixed(super.settings);

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
    final homeCalendarFormat = _parseHomeCalendarFormat(
      await AnimeStorage.getHomeCalendarFormat(),
    );
    final homeListColumns = await AnimeStorage.getHomeListColumns();
    final manageListColumns = await AnimeStorage.getManageListColumns();
    final manageViewMode = parseManageViewMode(
      await AnimeStorage.getManageViewMode(),
    );
    final manageSeriesSort = parseManageSeriesSort(
      await AnimeStorage.getManageSeriesSort(),
    );
    final statsListColumns = await AnimeStorage.getStatsListColumns();
    final kanaTabEnabled = await AnimeStorage.getKanaTabEnabled();
    final onDeviceAiEnabled = await AnimeStorage.getOnDeviceAiEnabled();
    final onDeviceAiPreferFast = await AnimeStorage.getOnDeviceAiPreferFast();
    final autoCategoriesEnabled = await AnimeStorage.getAutoCategoriesEnabled();
    final recommendationsEnabled =
        await AnimeStorage.getRecommendationsEnabled();

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
      homeCalendarFormat: homeCalendarFormat,
      homeListColumns: homeListColumns,
      manageListColumns: manageListColumns,
      manageViewMode: manageViewMode,
      manageSeriesSort: manageSeriesSort,
      statsListColumns: statsListColumns,
      kanaTabEnabled: kanaTabEnabled,
      onDeviceAiEnabled: onDeviceAiEnabled,
      onDeviceAiPreferFast: onDeviceAiPreferFast,
      autoCategoriesEnabled: autoCategoriesEnabled,
      recommendationsEnabled: recommendationsEnabled,
    );
    CategoryClassifier.instance.enabled = autoCategoriesEnabled;
    // The service holds no preference of its own; it is told once here and
    // again by each setter below.
    final ai = OnDeviceAiService.instance;
    await ai.setPreferFast(onDeviceAiPreferFast);
    await ai.setEnabled(onDeviceAiEnabled);
    unawaited(CategoryClassifier.instance.trickle());
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

  /// Purpose: Update the remembered home calendar view format.
  /// Inputs: `format`.
  /// Returns: None.
  /// Side effects: Persists the selected calendar view format.
  /// Notes: Called whenever the user switches month/two-week/week view on the home calendar.
  void setHomeCalendarFormat(CalendarFormat format) {
    state = state.copyWith(homeCalendarFormat: format);
    AnimeStorage.setHomeCalendarFormat(
      format == CalendarFormat.month ? null : format.name,
    );
  }

  /// Purpose: Update the remembered home list column preference.
  /// Inputs: `columns` — `listColumnsAuto` or a pinned count.
  /// Returns: None.
  /// Side effects: Persists the selected column count.
  /// Notes: Stored per module, so the three data-browsing tabs are independent.
  void setHomeListColumns(int columns) {
    state = state.copyWith(homeListColumns: columns);
    AnimeStorage.setHomeListColumns(columns);
  }

  /// Purpose: Update the remembered management list column preference.
  /// Inputs: `columns` — `listColumnsAuto` or a pinned count.
  /// Returns: None.
  /// Side effects: Persists the selected column count.
  /// Notes: None.
  void setManageListColumns(int columns) {
    state = state.copyWith(manageListColumns: columns);
    AnimeStorage.setManageListColumns(columns);
  }

  /// Purpose: Update the remembered Manage view mode (1.6.2).
  /// Inputs: `mode`.
  /// Returns: None.
  /// Side effects: Persists the mode; the default quarter view removes the
  /// key.
  /// Notes: Device-local.
  void setManageViewMode(ManageViewMode mode) {
    state = state.copyWith(manageViewMode: mode);
    AnimeStorage.setManageViewMode(
      mode == ManageViewMode.quarter ? null : mode.name,
    );
  }

  /// Purpose: Update the remembered Manage series-view sort (1.6.2).
  /// Inputs: `sort`.
  /// Returns: None.
  /// Side effects: Persists the sort; the default removes the key.
  /// Notes: Device-local.
  void setManageSeriesSort(ManageSeriesSort sort) {
    state = state.copyWith(manageSeriesSort: sort);
    AnimeStorage.setManageSeriesSort(
      sort == ManageSeriesSort.latest ? null : sort.name,
    );
  }

  /// Purpose: Update the remembered statistics list column preference.
  /// Inputs: `columns` — `listColumnsAuto` or a pinned count.
  /// Returns: None.
  /// Side effects: Persists the selected column count.
  /// Notes: None.
  void setStatsListColumns(int columns) {
    state = state.copyWith(statsListColumns: columns);
    AnimeStorage.setStatsListColumns(columns);
  }

  /// Purpose: Show or hide the Kana quick-reference tab.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference; the shell rebuilds with four or
  /// five destinations.
  /// Notes: Off by default.
  void setKanaTabEnabled(bool enabled) {
    state = state.copyWith(kanaTabEnabled: enabled);
    AnimeStorage.setKanaTabEnabled(enabled);
  }

  /// Purpose: Turn on-device AI on or off.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference and switches `OnDeviceAiService`.
  /// Notes: Off by default. Switching off cancels anything running.
  void setOnDeviceAiEnabled(bool enabled) {
    state = state.copyWith(onDeviceAiEnabled: enabled);
    AnimeStorage.setOnDeviceAiEnabled(enabled);
    OnDeviceAiService.instance
        .setEnabled(enabled)
        .then((_) => CategoryClassifier.instance.trickle());
  }

  /// Purpose: Prefer the faster on-device model where both sizes are served.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference; the service re-probes.
  /// Notes: Android only.
  void setOnDeviceAiPreferFast(bool enabled) {
    state = state.copyWith(onDeviceAiPreferFast: enabled);
    AnimeStorage.setOnDeviceAiPreferFast(enabled);
    OnDeviceAiService.instance.setPreferFast(enabled);
  }

  /// Purpose: Turn automatic categories on or off.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference and switches the classifier.
  /// Notes: Off by default. Turning it off also turns on-device AI off when
  /// recommendations are off too, since nothing else would use it.
  void setAutoCategoriesEnabled(bool enabled) {
    state = state.copyWith(autoCategoriesEnabled: enabled);
    AnimeStorage.setAutoCategoriesEnabled(enabled);
    CategoryClassifier.instance.enabled = enabled;
    if (enabled) {
      unawaited(CategoryClassifier.instance.trickle());
    } else {
      _dropAiIfUnused();
    }
  }

  /// Purpose: Turn recommendations on or off.
  /// Inputs: `enabled`.
  /// Returns: None.
  /// Side effects: Persists the preference; may turn on-device AI off.
  /// Notes: Off by default. The Home app bar shows the recommendations
  /// action only while this is on.
  void setRecommendationsEnabled(bool enabled) {
    state = state.copyWith(recommendationsEnabled: enabled);
    AnimeStorage.setRecommendationsEnabled(enabled);
    if (!enabled) _dropAiIfUnused();
  }

  /// Purpose: Turn on-device AI off once no feature uses it.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May switch on-device AI off and persist that.
  /// Notes: Internal helper used within this file only. The AI switch is
  /// only usable while automatic categories or recommendations are on.
  void _dropAiIfUnused() {
    if (state.onDeviceAiEnabled &&
        !state.autoCategoriesEnabled &&
        !state.recommendationsEnabled) {
      setOnDeviceAiEnabled(false);
    }
  }
}

class AppSettings {
  final ThemeMode themeMode;
  final Locale? locale;
  final int weekStartDay;
  final HomeCalendarLayout homeCalendarLayout;
  final HomeCalendarTimeBasis homeCalendarTimeBasis;
  final CalendarFormat homeCalendarFormat;

  /// Column preference for the home list: `listColumnsAuto` or a pinned count.
  final int homeListColumns;

  /// Column preference for the management list.
  final int manageListColumns;

  /// How the Manage tab lays out the library (1.6.2).
  final ManageViewMode manageViewMode;

  /// How the Manage tab's series view orders its groups (1.6.2).
  final ManageSeriesSort manageSeriesSort;

  /// Column preference for the statistics lists.
  final int statsListColumns;

  /// Whether the Kana quick-reference tab appears in navigation. Off by default.
  final bool kanaTabEnabled;

  /// Whether on-device AI is turned on. Off by default.
  final bool onDeviceAiEnabled;

  /// Whether the faster on-device model is preferred (Android).
  final bool onDeviceAiPreferFast;

  /// Whether automatic categories are on. Off by default.
  final bool autoCategoriesEnabled;

  /// Whether recommendations are on. Off by default.
  final bool recommendationsEnabled;

  /// Purpose: Create a app settings instance.
  /// Inputs: `themeMode`, `locale`, `weekStartDay`, `homeCalendarLayout`, `homeCalendarTimeBasis`, `homeCalendarFormat`, `homeListColumns`, `manageListColumns`, `manageViewMode`, `manageSeriesSort`, `statsListColumns`, `kanaTabEnabled`, `onDeviceAiEnabled`, `onDeviceAiPreferFast`, `autoCategoriesEnabled`, `recommendationsEnabled`.
  /// Returns: A new `AppSettings` instance.
  /// Side effects: None.
  /// Notes: `weekStartDay` stores the local-calendar preference; Japanese layout uses Sunday effectively.
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.weekStartDay = defaultWeekStartDay,
    this.homeCalendarLayout = HomeCalendarLayout.local,
    this.homeCalendarTimeBasis = HomeCalendarTimeBasis.jst,
    this.homeCalendarFormat = CalendarFormat.month,
    this.homeListColumns = listColumnsAuto,
    this.manageListColumns = listColumnsAuto,
    this.manageViewMode = ManageViewMode.quarter,
    this.manageSeriesSort = ManageSeriesSort.latest,
    this.statsListColumns = listColumnsAuto,
    this.kanaTabEnabled = false,
    this.onDeviceAiEnabled = false,
    this.onDeviceAiPreferFast = false,
    this.autoCategoriesEnabled = false,
    this.recommendationsEnabled = false,
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
  /// Inputs: `themeMode`, `locale`, `weekStartDay`, `homeCalendarLayout`, `homeCalendarTimeBasis`, `homeCalendarFormat`, `homeListColumns`, `manageListColumns`, `manageViewMode`, `manageSeriesSort`, `statsListColumns`, `kanaTabEnabled`, `onDeviceAiEnabled`, `onDeviceAiPreferFast`, `autoCategoriesEnabled`, `recommendationsEnabled`, `clearLocale`.
  /// Returns: `AppSettings`.
  /// Side effects: None.
  /// Notes: None.
  AppSettings copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    int? weekStartDay,
    HomeCalendarLayout? homeCalendarLayout,
    HomeCalendarTimeBasis? homeCalendarTimeBasis,
    CalendarFormat? homeCalendarFormat,
    int? homeListColumns,
    int? manageListColumns,
    ManageViewMode? manageViewMode,
    ManageSeriesSort? manageSeriesSort,
    int? statsListColumns,
    bool? kanaTabEnabled,
    bool? onDeviceAiEnabled,
    bool? onDeviceAiPreferFast,
    bool? autoCategoriesEnabled,
    bool? recommendationsEnabled,
    bool clearLocale = false,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      locale: clearLocale ? null : (locale ?? this.locale),
      weekStartDay: weekStartDay ?? this.weekStartDay,
      homeCalendarLayout: homeCalendarLayout ?? this.homeCalendarLayout,
      homeCalendarTimeBasis:
          homeCalendarTimeBasis ?? this.homeCalendarTimeBasis,
      homeCalendarFormat: homeCalendarFormat ?? this.homeCalendarFormat,
      homeListColumns: homeListColumns ?? this.homeListColumns,
      manageListColumns: manageListColumns ?? this.manageListColumns,
      manageViewMode: manageViewMode ?? this.manageViewMode,
      manageSeriesSort: manageSeriesSort ?? this.manageSeriesSort,
      statsListColumns: statsListColumns ?? this.statsListColumns,
      kanaTabEnabled: kanaTabEnabled ?? this.kanaTabEnabled,
      onDeviceAiEnabled: onDeviceAiEnabled ?? this.onDeviceAiEnabled,
      onDeviceAiPreferFast: onDeviceAiPreferFast ?? this.onDeviceAiPreferFast,
      autoCategoriesEnabled:
          autoCategoriesEnabled ?? this.autoCategoriesEnabled,
      recommendationsEnabled:
          recommendationsEnabled ?? this.recommendationsEnabled,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>(
      (ref) => AppSettingsNotifier(),
    );
