import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:myapps_profile/myapps_profile.dart';
import '../../../l10n/app_localizations.dart';

/// Purpose: Open the shared avatar editor through the existing app entry point.
/// Inputs: `context`, `source`.
/// Returns: Edited JPEG or null on cancellation.
/// Side effects: Pushes the localized editor route.
/// Notes: Source bytes are not saved by the editor.
Future<Uint8List?> showAvatarEditor(BuildContext context, Uint8List source) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AvatarEditorPage(source: source),
      ),
    );

class AvatarEditorPage extends StatelessWidget {
  final Uint8List source;

  /// Purpose: Construct the app's editor adapter.
  /// Inputs: `source`.
  /// Returns: Editor adapter.
  /// Side effects: None.
  /// Notes: Public constructor retained.
  const AvatarEditorPage({super.key, required this.source});

  /// Purpose: Supply app-localized labels to the shared editor.
  /// Inputs: `context`.
  /// Returns: Shared editor page.
  /// Side effects: None.
  /// Notes: Processing and editor state belong to the shared package.
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ProfileAvatarEditorPage(
      source: source,
      labels: AvatarEditorLabels(
        title: l.profileAdjustAvatar,
        rotate: l.profileAvatarRotate,
        reset: l.profileAvatarReset,
        error: l.profileAvatarError,
        hint: l.profileAvatarEditorHint,
      ),
    );
  }
}
