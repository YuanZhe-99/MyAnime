import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/auto_sync_service.dart';
import '../../../shared/services/backup_service.dart';
import '../../../shared/services/reminder_service.dart';
import '../../../shared/services/sync_wake_lock.dart';
import '../../../shared/services/webdav_service.dart';

class BackupPage extends StatefulWidget {
  /// Purpose: Create a backup page instance.
  /// Inputs: None.
  /// Returns: A new `BackupPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const BackupPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupInfo> _backups = [];
  bool _loading = true;
  bool _autoBackup = false;
  int _retentionDays = 0;

  static const _retentionOptions = [0, 3, 7, 14, 30, 60, 90];

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Purpose: Provide the internal load helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _load() async {
    await BackupService.loadSettings();
    final backups = await BackupService.listBackups();
    if (mounted) {
      setState(() {
        _backups = backups;
        _autoBackup = BackupService.autoBackupEnabled;
        _retentionDays = BackupService.retentionDays;
        _loading = false;
      });
    }
  }

  /// Purpose: Provide the internal create backup helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Shows a failure
  /// snackbar when the backup could not be created.
  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await BackupService.createBackup();
    if (!mounted) return;
    if (file != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupCreated)));
      await _load();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupFailed)));
    }
  }

  /// Purpose: Provide the internal restore backup helper for this file.
  /// Inputs: `backup`.
  /// Returns: None.
  /// Side effects: May disable WebDAV auto-sync, overwrite local data files,
  /// and show dialogs/snackbars.
  /// Notes: Internal helper used within this file only. When WebDAV auto-sync
  /// is enabled it is disabled *before* any file is written and without a
  /// `mounted` gate, so a crash or page disposal mid-restore can never leave
  /// restored-old data with auto-sync still on (which would propagate stale
  /// records and deletions to the remote and other devices). Auto-sync is
  /// re-enabled only when the restore failed before writing anything.
  Future<void> _restoreBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;

    final availableModules = await BackupService.getBackupModules(backup.file);
    if (!mounted) return;
    if (availableModules.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupRestoreFailed)));
      return;
    }

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) =>
          _RestoreModuleDialog(availableModules: availableModules),
    );
    if (selected == null || selected.isEmpty) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestore),
        content: Text(l10n.backupRestoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.backupRestore),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // Disable auto-sync before the first write, not after the restore:
    // otherwise a crash or page disposal mid-restore would leave restored-old
    // data behind with auto-sync still enabled.
    final config = await WebDAVService.loadConfig();
    final webDavConfigured = config != null && config.isConfigured;
    final hadAutoSync = webDavConfigured && config.autoSync;
    if (hadAutoSync) {
      await WebDAVService.saveConfig(config.copyWith(autoSync: false));
    }

    final result = await BackupService.restoreBackup(
      backup.file,
      moduleKeys: selected,
    );
    if (!result.ok) {
      // Local data is untouched only when nothing was written; only then is
      // it safe to turn auto-sync back on.
      if (hadAutoSync && !result.wroteAnything) {
        await WebDAVService.saveConfig(config.copyWith(autoSync: true));
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupRestoreFailed)));
      return;
    }

    // Reload open pages and reminder schedules with the restored data.
    AutoSyncService.instance.notifyLocalDataChangedNow();
    ReminderService.notifyDataChanged();

    if (result.missingImages > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.backupRestoreMissingImages(result.missingImages),
          ),
        ),
      );
    }

    if (!mounted) return;
    await _handlePostRestoreSync(webDavConfigured ? config : null);
  }

  /// Purpose: Offer a force upload after a restore with WebDAV configured.
  /// Inputs: `config` — the WebDAV config loaded before the restore, or null
  /// when WebDAV sync is not configured.
  /// Returns: None.
  /// Side effects: May force-upload local data to the WebDAV remote under a
  /// wake lock and show dialogs/snackbars.
  /// Notes: Internal helper used within this file only. Auto-sync was already
  /// disabled by [_restoreBackup] before any file was written; this helper
  /// only handles the user-facing follow-up. Does nothing beyond a success
  /// snackbar when WebDAV sync is not configured: restoring an older backup
  /// and letting auto-sync merge it would otherwise propagate stale records
  /// and deletions to the remote and other devices.
  Future<void> _handlePostRestoreSync(WebDAVConfig? config) async {
    final l10n = AppLocalizations.of(context)!;

    if (config == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.backupRestored)));
      return;
    }

    final forceUpload = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.backupRestored),
        content: Text(
          '${l10n.backupRestoredSyncDisabled}\n\n'
          '${l10n.backupForceUploadPrompt}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.backupForceUploadSkip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.settingsWebDAVForceUpload),
          ),
        ],
      ),
    );
    if (forceUpload != true || !mounted) return;

    await SyncWakeLock.acquire();
    SyncResult result;
    try {
      result = await WebDAVService.forceUpload(config);
    } finally {
      await SyncWakeLock.release();
    }
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? l10n.backupForceUploadDone
              : l10n.backupForceUploadFailed,
        ),
      ),
    );
  }

  /// Purpose: Provide the internal delete backup helper for this file.
  /// Inputs: `backup`.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _deleteBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.backupDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await BackupService.deleteBackup(backup.file);
    await _load();
  }

  /// Purpose: Provide the internal toggle auto backup helper for this file.
  /// Inputs: `value`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _toggleAutoBackup(bool value) async {
    setState(() => _autoBackup = value);
    BackupService.autoBackupEnabled = value;
    await BackupService.saveSettings();
  }

  /// Purpose: Provide the internal set retention helper for this file.
  /// Inputs: `days`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _setRetention(int days) async {
    setState(() => _retentionDays = days);
    BackupService.retentionDays = days;
    await BackupService.saveSettings();
  }

  /// Purpose: Provide the internal build section helper for this file.
  /// Inputs: `context`, `title`, `children`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
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

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMd().add_Hms();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.backupTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.backupLocalOnlyNote,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _buildSection(context, l10n.settingsGeneral, [
                  SwitchListTile(
                    secondary: const Icon(Icons.schedule_outlined),
                    title: Text(l10n.backupAutoBackup),
                    subtitle: Text(l10n.backupAutoBackupDesc),
                    value: _autoBackup,
                    onChanged: _toggleAutoBackup,
                  ),
                  ListTile(
                    leading: const Icon(Icons.auto_delete),
                    title: Text(l10n.backupRetention),
                    trailing: DropdownButton<int>(
                      value: _retentionDays,
                      underline: const SizedBox.shrink(),
                      items: _retentionOptions.map((d) {
                        final label = d == 0
                            ? l10n.backupKeepForever
                            : l10n.backupKeepDays(d);
                        return DropdownMenuItem(value: d, child: Text(label));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) _setRetention(v);
                      },
                    ),
                  ),
                ]),
                _buildSection(context, l10n.backupCreate, [
                  ListTile(
                    leading: const Icon(Icons.backup),
                    title: Text(l10n.backupCreate),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _createBackup,
                  ),
                ]),
                _buildSection(
                  context,
                  l10n.backupHistory(_backups.length),
                  _backups.isEmpty
                      ? [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              l10n.backupNoBackups,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ]
                      : _backups.map((b) {
                          final dateStr = dateFormat.format(b.date);
                          return ListTile(
                            leading: Icon(
                              b.corrupt
                                  ? Icons.error_outline
                                  : Icons.inventory_2_outlined,
                              color: b.corrupt
                                  ? theme.colorScheme.error
                                  : null,
                            ),
                            title: Text(dateStr),
                            subtitle: Text(
                              b.corrupt
                                  ? '${b.displaySize} · ${l10n.backupCorrupt}'
                                  : b.displaySize,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore),
                                  tooltip: l10n.backupRestore,
                                  onPressed: b.corrupt
                                      ? null
                                      : () => _restoreBackup(b),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: l10n.delete,
                                  onPressed: () => _deleteBackup(b),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                ),
              ],
            ),
    );
  }
}

class _RestoreModuleDialog extends StatefulWidget {
  final List<String> availableModules;

  /// Purpose: Create a restore module dialog instance.
  /// Inputs: None.
  /// Returns: A new `_RestoreModuleDialog` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _RestoreModuleDialog({required this.availableModules});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<_RestoreModuleDialog> createState() => _RestoreModuleDialogState();
}

class _RestoreModuleDialogState extends State<_RestoreModuleDialog> {
  late final Set<String> _selected;
  bool _selectAll = true;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.availableModules);
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final moduleLabels = {
      'anime': (l10n.backupModuleAnime, Icons.video_library),
    };
    return AlertDialog(
      title: Text(l10n.backupRestoreModules),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            title: Text(l10n.backupSelectAll),
            value: _selectAll,
            onChanged: (v) {
              setState(() {
                _selectAll = v ?? false;
                if (_selectAll) {
                  _selected.addAll(widget.availableModules);
                } else {
                  _selected.clear();
                }
              });
            },
          ),
          const Divider(),
          ...widget.availableModules.map((m) {
            final label = moduleLabels[m];
            return CheckboxListTile(
              secondary: Icon(label?.$2 ?? Icons.data_object),
              title: Text(label?.$1 ?? m),
              value: _selected.contains(m),
              onChanged: (v) {
                setState(() {
                  if (v == true) {
                    _selected.add(m);
                  } else {
                    _selected.remove(m);
                  }
                  _selectAll =
                      _selected.length == widget.availableModules.length;
                });
              },
            );
          }),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: Text(l10n.backupRestore),
        ),
      ],
    );
  }
}
