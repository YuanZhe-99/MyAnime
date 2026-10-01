import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../services/avatar_image.dart';
import '../services/profile_store.dart';

/// Purpose: Let the user frame an avatar and return the result (1.7.2).
/// Inputs: `context`; `source` — the picked image or the current avatar.
/// Returns: `Future<Uint8List?>` — a [ProfileStore.avatarSize]-pixel square
/// JPEG, or null when the user backed out.
/// Side effects: Pushes a full-screen editor route.
/// Notes: Throws nothing for bad input: an undecodable image shows an error
/// state in the editor instead.
Future<Uint8List?> showAvatarEditor(BuildContext context, Uint8List source) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarEditorPage(source: source),
      ),
    );

/// A full-screen editor that frames an image inside a circle: drag to move,
/// pinch or scroll to zoom, rotate in quarter turns. The framed square is
/// what [ProfileStore] stores, so the avatar always matches what was shown.
class AvatarEditorPage extends StatefulWidget {
  /// The image to frame (any format the `image` package decodes).
  final Uint8List source;

  /// Purpose: Create the avatar editor.
  /// Inputs: `source`.
  /// Returns: A new `AvatarEditorPage`.
  /// Side effects: None.
  /// Notes: Open it through [showAvatarEditor].
  const AvatarEditorPage({super.key, required this.source});

  /// Purpose: Create the editor state.
  /// Inputs: None.
  /// Returns: `State<AvatarEditorPage>`.
  /// Side effects: None.
  /// Notes: None.
  @override
  State<AvatarEditorPage> createState() => _AvatarEditorPageState();
}

class _AvatarEditorPageState extends State<AvatarEditorPage> {
  final _transform = TransformationController();
  AvatarSource? _image;
  int _turns = 0;
  bool _busy = true;
  bool _failed = false;

  /// The viewport edge and the image's scaled size at zoom 1, recorded by
  /// [build] so [_save] can map the view back to image pixels.
  double _viewport = 0;
  Size _base = Size.zero;

  /// Purpose: Start preparing the image.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Decodes the source in another isolate.
  /// Notes: None.
  @override
  void initState() {
    super.initState();
    _prepare();
  }

  /// Purpose: Release the transformation controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: None.
  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Purpose: Decode, orient and size the source for the current rotation.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Runs [prepareAvatarSource] in another isolate; resets the
  /// framing; updates the busy and failure flags.
  /// Notes: Internal helper used within this file only.
  Future<void> _prepare() async {
    setState(() => _busy = true);
    final bytes = widget.source;
    final turns = _turns;
    try {
      final image = await prepareAvatarSourceInBackground(
        bytes,
        quarterTurns: turns,
      );
      if (!mounted) return;
      setState(() {
        _image = image;
        _busy = false;
        _failed = false;
        _viewport = 0; // re-centred by the next build
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  /// Purpose: Rotate a quarter turn clockwise.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Re-prepares the image and resets the framing.
  /// Notes: Internal helper used within this file only.
  void _rotate() {
    _turns = (_turns + 1) % 4;
    _prepare();
  }

  /// Purpose: Return to the initial framing (centred, filling the circle).
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Updates the transformation.
  /// Notes: Internal helper used within this file only.
  void _reset() {
    _transform.value = Matrix4.translationValues(
      -(_base.width - _viewport) / 2,
      -(_base.height - _viewport) / 2,
      0,
    );
  }

  /// Purpose: Crop what the circle shows and return it.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Runs [cropAvatarJpeg] in another isolate, then pops the
  /// route with the JPEG.
  /// Notes: Internal helper used within this file only. The view's top-left
  /// and size are mapped back through the zoom/pan matrix to image pixels.
  Future<void> _save() async {
    final image = _image;
    if (image == null || _viewport <= 0) return;
    setState(() => _busy = true);
    final m = _transform.value;
    final scale = m.getMaxScaleOnAxis();
    final t = m.getTranslation();
    final toPixels = image.width / _base.width;
    final x = (-t.x / scale * toPixels).round();
    final y = (-t.y / scale * toPixels).round();
    final side = (_viewport / scale * toPixels).round();
    final bytes = image.bytes;
    try {
      final jpeg = await cropAvatarJpegInBackground(
        bytes,
        x: x,
        y: y,
        side: side,
        size: ProfileStore.avatarSize,
      );
      if (mounted) Navigator.of(context).pop(jpeg);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  /// Purpose: Build the editor.
  /// Inputs: `context`.
  /// Returns: The page.
  /// Side effects: Records the viewport and base size for [_save]; centres a
  /// freshly prepared image.
  /// Notes: The image is laid out to cover the square viewport at zoom 1;
  /// `minScale: 1` and a zero boundary margin keep it covering the circle
  /// however the user drags or zooms.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final image = _image;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileAdjustAvatar),
        actions: [
          IconButton(
            tooltip: l10n.profileAvatarRotate,
            onPressed: _busy || image == null ? null : _rotate,
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
          ),
          IconButton(
            tooltip: l10n.profileAvatarReset,
            onPressed: _busy || image == null ? null : _reset,
            icon: const Icon(Icons.restart_alt),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _busy || image == null || _failed ? null : _save,
              child: Text(MaterialLocalizations.of(context).saveButtonLabel),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _failed
            ? Center(child: Text(l10n.profileAvatarError))
            : image == null
            ? const Center(child: CircularProgressIndicator())
            : LayoutBuilder(
                builder: (context, constraints) {
                  final side =
                      (math.min(
                                constraints.maxWidth,
                                constraints.maxHeight - 96,
                              ) -
                              32)
                          .clamp(160.0, 480.0);
                  final cover =
                      side / math.min(image.width, image.height).toDouble();
                  final base = Size(image.width * cover, image.height * cover);
                  if (_viewport != side || _base != base) {
                    _viewport = side;
                    _base = base;
                    // The controller notifies listeners, so it must not be
                    // changed during build.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _reset();
                    });
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: side,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRect(
                              child: InteractiveViewer(
                                transformationController: _transform,
                                constrained: false,
                                minScale: 1,
                                maxScale: 8,
                                boundaryMargin: EdgeInsets.zero,
                                child: SizedBox(
                                  width: base.width,
                                  height: base.height,
                                  child: Image.memory(
                                    image.bytes,
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                  ),
                                ),
                              ),
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _CircleMaskPainter(
                                  scrim: theme.colorScheme.scrim.withValues(
                                    alpha: 0.55,
                                  ),
                                  ring: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            if (_busy)
                              const Center(child: CircularProgressIndicator()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.profileAvatarEditorHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}

/// Darkens everything outside the avatar circle and outlines the circle.
class _CircleMaskPainter extends CustomPainter {
  final Color scrim;
  final Color ring;

  /// Purpose: Create the mask painter.
  /// Inputs: `scrim` — colour outside the circle; `ring` — circle outline.
  /// Returns: A new `_CircleMaskPainter`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _CircleMaskPainter({required this.scrim, required this.ring});

  /// Purpose: Paint the scrim with a circular hole and the outline.
  /// Inputs: `canvas`, `size`.
  /// Returns: None.
  /// Side effects: Draws on the canvas.
  /// Notes: None.
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final circle = Rect.fromCircle(
      center: rect.center,
      radius: size.shortestSide / 2,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addOval(circle);
    canvas.drawPath(mask, Paint()..color = scrim);
    canvas.drawOval(
      circle.deflate(1),
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Purpose: Repaint only when the colours change.
  /// Inputs: `oldDelegate`.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  @override
  bool shouldRepaint(_CircleMaskPainter oldDelegate) =>
      oldDelegate.scrim != scrim || oldDelegate.ring != ring;
}
