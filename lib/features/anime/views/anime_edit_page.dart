import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../models/anime.dart';
import '../services/anime_search_service.dart';
import '../services/anime_storage.dart';
import 'anime_search_dialog.dart';

class AnimeEditPage extends StatefulWidget {
  final String? animeId;
  const AnimeEditPage({super.key, this.animeId});

  @override
  State<AnimeEditPage> createState() => _AnimeEditPageState();
}

class _AnimeEditPageState extends State<AnimeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleJaController = TextEditingController();
  final _seasonController = TextEditingController();
  final _startEpController = TextEditingController(text: '1');
  final _endEpController = TextEditingController(text: '12');
  final _airTimeController = TextEditingController();
  final _notesController = TextEditingController();
  final _watchUrlController = TextEditingController();

  int? _airDayOfWeek;
  DateTime? _firstAirDate;
  AnimeType? _manualType;
  String? _coverImage;

  bool _isEdit = false;
  Anime? _existing;

  @override
  void initState() {
    super.initState();
    // Default season: Season 1
    _seasonController.text = 'Season 1';

    if (widget.animeId != null) {
      _loadExisting();
    }
  }

  Future<void> _loadExisting() async {
    final data = await AnimeStorage.load();
    final found =
        data.animeList.where((a) => a.id == widget.animeId).firstOrNull;
    if (found != null && mounted) {
      setState(() {
        _isEdit = true;
        _existing = found;
        _titleController.text = found.title ?? '';
        _titleJaController.text = found.titleJa ?? '';
        _seasonController.text = found.season;
        _startEpController.text = found.startEpisode.toString();
        _endEpController.text = found.endEpisode.toString();
        _airTimeController.text = found.airTime ?? '';
        _notesController.text = found.notes ?? '';
        _watchUrlController.text = found.watchUrl ?? '';
        _airDayOfWeek = found.airDayOfWeek;
        _firstAirDate = found.firstAirDate;
        _manualType = found.manualType;
        _coverImage = found.coverImage;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleJaController.dispose();
    _seasonController.dispose();
    _startEpController.dispose();
    _endEpController.dispose();
    _airTimeController.dispose();
    _notesController.dispose();
    _watchUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final path = await ImageService.pickAndSaveImage();
    if (path != null && mounted) {
      setState(() => _coverImage = path);
    }
  }

  Future<void> _searchWatchUrl() async {
    final title = _titleController.text.trim();
    final titleJa = _titleJaController.text.trim();
    final query = title.isNotEmpty ? title : titleJa;
    if (query.isEmpty) return;
    final l10n = AppLocalizations.of(context)!;

    final selectedUrl = await showDialog<String>(
      context: context,
      builder: (_) => _WatchUrlSearchDialog(
        query: query,
        altQueries: [
          if (title.isNotEmpty && titleJa.isNotEmpty) titleJa,
          if (title.isEmpty && titleJa.isNotEmpty) title,
        ],
      ),
    );
    if (selectedUrl != null && mounted) {
      setState(() => _watchUrlController.text = selectedUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.searchWatchUrlSet)),
      );
    }
  }

  Future<void> _showSearchDialog() async {
    final query = _titleController.text.isNotEmpty
        ? _titleController.text
        : _titleJaController.text;
    final result = await showAnimeSearchDialog(
      context,
      initialQuery: query,
      currentTitle:
          _titleController.text.isEmpty ? null : _titleController.text,
      currentTitleJa:
          _titleJaController.text.isEmpty ? null : _titleJaController.text,
      currentEndEp: int.tryParse(_endEpController.text),
      currentFirstAirDate: _firstAirDate,
      currentAirDay: _airDayOfWeek,
      currentAirTime:
          _airTimeController.text.isEmpty ? null : _airTimeController.text,
      currentCoverImage: _coverImage,
      currentNotes:
          _notesController.text.isEmpty ? null : _notesController.text,
    );
    if (result != null && mounted) {
      setState(() {
        if (result.containsKey('title')) {
          _titleController.text = result['title'] as String;
        }
        if (result.containsKey('titleJa')) {
          _titleJaController.text = result['titleJa'] as String;
        }
        if (result.containsKey('endEpisode')) {
          _endEpController.text = (result['endEpisode'] as int).toString();
        }
        if (result.containsKey('firstAirDate')) {
          _firstAirDate = result['firstAirDate'] as DateTime;
        }
        if (result.containsKey('airDayOfWeek')) {
          _airDayOfWeek = result['airDayOfWeek'] as int;
        }
        if (result.containsKey('airTime')) {
          _airTimeController.text = result['airTime'] as String;
        }
        if (result.containsKey('notes')) {
          _notesController.text = result['notes'] as String;
        }
        if (result.containsKey('coverImage')) {
          _coverImage = result['coverImage'] as String;
        }
      });
    }
  }

  Future<void> _pickFirstAirDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _firstAirDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
    if (date != null && mounted) {
      setState(() => _firstAirDate = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate key fields for new anime
    if (!_isEdit) {
      final l10n = AppLocalizations.of(context)!;
      final missing = <String>[];
      if (_titleController.text.trim().isEmpty &&
          _titleJaController.text.trim().isEmpty) {
        missing.add(l10n.animeTitle);
      }
      if (_firstAirDate == null) {
        missing.add(l10n.animeFirstAirDate);
      }
      if (missing.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.animeFieldRequired),
            content: Text(l10n.animeMissingFields(missing.join(', '))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.settingsConfirm),
              ),
            ],
          ),
        );
        return;
      }
    }

    final startEp = int.tryParse(_startEpController.text) ?? 1;
    var endEp = int.tryParse(_endEpController.text) ?? 12;

    // If startEpisode > endEpisode, adjust endEpisode to preserve episode count.
    if (startEp > endEp) {
      final originalEnd = _isEdit && _existing != null
          ? (_existing!.endEpisode ?? endEp)
          : endEp;
      endEp = originalEnd - 1 + startEp;
    }

    if (_isEdit && _existing != null) {
      final updated = _existing!.copyWith(
        title: _titleController.text.trim(),
        titleJa: _titleJaController.text.trim().isEmpty
            ? null
            : _titleJaController.text.trim(),
        season: _seasonController.text.trim(),
        startEpisode: startEp,
        endEpisode: endEp,
        manualType: _manualType,
        airDayOfWeek: _airDayOfWeek,
        airTime: _airTimeController.text.trim().isEmpty
            ? null
            : _airTimeController.text.trim(),
        firstAirDate: _firstAirDate,
        coverImage: _coverImage,
        watchUrl: _watchUrlController.text.trim().isEmpty
            ? null
            : _watchUrlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        modifiedAt: DateTime.now().toUtc(),
      );
      await AnimeStorage.addOrUpdate(updated);
    } else {
      final anime = Anime.create(
        title: _titleController.text.trim(),
        titleJa: _titleJaController.text.trim().isEmpty
            ? null
            : _titleJaController.text.trim(),
        season: _seasonController.text.trim(),
        startEpisode: startEp,
        endEpisode: endEp,
        manualType: _manualType,
        airDayOfWeek: _airDayOfWeek,
        airTime: _airTimeController.text.trim().isEmpty
            ? null
            : _airTimeController.text.trim(),
        firstAirDate: _firstAirDate,
        coverImage: _coverImage,
        watchUrl: _watchUrlController.text.trim().isEmpty
            ? null
            : _watchUrlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      await AnimeStorage.addOrUpdate(anime);
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.animeEdit : l10n.animeAdd),
        actions: [
          if (AppFlavor.isFull)
            IconButton(
              icon: const Icon(Icons.travel_explore),
              tooltip: l10n.searchAnimeInfo,
              onPressed: _showSearchDialog,
            ),
          TextButton(
            onPressed: _save,
            child: Text(l10n.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Cover image
            Center(
              child: GestureDetector(
                onTap: _pickCoverImage,
                child: Container(
                  width: 120,
                  height: 170,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _coverImage != null
                      ? FutureBuilder<dynamic>(
                          future: ImageService.resolve(_coverImage!),
                          builder: (context, snap) {
                            if (snap.hasData) {
                              final file = snap.data!;
                              if (file.existsSync()) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(file,
                                      fit: BoxFit.cover,
                                      width: 120,
                                      height: 170),
                                );
                              }
                            }
                            return const Icon(Icons.add_photo_alternate,
                                size: 40);
                          },
                        )
                      : const Icon(Icons.add_photo_alternate, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.animeTitle,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.animeFieldRequired : null,
            ),
            const SizedBox(height: 12),

            // Japanese title
            TextFormField(
              controller: _titleJaController,
              decoration: InputDecoration(
                labelText: l10n.animeTitleJa,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Season
            TextFormField(
              controller: _seasonController,
              decoration: InputDecoration(
                labelText: l10n.animeSeason,
                hintText: 'Season 1',
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.animeFieldRequired : null,
            ),
            const SizedBox(height: 12),

            // Episode range
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _startEpController,
                    decoration: InputDecoration(
                      labelText: l10n.animeStartEp,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _endEpController,
                    decoration: InputDecoration(
                      labelText: l10n.animeEndEp,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type override
            DropdownButtonFormField<AnimeType?>(
              initialValue: _manualType,
              decoration: InputDecoration(
                labelText: l10n.animeType,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<AnimeType?>(
                  value: null,
                  child: Text(l10n.animeTypeAuto),
                ),
                ...AnimeType.values.map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(_typeLabel(t, l10n)),
                    )),
              ],
              onChanged: (v) => setState(() => _manualType = v),
            ),
            const SizedBox(height: 12),

            // Air day of week
            DropdownButtonFormField<int?>(
              initialValue: _airDayOfWeek,
              decoration: InputDecoration(
                labelText: l10n.animeAirDay,
                border: const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('-')),
                for (var i = 1; i <= 7; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(_dayName(i)),
                  ),
              ],
              onChanged: (v) => setState(() => _airDayOfWeek = v),
            ),
            const SizedBox(height: 12),

            // Air time (supports 25:00 format)
            TextFormField(
              controller: _airTimeController,
              decoration: InputDecoration(
                labelText: l10n.animeAirTime,
                hintText: '23:30',
                helperText: l10n.animeAirTimeHelper,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // First air date
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.animeFirstAirDate),
              subtitle: Text(_firstAirDate != null
                  ? DateFormat.yMMMd().format(_firstAirDate!)
                  : '-'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickFirstAirDate,
                  ),
                  if (_firstAirDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _firstAirDate = null),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Watch URL
            TextFormField(
              controller: _watchUrlController,
              decoration: InputDecoration(
                labelText: l10n.animeWatchUrl,
                hintText: 'https://',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
                suffixIcon: AppFlavor.isFull
                    ? IconButton(
                        icon: const Icon(Icons.search),
                        tooltip: l10n.searchWatchUrl,
                        onPressed: _searchWatchUrl,
                      )
                    : null,
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Notes
            TextFormField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: l10n.animeNotes,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _dayName(int dow) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[dow.clamp(1, 7)];
  }

  String _typeLabel(AnimeType type, AppLocalizations l10n) {
    switch (type) {
      case AnimeType.singleCour:
        return l10n.animeTypeSingleCour;
      case AnimeType.halfYear:
        return l10n.animeTypeHalfYear;
      case AnimeType.fullYear:
        return l10n.animeTypeFullYear;
      case AnimeType.longRunning:
        return l10n.animeTypeLongRunning;
      case AnimeType.allAtOnce:
        return l10n.animeTypeAllAtOnce;
    }
  }
}

/// Dialog for searching watch URLs on anime1.me.
class _WatchUrlSearchDialog extends StatefulWidget {
  final String query;
  final List<String> altQueries;
  const _WatchUrlSearchDialog({required this.query, this.altQueries = const []});

  @override
  State<_WatchUrlSearchDialog> createState() => _WatchUrlSearchDialogState();
}

class _WatchUrlSearchDialogState extends State<_WatchUrlSearchDialog> {
  late final TextEditingController _controller;
  List<({String title, String url})> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      final results = await AnimeSearchService.searchAnime1(
        q,
        altQueries: widget.altQueries,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) {
          _error = AppLocalizations.of(context)!.searchWatchUrlEmpty;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.play_circle_outline, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.searchWatchUrlTitle,
              style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: 360,
        height: 340,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: l10n.searchHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: Text(l10n.searchButton),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_results.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = _results[i];
        return ListTile(
          leading: const Icon(Icons.play_circle_outline, size: 20),
          title: Text(r.title, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            r.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          dense: true,
          onTap: () => Navigator.of(context).pop(r.url),
        );
      },
    );
  }
}
