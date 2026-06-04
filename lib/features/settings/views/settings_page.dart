import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/jst_time.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/services/import_export_service.dart';
import '../../../shared/services/local_api_server.dart';
import '../../../shared/services/reminder_service.dart';
import '../../../shared/services/tray_service.dart';
import '../../../shared/utils/calendar_preferences.dart';
import '../../../shared/views/webdav_config_page.dart';
import '../../anime/services/anime_storage.dart';
import 'backup_page.dart';
import 'license_page.dart' as app_license;
import 'privacy_policy_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  /// Purpose: Create a settings page instance.
  /// Inputs: None.
  /// Returns: A new `SettingsPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const SettingsPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _version = '';
  String _storagePath = '';
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);
  // Tray settings
  bool _minimizeToTray = false;
  bool _closeToTray = false;
  bool _autoStart = false;
  // API server settings
  bool _apiEnabled = false;
  int _apiPort = 7788;
  String _apiListenAddress = 'localhost';
  String _apiUsername = '';
  String _apiPassword = '';

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadStoragePath();
    _loadReminder();
    if (_isDesktop) {
      _loadTraySettings();
      _loadAutoStartStatus();
      _loadApiSettings();
    }
  }

  /// Purpose: Provide the internal load version helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version}+${info.buildNumber}');
    }
  }

  /// Purpose: Provide the internal build section helper for this file.
  /// Inputs: `title`, `children`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  /// Purpose: Return the localized label for a home calendar layout option.
  /// Inputs: `layout`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _calendarLayoutLabel(
    HomeCalendarLayout layout,
    AppLocalizations l10n,
  ) {
    return switch (layout) {
      HomeCalendarLayout.local => l10n.settingsHomeCalendarLayoutLocal,
      HomeCalendarLayout.japanese => l10n.settingsHomeCalendarLayoutJapanese,
    };
  }

  /// Purpose: Return the localized label for a home calendar time basis option.
  /// Inputs: `basis`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _homeCalendarTimeBasisLabel(
    HomeCalendarTimeBasis basis,
    AppLocalizations l10n,
  ) {
    return switch (basis) {
      HomeCalendarTimeBasis.jst => l10n.settingsHomeCalendarTimeBasisJst,
      HomeCalendarTimeBasis.local => l10n.settingsHomeCalendarTimeBasisLocal,
    };
  }

  /// Purpose: Return a localized weekday label for settings controls.
  /// Inputs: `weekday`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Weekday values use Dart's Monday=1 through Sunday=7 numbering.
  String _weekdayLabel(int weekday, AppLocalizations l10n) {
    final days = [
      '',
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];
    return days[weekday.clamp(1, 7)];
  }

  /// Purpose: Provide the internal is desktop helper for this file.
  /// Inputs: `isLinux`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Purpose: Provide the internal export data helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;

    // Ask user which format to export
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.exportData),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'zip'),
            child: ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(l10n.exportAsZip),
              subtitle: Text(
                l10n.exportAsZipDesc,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'markdown'),
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.exportAsMarkdown),
              subtitle: Text(
                l10n.exportAsMarkdownDesc,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || !mounted) return;

    final String? path;
    if (choice == 'markdown') {
      path = await ImportExportService.exportMarkdown(dir);
    } else {
      path = await ImportExportService.exportZIP(dir);
    }
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.exportSuccess)));
    }
  }

  /// Purpose: Provide the internal import data helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _importData() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null || !mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.importData),
        content: Text(l10n.importConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.importData),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final success = await ImportExportService.importZIP(
      result.files.single.path!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? l10n.importSuccess : l10n.importFailed)),
    );
  }

  /// Purpose: Provide the internal open data folder helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _openDataFolder() async {
    final appDir = await AnimeStorage.getAppDir();
    if (Platform.isWindows) {
      await Process.run('explorer', [appDir.path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [appDir.path]);
    } else if (Platform.isLinux) {
      final uri = Uri.directory(appDir.path);
      await Process.run('xdg-open', [uri.toFilePath()]);
    }
  }

  /// Purpose: Provide the internal load storage path helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadStoragePath() async {
    final path = await AnimeStorage.getStoragePath();
    if (mounted) setState(() => _storagePath = path);
  }

  /// Purpose: Provide the internal load reminder helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadReminder() async {
    final config = await AnimeStorage.readConfig();
    if (!mounted) return;
    setState(() {
      _reminderEnabled = config['reminderEnabled'] as bool? ?? false;
      final ts = config['reminderTime'] as String?;
      if (ts != null) {
        final p = ts.split(':');
        _reminderTime = TimeOfDay(
          hour: int.tryParse(p[0]) ?? 18,
          minute: int.tryParse(p[1]) ?? 0,
        );
      }
    });
  }

  /// Purpose: Provide the internal load tray settings helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadTraySettings() async {
    final config = await AnimeStorage.readConfig();
    if (!mounted) return;
    setState(() {
      _minimizeToTray = config['minimizeToTray'] as bool? ?? false;
      _closeToTray = config['closeToTray'] as bool? ?? false;
    });
  }

  /// Purpose: Provide the internal load auto start status helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadAutoStartStatus() async {
    final enabled = await launchAtStartup.isEnabled();
    if (!mounted) return;
    setState(() => _autoStart = enabled);
  }

  /// Purpose: Provide the internal load api settings helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadApiSettings() async {
    final config = await AnimeStorage.readConfig();
    if (!mounted) return;
    setState(() {
      _apiEnabled = config['apiEnabled'] as bool? ?? false;
      _apiPort = config['apiPort'] as int? ?? 7788;
      _apiListenAddress = config['apiListenAddress'] as String? ?? 'localhost';
      _apiUsername = config['apiUsername'] as String? ?? '';
      _apiPassword = config['apiPassword'] as String? ?? '';
    });
  }

  /// Purpose: Provide the internal show api settings dialog helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _showApiSettingsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final portCtrl = TextEditingController(text: _apiPort.toString());
    final addrCtrl = TextEditingController(text: _apiListenAddress);
    final userCtrl = TextEditingController(text: _apiUsername);
    final passCtrl = TextEditingController(text: _apiPassword);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsApiServer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: addrCtrl,
              decoration: InputDecoration(
                labelText: l10n.settingsApiListenAddress,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: portCtrl,
              decoration: InputDecoration(labelText: l10n.settingsApiPort),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userCtrl,
              decoration: InputDecoration(labelText: l10n.settingsApiUsername),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passCtrl,
              decoration: InputDecoration(labelText: l10n.settingsApiPassword),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final newPort = int.tryParse(portCtrl.text.trim()) ?? 7788;
    final newAddr = addrCtrl.text.trim().isEmpty
        ? 'localhost'
        : addrCtrl.text.trim();
    final newUser = userCtrl.text.trim();
    final newPass = passCtrl.text.trim();
    final config = await AnimeStorage.readConfig();
    config['apiPort'] = newPort;
    config['apiListenAddress'] = newAddr;
    config['apiUsername'] = newUser.isEmpty ? null : newUser;
    config['apiPassword'] = newPass.isEmpty ? null : newPass;
    await AnimeStorage.writeConfig(config);
    setState(() {
      _apiPort = newPort;
      _apiListenAddress = newAddr;
      _apiUsername = newUser;
      _apiPassword = newPass;
    });
    await LocalApiServer.restart();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsApiRestarted(LocalApiServer.port))),
      );
    }
  }

  /// Purpose: Provide the internal set reminder enabled helper for this file.
  /// Inputs: `v`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _setReminderEnabled(bool v) async {
    setState(() => _reminderEnabled = v);
    final config = await AnimeStorage.readConfig();
    config['reminderEnabled'] = v;
    await AnimeStorage.writeConfig(config);
    ReminderService.startPeriodicCheck();
  }

  /// Purpose: Provide the internal pick reminder time helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    final config = await AnimeStorage.readConfig();
    config['reminderTime'] =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    // Reset lastReminderDate so the new time takes effect today.
    config.remove('lastReminderDate');
    await AnimeStorage.writeConfig(config);
    if (_reminderEnabled) ReminderService.startPeriodicCheck();
  }

  /// Purpose: Provide the internal show storage path dialog helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _showStoragePathDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: _storagePath);

    final newPath = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsStorageLocation),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.settingsStoragePathHint),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.settingsDirectoryPath,
                hintText: 'C:\\Users\\...\\MyAnime',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: Text(l10n.settingsResetDefault),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.settingsConfirm),
          ),
        ],
      ),
    );

    if (newPath == null) return;
    final pathToSet = newPath.isEmpty ? null : newPath;
    final ok = await AnimeStorage.setStoragePath(pathToSet);
    if (ok) {
      await _loadStoragePath();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pathToSet == null
                  ? l10n.settingsResetDefaultLocation
                  : l10n.settingsStoragePathUpdated,
            ),
          ),
        );
      }
    }
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final usesJapaneseCalendar =
        settings.homeCalendarLayout == HomeCalendarLayout.japanese;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        children: [
          // ── General ──
          _buildSection(l10n.settingsGeneral, [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: Text(l10n.settingsTheme),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: const Icon(Icons.brightness_auto, size: 18),
                    label: Text(l10n.settingsThemeSystem),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: const Icon(Icons.light_mode, size: 18),
                    label: Text(l10n.settingsThemeLight),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: const Icon(Icons.dark_mode, size: 18),
                    label: Text(l10n.settingsThemeDark),
                  ),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (s) => notifier.setThemeMode(s.first),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.settingsLanguage),
              trailing: DropdownButton<Locale?>(
                value: settings.locale,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(l10n.settingsLanguageSystem),
                  ),
                  const DropdownMenuItem(
                    value: Locale('en'),
                    child: Text('English'),
                  ),
                  const DropdownMenuItem(
                    value: Locale('zh'),
                    child: Text('简体中文'),
                  ),
                  const DropdownMenuItem(
                    value: Locale('zh', 'TW'),
                    child: Text('繁體中文'),
                  ),
                  const DropdownMenuItem(
                    value: Locale('ja'),
                    child: Text('日本語'),
                  ),
                ],
                onChanged: (locale) => notifier.setLocale(locale),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: Text(l10n.settingsHomeCalendarLayout),
              trailing: DropdownButton<HomeCalendarLayout>(
                value: settings.homeCalendarLayout,
                underline: const SizedBox.shrink(),
                items: [
                  for (final layout in HomeCalendarLayout.values)
                    DropdownMenuItem(
                      value: layout,
                      child: Text(_calendarLayoutLabel(layout, l10n)),
                    ),
                ],
                onChanged: (layout) {
                  if (layout != null) notifier.setHomeCalendarLayout(layout);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.view_week_outlined),
              title: Text(l10n.settingsWeekStartDay),
              subtitle: usesJapaneseCalendar
                  ? Text(l10n.settingsWeekStartLockedJapanese)
                  : null,
              trailing: DropdownButton<int>(
                value: settings.effectiveWeekStartDay,
                underline: const SizedBox.shrink(),
                items: [
                  for (final weekday in weekdaySequence(defaultWeekStartDay))
                    DropdownMenuItem(
                      value: weekday,
                      child: Text(_weekdayLabel(weekday, l10n)),
                    ),
                ],
                onChanged: usesJapaneseCalendar
                    ? null
                    : (weekday) {
                        if (weekday != null) notifier.setWeekStartDay(weekday);
                      },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: Text(l10n.settingsHomeCalendarTimeBasis),
              subtitle: Text(l10n.settingsHomeCalendarTimeBasisDesc),
              trailing: DropdownButton<HomeCalendarTimeBasis>(
                value: settings.homeCalendarTimeBasis,
                underline: const SizedBox.shrink(),
                items: [
                  for (final basis in HomeCalendarTimeBasis.values)
                    DropdownMenuItem(
                      value: basis,
                      child: Text(_homeCalendarTimeBasisLabel(basis, l10n)),
                    ),
                ],
                onChanged: (basis) {
                  if (basis != null) {
                    notifier.setHomeCalendarTimeBasis(basis);
                  }
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: Text(l10n.settingsReminder),
              subtitle: Text(
                _reminderEnabled
                    ? _reminderTime.format(context)
                    : l10n.settingsReminderOff,
              ),
              value: _reminderEnabled,
              onChanged: _setReminderEnabled,
            ),
            if (_reminderEnabled)
              ListTile(
                leading: const SizedBox(width: 24),
                title: Text(l10n.settingsReminderTime),
                trailing: TextButton(
                  onPressed: _pickReminderTime,
                  child: Text(_reminderTime.format(context)),
                ),
              ),
          ]),

          // ── Data ──
          _buildSection(l10n.settingsData, [
            ListTile(
              leading: const Icon(Icons.sync_outlined),
              title: Text(l10n.settingsWebDAVSync),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const WebDAVConfigPage()),
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: Text(l10n.backupTitle),
              subtitle: Text(l10n.backupSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
                rootNavigator: true,
              ).push(MaterialPageRoute(builder: (_) => const BackupPage())),
            ),
            ListTile(
              leading: const Icon(Icons.file_upload_outlined),
              title: Text(l10n.exportData),
              onTap: _exportData,
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: Text(l10n.importData),
              onTap: _importData,
            ),
            if (_isDesktop)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.settingsStorageLocation),
                subtitle: Text(
                  _storagePath,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showStoragePathDialog,
              ),
            if (_isDesktop)
              ListTile(
                leading: const Icon(Icons.folder_open_outlined),
                title: Text(l10n.dataMigration),
                subtitle: Text(l10n.dataMigrationDesc),
                onTap: _openDataFolder,
              ),
          ]),

          // ── Debug ──
          if (kDebugMode)
            _buildSection('Debug', [
              ListTile(
                leading: const Icon(Icons.schedule),
                title: const Text('JST Time'),
                subtitle: Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss').format(JstTime.now()),
                ),
              ),
            ]),

          // ── Desktop ──
          if (_isDesktop)
            _buildSection(l10n.settingsDesktop, [
              SwitchListTile(
                secondary: const Icon(Icons.minimize_outlined),
                title: Text(l10n.settingsMinimizeToTray),
                value: _minimizeToTray,
                onChanged: (v) {
                  setState(() => _minimizeToTray = v);
                  TrayService.instance.setMinimizeToTray(v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.close_outlined),
                title: Text(l10n.settingsCloseToTray),
                value: _closeToTray,
                onChanged: (v) {
                  setState(() => _closeToTray = v);
                  TrayService.instance.setCloseToTray(v);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.login_outlined),
                title: Text(l10n.settingsAutoStart),
                value: _autoStart,
                onChanged: (v) async {
                  if (v) {
                    await launchAtStartup.enable();
                  } else {
                    await launchAtStartup.disable();
                  }
                  setState(() => _autoStart = v);
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              SwitchListTile(
                secondary: const Icon(Icons.dns_outlined),
                title: Text(l10n.settingsApiEnabled),
                subtitle: Text(
                  LocalApiServer.isRunning
                      ? l10n.settingsApiRunning(LocalApiServer.port)
                      : LocalApiServer.lastError == 'credentials_required'
                      ? l10n.settingsApiNeedCredentials
                      : LocalApiServer.lastError != null
                      ? '${l10n.settingsApiStopped} (${LocalApiServer.lastError})'
                      : l10n.settingsApiStopped,
                  style:
                      !LocalApiServer.isRunning &&
                          LocalApiServer.lastError != null
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
                value: _apiEnabled,
                onChanged: (v) async {
                  final config = await AnimeStorage.readConfig();
                  config['apiEnabled'] = v;
                  await AnimeStorage.writeConfig(config);
                  setState(() => _apiEnabled = v);
                  if (v) {
                    await LocalApiServer.start();
                  } else {
                    await LocalApiServer.stop();
                  }
                  if (mounted) setState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l10n.settingsApiServer),
                trailing: const Icon(Icons.chevron_right),
                enabled: _apiEnabled,
                onTap: _apiEnabled ? _showApiSettingsDialog : null,
              ),
            ]),

          // ── About ──
          _buildSection(l10n.settingsAbout, [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.settingsVersion),
              trailing: Text(
                _version,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l10n.settingsPrivacyPolicy),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l10n.settingsLicense),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (_) => const app_license.LicensePage(),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l10n.settingsLicenses),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: _version,
              ),
            ),
          ]),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
