import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/jst_time.dart';
import '../../../shared/providers/app_settings.dart';
import '../../../shared/services/import_export_service.dart';
import '../../../shared/services/reminder_service.dart';
import '../../../shared/views/webdav_config_page.dart';
import '../../anime/services/anime_storage.dart';
import 'backup_page.dart';
import 'license_page.dart' as app_license;
import 'privacy_policy_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  String _version = '';
  String _storagePath = '';
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadStoragePath();
    _loadReminder();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version}+${info.buildNumber}');
    }
  }

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

  bool get _isDesktop =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  Future<void> _exportData() async {
    final l10n = AppLocalizations.of(context)!;
    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null || !mounted) return;

    final path = await ImportExportService.exportZIP(dir);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSuccess)),
      );
    }
  }

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

    final success =
        await ImportExportService.importZIP(result.files.single.path!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? l10n.importSuccess : l10n.importFailed),
      ),
    );
  }

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

  Future<void> _loadStoragePath() async {
    final path = await AnimeStorage.getStoragePath();
    if (mounted) setState(() => _storagePath = path);
  }

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

  Future<void> _setReminderEnabled(bool v) async {
    setState(() => _reminderEnabled = v);
    final config = await AnimeStorage.readConfig();
    config['reminderEnabled'] = v;
    await AnimeStorage.writeConfig(config);
    ReminderService.startPeriodicCheck();
  }

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
            content: Text(pathToSet == null
                ? l10n.settingsResetDefaultLocation
                : l10n.settingsStoragePathUpdated),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

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
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(builder: (_) => const BackupPage()),
              ),
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
                MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l10n.settingsLicense),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                    builder: (_) => const app_license.LicensePage()),
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
