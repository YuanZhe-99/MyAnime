import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MyAnime!!!!!'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get navManage;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @homeAiringOn.
  ///
  /// In en, this message translates to:
  /// **'Airing on {date}'**
  String homeAiringOn(String date);

  /// No description provided for @homeUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Unwatched ({count})'**
  String homeUnwatched(int count);

  /// No description provided for @homeEmpty.
  ///
  /// In en, this message translates to:
  /// **'No anime yet. Add one to get started!'**
  String get homeEmpty;

  /// No description provided for @animeTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get animeTitle;

  /// No description provided for @animeTitleJa.
  ///
  /// In en, this message translates to:
  /// **'Japanese Title'**
  String get animeTitleJa;

  /// No description provided for @animeSeason.
  ///
  /// In en, this message translates to:
  /// **'Season'**
  String get animeSeason;

  /// No description provided for @animeStartEp.
  ///
  /// In en, this message translates to:
  /// **'Start Ep'**
  String get animeStartEp;

  /// No description provided for @animeEndEp.
  ///
  /// In en, this message translates to:
  /// **'End Ep'**
  String get animeEndEp;

  /// No description provided for @animeType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get animeType;

  /// No description provided for @animeTypeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get animeTypeAuto;

  /// No description provided for @animeTypeSingleCour.
  ///
  /// In en, this message translates to:
  /// **'Single Cour'**
  String get animeTypeSingleCour;

  /// No description provided for @animeTypeHalfYear.
  ///
  /// In en, this message translates to:
  /// **'Half Year'**
  String get animeTypeHalfYear;

  /// No description provided for @animeTypeFullYear.
  ///
  /// In en, this message translates to:
  /// **'Full Year'**
  String get animeTypeFullYear;

  /// No description provided for @animeTypeLongRunning.
  ///
  /// In en, this message translates to:
  /// **'Long Running'**
  String get animeTypeLongRunning;

  /// No description provided for @animeTypeAllAtOnce.
  ///
  /// In en, this message translates to:
  /// **'All at Once'**
  String get animeTypeAllAtOnce;

  /// No description provided for @animeAirDay.
  ///
  /// In en, this message translates to:
  /// **'Air Day'**
  String get animeAirDay;

  /// No description provided for @animeAirTime.
  ///
  /// In en, this message translates to:
  /// **'Air Time'**
  String get animeAirTime;

  /// No description provided for @animeAirTimeHelper.
  ///
  /// In en, this message translates to:
  /// **'Japan time, supports 25:00 format'**
  String get animeAirTimeHelper;

  /// No description provided for @animeFirstAirDate.
  ///
  /// In en, this message translates to:
  /// **'First Air Date'**
  String get animeFirstAirDate;

  /// No description provided for @animeNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get animeNotes;

  /// No description provided for @animeWatchUrl.
  ///
  /// In en, this message translates to:
  /// **'Watch URL'**
  String get animeWatchUrl;

  /// No description provided for @animeOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get animeOpenUrl;

  /// No description provided for @searchAnimeInfo.
  ///
  /// In en, this message translates to:
  /// **'Search Anime Info'**
  String get searchAnimeInfo;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter title to search…'**
  String get searchHint;

  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover Image'**
  String get searchCoverImage;

  /// No description provided for @searchFetchCover.
  ///
  /// In en, this message translates to:
  /// **'Fetch'**
  String get searchFetchCover;

  /// No description provided for @searchCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get searchCurrent;

  /// No description provided for @searchFetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched'**
  String get searchFetched;

  /// No description provided for @searchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchApply;

  /// No description provided for @searchWatchUrl.
  ///
  /// In en, this message translates to:
  /// **'Search watch URL on anime1.me'**
  String get searchWatchUrl;

  /// No description provided for @searchWatchUrlSet.
  ///
  /// In en, this message translates to:
  /// **'Watch URL filled in'**
  String get searchWatchUrlSet;

  /// No description provided for @searchWatchUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Search Watch URL'**
  String get searchWatchUrlTitle;

  /// No description provided for @searchWatchUrlEmpty.
  ///
  /// In en, this message translates to:
  /// **'No matching watch URL found'**
  String get searchWatchUrlEmpty;

  /// No description provided for @animeEpisodes.
  ///
  /// In en, this message translates to:
  /// **'episodes'**
  String get animeEpisodes;

  /// No description provided for @animeEpisodeList.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get animeEpisodeList;

  /// No description provided for @animeEpisodeShort.
  ///
  /// In en, this message translates to:
  /// **'EP {ep}'**
  String animeEpisodeShort(int ep);

  /// No description provided for @animeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add Anime'**
  String get animeAdd;

  /// No description provided for @animeEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit Anime'**
  String get animeEdit;

  /// No description provided for @animeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search anime...'**
  String get animeSearchHint;

  /// No description provided for @animeNoResults.
  ///
  /// In en, this message translates to:
  /// **'No anime in this season'**
  String get animeNoResults;

  /// No description provided for @animeFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get animeFieldRequired;

  /// No description provided for @animeMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill in the following fields: {fields}'**
  String animeMissingFields(String fields);

  /// No description provided for @animeWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get animeWatched;

  /// No description provided for @animeUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Unwatched'**
  String get animeUnwatched;

  /// No description provided for @animeSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get animeSkipped;

  /// No description provided for @animeShiftForward.
  ///
  /// In en, this message translates to:
  /// **'Move forward 1 week (this ep and after)'**
  String get animeShiftForward;

  /// No description provided for @animeShiftBackward.
  ///
  /// In en, this message translates to:
  /// **'Move backward 1 week (this ep and after)'**
  String get animeShiftBackward;

  /// No description provided for @animeMarkAllWatched.
  ///
  /// In en, this message translates to:
  /// **'All Watched'**
  String get animeMarkAllWatched;

  /// No description provided for @animeMarkAllUnwatched.
  ///
  /// In en, this message translates to:
  /// **'Unmark All'**
  String get animeMarkAllUnwatched;

  /// No description provided for @animeResetSchedule.
  ///
  /// In en, this message translates to:
  /// **'Reset Schedule'**
  String get animeResetSchedule;

  /// No description provided for @animeResetScheduleConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset all episode date adjustments to the original schedule based on the first air date?'**
  String get animeResetScheduleConfirm;

  /// No description provided for @animeAbandon.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get animeAbandon;

  /// No description provided for @animeResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get animeResume;

  /// No description provided for @animePrevSeason.
  ///
  /// In en, this message translates to:
  /// **'Prev Season'**
  String get animePrevSeason;

  /// No description provided for @animeNextSeason.
  ///
  /// In en, this message translates to:
  /// **'Next Season'**
  String get animeNextSeason;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get commonDelete;

  /// No description provided for @commonDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{item}\"?'**
  String commonDeleteConfirm(String item);

  /// No description provided for @commonDontAskMinutes.
  ///
  /// In en, this message translates to:
  /// **'Don\'t ask for 5 minutes'**
  String get commonDontAskMinutes;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily Reminder'**
  String get settingsReminder;

  /// No description provided for @settingsReminderOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get settingsReminderOff;

  /// No description provided for @settingsReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Reminder Time'**
  String get settingsReminderTime;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'License (GPLv3)'**
  String get settingsLicense;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsLicenses;

  /// No description provided for @settingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsConfirm;

  /// No description provided for @settingsWebDAVSync.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get settingsWebDAVSync;

  /// No description provided for @settingsWebDAVServerURL.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsWebDAVServerURL;

  /// No description provided for @settingsWebDAVUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsWebDAVUsername;

  /// No description provided for @settingsWebDAVPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsWebDAVPassword;

  /// No description provided for @settingsWebDAVRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote Path'**
  String get settingsWebDAVRemotePath;

  /// No description provided for @settingsWebDAVNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud'**
  String get settingsWebDAVNextcloud;

  /// No description provided for @settingsWebDAVTest.
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get settingsWebDAVTest;

  /// No description provided for @settingsWebDAVAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get settingsWebDAVAutoSync;

  /// No description provided for @settingsWebDAVSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settingsWebDAVSyncNow;

  /// No description provided for @settingsWebDAVDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsWebDAVDisconnect;

  /// No description provided for @settingsWebDAVConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved'**
  String get settingsWebDAVConfigSaved;

  /// No description provided for @settingsWebDAVConfigRemoved.
  ///
  /// In en, this message translates to:
  /// **'Configuration removed'**
  String get settingsWebDAVConfigRemoved;

  /// No description provided for @settingsWebDAVConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get settingsWebDAVConnectionSuccess;

  /// No description provided for @settingsWebDAVConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get settingsWebDAVConnectionFailed;

  /// No description provided for @settingsWebDAVSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get settingsWebDAVSyncSuccess;

  /// No description provided for @settingsWebDAVSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get settingsWebDAVSyncFailed;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full local backup (data + images)'**
  String get backupSubtitle;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get backupCreate;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// No description provided for @backupAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get backupAutoBackup;

  /// No description provided for @backupRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention Period'**
  String get backupRetention;

  /// No description provided for @backupKeepForever.
  ///
  /// In en, this message translates to:
  /// **'Keep forever'**
  String get backupKeepForever;

  /// No description provided for @backupKeepDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String backupKeepDays(int days);

  /// No description provided for @backupHistory.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String backupHistory(int count);

  /// No description provided for @backupNoBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupNoBackups;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestore;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get backupRestoreFailed;

  /// No description provided for @backupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this backup?'**
  String get backupDeleteConfirm;

  /// No description provided for @backupRestoreModules.
  ///
  /// In en, this message translates to:
  /// **'Select Data to Restore'**
  String get backupRestoreModules;

  /// No description provided for @backupSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get backupSelectAll;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data exported successfully'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data imported successfully'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get importConfirm;

  /// No description provided for @settingsStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get settingsStorageLocation;

  /// No description provided for @settingsStoragePathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a custom directory path for data storage. Leave empty to use default.'**
  String get settingsStoragePathHint;

  /// No description provided for @settingsDirectoryPath.
  ///
  /// In en, this message translates to:
  /// **'Directory Path'**
  String get settingsDirectoryPath;

  /// No description provided for @settingsResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset Default'**
  String get settingsResetDefault;

  /// No description provided for @settingsResetDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage location reset to default'**
  String get settingsResetDefaultLocation;

  /// No description provided for @settingsStoragePathUpdated.
  ///
  /// In en, this message translates to:
  /// **'Storage location updated'**
  String get settingsStoragePathUpdated;

  /// No description provided for @dataMigration.
  ///
  /// In en, this message translates to:
  /// **'Open Data Folder'**
  String get dataMigration;

  /// No description provided for @dataMigrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Open the application data directory'**
  String get dataMigrationDesc;

  /// No description provided for @homeCalendarJst.
  ///
  /// In en, this message translates to:
  /// **'Calendar dates in JST (UTC+9)'**
  String get homeCalendarJst;

  /// No description provided for @animeShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get animeShare;

  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'Image copied to clipboard'**
  String get shareCopied;

  /// No description provided for @shareCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareCopy;

  /// No description provided for @shareSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get shareSaveAs;

  /// No description provided for @shareSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get shareSaved;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get shareFailed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
