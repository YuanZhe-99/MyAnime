import 'package:flutter/material.dart';

import '../../features/anime/models/anime.dart';
import '../../l10n/app_localizations.dart';
import '../services/auto_sync_service.dart';
import '../services/sync_merge.dart';
import '../services/webdav_service.dart';

class WebDAVConfigPage extends StatefulWidget {
  /// Purpose: Create a web davconfig page instance.
  /// Inputs: None.
  /// Returns: A new `WebDAVConfigPage` instance.
  /// Side effects: None.
  /// Notes: None.
  const WebDAVConfigPage({super.key});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<WebDAVConfigPage> createState() => _WebDAVConfigPageState();
}

class _WebDAVConfigPageState extends State<WebDAVConfigPage> {
  final _urlController = TextEditingController();
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  final _pathController = TextEditingController(text: '/MyAnime');
  bool _loading = true;
  bool _testing = false;
  bool _syncing = false;
  bool _isConfigured = false;
  bool _autoSync = false;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    AutoSyncService.instance.addOnStatusChanged(_refreshSyncStatus);
    _loadConfig();
  }

  /// Purpose: Refresh this page when background sync status changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Triggers a rebuild.
  /// Notes: Internal helper used within this file only.
  void _refreshSyncStatus() {
    if (mounted) setState(() {});
  }

  /// Purpose: Provide the internal load config helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadConfig() async {
    final config = await WebDAVService.loadConfig();
    if (config != null) {
      _urlController.text = config.serverUrl;
      _userController.text = config.username;
      _passController.text = config.password;
      _pathController.text = config.remotePath;
      _isConfigured = config.isConfigured;
      _autoSync = config.autoSync;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers, listeners, and other owned resources.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnStatusChanged(_refreshSyncStatus);
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal current config helper for this file.
  /// Inputs: `_autoSync`.
  /// Returns: `WebDAVConfig`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  WebDAVConfig get _currentConfig => WebDAVConfig(
    serverUrl: _urlController.text.trim(),
    username: _userController.text.trim(),
    password: _passController.text.trim(),
    remotePath: _pathController.text.trim(),
    autoSync: _autoSync,
  );

  /// Purpose: Provide the internal save config helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    if (config.isConfigured && config.autoSync) {
      AutoSyncService.instance.requestSyncNow();
    }
    setState(() => _isConfigured = config.isConfigured);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsWebDAVConfigSaved,
          ),
        ),
      );
    }
  }

  /// Purpose: Provide the internal test connection helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final ok = await WebDAVService.testConnection(_currentConfig);
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.settingsWebDAVConnectionSuccess
                : AppLocalizations.of(context)!.settingsWebDAVConnectionFailed,
          ),
        ),
      );
    }
  }

  /// Purpose: Provide the internal sync now helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final result = await WebDAVService.sync(_currentConfig);
    if (!mounted) return;
    AutoSyncService.instance.recordSyncResult(result);
    setState(() => _syncing = false);

    if (result.hasConflicts) {
      await _resolveConflicts(result.pending!);
      return;
    }

    final l10n = AppLocalizations.of(context)!;

    if (!result.success) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncFailed),
          content: SingleChildScrollView(child: Text(result.error ?? '-')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (result.warnings.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsWebDAVSyncSuccess),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsWebDAVSyncImageWarnings(result.warnings.length),
                ),
                const SizedBox(height: 8),
                ...result.warnings.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(w, style: Theme.of(ctx).textTheme.bodySmall),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.settingsWebDAVSyncSuccess)));
  }

  /// Purpose: Provide the internal resolve conflicts helper for this file.
  /// Inputs: `pending`.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _resolveConflicts(PendingSync pending) async {
    final resolutions = <String, Anime>{};

    for (final conflict in pending.allConflicts) {
      if (!mounted) return;
      final chosen = await showDialog<Anime>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _ConflictDialog(conflict: conflict),
      );
      if (chosen != null) {
        resolutions[conflict.id] = chosen;
      } else {
        // User cancelled — use local by default
        resolutions[conflict.id] = conflict.localRecord;
      }
    }

    final ok = await WebDAVService.finalizePendingSync(
      _currentConfig,
      pending,
      resolutions,
    );
    AutoSyncService.instance.recordFinalizeResult(ok);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? AppLocalizations.of(context)!.settingsWebDAVSyncSuccess
                : AppLocalizations.of(context)!.settingsWebDAVSyncFailed,
          ),
        ),
      );
    }
  }

  /// Purpose: Provide the internal disconnect helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _disconnect() async {
    await WebDAVService.deleteConfig();
    _urlController.clear();
    _userController.clear();
    _passController.clear();
    _pathController.text = '/MyAnime';
    setState(() {
      _isConfigured = false;
      _autoSync = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.settingsWebDAVConfigRemoved,
          ),
        ),
      );
    }
  }

  /// Purpose: Provide the internal fill nextcloud helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  void _fillNextcloud() {
    _urlController.text =
        'https://your-nextcloud-host/remote.php/dav/files/USERNAME';
    _pathController.text = '/MyAnime';
    setState(() {});
  }

  /// Purpose: Build a short sync health summary for display.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String? _syncStatusText(AppLocalizations l10n) {
    final service = AutoSyncService.instance;
    if (service.lastError != null) {
      return service.hasPendingConflicts
          ? '${l10n.settingsWebDAVAutoSyncConflict}: ${service.lastError}'
          : '${l10n.settingsWebDAVAutoSyncFailed}: ${service.lastError}';
    }
    if (service.lastSuccessAt != null) {
      return '${l10n.settingsWebDAVLastSuccess}: ${service.lastSuccessAt!.toLocal()}';
    }
    return null;
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
    final syncStatus = _syncStatusText(l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsWebDAVSync), centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _fillNextcloud,
                      icon: const Icon(Icons.cloud, size: 18),
                      label: Text(l10n.settingsWebDAVNextcloud),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVServerURL,
                    hintText: 'https://example.com/remote.php/dav/files/user',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVUsername,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVPassword,
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pathController,
                  decoration: InputDecoration(
                    labelText: l10n.settingsWebDAVRemotePath,
                    hintText: '/MyAnime',
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveConfig,
                        child: Text(l10n.save),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _testing ? null : _testConnection,
                        child: _testing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.settingsWebDAVTest),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: Text(l10n.settingsWebDAVAutoSync),
                  value: _autoSync,
                  onChanged: (v) {
                    setState(() => _autoSync = v);
                    _saveConfig();
                  },
                ),
                const SizedBox(height: 16),
                if (_isConfigured) ...[
                  if (syncStatus != null) ...[
                    Card(
                      color: AutoSyncService.instance.lastError == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : theme.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          syncStatus,
                          style: TextStyle(
                            color: AutoSyncService.instance.lastError == null
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _syncing ? null : () => _syncNow(),
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(l10n.settingsWebDAVSyncNow),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _disconnect,
                    icon: const Icon(Icons.link_off),
                    label: Text(l10n.settingsWebDAVDisconnect),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ConflictDialog extends StatelessWidget {
  final RecordConflict<Anime> conflict;

  /// Purpose: Create a conflict dialog instance.
  /// Inputs: None.
  /// Returns: A new `_ConflictDialog` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ConflictDialog({required this.conflict});

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final local = conflict.localRecord;
    final remote = conflict.remoteRecord;

    return AlertDialog(
      title: Text(l10n.syncConflictTitle(conflict.displayName)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.syncConflictDesc),
            const SizedBox(height: 16),
            Text(
              l10n.syncLocalVersion,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(l10n.syncModifiedAt('${local.modifiedAt.toLocal()}')),
            if (local.endEpisode != null)
              Text(
                l10n.syncEpisodeRange(local.startEpisode, local.endEpisode!),
              ),
            Text(
              l10n.syncWatched(
                local.episodeStatuses.values
                    .where((s) => s == EpisodeStatus.watched)
                    .length,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.syncRemoteVersion,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(l10n.syncModifiedAt('${remote.modifiedAt.toLocal()}')),
            if (remote.endEpisode != null)
              Text(
                l10n.syncEpisodeRange(remote.startEpisode, remote.endEpisode!),
              ),
            Text(
              l10n.syncWatched(
                remote.episodeStatuses.values
                    .where((s) => s == EpisodeStatus.watched)
                    .length,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(local),
          child: Text(l10n.syncKeepLocal),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(remote),
          child: Text(l10n.syncKeepRemote),
        ),
      ],
    );
  }
}
