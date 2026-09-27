import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/flavor.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';
import '../../../shared/utils/detail_layout.dart';
import '../../../shared/utils/playback_time.dart';
import '../../../shared/widgets/adaptive_tile_grid.dart';
import '../models/anime.dart';
import '../models/anime_episode.dart';
import '../models/playback_progress.dart';
import '../services/anime_episode_service.dart';
import '../services/anime_storage.dart';
import '../services/playback_progress_store.dart';
import 'anime_player_page.dart';

/// Purpose: Open a mapped episode or the shared correction screen.
/// Inputs: Record, optional local episode, and whether to edit instead of playing.
/// Returns: Completion when the viewing route closes.
/// Side effects: Navigation or external URL opening.
/// Notes: Store builds and other providers retain their original external behavior.
Future<void> openAnimeWatch(
  BuildContext context,
  Anime anime, {
  int? episode,
  bool edit = false,
}) async {
  final url = anime.watchUrl;
  if (url == null) return;
  if (!AppFlavor.isFull || !AnimeEpisodeService.isPageUrl(url.trim())) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AnimeEpisodeLinksPage(
        animeId: anime.id,
        episode: episode,
        edit: edit,
      ),
    ),
  );
}

class AnimeEpisodeLinksPage extends StatefulWidget {
  final String animeId;
  final int? episode;
  final bool edit;

  /// Purpose: Present a source-bound episode directory and season corrections.
  /// Inputs: Anime id, optional episode requested, edit mode.
  /// Returns: Directory route.
  /// Side effects: None until mounted.
  /// Notes: Uses fresh storage instead of a possibly stale page snapshot.
  const AnimeEpisodeLinksPage({
    super.key,
    required this.animeId,
    this.episode,
    this.edit = false,
  });

  /// Purpose: Create directory state.
  /// Inputs: None.
  /// Returns: State.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<AnimeEpisodeLinksPage> createState() => _AnimeEpisodePageState();
}

class _AnimeEpisodePageState extends State<AnimeEpisodeLinksPage> {
  Anime? _anime;
  List<Anime> _library = [];
  bool _busy = true;
  bool _failed = false;
  bool _sourceChanged = false;
  bool _invalidRange = false;
  bool _dirty = false;
  String? _source;
  String? _group;
  final _first = TextEditingController();
  final _last = TextEditingController();
  Map<int, String> _overrides = {};
  PlaybackProgressData _progress = PlaybackProgressData();

  /// Purpose: Load directory and attempt the requested mapped episode.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Starts loading only in full builds.
  /// Notes: Explicit gate covers direct construction as well as the common entry point.
  @override
  void initState() {
    super.initState();
    if (AppFlavor.isFull) {
      _load(initial: true);
    } else {
      _busy = false;
    }
  }

  /// Purpose: Release form controllers.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Controller disposal.
  /// Notes: None.
  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  /// Purpose: Materialize the unsaved correction preview.
  /// Inputs: None.
  /// Returns: Source-bound manual configuration.
  /// Side effects: None.
  /// Notes: Unknown saved fields are preserved.
  AnimeEpisodeMapping _choices() => AnimeEpisodeMapping(
    sourceUrl: _source!,
    group: _group,
    first: int.tryParse(_first.text),
    last: int.tryParse(_last.text),
    overrides: _overrides,
    extraJson: _anime?.episodeMapping?.extraJson ?? const {},
  );

  /// Purpose: Load or refresh a directory without overwriting user fields.
  /// Inputs: Whether to force a fetch and attempt the initial requested playback.
  /// Returns: Completion.
  /// Side effects: Reads storage, fetches public metadata and patches its cache.
  /// Notes: Rechecks the source on write and rereads storage before rendering.
  Future<void> _load({bool force = false, bool initial = false}) async {
    if (!AppFlavor.isFull) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      var data = await AnimeStorage.load();
      var anime = data.animes.where((a) => a.id == widget.animeId).firstOrNull;
      if (anime == null || anime.watchUrl == null) {
        throw StateError('Missing source');
      }
      final source = anime.watchUrl!.trim();
      if (_source != null && _source != source) {
        if (mounted) setState(() => _sourceChanged = true);
        return;
      }
      _source = source;
      {
        _failed = !await AnimeEpisodeService.ensure(anime, force: force);
        data = await AnimeStorage.load();
        anime = data.animes.where((a) => a.id == widget.animeId).firstOrNull;
        if (anime == null || anime.watchUrl?.trim() != source) {
          if (mounted) setState(() => _sourceChanged = true);
          return;
        }
      }
      final progress = await PlaybackProgressStore.load();
      if (!mounted) return;
      _anime = anime;
      _library = data.animes;
      _progress = progress;
      if (!_dirty) {
        final saved = anime.episodeMapping?.sourceUrl == source
            ? anime.episodeMapping
            : null;
        _group = saved?.group;
        _first.text = saved?.first?.toString() ?? '';
        _last.text = saved?.last?.toString() ?? '';
        _overrides = Map.of(saved?.overrides ?? {});
      }
      setState(() {});
      if (initial && !widget.edit) {
        final resolution = AnimeEpisodeService.resolve(
          anime,
          library: _library,
        );
        final target =
            widget.episode ??
            _continueTarget(anime, resolution.links.keys) ??
            _firstUnwatched(anime, resolution.links.keys);
        final page = resolution.links[target];
        if (page != null) await _play(page, episode: target);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Purpose: Choose the first eligible local episode without skipping missing links.
  /// Inputs: Anime and known mapped local episode numbers.
  /// Returns: First unwatched number, or null for a finished record.
  /// Side effects: None.
  /// Notes: An unknown end uses the highest known mapped episode.
  int? _firstUnwatched(Anime anime, Iterable<int> known) {
    final end =
        anime.endEpisode ??
        known.fold<int>(anime.startEpisode, (a, b) => a > b ? a : b);
    for (var n = anime.startEpisode; n <= end; n++) {
      if ((anime.episodeStatuses[n] ?? EpisodeStatus.unwatched) ==
          EpisodeStatus.unwatched) {
        return n;
      }
    }
    return null;
  }

  /// Purpose: Pick the episode whose playback stopped part-way most recently.
  /// Inputs: Anime and known mapped local episode numbers.
  /// Returns: Local episode number, or null when none is in progress.
  /// Side effects: None.
  /// Notes: 1.6.5. Only numbered, mapped, not-yet-watched episodes qualify,
  /// so the auto-play target continues where the user stopped before falling
  /// back to the first unwatched episode.
  int? _continueTarget(Anime anime, Iterable<int> known) {
    final mapped = known.toSet();
    PlaybackProgressEntry? best;
    for (final e in _progress.entries.values) {
      final n = e.episode;
      if (e.animeId != anime.id || n == null || !mapped.contains(n)) continue;
      if (anime.episodeStatuses[n] == EpisodeStatus.watched) continue;
      if (best == null || e.updatedAt.isAfter(best.updatedAt)) best = e;
    }
    return best?.episode;
  }

  /// Purpose: Save only the user's corrections against the latest record.
  /// Inputs: Whether to clear corrections entirely.
  /// Returns: Completion.
  /// Side effects: Writes user metadata with a fresh modifiedAt timestamp.
  /// Notes: Source changes prevent saving a stale editor into a different collection.
  Future<void> _save({bool reset = false}) async {
    final first = int.tryParse(_first.text);
    final last = int.tryParse(_last.text);
    if (!reset &&
        ((_first.text.isNotEmpty && (first == null || first < 1)) ||
            (_last.text.isNotEmpty &&
                (last == null || last < 1 || first == null || last < first)))) {
      setState(() => _invalidRange = true);
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await AnimeStorage.load();
      final anime = data.animes
          .where((a) => a.id == widget.animeId)
          .firstOrNull;
      if (anime == null || anime.watchUrl?.trim() != _source) {
        if (mounted) setState(() => _sourceChanged = true);
        return;
      }
      await AnimeStorage.addOrUpdate(
        anime.copyWith(
          episodeMapping: reset ? null : _choices(),
          clearEpisodeMapping: reset,
        ),
      );
      _dirty = false;
      if (mounted) await _load();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Purpose: Let the user assign any real page to one local episode.
  /// Inputs: Local episode number and public directory.
  /// Returns: Completion.
  /// Side effects: Changes the unsaved mapping preview.
  /// Notes: Page addresses distinguish duplicate titles; save commits choices and cancel keeps the current value.
  Future<void> _choose(int episode, AnimeEpisodeCatalog catalog) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.episodeChoose),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'auto'),
            child: Text(l10n.episodeNoOverride),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l10n.episodeLeaveUnmapped),
          ),
          for (final p in catalog.pages)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, p.url),
              child: Text('${p.title}\n${p.url}'),
            ),
        ],
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (selected == 'auto') {
        _overrides.remove(episode);
      } else {
        _overrides[episode] = selected;
      }
      _dirty = true;
    });
  }

  /// Purpose: Open one real episode in the in-app player.
  /// Inputs: Public episode descriptor; `episode` — its local number, null
  /// for extras.
  /// Returns: Completion when playback closes.
  /// Side effects: Pushes the player route, then reloads playback progress.
  /// Notes: Only resolved links enter the regular playlist; extras can still
  /// be selected directly. Since 1.6.5 the player records a resume point and
  /// marks a numbered episode watched past 95%.
  Future<void> _play(AnimeEpisodePage page, {int? episode}) async {
    final resolution = AnimeEpisodeService.resolve(
      _anime!,
      choices: _choices(),
      library: _library,
    );
    final entries = resolution.links.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnimePlayerPage(
          page: page,
          animeId: widget.animeId,
          episode: episode,
          playlist: {
            for (final e in entries)
              e.value.url: AnimePlaylistEntry(e.value, episode: e.key),
          }.values.toList(),
        ),
      ),
    );
    final progress = await PlaybackProgressStore.load();
    if (mounted) setState(() => _progress = progress);
  }

  /// Purpose: Build the status lines shown above everything else.
  /// Inputs: `l10n`.
  /// Returns: Widgets, possibly empty.
  /// Side effects: None.
  /// Notes: The busy bar is drawn separately so it can span both panes.
  List<Widget> _buildStatusChildren(AppLocalizations l10n) => [
    if (_sourceChanged) Text(l10n.episodeSourceChanged),
    if (_failed) Text(l10n.episodeDirectoryFailed),
  ];

  /// Purpose: Build the season-mapping form.
  /// Inputs: `l10n`, `anime`, `catalog`, `resolution`, `groups`.
  /// Returns: Widgets for the single column or the left pane.
  /// Side effects: User actions change the unsaved mapping, save or reset.
  /// Notes: None.
  List<Widget> _buildMappingChildren(
    AppLocalizations l10n,
    Anime anime,
    AnimeEpisodeCatalog? catalog,
    AnimeEpisodeResolution resolution,
    Set<String> groups,
  ) => [
    Text(anime.displayTitle, style: Theme.of(context).textTheme.titleLarge),
    Text(l10n.episodeMappingHelp),
    Text(
      [
        anime.season,
        if (anime.firstAirDate != null)
          anime.firstAirDate!.toIso8601String().split('T').first,
      ].join(' · '),
    ),
    if (catalog != null)
      Text(
        [
          catalog.indexTitle ?? catalog.title,
          if (catalog.indexEpisodes != null) catalog.indexEpisodes!,
        ].join(' · '),
      ),
    if (catalog != null && !catalog.complete) Text(l10n.episodeIncomplete),
    if (resolution.needsConfirmation) Text(l10n.episodeUncertain),
    DropdownButtonFormField<String>(
      initialValue: _group ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.episodeGroup),
      key: ValueKey(_group),
      items: [
        DropdownMenuItem(value: '', child: Text(l10n.episodeAuto)),
        for (final group in groups)
          DropdownMenuItem(
            value: group,
            child: Text(group, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() {
              _group = value == '' ? null : value;
              _dirty = true;
            }),
    ),
    TextField(
      controller: _first,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: l10n.episodeFirst,
        hintText: resolution.first?.toString(),
      ),
      onChanged: (_) => setState(() {
        _dirty = true;
        _invalidRange = false;
      }),
    ),
    TextField(
      controller: _last,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(labelText: l10n.episodeLast),
      onChanged: (_) => setState(() {
        _dirty = true;
        _invalidRange = false;
      }),
    ),
    if (_invalidRange) Text(l10n.episodeInvalidRange),
    Wrap(
      spacing: 8,
      children: [
        FilledButton(
          onPressed: _busy || !_dirty ? null : () => _save(),
          child: Text(l10n.save),
        ),
        TextButton(
          onPressed: _busy ? null : () => _save(reset: true),
          child: Text(l10n.episodeReset),
        ),
        TextButton(
          onPressed: () => launchUrl(
            Uri.parse(catalog?.categoryUrl ?? anime.watchUrl!),
            mode: LaunchMode.externalApplication,
          ),
          child: Text(l10n.episodeCollection),
        ),
      ],
    ),
  ];

  /// Purpose: Build the resume bar and text for one stored position.
  /// Inputs: `l10n`, `entry` — may be null.
  /// Returns: Widgets to append under a tile's subtitle, possibly empty.
  /// Side effects: None.
  /// Notes: 1.6.5.
  List<Widget> _buildResume(
    AppLocalizations l10n,
    PlaybackProgressEntry? entry,
  ) => entry == null
      ? const []
      : [
          const SizedBox(height: 4),
          LinearProgressIndicator(value: entry.fraction),
          const SizedBox(height: 2),
          Text(l10n.episodeResume(formatPlaybackClock(entry.position))),
        ];

  /// Purpose: Build one local episode's tile.
  /// Inputs: `l10n`, `anime`, `n`, `catalog`, `resolution`.
  /// Returns: Widget.
  /// Side effects: User actions play or open the page chooser.
  /// Notes: The play icon becomes a filled circle when a resume point exists.
  Widget _buildEpisodeTile(
    AppLocalizations l10n,
    Anime anime,
    int n,
    AnimeEpisodeCatalog? catalog,
    AnimeEpisodeResolution resolution,
  ) {
    final page = resolution.links[n];
    final entry = _progress.entries[playbackProgressKey(anime.id, n)];
    return ListTile(
      key: ValueKey('episodeTile$n'),
      title: Text(l10n.animeEpisodeShort(n)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            page == null ? l10n.episodeMissing : '${page.title}\n${page.url}',
          ),
          ..._buildResume(l10n, entry),
        ],
      ),
      leading: IconButton(
        icon: Icon(entry == null ? Icons.play_arrow : Icons.play_circle),
        tooltip: entry == null
            ? l10n.episodePlay
            : l10n.episodeResume(formatPlaybackClock(entry.position)),
        onPressed: _busy || page == null ? null : () => _play(page, episode: n),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        tooltip: l10n.episodeChoose,
        onPressed: _busy || catalog == null ? null : () => _choose(n, catalog),
      ),
    );
  }

  /// Purpose: Build one extra page's tile.
  /// Inputs: `l10n`, `anime`, `page`.
  /// Returns: Widget.
  /// Side effects: Tapping plays the page.
  /// Notes: Extras are keyed by page address for playback progress.
  Widget _buildSpecialTile(
    AppLocalizations l10n,
    Anime anime,
    AnimeEpisodePage page,
  ) {
    final entry =
        _progress.entries[playbackProgressExtraKey(anime.id, page.url)];
    return ListTile(
      title: Text(page.title),
      subtitle: entry == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildResume(l10n, entry),
            ),
      onTap: _busy ? null : () => _play(page),
      trailing: Icon(entry == null ? Icons.play_arrow : Icons.play_circle),
    );
  }

  /// Purpose: Build the episode and extras list.
  /// Inputs: `l10n`, `anime`, `catalog`, `resolution`, `end`, `columns`.
  /// Returns: Widgets for the single column or the right pane.
  /// Side effects: None.
  /// Notes: Tiles are laid out left to right in `columns` columns.
  List<Widget> _buildEpisodeChildren(
    AppLocalizations l10n,
    Anime anime,
    AnimeEpisodeCatalog? catalog,
    AnimeEpisodeResolution resolution,
    int end,
    int columns,
  ) {
    final count = end < anime.startEpisode ? 0 : end - anime.startEpisode + 1;
    final specials = catalog == null
        ? const <AnimeEpisodePage>[]
        : catalog.pages.where((p) => p.number == null).toList();
    return [
      ...adaptiveTileRows(
        columns: columns,
        itemCount: count,
        itemBuilder: (i) => _buildEpisodeTile(
          l10n,
          anime,
          anime.startEpisode + i,
          catalog,
          resolution,
        ),
      ),
      if (specials.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            l10n.episodeSpecials,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...adaptiveTileRows(
          columns: columns,
          itemCount: specials.length,
          itemBuilder: (i) => _buildSpecialTile(l10n, anime, specials[i]),
        ),
      ],
    ];
  }

  /// Purpose: Preview season evidence, corrected page addresses, missing links and extras.
  /// Inputs: Build context.
  /// Returns: One scrolling column, or two panes where the window may split.
  /// Side effects: User actions refresh, save, correct or play.
  /// Notes: 1.6.5 puts the mapping form in a left pane and the episodes in a
  /// right pane under the app-wide split rule (`useDetailTwoPane`), with the
  /// episodes in columns of at least `episodeTileMinWidth`. The page is pushed
  /// outside the shell, so it measures the whole window. Padding lives inside
  /// the scroll views' children so safe-area insets still apply.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final anime = _anime;
    final catalog = anime == null
        ? null
        : AnimeEpisodeService.catalogFor(anime);
    final resolution = anime == null
        ? null
        : AnimeEpisodeService.resolve(
            anime,
            choices: _choices(),
            library: _library,
          );
    final groups = <String>{?_group, ...?catalog?.pages.map((p) => p.group)};
    final end = anime == null
        ? 0
        : anime.endEpisode ??
              (resolution?.links.keys.fold<int>(
                    anime.startEpisode,
                    (a, b) => a > b ? a : b,
                  ) ??
                  anime.startEpisode);
    final ready = anime != null && resolution != null && !_sourceChanged;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.episodeMappingTitle),
        actions: [
          if (AppFlavor.isFull)
            IconButton(
              onPressed: _busy || _sourceChanged
                  ? null
                  : () => _load(force: true),
              icon: const Icon(Icons.refresh),
              tooltip: l10n.episodeRefresh,
            ),
        ],
      ),
      body: !AppFlavor.isFull
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) {
                final screen = MediaQuery.sizeOf(context);
                final status = _buildStatusChildren(l10n);
                if (!ready || !useDetailTwoPane(screen.width, screen.height)) {
                  return ListView(
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...status,
                            if (ready)
                              ..._buildMappingChildren(
                                l10n,
                                anime,
                                catalog,
                                resolution,
                                groups,
                              ),
                            if (ready)
                              ..._buildEpisodeChildren(
                                l10n,
                                anime,
                                catalog,
                                resolution,
                                end,
                                1,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                final paneWidth = detailLeftPaneWidth(constraints.maxWidth);
                final columns = columnCapacity(
                  constraints.maxWidth - paneWidth - 1 - 32,
                  minItemWidth: episodeTileMinWidth,
                );
                return Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            key: const ValueKey('episodeMappingPane'),
                            width: paneWidth,
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ...status,
                                    ..._buildMappingChildren(
                                      l10n,
                                      anime,
                                      catalog,
                                      resolution,
                                      groups,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: ListView(
                              key: const ValueKey('episodeListPane'),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _buildEpisodeChildren(
                                      l10n,
                                      anime,
                                      catalog,
                                      resolution,
                                      end,
                                      columns,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
