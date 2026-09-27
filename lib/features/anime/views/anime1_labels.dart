import '../../../l10n/app_localizations.dart';
import '../models/anime.dart';
import '../services/anime1_service.dart';
import '../services/anime_episode_service.dart';

/// Purpose: Localize an anime1.me episode cell for a chip or subtitle.
/// Inputs: `l10n`, `info`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: An ongoing cell reads "updated to episode N"; a completed run reads
/// "episodes 1-12", keeping the site's own extras such as `+OVA`; films and
/// specials get their localized nouns; anything else is shown verbatim.
String anime1EpisodesLabel(AppLocalizations l10n, Anime1EpisodeInfo info) {
  switch (info.kind) {
    case Anime1EpisodeKind.ongoing:
      return info.latest != null ? l10n.anime1Ongoing(info.latest!) : info.raw;
    case Anime1EpisodeKind.range:
      if (info.extras != null) return l10n.anime1EpisodeRange(info.raw);
      final first = info.first;
      final last = info.last;
      if (first == null || last == null) return info.raw;
      return l10n.anime1EpisodeRange(first == last ? '$last' : '$first-$last');
    case Anime1EpisodeKind.movie:
      return l10n.anime1Movie;
    case Anime1EpisodeKind.special:
      return l10n.anime1Special;
    case Anime1EpisodeKind.other:
      return info.raw;
  }
}

/// Purpose: Localize anime1.me's year/season cell, e.g. "2022 Fall".
/// Inputs: `l10n`, `year`, `season`.
/// Returns: `String?` — `null` when both are blank.
/// Side effects: None.
/// Notes: Reuses the calendar's season names; an unknown season value is
/// shown as the site wrote it.
String? anime1SeasonLabel(AppLocalizations l10n, String? year, String? season) {
  final y = year?.trim() ?? '';
  final s = season?.trim() ?? '';
  final name = switch (s) {
    '春' => l10n.seasonSpring,
    '夏' => l10n.seasonSummer,
    '秋' => l10n.seasonFall,
    '冬' => l10n.seasonWinter,
    _ => s,
  };
  final parts = [if (y.isNotEmpty) y, if (name.isNotEmpty) name];
  return parts.isEmpty ? null : parts.join(' ');
}

/// Purpose: Compose the one-line description under a search result.
/// Inputs: `l10n`, `match`.
/// Returns: `String?` — `null` for scrape-fallback hits, which carry no data.
/// Side effects: None.
/// Notes: Season, episodes, and fansub are joined with a middle dot; blank
/// parts are skipped.
String? anime1InfoLine(AppLocalizations l10n, Anime1Match match) {
  final parts = <String>[
    ?anime1SeasonLabel(l10n, match.year, match.season),
    if (match.episodes != null) anime1EpisodesLabel(l10n, match.episodes!),
    if (match.fansub != null && match.fansub!.isNotEmpty) match.fansub!,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Purpose: Localize a stored watch-progress record.
/// Inputs: `l10n`, `progress`.
/// Returns: `String?` — `null` when the record holds no episode data.
/// Side effects: None.
/// Notes: Re-parses the stored episode text so a completed run and an
/// ongoing one read differently, exactly as in the search dialog.
String? watchProgressLabel(AppLocalizations l10n, AnimeWatchProgress progress) {
  final text = progress.episodesText;
  if (text != null && text.isNotEmpty) {
    return anime1EpisodesLabel(l10n, Anime1Service.parseEpisodes(text));
  }
  final latest = progress.latestEpisode;
  if (latest == null) return null;
  return progress.ongoing
      ? l10n.anime1Ongoing(latest)
      : l10n.anime1EpisodeRange('$latest');
}

/// Purpose: Show current-season progress without conflating site and local numbers.
/// Inputs: Localization and current anime record.
/// Returns: Mapped progress, or the site's explicitly labeled original progress.
/// Side effects: None.
/// Notes: Uses only verified links; ambiguous mappings do not imply local availability.
String? animeEpisodeProgressLabel(
  AppLocalizations l10n,
  Anime anime, {
  List<Anime> library = const [],
}) {
  final result = AnimeEpisodeService.resolve(anime, library: library);
  if (!result.needsConfirmation && result.links.isNotEmpty) {
    final latest = result.links.keys.reduce((a, b) => a > b ? a : b);
    return l10n.episodeMappedLabel(latest, result.links[latest]!.label);
  }
  final progress = anime.validWatchProgress;
  final text = progress == null ? null : watchProgressLabel(l10n, progress);
  return text == null ? null : l10n.anime1ProgressLabel(text);
}
