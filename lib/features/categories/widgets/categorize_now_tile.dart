import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../ai/services/genai_backend.dart';
import '../../ai/services/on_device_ai_service.dart';
import '../services/category_service.dart';

/// The Settings row that classifies every pending record now, with an
/// "N of M" count.
///
/// Shown only while on-device AI is on, on a platform that can have a model.
class CategorizeNowTile extends StatefulWidget {
  /// The classifier; defaults to the app-wide instance.
  final CategoryClassifier? classifier;

  /// The AI service; defaults to the app-wide instance.
  final OnDeviceAiService? ai;

  /// Purpose: Create the tile.
  /// Inputs: `classifier`, `ai` — injectable for tests.
  /// Returns: A new `CategorizeNowTile`.
  /// Side effects: None.
  /// Notes: None.
  const CategorizeNowTile({super.key, this.classifier, this.ai});

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  State<CategorizeNowTile> createState() => _CategorizeNowTileState();
}

class _CategorizeNowTileState extends State<CategorizeNowTile> {
  CategoryClassifier get _classifier =>
      widget.classifier ?? CategoryClassifier.instance;
  OnDeviceAiService get _ai => widget.ai ?? OnDeviceAiService.instance;

  /// Purpose: Read the pending count when the tile appears.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the library and the AI cache.
  /// Notes: Flutter lifecycle override.
  @override
  void initState() {
    super.initState();
    _classifier.refreshCounts();
  }

  /// Purpose: Build the row.
  /// Inputs: `context`.
  /// Returns: A `ListTile`, or nothing when AI is off.
  /// Side effects: None.
  /// Notes: The button is enabled only while the model can generate and no
  /// pass is running.
  @override
  Widget build(BuildContext context) {
    if (!platformMayHaveOnDeviceModel) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: Listenable.merge([_classifier, _ai]),
      builder: (context, _) {
        if (!_ai.enabled) return const SizedBox.shrink();
        final busy = _classifier.running;
        return ListTile(
          leading: const SizedBox(width: 24),
          title: Text(l10n.aiCategorizeNow),
          subtitle: Text(
            l10n.aiCategorizeProgress(
              _classifier.pending,
              _classifier.candidates,
            ),
          ),
          trailing: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : FilledButton.tonal(
                  onPressed: _ai.canGenerate && _classifier.pending > 0
                      ? () async {
                          await _classifier.classifyAll();
                          await _classifier.refreshCounts();
                        }
                      : null,
                  child: Text(l10n.aiCategorizeNow),
                ),
        );
      },
    );
  }
}
