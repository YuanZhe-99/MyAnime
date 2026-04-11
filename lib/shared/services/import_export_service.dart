import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../../features/anime/models/anime.dart';
import '../../features/anime/services/anime_storage.dart';

class ImportExportService {
  /// Export all anime data as a ZIP file containing anime_data.json and images/.
  /// Returns the exported file path, or null on failure.
  static Future<String?> exportZIP(String destDir) async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final archive = Archive();

      final dataFile = File(p.join(appDir.path, 'anime_data.json'));
      if (await dataFile.exists()) {
        final bytes = await dataFile.readAsBytes();
        archive.addFile(ArchiveFile('anime_data.json', bytes.length, bytes));
      }

      // Include images
      final imgDir = Directory(p.join(appDir.path, 'images'));
      if (await imgDir.exists()) {
        await for (final entity in imgDir.list()) {
          if (entity is File) {
            final bytes = await entity.readAsBytes();
            final name = 'images/${p.basename(entity.path)}';
            archive.addFile(ArchiveFile(name, bytes.length, bytes));
          }
        }
      }

      final zipData = ZipEncoder().encode(archive);

      final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final outFile = File(p.join(destDir, 'myanime_export_$stamp.zip'));
      await outFile.writeAsBytes(zipData);
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Import data from a previously exported ZIP file.
  /// Returns true on success.
  static Future<bool> importZIP(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await AnimeStorage.getAppDir();

      for (final entry in archive) {
        if (entry.isFile) {
          // Prevent path traversal attacks
          final normalized = p.normalize(entry.name);
          if (p.isAbsolute(normalized) || normalized.startsWith('..')) continue;

          final outPath = p.join(appDir.path, normalized);
          // Ensure parent directory exists
          final parent = Directory(p.dirname(outPath));
          if (!await parent.exists()) {
            await parent.create(recursive: true);
          }
          final outFile = File(outPath);
          await outFile.writeAsBytes(entry.content as List<int>);
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Export all anime data as a Markdown file, sorted by first air date.
  /// Designed for LLM personalization / learning context.
  /// Returns the exported file path, or null on failure.
  static Future<String?> exportMarkdown(String destDir) async {
    try {
      final appDir = await AnimeStorage.getAppDir();
      final dataFile = File(p.join(appDir.path, 'anime_data.json'));
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
          'Exported: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
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
              '- **First Air Date:** ${DateFormat('yyyy-MM-dd').format(anime.firstAirDate!)}');
        }
        if (anime.airDayOfWeek != null) {
          final day = _dayLabel(anime.airDayOfWeek!);
          final time = anime.airTime ?? '';
          buf.writeln(
              '- **Air Schedule:** $day${time.isNotEmpty ? ' $time JST' : ''}');
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
            '- **Status:** $statusLabel (Watched: $watched${total != null ? '/$total' : ''}${skipped > 0 ? ', Skipped: $skipped' : ''})');

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
      final outFile =
          File(p.join(destDir, 'myanime_export_$stamp.md'));
      await outFile.writeAsString(buf.toString());
      return outFile.path;
    } catch (_) {
      return null;
    }
  }

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

  static String _dayLabel(int dow) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return dow >= 1 && dow <= 7 ? days[dow] : '';
  }

  static String _deriveStatus(Anime anime) {
    if (anime.isCompleted) return 'Completed';
    final hasWatched = anime.episodeStatuses.values
        .any((s) => s == EpisodeStatus.watched);
    final hasUnwatched = anime.endEpisode != null &&
        Iterable.generate(
          anime.endEpisode! - anime.startEpisode + 1,
          (i) => anime.startEpisode + i,
        ).any((ep) =>
            anime.episodeStatuses[ep] == null ||
            anime.episodeStatuses[ep] == EpisodeStatus.unwatched);
    final hasSkipped = anime.episodeStatuses.values
        .any((s) => s == EpisodeStatus.skippedThisWeek);
    if (hasSkipped && !hasUnwatched) return 'Dropped';
    if (hasWatched && hasUnwatched) return 'Watching';
    if (hasWatched) return 'Watching';
    return 'Not Started';
  }
}
