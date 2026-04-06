import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
import 'image_service.dart';

class ShareService {
  static const double _cardWidth = 480;
  static const double _padding = 24;
  static const double _gap = 16;
  static const double _coverWidth = 130;
  static const double _coverHeight = 180;
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
    try {
      final imageBytes = await _generateShareImage(anime, l10n);
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, 'myanime_share.png'));
      await file.writeAsBytes(imageBytes);

      if (!context.mounted) return;

      if (Platform.isAndroid || Platform.isIOS) {
        await Share.shareXFiles([XFile(file.path)]);
      } else {
        await _showDesktopPreview(context, imageBytes, file.path, l10n);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.shareFailed)),
        );
      }
    }
  }

  static Future<Uint8List> _generateShareImage(
    Anime anime,
    AppLocalizations l10n,
  ) async {
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
    final hasQr = anime.watchUrl != null && anime.watchUrl!.isNotEmpty;
    final hasNotes = anime.notes != null && anime.notes!.isNotEmpty;

    // Info text width (beside cover or full width)
    final infoWidth =
        hasCover ? contentWidth - _coverWidth - _gap : contentWidth;

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
    final showJa = anime.titleJa != null &&
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
    infoLines
        .add('${anime.season} · ${_typeLabel(anime.effectiveType, l10n)}');

    // Schedule
    if (anime.airDayOfWeek != null) {
      final day = _dayName(anime.airDayOfWeek!);
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
    final topSectionHeight =
        hasCover ? max<double>(infoHeight, _coverHeight) : infoHeight;
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

    // QR section
    double qrY = y;
    TextPainter? urlPainter;
    if (hasQr) {
      y += _gap;
      qrY = y;
      urlPainter = _layoutText(
        anime.watchUrl!,
        const TextStyle(color: _subtitleColor, fontSize: 11),
        contentWidth - _qrSize - _gap,
        maxLines: 3,
      );
      y += max<double>(_qrSize, urlPainter.height);
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
    final watermarkRowHeight =
        logoImage != null ? max<double>(_logoSize, watermarkPainter.height) : watermarkPainter.height;
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
      final srcW = coverImage!.width.toDouble();
      final srcH = coverImage.height.toDouble();
      final scale = max(_coverWidth / srcW, _coverHeight / srcH);
      final cropW = _coverWidth / scale;
      final cropH = _coverHeight / scale;
      final srcRect = Rect.fromLTWH(
        (srcW - cropW) / 2,
        (srcH - cropH) / 2,
        cropW,
        cropH,
      );
      final dstRect =
          Rect.fromLTWH(_padding, topY, _coverWidth, _coverHeight);
      canvas.save();
      canvas.clipRRect(
          RRect.fromRectAndRadius(dstRect, const Radius.circular(8)));
      canvas.drawImageRect(coverImage, srcRect, dstRect, Paint());
      canvas.restore();
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

    // QR code + URL
    if (hasQr) {
      final qrPainter = QrPainter(
        data: anime.watchUrl!,
        version: QrVersions.auto,
      );
      canvas.save();
      canvas.translate(_padding, qrY);
      qrPainter.paint(canvas, Size(_qrSize, _qrSize));
      canvas.restore();

      urlPainter?.paint(
        canvas,
        Offset(
          _padding + _qrSize + _gap,
          qrY + (_qrSize - urlPainter.height) / 2,
        ),
      );
    }

    // Watermark row (right-aligned): [logo] [gap] [MyAnime!!!!!]
    const logoGap = 6.0;
    if (logoImage != null) {
      final logoAspect = logoImage.width / logoImage.height;
      final logoDrawW = _logoSize * logoAspect;
      final rowWidth = logoDrawW + logoGap + watermarkPainter.width;
      final rowX = _cardWidth - _padding - rowWidth;
      final logoY = watermarkY + (watermarkRowHeight - _logoSize) / 2;
      final textY = watermarkY + (watermarkRowHeight - watermarkPainter.height) / 2;
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
        Offset(_cardWidth - _padding - watermarkPainter.width, watermarkY),
      );
    }

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

  static String _dayName(int dow) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    AppLocalizations l10n,
  ) async {
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
                          fileName: 'myanime_share.png',
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
