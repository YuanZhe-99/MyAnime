/// Purpose: MyAnime's ZIP and Markdown export/import API. The ZIP half is now a
/// facade over the shared `ZipTransfer` engine; the Markdown export is
/// domain-specific and stays here (PLAN.md M14 non-goal).
/// Inputs: Destination directories and ZIP file paths from the settings pages.
/// Returns: Written file paths, or import success flags.
/// Side effects: Reads and writes the app data directory.
/// Notes: PLAN.md P3.1.3. `exportZIP`/`importZIP` keep their names, signatures,
/// and archive naming (`myanime_export_<stamp>.zip`) (I7).
library;

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:myapps_data/myapps_data.dart' as shared;
import 'package:path/path.dart' as p;

import '../../app/data_modules.dart';
import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';

class ImportExportService {
  /// Shared ZIP engine configured to match MyAnime's existing leniency.
  ///
  /// Unknown entries are skipped rather than rejected so an archive from a
  /// newer build still imports, and payloads are written as raw bytes without
  /// UTF-8 or model validation — exactly what this service did before.
  /// Path traversal is the one thing that is not configurable: the engine
  /// always refuses such an archive outright.
  static final shared.ZipTransfer _zip = shared.ZipTransfer(
    storage: const AnimeStorageAdapter(),
    modules: animeModuleRegistry,
    archiveNamePrefix: animeArchiveNamePrefix,
    rejectUnknownEntries: false,
    strictUtf8: false,
    validateBeforeWrite: false,
    atomicWrites: false,
  );

  /// Purpose: Export all anime data as a ZIP file containing anime_data.json and images/.
  /// Inputs: `destDir`.
  /// Returns: `Future<String?>` — the exported file path, or null on failure.
  /// Side effects: Writes `myanime_export_<yyyyMMdd_HHmmss>.zip` in `destDir`.
  /// Notes: Bundles the registry's data files plus flat `images/<name>` entries.
  /// Config, `.sync_base/`, and `backups/` are never included.
  static Future<String?> exportZIP(String destDir) => _zip.exportZip(destDir);

  /// Purpose: Import data from a previously exported ZIP file.
  /// Inputs: `filePath`.
  /// Returns: `Future<bool>` — true on success.
  /// Side effects: Overwrites allowlisted data files and images.
  /// Notes: Only allowlisted entries (the registry's data files and flat files
  /// under `images/`) are extracted, and every entry must resolve inside the
  /// app dir, so a crafted ZIP cannot overwrite configuration such as
  /// `webdav_config.json`. An archive containing a traversal entry is now
  /// rejected outright (returns false, writes nothing) rather than having the
  /// bad entry skipped — see PLAN.md's accepted-unification list.
  static Future<bool> importZIP(String filePath) => _zip.importZip(filePath);

  /// Purpose: Export all anime data as a Markdown file, sorted by first air date.
  /// Inputs: `destDir`.
  /// Returns: `Future<String?>`.
  /// Side effects: May read or mutate application state, storage, or service resources.
  /// Notes: Export all anime data as a Markdown file, sorted by first air date. Designed for LLM personalization / learning context. Returns the exported file path, or null on failure.
  static Future<String?> exportMarkdown(String destDir) async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final dataFile = File(p.join(appDir.path, animeDataFileName));
      if (!await dataFile.exists()) return null;

      final jsonStr = await dataFile.readAsString();
      final jsonData = json.decode(jsonStr) as Map<String, dynamic>;
      final animeData = AnimeData.fromJson(jsonData);

      // Sort by firstAirDate (nulls at the end)
      final sorted = List<Anime>.from(animeData.animes)
        ..sort((a, b) {
          if (a.firstAirDate == null && b.firstAirDate == null) {
            return a.displayTitle.compareTo(b.displayTitle);
          }
          if (a.firstAirDate == null) return 1;
          if (b.firstAirDate == null) return -1;
          return a.firstAirDate!.compareTo(b.firstAirDate!);
        });

      final buf = StringBuffer();
      buf.writeln('# MyAnime!!!!! — Anime Tracking Record');
      buf.writeln();
      buf.writeln(
        'Exported: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
      );
      buf.writeln('Total: ${sorted.length} anime');
      buf.writeln();
      buf.writeln('---');

      for (final anime in sorted) {
        buf.writeln();
        buf.writeln('## ${anime.displayTitle}');
        buf.writeln();

        // Titles
        if (anime.title != null &&
            anime.titleJa != null &&
            anime.title != anime.titleJa) {
          buf.writeln('- **Japanese Title:** ${anime.titleJa}');
        }

        // Season
        if (anime.season != 'Season 1') {
          buf.writeln('- **Season:** ${anime.season}');
        }

        // Type
        buf.writeln('- **Type:** ${_typeLabel(anime.effectiveType)}');

        // Air schedule
        if (anime.firstAirDate != null) {
          buf.writeln(
            '- **First Air Date:** ${DateFormat('yyyy-MM-dd').format(anime.firstAirDate!)}',
          );
        }
        if (anime.airDayOfWeek != null) {
          final day = _dayLabel(anime.airDayOfWeek!);
          final time = anime.airTime ?? '';
          buf.writeln(
            '- **Air Schedule:** $day${time.isNotEmpty ? ' $time JST' : ''}',
          );
        }

        // Episodes
        final epRange = anime.endEpisode != null
            ? 'EP ${anime.startEpisode}–${anime.endEpisode}'
            : 'EP ${anime.startEpisode}–?';
        buf.writeln('- **Episodes:** $epRange');

        // Watching status
        final total = anime.totalEpisodes;
        final watched = anime.episodeStatuses.values
            .where((s) => s == EpisodeStatus.watched)
            .length;
        final skipped = anime.episodeStatuses.values
            .where((s) => s == EpisodeStatus.skippedThisWeek)
            .length;
        final statusLabel = _deriveStatus(anime);
        buf.writeln(
          '- **Status:** $statusLabel (Watched: $watched${total != null ? '/$total' : ''}${skipped > 0 ? ', Skipped: $skipped' : ''})',
        );

        // URLs
        if (anime.infoUrl != null) {
          buf.writeln('- **Info URL:** ${anime.infoUrl}');
        }
        if (anime.watchUrl != null) {
          buf.writeln('- **Watch URL:** ${anime.watchUrl}');
        }

        // Notes
        if (anime.notes != null && anime.notes!.isNotEmpty) {
          buf.writeln('- **Notes:** ${anime.notes}');
        }
      }

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(destDir, 'myanime_export_$stamp.md'));
      await outFile.writeAsString(buf.toString());
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Purpose: Provide the internal type label helper for this file.
  /// Inputs: `type`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _typeLabel(AnimeType type) {
    switch (type) {
      case AnimeType.singleCour:
        return 'Single Cour';
      case AnimeType.halfYear:
        return 'Half Year (2-cour)';
      case AnimeType.fullYear:
        return 'Full Year (4-cour)';
      case AnimeType.longRunning:
        return 'Long Running';
      case AnimeType.allAtOnce:
        return 'All at Once';
    }
  }

  /// Purpose: Provide the internal day label helper for this file.
  /// Inputs: `dow`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _dayLabel(int dow) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return dow >= 1 && dow <= 7 ? days[dow] : '';
  }

  /// Purpose: Provide the internal derive status helper for this file.
  /// Inputs: `anime`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  static String _deriveStatus(Anime anime) {
    if (anime.isCompleted) return 'Completed';
    final hasWatched = anime.episodeStatuses.values.any(
      (s) => s == EpisodeStatus.watched,
    );
    final hasUnwatched =
        anime.endEpisode != null &&
        Iterable.generate(
          anime.endEpisode! - anime.startEpisode + 1,
          (i) => anime.startEpisode + i,
        ).any(
          (ep) =>
              anime.episodeStatuses[ep] == null ||
              anime.episodeStatuses[ep] == EpisodeStatus.unwatched,
        );
    final hasSkipped = anime.episodeStatuses.values.any(
      (s) => s == EpisodeStatus.skippedThisWeek,
    );
    if (hasSkipped && !hasUnwatched) return 'Dropped';
    if (hasWatched && hasUnwatched) return 'Watching';
    if (hasWatched) return 'Watching';
    return 'Not Started';
  }
}
