// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MyAnime!!!!!';

  @override
  String get navHome => 'Home';

  @override
  String get navManage => 'Manage';

  @override
  String get navStats => 'Stats';

  @override
  String get navKana => 'Kana';

  @override
  String get navSettings => 'Settings';

  @override
  String homeAiringOn(String date) {
    return 'Airing on $date';
  }

  @override
  String homeUnwatched(int animeCount, int episodeCount) {
    return 'Unwatched: $animeCount anime, $episodeCount episode(s)';
  }

  @override
  String get homeEmpty => 'No anime yet. Add one to get started!';

  @override
  String get homeCalendarTimeNoteJst => 'Calendar dates use Japan time (UTC+9)';

  @override
  String get homeCalendarTimeNoteLocal =>
      'Calendar dates use device local time; airing times stay in Japan time';

  @override
  String get calendarFormatMonth => 'Month';

  @override
  String get calendarFormatTwoWeeks => '2 weeks';

  @override
  String get calendarFormatWeek => 'Week';

  @override
  String get animeTitle => 'Title';

  @override
  String get animeTitleJa => 'Japanese Title';

  @override
  String get animeSeason => 'Season';

  @override
  String get animeStartEp => 'Start Ep';

  @override
  String get animeEndEp => 'End Ep';

  @override
  String get animeType => 'Type';

  @override
  String get animeTypeAuto => 'Auto';

  @override
  String get animeTypeSingleCour => 'Single Cour';

  @override
  String get animeTypeHalfYear => 'Half Year';

  @override
  String get animeTypeFullYear => 'Full Year';

  @override
  String get animeTypeLongRunning => 'Long Running';

  @override
  String get animeTypeAllAtOnce => 'All at Once';

  @override
  String get animeAirDay => 'Air Day';

  @override
  String get animeAirTime => 'Air Time';

  @override
  String get animeAirTimeHelper => 'Japan time, supports 25:00 format';

  @override
  String get animeFirstAirDate => 'First Air Date';

  @override
  String get animeNotes => 'Notes';

  @override
  String get animeWatchUrl => 'Watch URL';

  @override
  String get animeInfoUrl => 'Info URL';

  @override
  String get animeOpenUrl => 'Watch';

  @override
  String get animeOpenInfoUrl => 'Info';

  @override
  String get animeRating => 'Rating';

  @override
  String get animeRatingOverall => 'Overall';

  @override
  String get animeRatingVisual => 'Visuals/Direction';

  @override
  String get animeRatingStory => 'Story';

  @override
  String get animeRatingCharacter => 'Characters';

  @override
  String get animeRatingMusic => 'Music/Sound';

  @override
  String get animeRatingEnjoyment => 'Enjoyment';

  @override
  String get animeRatingAutoHint =>
      'Optional, 0-10. Overall can be averaged from sub-scores.';

  @override
  String get animeRatingOverallHelper => 'Leave empty to average sub-scores';

  @override
  String get animeRatingInvalid => 'Enter a score from 0 to 10';

  @override
  String get animeRatingManualOverall => 'Manual overall score';

  @override
  String get animeRatingAutoOverall => 'Overall score averaged from sub-scores';

  @override
  String get searchAnimeInfo => 'Search Anime Info';

  @override
  String get searchHint => 'Enter title to search…';

  @override
  String get searchButton => 'Search';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchCoverImage => 'Cover Image';

  @override
  String get searchFetchCover => 'Fetch';

  @override
  String get searchCurrent => 'Current';

  @override
  String get searchFetched => 'Fetched';

  @override
  String get searchApply => 'Apply';

  @override
  String get searchWatchUrl => 'Search watch URL on anime1.me';

  @override
  String get searchWatchUrlSet => 'Watch URL filled in';

  @override
  String get searchWatchUrlTitle => 'Search Watch URL';

  @override
  String get searchWatchUrlEmpty => 'No matching watch URL found';

  @override
  String get animeEpisodes => 'episodes';

  @override
  String get animeEpisodeList => 'Episodes';

  @override
  String animeEpisodeShort(int ep) {
    return 'EP $ep';
  }

  @override
  String get animeAdd => 'Add Anime';

  @override
  String get animeEdit => 'Edit Anime';

  @override
  String get animeSearchHint => 'Search anime...';

  @override
  String get animeNoResults => 'No anime in this season';

  @override
  String get animeFieldRequired => 'Required';

  @override
  String animeMissingFields(String fields) {
    return 'Please fill in the following fields: $fields';
  }

  @override
  String get animeWatched => 'Watched';

  @override
  String get animeUnwatched => 'Unwatched';

  @override
  String get animeSkipped => 'Skipped';

  @override
  String get animeShiftForward => 'Move forward 1 week (this ep and after)';

  @override
  String get animeShiftBackward => 'Move backward 1 week (this ep and after)';

  @override
  String get animeMarkAllWatched => 'All Watched';

  @override
  String get animeMarkAllUnwatched => 'Unmark All';

  @override
  String get animeResetSchedule => 'Reset Schedule';

  @override
  String get animeResetScheduleConfirm =>
      'Reset all episode date adjustments to the original schedule based on the first air date?';

  @override
  String get animeAbandon => 'Drop';

  @override
  String get animeResume => 'Resume';

  @override
  String get animePrevSeason => 'Prev Season';

  @override
  String get animeNextSeason => 'Next Season';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get commonDelete => 'Confirm Delete';

  @override
  String commonDeleteConfirm(String item) {
    return 'Delete \"$item\"?';
  }

  @override
  String get commonDontAskMinutes => 'Don\'t ask for 5 minutes';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsHomeCalendarLayout => 'Home Calendar Style';

  @override
  String get settingsHomeCalendarLayoutLocal => 'Local';

  @override
  String get settingsHomeCalendarLayoutJapanese => 'Japanese (日月火水木金土)';

  @override
  String get settingsWeekStartDay => 'Week Starts On';

  @override
  String get settingsWeekStartLockedJapanese =>
      'Japanese calendar always starts on Sunday';

  @override
  String get settingsHomeCalendarTimeBasis => 'Home Calendar Time';

  @override
  String get settingsHomeCalendarTimeBasisJst => 'Japan Time';

  @override
  String get settingsHomeCalendarTimeBasisLocal => 'Local Time';

  @override
  String get settingsHomeCalendarTimeBasisDesc =>
      'Anime airing times are still calculated in Japan time.';

  @override
  String get settingsReminder => 'Daily Reminder';

  @override
  String get settingsReminderOff => 'Off';

  @override
  String get settingsReminderTime => 'Reminder Time';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsLicense => 'License (GPLv3)';

  @override
  String get settingsLicenses => 'Open Source Licenses';

  @override
  String get settingsConfirm => 'Confirm';

  @override
  String get settingsWebDAVSync => 'WebDAV Sync';

  @override
  String get settingsWebDAVServerURL => 'Server URL';

  @override
  String get settingsWebDAVUsername => 'Username';

  @override
  String get settingsWebDAVPassword => 'Password';

  @override
  String get settingsWebDAVRemotePath => 'Remote Path';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTest => 'Test';

  @override
  String get settingsWebDAVAutoSync => 'Auto Sync';

  @override
  String get settingsWebDAVSyncNow => 'Sync Now';

  @override
  String get settingsWebDAVDisconnect => 'Disconnect';

  @override
  String get settingsWebDAVConfigSaved => 'Configuration saved';

  @override
  String get settingsWebDAVConfigRemoved => 'Configuration removed';

  @override
  String get settingsWebDAVConnectionSuccess => 'Connection successful';

  @override
  String get settingsWebDAVConnectionFailed => 'Connection failed';

  @override
  String get settingsWebDAVSyncSuccess => 'Sync completed';

  @override
  String get settingsWebDAVSyncFailed => 'Sync failed';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return 'Sync completed, but $count image(s) failed to transfer';
  }

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle => 'Full local backup (data + images)';

  @override
  String get backupCreate => 'Create Backup';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupAutoBackup => 'Auto Backup';

  @override
  String get backupRetention => 'Retention Period';

  @override
  String get backupKeepForever => 'Keep forever';

  @override
  String backupKeepDays(int days) {
    return '$days days';
  }

  @override
  String backupHistory(int count) {
    return 'History ($count)';
  }

  @override
  String get backupNoBackups => 'No backups yet';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupRestoreConfirm =>
      'This will overwrite your current data. Continue?';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupRestoreFailed => 'Restore failed';

  @override
  String get backupDeleteConfirm => 'Delete this backup?';

  @override
  String get backupRestoreModules => 'Select Data to Restore';

  @override
  String get backupSelectAll => 'Select All';

  @override
  String get exportData => 'Export Data';

  @override
  String get importData => 'Import Data';

  @override
  String get exportSuccess => 'Data exported successfully';

  @override
  String get importSuccess => 'Data imported successfully';

  @override
  String get importFailed => 'Import failed';

  @override
  String get importConfirm =>
      'This will overwrite your current data. Continue?';

  @override
  String get settingsStorageLocation => 'Storage Location';

  @override
  String get settingsStoragePathHint =>
      'Enter a custom directory path for data storage. Leave empty to use default.';

  @override
  String get settingsDirectoryPath => 'Directory Path';

  @override
  String get settingsResetDefault => 'Reset Default';

  @override
  String get settingsResetDefaultLocation =>
      'Storage location reset to default';

  @override
  String get settingsStoragePathUpdated => 'Storage location updated';

  @override
  String get dataMigration => 'Open Data Folder';

  @override
  String get dataMigrationDesc => 'Open the application data directory';

  @override
  String get homeCalendarJst => 'Calendar dates in JST (UTC+9)';

  @override
  String get animeShare => 'Share';

  @override
  String get shareCopied => 'Image copied to clipboard';

  @override
  String get shareCopy => 'Copy';

  @override
  String get shareSaveAs => 'Save As';

  @override
  String get shareSaved => 'Image saved';

  @override
  String get shareFailed => 'Share failed';

  @override
  String get shareUrlOptions => 'Include URLs';

  @override
  String get statsTitle => 'Statistics';

  @override
  String get statsQuarter => 'Quarter';

  @override
  String get statsYear => 'Year';

  @override
  String get statsAll => 'All';

  @override
  String get statsTracked => 'Tracked';

  @override
  String get statsCompleted => 'Completed';

  @override
  String get statsDropped => 'Dropped';

  @override
  String get statsWatching => 'Watching';

  @override
  String get statsNotStarted => 'Not Started';

  @override
  String get statsTrend => 'Trend';

  @override
  String get statsRanking => 'Ranking';

  @override
  String get statsRankingFilters => 'Filters';

  @override
  String get statsRankingTimeFilter => 'Time';

  @override
  String get statsRankingTypeFilter => 'Type';

  @override
  String get statsRankingAllTypes => 'All types';

  @override
  String get statsRankingSortBy => 'Sort by';

  @override
  String get statsRankingDescending => 'High to low';

  @override
  String get statsRankingAscending => 'Low to high';

  @override
  String get statsRankingDescShort => 'Desc';

  @override
  String get statsRankingAscShort => 'Asc';

  @override
  String get statsRankingCustomRange => 'Custom range';

  @override
  String get statsRankingSelectYear => 'Select Year';

  @override
  String get statsRankingStartQuarter => 'Start quarter';

  @override
  String get statsRankingEndQuarter => 'End quarter';

  @override
  String get statsRankingEmpty => 'No rated anime matches these filters';

  @override
  String statsRankingCount(int count) {
    return '$count rated anime';
  }

  @override
  String get manageJumpToQuarter => 'Jump to Quarter';

  @override
  String get manageNoSearchResults => 'No matching anime found';

  @override
  String get manageOther => 'Other';

  @override
  String get dayMon => 'Mon';

  @override
  String get dayTue => 'Tue';

  @override
  String get dayWed => 'Wed';

  @override
  String get dayThu => 'Thu';

  @override
  String get dayFri => 'Fri';

  @override
  String get daySat => 'Sat';

  @override
  String get daySun => 'Sun';

  @override
  String get seasonWinter => 'Winter';

  @override
  String get seasonSpring => 'Spring';

  @override
  String get seasonSummer => 'Summer';

  @override
  String get seasonFall => 'Fall';

  @override
  String reminderAiringToday(int animeCount, int episodeCount) {
    return 'Today: $animeCount anime airing, $episodeCount episode(s)';
  }

  @override
  String reminderUnwatched(int animeCount, int episodeCount) {
    return 'To watch: $animeCount anime, $episodeCount episode(s)';
  }

  @override
  String syncConflictTitle(String name) {
    return 'Sync Conflict: $name';
  }

  @override
  String get syncConflictDesc =>
      'This anime was modified on both devices since last sync.';

  @override
  String get syncLocalVersion => 'Local version:';

  @override
  String get syncRemoteVersion => 'Remote version:';

  @override
  String syncModifiedAt(String time) {
    return 'Modified: $time';
  }

  @override
  String syncEpisodeRange(int start, int end) {
    return 'Episodes: $start–$end';
  }

  @override
  String syncWatched(int count) {
    return 'Watched: $count';
  }

  @override
  String get syncKeepLocal => 'Keep Local';

  @override
  String get syncKeepRemote => 'Keep Remote';

  @override
  String searchEpisodesCount(int count) {
    return '$count eps';
  }

  @override
  String get animeSeasonHint => 'Season 1';

  @override
  String get shareTypeTitle => 'Share Type';

  @override
  String get shareAsImage => 'Share as Image';

  @override
  String get shareAsData => 'Share as Data File';

  @override
  String get importAnimeSuccess => 'Anime imported successfully';

  @override
  String get importAnimeFailed => 'Failed to import anime';

  @override
  String get addAnimeCreate => 'Create New';

  @override
  String get addAnimeImport => 'Import from File';

  @override
  String get exportAsZip => 'Export as ZIP';

  @override
  String get exportAsZipDesc =>
      'Full data archive (anime data + cover images) for backup or migration';

  @override
  String get exportAsMarkdown => 'Export as Markdown';

  @override
  String get exportAsMarkdownDesc =>
      'Anime list sorted by air date with viewing status, for LLM personalization';

  @override
  String get trayShow => 'Show';

  @override
  String get trayQuit => 'Quit';

  @override
  String get settingsMinimizeToTray => 'Minimize to Tray';

  @override
  String get settingsCloseToTray => 'Close to Tray';

  @override
  String get settingsAutoStart => 'Launch at Startup';

  @override
  String get settingsApiServer => 'API Server Settings';

  @override
  String get settingsApiEnabled => 'Local API Server';

  @override
  String get settingsApiListenAddress => 'Listen Address';

  @override
  String get settingsApiPort => 'Port';

  @override
  String get settingsApiUsername => 'Username';

  @override
  String get settingsApiPassword => 'Password';

  @override
  String settingsApiRunning(int port) {
    return 'Running on port $port';
  }

  @override
  String get settingsApiStopped => 'Stopped';

  @override
  String get settingsApiNeedCredentials =>
      'Set username and password before listening on non-localhost';

  @override
  String get settingsApiRestart => 'Restart Server';

  @override
  String settingsApiRestarted(int port) {
    return 'API server restarted on port $port';
  }

  @override
  String get kanaTitle => 'Kana';

  @override
  String get kanaScriptHiragana => 'Hiragana';

  @override
  String get kanaScriptKatakana => 'Katakana';

  @override
  String get kanaSearchHint => 'Search kana or romaji...';

  @override
  String kanaSearchResults(int count) {
    return 'Matches ($count)';
  }

  @override
  String get kanaNoMatches => 'No matching kana';

  @override
  String get kanaBasicSection => 'Gojūon';

  @override
  String get kanaVoicedSection => 'Dakuten';

  @override
  String get kanaYoonSection => 'Yōon';

  @override
  String get kanaRulesSection => 'Pronunciation';

  @override
  String get kanaRuleMoraTitle => 'One kana, one beat';

  @override
  String get kanaRuleMoraBody =>
      'Each kana is one mora. Keep the rhythm even, like ka-ki-ku-ke-ko.';

  @override
  String get kanaRuleVowelsTitle => 'Stable vowels';

  @override
  String get kanaRuleVowelsBody =>
      'a, i, u, e, o stay short and clean. Do not reduce them like unstressed English vowels.';

  @override
  String get kanaRuleDakutenTitle => 'Dakuten and handakuten';

  @override
  String get kanaRuleDakutenBody =>
      '゛voices consonants: k to g, s to z, t to d, h to b. ゜changes h to p.';

  @override
  String get kanaRuleYoonTitle => 'Yōon combinations';

  @override
  String get kanaRuleYoonBody =>
      'Small ゃ/ゅ/ょ merges with an i-row kana: き + ゃ becomes きゃ kya.';

  @override
  String get kanaRuleSokuonTitle => 'Small tsu';

  @override
  String get kanaRuleSokuonBody =>
      'Small っ/ッ doubles the next consonant with a brief stop, as in まって matte.';

  @override
  String get kanaRuleLongVowelsTitle => 'Long vowels';

  @override
  String get kanaRuleLongVowelsBody =>
      'ー lengthens katakana sounds. In hiragana, おう often sounds like long o, and えい like long e.';

  @override
  String get kanaRuleNTitle => 'ん / ン';

  @override
  String get kanaRuleNBody =>
      'Usually n, but it becomes m before m, b, or p, and a soft nasal before k or g.';

  @override
  String get settingsDesktop => 'Desktop';
}
