import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/anime/models/anime.dart';
import '../../l10n/app_localizations.dart';
import '../utils/jst_time.dart';
import 'file_open_service.dart';
import 'image_service.dart';

class RankingShareEntry {
  final Anime anime;
  final int rank;
  final double score;

  const RankingShareEntry({
    required this.anime,
    required this.rank,
    required this.score,
  });
}

class ShareService {
  static const double _cardWidth = 480;
  static const double _rankingCardWidth = 560;
  static const double _padding = 24;
  static const double _gap = 16;
  static const double _coverWidth = 130;
  static const double _coverHeight = 180;
  static const double _rankingCoverWidth = 44;
  static const double _rankingCoverHeight = 62;
  static const double _rankingRowHeight = 86;
  static const double _rankingRankSize = 36;
  static const double _rankingScoreWidth = 68;
  static const double _qrSize = 100;
  static const double _headerHeight = 6;
  static const double _pixelRatio = 3.0;
  static const double _logoSize = 18.0;

  static const _accentColor = Color(0xFF673AB7);
  static const _bgColor = Color(0xFFFFFFFF);
  static const _textColor = Color(0xFF212121);
  static const _subtitleColor = Color(0xFF757575);
  static const _borderColor = Color(0xFFE0E0E0);
  static const _trackColor = Color(0xFFE0E0E0);

  static Future<void> shareAnime(BuildContext context, Anime anime) async {
    final l10n = AppLocalizations.of(context)!;

    // Ask share type: image or data file
    final shareType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.shareTypeTitle),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'image'),
            child: ListTile(
              leading: const Icon(Icons.image),
              title: Text(l10n.shareAsImage),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'data'),
            child: ListTile(
              leading: const Icon(Icons.file_present),
              title: Text(l10n.shareAsData),
            ),
          ),
        ],
      ),
    );
    if (shareType == null || !context.mounted) return;

    if (shareType == 'data') {
      await _shareAnimeData(context, anime, l10n);
    } else {
      await _shareAnimeImage(context, anime, l10n);
    }
  }

  static Future<void> shareRankingImage(
    BuildContext context, {
    required List<RankingShareEntry> entries,
    required String title,
    required String subtitle,
    required String sortLabel,
    required String orderLabel,
    required AppLocalizations l10n,
  }) async {
    if (entries.isEmpty) return;

    try {
      final imageBytes = await _generateRankingShareImage(
        entries: entries,
        title: title,
        subtitle: subtitle,
        sortLabel: sortLabel,
        orderLabel: orderLabel,
        l10n: l10n,
      );
      if (!context.mounted) return;
      await _shareImageBytes(
        context,
        imageBytes,
        l10n,
        fileName: 'myanime_ranking.png',
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }

  static Future<void> _shareAnimeData(
    BuildContext context,
    Anime anime,
    AppLocalizations l10n,
  ) async {
    try {
      final filePath = await FileOpenService.exportAnimeItem(anime);
      if (filePath == null) throw Exception('Export failed');
      if (!context.mounted) return;

      if (Platform.isAndroid) {
        const channel = MethodChannel('com.yuanzhe.my_anime/share');
        await channel.invokeMethod('shareFile', {
          'path': filePath,
          'mimeType': 'application/json',
        });
      } else if (Platform.isIOS) {
        await Share.shareXFiles([XFile(filePath)]);
      } else {
        // Desktop: save as dialog
        final result = await FilePicker.platform.saveFile(
          dialogTitle: l10n.shareSaveAs,
          fileName: p.basename(filePath),
          type: FileType.any,
        );
        if (result != null) {
          await File(filePath).copy(result);
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.shareSaved)));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }

  static Future<void> _shareAnimeImage(
    BuildContext context,
    Anime anime,
    AppLocalizations l10n,
  ) async {
    // Show URL options dialog if any URL is available
    final hasInfoUrl = anime.infoUrl != null && anime.infoUrl!.isNotEmpty;
    final hasWatchUrl = anime.watchUrl != null && anime.watchUrl!.isNotEmpty;
    bool includeInfoUrl = false;
    bool includeWatchUrl = false;

    if (hasInfoUrl || hasWatchUrl) {
      final result = await _showUrlOptionsDialog(
        context,
        l10n,
        hasInfoUrl,
        hasWatchUrl,
      );
      if (result == null) return; // cancelled
      includeInfoUrl = result.includeInfoUrl;
      includeWatchUrl = result.includeWatchUrl;
    }

    try {
      final imageBytes = await _generateShareImage(
        anime,
        l10n,
        includeInfoUrl: includeInfoUrl,
        includeWatchUrl: includeWatchUrl,
      );
      if (!context.mounted) return;
      await _shareImageBytes(
        context,
        imageBytes,
        l10n,
        fileName: 'myanime_share.png',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.shareFailed)));
      }
    }
  }

  static Future<void> _shareImageBytes(
    BuildContext context,
    Uint8List imageBytes,
    AppLocalizations l10n, {
    required String fileName,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, fileName));
    await file.writeAsBytes(imageBytes);

    if (!context.mounted) return;

    if (Platform.isAndroid) {
      const channel = MethodChannel('com.yuanzhe.my_anime/share');
      await channel.invokeMethod('shareFile', {
        'path': file.path,
        'mimeType': 'image/png',
      });
    } else if (Platform.isIOS) {
      await Share.shareXFiles([XFile(file.path)]);
    } else {
      await _showDesktopPreview(
        context,
        imageBytes,
        file.path,
        l10n,
        fileName: fileName,
      );
    }
  }

  static Future<({bool includeInfoUrl, bool includeWatchUrl})?>
  _showUrlOptionsDialog(
    BuildContext context,
    AppLocalizations l10n,
    bool hasInfoUrl,
    bool hasWatchUrl,
  ) async {
    bool infoUrl = false;
    bool watchUrl = false;
    return showDialog<({bool includeInfoUrl, bool includeWatchUrl})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(l10n.shareUrlOptions),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasInfoUrl)
                CheckboxListTile(
                  value: infoUrl,
                  onChanged: (v) => setDialogState(() => infoUrl = v ?? false),
                  title: Text(l10n.animeInfoUrl),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              if (hasWatchUrl)
                CheckboxListTile(
                  value: watchUrl,
                  onChanged: (v) => setDialogState(() => watchUrl = v ?? false),
                  title: Text(l10n.animeWatchUrl),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                ctx,
              ).pop((includeInfoUrl: infoUrl, includeWatchUrl: watchUrl)),
              child: Text(l10n.animeShare),
            ),
          ],
        ),
      ),
    );
  }

  static Future<Uint8List> _generateShareImage(
    Anime anime,
    AppLocalizations l10n, {
    bool includeInfoUrl = false,
    bool includeWatchUrl = false,
  }) async {
    // Load app logo
    ui.Image? logoImage;
    try {
      final logoData = await rootBundle.load('assets/icon/app_icon.png');
      final logoCodec = await ui.instantiateImageCodec(
        logoData.buffer.asUint8List(),
      );
      final logoFrame = await logoCodec.getNextFrame();
      logoImage = logoFrame.image;
    } catch (_) {
      // Proceed without logo
    }

    // Load cover image
    ui.Image? coverImage;
    if (anime.coverImage != null) {
      try {
        final file = await ImageService.resolve(anime.coverImage!);
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          coverImage = frame.image;
        }
      } catch (_) {
        // Proceed without cover if decoding fails
      }
    }

    final contentWidth = _cardWidth - _padding * 2;
    final hasCover = coverImage != null;
    // Build list of URLs to show on the card
    final shareUrls = <({String url, String label})>[];
    if (includeInfoUrl && anime.infoUrl != null && anime.infoUrl!.isNotEmpty) {
      shareUrls.add((url: anime.infoUrl!, label: anime.infoUrl!));
    }
    if (includeWatchUrl &&
        anime.watchUrl != null &&
        anime.watchUrl!.isNotEmpty) {
      shareUrls.add((url: anime.watchUrl!, label: anime.watchUrl!));
    }
    final hasQr = shareUrls.isNotEmpty;
    final hasNotes = anime.notes != null && anime.notes!.isNotEmpty;

    // Info text width (beside cover or full width)
    final infoWidth = hasCover
        ? contentWidth - _coverWidth - _gap
        : contentWidth;

    // ── Layout calculation ──
    double y = _padding + _headerHeight + _gap;
    final topY = y;

    // Title
    final titlePainter = _layoutText(
      anime.displayTitle,
      const TextStyle(
        color: _textColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      infoWidth,
    );
    final titleY = y;
    y += titlePainter.height;

    // Japanese title (show only when both titles exist and differ)
    TextPainter? titleJaPainter;
    double titleJaY = y;
    final showJa =
        anime.titleJa != null &&
        anime.titleJa!.isNotEmpty &&
        anime.title != null &&
        anime.title!.isNotEmpty &&
        anime.titleJa != anime.title;
    if (showJa) {
      y += 4;
      titleJaY = y;
      titleJaPainter = _layoutText(
        anime.titleJa!,
        const TextStyle(color: _subtitleColor, fontSize: 14),
        infoWidth,
      );
      y += titleJaPainter.height;
    }

    // Info lines
    y += 12;
    final infoLines = <String>[];

    // Season + Type
    infoLines.add('${anime.season} · ${_typeLabel(anime.effectiveType, l10n)}');

    // Schedule
    if (anime.airDayOfWeek != null) {
      final day = _dayName(anime.airDayOfWeek!, l10n);
      final time = anime.airTime ?? '';
      infoLines.add(time.isNotEmpty ? '$day $time JST' : '$day JST');
    }

    // First air date
    if (anime.firstAirDate != null) {
      final d = anime.firstAirDate!;
      infoLines.add(
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
      );
    }

    final infoPainters = <TextPainter>[];
    final infoYs = <double>[];
    for (final line in infoLines) {
      infoYs.add(y);
      final tp = _layoutText(
        line,
        const TextStyle(color: _textColor, fontSize: 14),
        infoWidth,
      );
      infoPainters.add(tp);
      y += tp.height + 4;
    }

    // Progress: aired episodes based on JST today
    y += 4;
    final totalEps = anime.totalEpisodes ?? 0;
    final airedCount = _countAiredEpisodes(anime);
    final progressY = y;
    final progressText = anime.endEpisode != null
        ? '$airedCount / $totalEps ${l10n.animeEpisodes}'
        : '$airedCount ${l10n.animeEpisodes}';
    final progressPainter = _layoutText(
      progressText,
      const TextStyle(color: _textColor, fontSize: 14),
      infoWidth,
    );
    y += progressPainter.height + 8;

    // Progress bar
    final progressBarY = y;
    y += 6;

    // Top section height (max of cover and info column)
    final infoHeight = y - topY;
    final topSectionHeight = hasCover
        ? max<double>(infoHeight, _coverHeight)
        : infoHeight;
    y = topY + topSectionHeight;

    // Notes section
    TextPainter? notesPainter;
    TextPainter? notesEllipsisPainter;
    double notesY = y;
    double notesEllipsisY = y;
    bool notesTruncated = false;
    if (hasNotes) {
      y += _gap;
      notesY = y;
      var notesText = anime.notes!;
      if (notesText.length > 300) {
        notesText = notesText.substring(0, 297);
        notesTruncated = true;
      }
      notesPainter = _layoutText(
        notesText,
        const TextStyle(color: _textColor, fontSize: 13),
        contentWidth,
        maxLines: 6,
      );
      // Check if TextPainter itself truncated (didExceedMaxLines)
      if (notesPainter.didExceedMaxLines) {
        notesTruncated = true;
      }
      y += notesPainter.height;
      if (notesTruncated) {
        y += 4;
        notesEllipsisY = y;
        notesEllipsisPainter = _layoutText(
          '...',
          const TextStyle(
            color: _accentColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          contentWidth,
        );
        y += notesEllipsisPainter.height;
      }
    }

    // QR + URL section(s)
    // For each URL: QR code on the left, URL text on the right
    final qrEntries = <({double y, String url, TextPainter painter})>[];
    if (hasQr) {
      for (final entry in shareUrls) {
        y += _gap;
        final entryY = y;
        final urlPainter = _layoutText(
          entry.label,
          const TextStyle(color: _subtitleColor, fontSize: 11),
          contentWidth - _qrSize - _gap,
          maxLines: 3,
        );
        qrEntries.add((y: entryY, url: entry.url, painter: urlPainter));
        y += max<double>(_qrSize, urlPainter.height);
      }
    }

    // Watermark: [logo] [MyAnime!!!!!]
    y += _gap;
    final watermarkPainter = _layoutText(
      'MyAnime!!!!!',
      const TextStyle(
        color: _accentColor,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
      contentWidth,
    );
    final watermarkY = y;
    // Row height = max(logo, text)
    final watermarkRowHeight = logoImage != null
        ? max<double>(_logoSize, watermarkPainter.height)
        : watermarkPainter.height;
    y += watermarkRowHeight;
    y += _padding;

    final cardHeight = y;

    // ── Drawing ──
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_pixelRatio, _pixelRatio);

    // Background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _cardWidth, cardHeight),
      Paint()..color = _bgColor,
    );

    // Border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _cardWidth, cardHeight),
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Header accent bar
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _cardWidth, _headerHeight),
      Paint()..color = _accentColor,
    );

    // Cover image with BoxFit.cover + rounded corners
    final infoX = hasCover ? _padding + _coverWidth + _gap : _padding;
    if (hasCover) {
      _drawCoverImage(
        canvas,
        coverImage,
        Rect.fromLTWH(_padding, topY, _coverWidth, _coverHeight),
        radius: 8,
      );
    }

    // Title
    titlePainter.paint(canvas, Offset(infoX, titleY));

    // Japanese title
    titleJaPainter?.paint(canvas, Offset(infoX, titleJaY));

    // Info lines
    for (int i = 0; i < infoPainters.length; i++) {
      infoPainters[i].paint(canvas, Offset(infoX, infoYs[i]));
    }

    // Progress text
    progressPainter.paint(canvas, Offset(infoX, progressY));

    // Progress bar
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(infoX, progressBarY, infoWidth, 6),
        const Radius.circular(3),
      ),
      Paint()..color = _trackColor,
    );
    if (totalEps > 0) {
      final fillWidth = infoWidth * airedCount / totalEps;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(infoX, progressBarY, fillWidth, 6),
          const Radius.circular(3),
        ),
        Paint()..color = _accentColor,
      );
    }

    // Notes
    notesPainter?.paint(canvas, Offset(_padding, notesY));

    // Notes truncation indicator
    if (notesEllipsisPainter != null) {
      notesEllipsisPainter.paint(
        canvas,
        Offset(
          _padding + (contentWidth - notesEllipsisPainter.width) / 2,
          notesEllipsisY,
        ),
      );
    }

    // QR code + URL entries
    for (final entry in qrEntries) {
      final qrPainter = QrPainter(data: entry.url, version: QrVersions.auto);
      canvas.save();
      canvas.translate(_padding, entry.y);
      qrPainter.paint(canvas, Size(_qrSize, _qrSize));
      canvas.restore();

      entry.painter.paint(
        canvas,
        Offset(
          _padding + _qrSize + _gap,
          entry.y + (_qrSize - entry.painter.height) / 2,
        ),
      );
    }

    // Watermark row (right-aligned): [logo] [gap] [MyAnime!!!!!]
    _drawWatermark(
      canvas,
      logoImage,
      watermarkPainter,
      watermarkY,
      watermarkRowHeight,
      _cardWidth,
    );

    // Encode to PNG
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_cardWidth * _pixelRatio).toInt(),
      (cardHeight * _pixelRatio).toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static TextPainter _layoutText(
    String text,
    TextStyle style,
    double maxWidth, {
    int? maxLines,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines != null ? '...' : null,
    );
    tp.layout(maxWidth: maxWidth);
    return tp;
  }

  static Future<Uint8List> _generateRankingShareImage({
    required List<RankingShareEntry> entries,
    required String title,
    required String subtitle,
    required String sortLabel,
    required String orderLabel,
    required AppLocalizations l10n,
  }) async {
    ui.Image? logoImage;
    try {
      final logoData = await rootBundle.load('assets/icon/app_icon.png');
      final logoCodec = await ui.instantiateImageCodec(
        logoData.buffer.asUint8List(),
      );
      final logoFrame = await logoCodec.getNextFrame();
      logoImage = logoFrame.image;
    } catch (_) {
      // Proceed without logo.
    }

    final coverImages = <String, ui.Image>{};
    for (final entry in entries) {
      final cover = entry.anime.coverImage;
      if (cover == null || coverImages.containsKey(cover)) continue;
      try {
        final file = await ImageService.resolve(cover);
        if (!file.existsSync()) continue;
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        coverImages[cover] = frame.image;
      } catch (_) {
        // Keep exporting even if one cover is missing or invalid.
      }
    }

    final contentWidth = _rankingCardWidth - _padding * 2;
    double y = _padding + _headerHeight + _gap;

    final titlePainter = _layoutText(
      title,
      const TextStyle(
        color: _textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      contentWidth,
    );
    final titleY = y;
    y += titlePainter.height + 6;

    final subtitlePainter = _layoutText(
      subtitle,
      const TextStyle(color: _subtitleColor, fontSize: 14),
      contentWidth,
      maxLines: 2,
    );
    final subtitleY = y;
    y += subtitlePainter.height + 8;

    final metaPainter = _layoutText(
      '${l10n.statsRankingSortBy}: $sortLabel · $orderLabel · ${l10n.statsRankingCount(entries.length)}',
      const TextStyle(color: _textColor, fontSize: 13),
      contentWidth,
      maxLines: 2,
    );
    final metaY = y;
    y += metaPainter.height + _gap;

    final rowYs = <double>[];
    for (final _ in entries) {
      rowYs.add(y);
      y += _rankingRowHeight;
    }

    final watermarkPainter = _layoutText(
      'MyAnime!!!!!',
      const TextStyle(
        color: _accentColor,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
      contentWidth,
    );
    final watermarkY = y + _gap;
    final watermarkRowHeight = logoImage != null
        ? max<double>(_logoSize, watermarkPainter.height)
        : watermarkPainter.height;
    y = watermarkY + watermarkRowHeight + _padding;

    final cardHeight = y;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_pixelRatio, _pixelRatio);

    canvas.drawRect(
      Rect.fromLTWH(0, 0, _rankingCardWidth, cardHeight),
      Paint()..color = _bgColor,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _rankingCardWidth, cardHeight),
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _rankingCardWidth, _headerHeight),
      Paint()..color = _accentColor,
    );

    titlePainter.paint(canvas, Offset(_padding, titleY));
    subtitlePainter.paint(canvas, Offset(_padding, subtitleY));
    metaPainter.paint(canvas, Offset(_padding, metaY));

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final rowY = rowYs[i];
      _drawRankingRow(canvas, entry, rowY, coverImages, l10n);
    }

    _drawWatermark(
      canvas,
      logoImage,
      watermarkPainter,
      watermarkY,
      watermarkRowHeight,
      _rankingCardWidth,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_rankingCardWidth * _pixelRatio).toInt(),
      (cardHeight * _pixelRatio).toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawRankingRow(
    Canvas canvas,
    RankingShareEntry entry,
    double rowY,
    Map<String, ui.Image> coverImages,
    AppLocalizations l10n,
  ) {
    final contentWidth = _rankingCardWidth - _padding * 2;
    final rowRect = Rect.fromLTWH(
      _padding,
      rowY,
      contentWidth,
      _rankingRowHeight - 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rowRect, const Radius.circular(12)),
      Paint()..color = const Color(0xFFF7F4FF),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rowRect, const Radius.circular(12)),
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final rankX = _padding + 12;
    final rankY = rowY + (rowRect.height - _rankingRankSize) / 2;
    canvas.drawCircle(
      Offset(rankX + _rankingRankSize / 2, rankY + _rankingRankSize / 2),
      _rankingRankSize / 2,
      Paint()..color = _accentColor,
    );
    final rankPainter = _layoutText(
      '${entry.rank}',
      const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      _rankingRankSize,
    );
    rankPainter.paint(
      canvas,
      Offset(
        rankX + (_rankingRankSize - rankPainter.width) / 2,
        rankY + (_rankingRankSize - rankPainter.height) / 2,
      ),
    );

    final coverX = rankX + _rankingRankSize + 12;
    final coverY = rowY + (rowRect.height - _rankingCoverHeight) / 2;
    final coverRect = Rect.fromLTWH(
      coverX,
      coverY,
      _rankingCoverWidth,
      _rankingCoverHeight,
    );
    final cover = entry.anime.coverImage == null
        ? null
        : coverImages[entry.anime.coverImage!];
    if (cover != null) {
      _drawCoverImage(canvas, cover, coverRect, radius: 6);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(coverRect, const Radius.circular(6)),
        Paint()..color = const Color(0xFFEDE7F6),
      );
      final placeholder = _layoutText(
        '#',
        const TextStyle(
          color: _accentColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        _rankingCoverWidth,
      );
      placeholder.paint(
        canvas,
        Offset(
          coverX + (_rankingCoverWidth - placeholder.width) / 2,
          coverY + (_rankingCoverHeight - placeholder.height) / 2,
        ),
      );
    }

    final scorePainter = _layoutText(
      _formatScore(entry.score),
      const TextStyle(
        color: _accentColor,
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
      _rankingScoreWidth,
    );
    final scoreX = _rankingCardWidth - _padding - 12 - _rankingScoreWidth;
    scorePainter.paint(
      canvas,
      Offset(scoreX + _rankingScoreWidth - scorePainter.width, rowY + 18),
    );

    final textX = coverX + _rankingCoverWidth + 12;
    final textWidth = scoreX - textX - 12;
    final titlePainter = _layoutText(
      entry.anime.displayTitle,
      const TextStyle(
        color: _textColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
      textWidth,
      maxLines: 1,
    );
    titlePainter.paint(canvas, Offset(textX, rowY + 14));

    final overall = entry.anime.rating?.effectiveOverall;
    final detail = [
      _typeLabel(entry.anime.effectiveType, l10n),
      if (overall != null)
        '${l10n.animeRatingOverall}: ${_formatScore(overall)}',
    ].join(' · ');
    final detailPainter = _layoutText(
      detail,
      const TextStyle(color: _subtitleColor, fontSize: 12),
      textWidth,
      maxLines: 1,
    );
    detailPainter.paint(canvas, Offset(textX, rowY + 40));
  }

  static void _drawCoverImage(
    Canvas canvas,
    ui.Image image,
    Rect dstRect, {
    required double radius,
  }) {
    final srcW = image.width.toDouble();
    final srcH = image.height.toDouble();
    final scale = max(dstRect.width / srcW, dstRect.height / srcH);
    final cropW = dstRect.width / scale;
    final cropH = dstRect.height / scale;
    final srcRect = Rect.fromLTWH(
      (srcW - cropW) / 2,
      (srcH - cropH) / 2,
      cropW,
      cropH,
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(dstRect, Radius.circular(radius)));
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
    canvas.restore();
  }

  static void _drawWatermark(
    Canvas canvas,
    ui.Image? logoImage,
    TextPainter watermarkPainter,
    double watermarkY,
    double watermarkRowHeight,
    double cardWidth,
  ) {
    const logoGap = 6.0;
    if (logoImage != null) {
      final logoAspect = logoImage.width / logoImage.height;
      final logoDrawW = _logoSize * logoAspect;
      final rowWidth = logoDrawW + logoGap + watermarkPainter.width;
      final rowX = cardWidth - _padding - rowWidth;
      final logoY = watermarkY + (watermarkRowHeight - _logoSize) / 2;
      final textY =
          watermarkY + (watermarkRowHeight - watermarkPainter.height) / 2;
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        ),
        Rect.fromLTWH(rowX, logoY, logoDrawW, _logoSize),
        Paint(),
      );
      watermarkPainter.paint(canvas, Offset(rowX + logoDrawW + logoGap, textY));
    } else {
      watermarkPainter.paint(
        canvas,
        Offset(cardWidth - _padding - watermarkPainter.width, watermarkY),
      );
    }
  }

  static String _formatScore(double score) {
    if (score == score.roundToDouble()) return score.toInt().toString();
    return score.toStringAsFixed(1);
  }

  static String _typeLabel(AnimeType type, AppLocalizations l10n) {
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

  static String _dayName(int dow, AppLocalizations l10n) {
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

  /// Count episodes that have aired as of today (JST).
  static int _countAiredEpisodes(Anime anime) {
    if (anime.endEpisode == null) return 0;
    if (anime.firstAirDate == null) return anime.totalEpisodes ?? 0;

    final today = JstTime.today();

    if (anime.effectiveType == AnimeType.allAtOnce) {
      final airDate = DateTime(
        anime.firstAirDate!.year,
        anime.firstAirDate!.month,
        anime.firstAirDate!.day,
      );
      return airDate.isAfter(today) ? 0 : (anime.totalEpisodes ?? 0);
    }

    int count = 0;
    for (int ep = anime.startEpisode; ep <= anime.endEpisode!; ep++) {
      final airDate = anime.getEpisodeCalendarDate(ep);
      if (airDate == null || !airDate.isAfter(today)) {
        count++;
      }
    }
    return count;
  }

  static Future<void> _showDesktopPreview(
    BuildContext context,
    Uint8List imageBytes,
    String tempPath,
    AppLocalizations l10n, {
    required String fileName,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Image.memory(imageBytes, fit: BoxFit.contain),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.copy),
                      label: Text(l10n.shareCopy),
                      onPressed: () async {
                        await _copyImageToClipboard(tempPath);
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(l10n.shareCopied)),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_alt),
                      label: Text(l10n.shareSaveAs),
                      onPressed: () async {
                        final result = await FilePicker.platform.saveFile(
                          dialogTitle: l10n.shareSaveAs,
                          fileName: fileName,
                          type: FileType.image,
                        );
                        if (result != null) {
                          await File(result).writeAsBytes(imageBytes);
                          if (ctx.mounted) {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(l10n.shareSaved)),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _copyImageToClipboard(String imagePath) async {
    if (Platform.isWindows) {
      await Process.run('powershell', [
        '-command',
        "Add-Type -AssemblyName System.Drawing; "
            "Add-Type -AssemblyName System.Windows.Forms; "
            "\$img = [System.Drawing.Image]::FromFile('$imagePath'); "
            "[System.Windows.Forms.Clipboard]::SetImage(\$img); "
            "\$img.Dispose()",
      ]);
    } else if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        "set the clipboard to (read (POSIX file \"$imagePath\") as \u00ABclass PNGf\u00BB)",
      ]);
    } else if (Platform.isLinux) {
      await Process.run('xclip', [
        '-selection',
        'clipboard',
        '-target',
        'image/png',
        '-i',
        imagePath,
      ]);
    }
  }
}
