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
  String get navSettings => 'Settings';

  @override
  String homeAiringOn(String date) {
    return 'Airing on $date';
  }

  @override
  String homeUnwatched(int count) {
    return 'Unwatched ($count)';
  }

  @override
  String get homeEmpty => 'No anime yet. Add one to get started!';

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
  String get manageJumpToQuarter => 'Jump to Quarter';

  @override
  String get manageNoSearchResults => 'No matching anime found';

  @override
  String get manageOther => 'Other';
}
