import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/services/image_service.dart';
import '../../../shared/utils/detail_layout.dart';
import '../models/anime.dart';
import '../services/anime_search_service.dart';
import '../services/anime_storage.dart';
import 'anime_search_dialog.dart';
import 'archive_labels.dart';

class AnimeEditPage extends StatefulWidget {
  final String? animeId;

  /// Open the online search dialog as soon as the record has loaded.
  ///
  /// Set by the update-review screen for a record the background service found
  /// candidates for but could not choose between, so the user lands directly on
  /// the search results instead of hunting for the button.
  final bool autoSearch;

  /// Purpose: Create a anime edit page instance.
  /// Inputs: `key`, `animeId`, `autoSearch`.
  /// Returns: A new `AnimeEditPage` instance.
  /// Side effects: None.
  /// Notes: `autoSearch` is ignored without an `animeId`, since there would be
  /// no title to search with.
  const AnimeEditPage({super.key, this.animeId, this.autoSearch = false});

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
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
  final _infoUrlController = TextEditingController();
  final _ratingOverallController = TextEditingController();
  final _ratingVisualController = TextEditingController();
  final _ratingStoryController = TextEditingController();
  final _ratingCharacterController = TextEditingController();
  final _ratingMusicController = TextEditingController();
  final _ratingEnjoymentController = TextEditingController();
  final _archiveCopiesController = TextEditingController();
  final _archiveLocationController = TextEditingController();

  int? _airDayOfWeek;
  DateTime? _firstAirDate;
  AnimeType? _manualType;
  String? _coverImage;
  bool _archived = false;
  ArchiveSource? _archiveSource;
  ArchiveResolution? _archiveResolution;

  bool _isEdit = false;
  bool _autoSearched = false;
  Anime? _existing;

  /// Public metadata pulled from external databases. Edited only by applying a
  /// search result, never typed by hand, so it has no form controller.
  AnimeExternalMeta? _externalMeta;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    // Default season: Season 1
    _seasonController.text = 'Season 1';

    if (widget.animeId != null) {
      _loadExisting();
    }
  }

  /// Purpose: Provide the internal load existing helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _loadExisting() async {
    final data = await AnimeStorage.load();
    final found = data.animeList
        .where((a) => a.id == widget.animeId)
        .firstOrNull;
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
        _infoUrlController.text = found.infoUrl ?? '';
        _ratingOverallController.text = _formatScore(found.rating?.overall);
        _ratingVisualController.text = _formatScore(found.rating?.visual);
        _ratingStoryController.text = _formatScore(found.rating?.story);
        _ratingCharacterController.text = _formatScore(found.rating?.character);
        _ratingMusicController.text = _formatScore(found.rating?.music);
        _ratingEnjoymentController.text = _formatScore(found.rating?.enjoyment);
        _airDayOfWeek = found.airDayOfWeek;
        _firstAirDate = found.firstAirDate;
        _manualType = found.manualType;
        _coverImage = found.coverImage;
        _archived = found.localArchive?.archived ?? false;
        _archiveSource = found.localArchive?.source;
        _archiveResolution = found.localArchive?.resolution;
        _archiveCopiesController.text =
            found.localArchive?.copies?.toString() ?? '';
        _archiveLocationController.text = found.localArchive?.location ?? '';
        _externalMeta = found.externalMeta;
      });
      // Opened from the update-review screen: go straight to the search, now
      // that the title fields are filled in and can seed the query. Guarded so
      // a later reload cannot reopen the dialog behind the user's back.
      if (widget.autoSearch && !_autoSearched) {
        _autoSearched = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSearchDialog();
        });
      }
    }
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers, listeners, and other owned resources.
  /// Notes: Flutter lifecycle override.
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
    _infoUrlController.dispose();
    _ratingOverallController.dispose();
    _ratingVisualController.dispose();
    _ratingStoryController.dispose();
    _ratingCharacterController.dispose();
    _ratingMusicController.dispose();
    _ratingEnjoymentController.dispose();
    _archiveCopiesController.dispose();
    _archiveLocationController.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal pick cover image helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Future<void> _pickCoverImage() async {
    final path = await ImageService.pickAndSaveImage();
    if (path != null && mounted) {
      setState(() => _coverImage = path);
    }
  }

  /// Purpose: Provide the internal search watch url helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.searchWatchUrlSet)));
    }
  }

  /// Purpose: Provide the internal show search dialog helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
  Future<void> _showSearchDialog() async {
    final query = _titleController.text.isNotEmpty
        ? _titleController.text
        : _titleJaController.text;
    final result = await showAnimeSearchDialog(
      context,
      initialQuery: query,
      currentTitle: _titleController.text.isEmpty
          ? null
          : _titleController.text,
      currentTitleJa: _titleJaController.text.isEmpty
          ? null
          : _titleJaController.text,
      currentEndEp: int.tryParse(_endEpController.text),
      currentFirstAirDate: _firstAirDate,
      currentAirDay: _airDayOfWeek,
      currentAirTime: _airTimeController.text.isEmpty
          ? null
          : _airTimeController.text,
      currentCoverImage: _coverImage,
      currentNotes: _notesController.text.isEmpty
          ? null
          : _notesController.text,
      currentExternalMeta: _externalMeta,
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
        if (result.containsKey('infoUrl')) {
          _infoUrlController.text = result['infoUrl'] as String;
        }
        if (result.containsKey('externalMeta')) {
          _externalMeta = result['externalMeta'] as AnimeExternalMeta;
        }
      });
    }
  }

  /// Purpose: Provide the internal pick first air date helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Provide the internal save helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Internal helper used within this file only.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate key fields for new anime
    if (!_isEdit) {
      final l10n = AppLocalizations.of(context)!;
      final missing = <String>[];
      final hasTitle = _titleController.text.trim().isNotEmpty;
      final hasTitleJa = _titleJaController.text.trim().isNotEmpty;
      if (!hasTitle && !hasTitleJa) {
        missing.add(l10n.animeTitle);
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
    final rating = _buildRating();
    final localArchive = _buildLocalArchive();

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
        infoUrl: _infoUrlController.text.trim().isEmpty
            ? null
            : _infoUrlController.text.trim(),
        watchUrl: _watchUrlController.text.trim().isEmpty
            ? null
            : _watchUrlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        rating: rating,
        clearRating: rating == null,
        localArchive: localArchive,
        clearLocalArchive: localArchive == null,
        externalMeta: _externalMeta,
        clearExternalMeta: _externalMeta == null,
        modifiedAt: DateTime.now().toUtc(),
      );
      await AnimeStorage.addOrUpdate(updated);
    } else {
      // Auto-fill title from titleJa if title is empty
      final title = _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : _titleJaController.text.trim();
      final anime = Anime.create(
        title: title,
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
        infoUrl: _infoUrlController.text.trim().isEmpty
            ? null
            : _infoUrlController.text.trim(),
        watchUrl: _watchUrlController.text.trim().isEmpty
            ? null
            : _watchUrlController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        rating: rating,
        localArchive: localArchive,
        externalMeta: _externalMeta,
      );
      await AnimeStorage.addOrUpdate(anime);
      if (mounted) context.pop(anime.id);
      return;
    }

    if (mounted) context.pop();
  }

  /// Purpose: Provide the internal build rating helper for this file.
  /// Inputs: None.
  /// Returns: `AnimeRating?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  AnimeRating? _buildRating() {
    final rating = AnimeRating(
      overall: _parseScore(_ratingOverallController),
      visual: _parseScore(_ratingVisualController),
      story: _parseScore(_ratingStoryController),
      character: _parseScore(_ratingCharacterController),
      music: _parseScore(_ratingMusicController),
      enjoyment: _parseScore(_ratingEnjoymentController),
      extraJson: _existing?.rating?.extraJson ?? const {},
    );
    return rating.hasAnyData ? rating : null;
  }

  /// Purpose: Provide the internal build local archive helper for this file.
  /// Inputs: None.
  /// Returns: `AnimeLocalArchive?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only. Returns null when the
  /// section was left untouched, so an anime without archive data never gains
  /// a `localArchive` key on disk.
  AnimeLocalArchive? _buildLocalArchive() {
    final location = _archiveLocationController.text.trim();
    final archive = AnimeLocalArchive(
      archived: _archived,
      source: _archiveSource,
      resolution: _archiveResolution,
      copies: int.tryParse(_archiveCopiesController.text.trim()),
      location: location.isEmpty ? null : location,
      extraJson: _existing?.localArchive?.extraJson ?? const {},
    );
    return archive.hasAnyData ? archive : null;
  }

  /// Purpose: Provide the internal parse score helper for this file.
  /// Inputs: `controller`.
  /// Returns: `double?`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  double? _parseScore(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  /// Purpose: Provide the internal format score helper for this file.
  /// Inputs: `score`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _formatScore(double? score) {
    if (score == null) return '';
    if (score == score.roundToDouble()) return score.toInt().toString();
    return score.toStringAsFixed(1);
  }

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
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
          TextButton(onPressed: _save, child: Text(l10n.save)),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screen = MediaQuery.sizeOf(context);
            final titleFields = _buildTitleFields(l10n);
            final detailFields = _buildDetailFields(l10n);

            if (!useDetailTwoPane(screen.width, screen.height)) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildCoverPicker(width: 120, height: 170),
                  const SizedBox(height: 16),
                  ...titleFields,
                  const SizedBox(height: 12),
                  ...detailFields,
                ],
              );
            }

            final paneWidth = detailLeftPaneWidth(constraints.maxWidth);
            final cover = editCoverSize(paneWidth, constraints.maxHeight);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: paneWidth,
                  child: LayoutBuilder(
                    builder: (context, paneConstraints) =>
                        SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: paneConstraints.maxHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCoverPicker(
                                    width: cover.width,
                                    height: cover.height,
                                  ),
                                  const SizedBox(height: 16),
                                  ...titleFields,
                                ],
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: detailFields,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Purpose: Build the cover picker at an explicit size.
  /// Inputs: `width`, `height` — the picker box in logical pixels.
  /// Returns: `Widget`.
  /// Side effects: Reads the cover file through `ImageService.resolve`; tapping
  /// opens the image picker.
  /// Notes: The size is a parameter because the two-pane layout sizes the
  /// picker from the height its left pane has left over, while the
  /// single-column layout keeps the original fixed 120x170 box. Mirrors
  /// `anime_detail_page._buildCover`.
  Widget _buildCoverPicker({required double width, required double height}) {
    return Center(
      child: GestureDetector(
        onTap: _pickCoverImage,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          child: Image.file(
                            file,
                            fit: BoxFit.cover,
                            width: width,
                            height: height,
                          ),
                        );
                      }
                    }
                    return const Icon(Icons.add_photo_alternate, size: 40);
                  },
                )
              : const Icon(Icons.add_photo_alternate, size: 40),
        ),
      ),
    );
  }

  /// Purpose: Build the two title fields that share the left pane with the cover.
  /// Inputs: `l10n`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: Separate from [_buildDetailFields] because the two-pane layout puts
  /// exactly these beside the cover and everything else in the scrolling pane.
  /// The title's validator accepts an empty value when the Japanese title is
  /// filled in, so the two have to stay together wherever they render.
  List<Widget> _buildTitleFields(AppLocalizations l10n) {
    return [
      // Title
      TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          labelText: l10n.animeTitle,
          border: const OutlineInputBorder(),
        ),
        validator: (v) {
          if (v != null && v.trim().isNotEmpty) return null;
          // Allow empty title if Japanese title is provided
          if (_titleJaController.text.trim().isNotEmpty) return null;
          return l10n.animeFieldRequired;
        },
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
    ];
  }

  /// Purpose: Build every form field below the two titles.
  /// Inputs: `l10n`.
  /// Returns: `List<Widget>`.
  /// Side effects: None.
  /// Notes: These are the scrolling pane's children in the two-pane layout and
  /// the tail of the single `ListView` otherwise. Both panes stay inside the one
  /// `Form`, so `_save`'s `validate()` still reaches the season field from here
  /// and the title field from [_buildTitleFields].
  List<Widget> _buildDetailFields(AppLocalizations l10n) {
    return [
      // Season
      TextFormField(
        controller: _seasonController,
        decoration: InputDecoration(
          labelText: l10n.animeSeason,
          hintText: l10n.animeSeasonHint,
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
          ...AnimeType.values.map(
            (t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t, l10n))),
          ),
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
            DropdownMenuItem(value: i, child: Text(_dayName(i))),
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
        subtitle: Text(
          _firstAirDate != null
              ? DateFormat.yMMMd().format(_firstAirDate!)
              : '-',
        ),
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
                onPressed: () => setState(() => _firstAirDate = null),
              ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Info URL
      TextFormField(
        controller: _infoUrlController,
        decoration: InputDecoration(
          labelText: l10n.animeInfoUrl,
          hintText: 'https://',
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.info_outline),
        ),
        keyboardType: TextInputType.url,
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
      Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: Text(l10n.animeRating),
          subtitle: Text(l10n.animeRatingAutoHint),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _buildRatingField(
              controller: _ratingOverallController,
              label: l10n.animeRatingOverall,
              helperText: l10n.animeRatingOverallHelper,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRatingField(
                    controller: _ratingVisualController,
                    label: l10n.animeRatingVisual,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRatingField(
                    controller: _ratingStoryController,
                    label: l10n.animeRatingStory,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildRatingField(
                    controller: _ratingCharacterController,
                    label: l10n.animeRatingCharacter,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildRatingField(
                    controller: _ratingMusicController,
                    label: l10n.animeRatingMusic,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildRatingField(
              controller: _ratingEnjoymentController,
              label: l10n.animeRatingEnjoyment,
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),

      // Local archive
      Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          title: Text(l10n.animeLocalArchive),
          subtitle: Text(l10n.animeLocalArchiveHint),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.animeLocalArchiveArchived),
              value: _archived,
              onChanged: (v) => setState(() => _archived = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ArchiveSource?>(
                    initialValue: _archiveSource,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.animeArchiveSource,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<ArchiveSource?>(
                        value: null,
                        child: Text('-'),
                      ),
                      ...ArchiveSource.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(archiveSourceLabel(s, l10n)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _archiveSource = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ArchiveResolution?>(
                    initialValue: _archiveResolution,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.animeArchiveResolution,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<ArchiveResolution?>(
                        value: null,
                        child: Text('-'),
                      ),
                      ...ArchiveResolution.values.map(
                        (r) => DropdownMenuItem(
                          value: r,
                          child: Text(archiveResolutionLabel(r, l10n)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _archiveResolution = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _archiveCopiesController,
                    decoration: InputDecoration(
                      labelText: l10n.animeArchiveCopies,
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final copies = int.tryParse(text);
                      if (copies == null || copies < 1) {
                        return l10n.animeArchiveCopiesInvalid;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _archiveLocationController,
                    decoration: InputDecoration(
                      labelText: l10n.animeArchiveLocation,
                      hintText: l10n.animeArchiveLocationHint,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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
    ];
  }

  /// Purpose: Provide the internal build rating field helper for this file.
  /// Inputs: `controller`, `label`, `helperText`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _buildRatingField({
    required TextEditingController controller,
    required String label,
    String? helperText,
  }) {
    final l10n = AppLocalizations.of(context)!;
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        suffixText: '/ 10',
        border: const OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return null;
        final score = double.tryParse(text);
        if (score == null || score < 0 || score > 10) {
          return l10n.animeRatingInvalid;
        }
        return null;
      },
    );
  }

  /// Purpose: Provide the internal day name helper for this file.
  /// Inputs: `dow`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  String _dayName(int dow) {
    final l10n = AppLocalizations.of(context)!;
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
    return days[dow.clamp(1, 7)];
  }

  /// Purpose: Provide the internal type label helper for this file.
  /// Inputs: `type`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Create a watch url search dialog instance.
  /// Inputs: `query`, `altQueries`.
  /// Returns: A new `_WatchUrlSearchDialog` instance.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _WatchUrlSearchDialog({
    required this.query,
    this.altQueries = const [],
  });

  /// Purpose: Create the mutable state object for this widget.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<_WatchUrlSearchDialog> createState() => _WatchUrlSearchDialogState();
}

class _WatchUrlSearchDialogState extends State<_WatchUrlSearchDialog> {
  late final TextEditingController _controller;
  List<({String title, String url})> _results = [];
  bool _loading = false;
  String? _error;

  /// Purpose: Initialize listeners, controllers, and first-load work for this state object.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Initializes owned state, listeners, or async work.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _search();
  }

  /// Purpose: Release listeners, controllers, and other owned resources.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes controllers, listeners, and other owned resources.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Purpose: Provide the internal search helper for this file.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May perform network or file-system operations.
  /// Notes: Internal helper used within this file only.
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

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.play_circle_outline, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.searchWatchUrlTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
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
                        horizontal: 12,
                        vertical: 10,
                      ),
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

  /// Purpose: Provide the internal build body helper for this file.
  /// Inputs: None.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
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
