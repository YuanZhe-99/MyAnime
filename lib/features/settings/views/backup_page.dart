import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/services/backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  List<BackupInfo> _backups = [];
  bool _loading = true;
  bool _autoBackup = false;
  int _retentionDays = 0;

  static const _retentionOptions = [0, 7, 14, 30, 60, 90];

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  Future<void> _createBackup() async {
    final l10n = AppLocalizations.of(context)!;
    final file = await BackupService.createBackup();
    if (!mounted) return;
    if (file != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupCreated)),
      );
      await _load();
    }
  }

  Future<void> _restoreBackup(BackupInfo backup) async {
    final l10n = AppLocalizations.of(context)!;

    final availableModules = await BackupService.getBackupModules(backup.file);
    if (!mounted) return;
    if (availableModules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.backupRestoreFailed)),
      );
      return;
    }

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _RestoreModuleDialog(
        availableModules: availableModules,
      ),
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

    final ok = await BackupService.restoreBackup(
      backup.file,
      moduleKeys: selected,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? l10n.backupRestored : l10n.backupRestoreFailed,
        ),
      ),
    );
  }

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

  Future<void> _toggleAutoBackup(bool value) async {
    setState(() => _autoBackup = value);
    BackupService.autoBackupEnabled = value;
    await BackupService.saveSettings();
  }

  Future<void> _setRetention(int days) async {
    setState(() => _retentionDays = days);
    BackupService.retentionDays = days;
    await BackupService.saveSettings();
  }

  Widget _buildSection(
      BuildContext context, String title, List<Widget> children) {
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
                _buildSection(context, l10n.settingsGeneral, [
                  SwitchListTile(
                    secondary: const Icon(Icons.schedule_outlined),
                    title: Text(l10n.backupAutoBackup),
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
                        return DropdownMenuItem(
                            value: d, child: Text(label));
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
                            leading: const Icon(Icons.inventory_2_outlined),
                            title: Text(dateStr),
                            subtitle: Text(b.displaySize),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.restore),
                                  tooltip: l10n.backupRestore,
                                  onPressed: () => _restoreBackup(b),
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
  const _RestoreModuleDialog({required this.availableModules});

  @override
  State<_RestoreModuleDialog> createState() => _RestoreModuleDialogState();
}

class _RestoreModuleDialogState extends State<_RestoreModuleDialog> {
  late final Set<String> _selected;
  bool _selectAll = true;

  static const _moduleLabels = {
    'anime': ('Anime Data', Icons.video_library),
  };

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.availableModules);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            final label = _moduleLabels[m];
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
