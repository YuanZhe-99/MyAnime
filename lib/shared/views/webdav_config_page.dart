import 'package:flutter/material.dart';

import '../../features/anime/models/anime.dart';
import '../../l10n/app_localizations.dart';
import '../services/sync_merge.dart';
import '../services/webdav_service.dart';

class WebDAVConfigPage extends StatefulWidget {
  const WebDAVConfigPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

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

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    _pathController.dispose();
    super.dispose();
  }

  WebDAVConfig get _currentConfig => WebDAVConfig(
        serverUrl: _urlController.text.trim(),
        username: _userController.text.trim(),
        password: _passController.text.trim(),
        remotePath: _pathController.text.trim(),
        autoSync: _autoSync,
      );

  Future<void> _saveConfig() async {
    final config = _currentConfig;
    await WebDAVService.saveConfig(config);
    setState(() => _isConfigured = config.isConfigured);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                AppLocalizations.of(context)!.settingsWebDAVConfigSaved)),
      );
    }
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    final ok = await WebDAVService.testConnection(_currentConfig);
    if (mounted) {
      setState(() => _testing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? AppLocalizations.of(context)!.settingsWebDAVConnectionSuccess
              : AppLocalizations.of(context)!.settingsWebDAVConnectionFailed),
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final result = await WebDAVService.sync(_currentConfig);
    if (!mounted) return;
    setState(() => _syncing = false);

    if (result.hasConflicts) {
      await _resolveConflicts(result.pending!);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.success
            ? AppLocalizations.of(context)!.settingsWebDAVSyncSuccess
            : AppLocalizations.of(context)!.settingsWebDAVSyncFailed),
      ),
    );
  }

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

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? AppLocalizations.of(context)!.settingsWebDAVSyncSuccess
              : AppLocalizations.of(context)!.settingsWebDAVSyncFailed),
        ),
      );
    }
  }

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
                AppLocalizations.of(context)!.settingsWebDAVConfigRemoved)),
      );
    }
  }

  void _fillNextcloud() {
    _urlController.text =
        'https://your-nextcloud-host/remote.php/dav/files/USERNAME';
    _pathController.text = '/MyAnime';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsWebDAVSync),
        centerTitle: true,
      ),
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
                    hintText:
                        'https://example.com/remote.php/dav/files/user',
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _userController,
                  decoration:
                      InputDecoration(labelText: l10n.settingsWebDAVUsername),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passController,
                  decoration:
                      InputDecoration(labelText: l10n.settingsWebDAVPassword),
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
                                    strokeWidth: 2),
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
                  FilledButton.icon(
                    onPressed: _syncing ? null : () => _syncNow(),
                    icon: _syncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
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
                      foregroundColor:
                          Theme.of(context).colorScheme.error,
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

  const _ConflictDialog({required this.conflict});

  @override
  Widget build(BuildContext context) {
    final local = conflict.localRecord;
    final remote = conflict.remoteRecord;

    return AlertDialog(
      title: Text('Sync Conflict: ${conflict.displayName}'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This anime was modified on both devices since last sync.'),
            const SizedBox(height: 16),
            Text('Local version:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Modified: ${local.modifiedAt.toLocal()}'),
            if (local.endEpisode != null)
              Text('Episodes: ${local.startEpisode}–${local.endEpisode}'),
            Text(
                'Watched: ${local.episodeStatuses.values.where((s) => s == EpisodeStatus.watched).length}'),
            const SizedBox(height: 12),
            Text('Remote version:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Modified: ${remote.modifiedAt.toLocal()}'),
            if (remote.endEpisode != null)
              Text('Episodes: ${remote.startEpisode}–${remote.endEpisode}'),
            Text(
                'Watched: ${remote.episodeStatuses.values.where((s) => s == EpisodeStatus.watched).length}'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(local),
          child: const Text('Keep Local'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(remote),
          child: const Text('Keep Remote'),
        ),
      ],
    );
  }
}
