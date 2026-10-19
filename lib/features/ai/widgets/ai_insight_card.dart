import 'package:myapps_ai_ui/myapps_ai_ui.dart';
export 'package:myapps_ai_ui/myapps_ai_ui.dart' show AiInsightSection;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/providers/app_settings.dart';
import '../services/ai_origin.dart';
import '../services/genai_backend.dart';
import '../services/insight_language.dart';
import '../services/insight_prompts.dart';
import '../services/insight_service.dart';
import '../services/on_device_ai_service.dart';

/// Builds a card's request for the current language and time, or returns
/// null when the module has nothing to talk about yet.
typedef AiInsightRequestBuilder =
    AiInsightRequest? Function(InsightLanguage language, DateTime now);

/// The AI insight card shown on the Statistics page's summary and ranking
/// views (1.9.1).
///
/// Renders nothing unless the user turned AI on and the selected source is
/// supported here, so every existing layout is unchanged otherwise. Unlike
/// MyDevice's card it does not require an on-device model: a local or online
/// source chosen in Settings works on any platform, as recommendation reasons
/// do. When the page's data or the date
/// changes, the card asks [AiInsightStore] to make itself
/// current; the store answers from `ai_insights.json` when the fingerprint
/// matches and only runs the model otherwise.
class AiInsightCard extends ConsumerStatefulWidget {
  /// Which card.
  final InsightModule module;

  /// Builds the request from the page's already-loaded data.
  final AiInsightRequestBuilder buildRequest;

  /// Optional grouping of lines by slot id.
  final List<AiInsightSection> sections;

  /// Collapsible, collapsed by default, showing one preview line (Finance's
  /// stacked phone layout, where height is scarce).
  final bool compact;

  /// Optional note under the lines, e.g. the cycle-estimate disclaimer.
  final String? footnote;

  /// Outer margin.
  final EdgeInsetsGeometry margin;

  /// Purpose: Create an insight card.
  /// Inputs: see fields.
  /// Returns: A new `AiInsightCard`.
  /// Side effects: None.
  /// Notes: Cheap to rebuild: the request is fingerprinted and compared with
  /// the cache before anything runs.
  const AiInsightCard({
    super.key,
    required this.module,
    required this.buildRequest,
    this.sections = const [],
    this.compact = false,
    this.footnote,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 8),
  });

  /// Purpose: Create the state object.
  /// Inputs: None.
  /// Returns: A new state object.
  /// Side effects: None.
  /// Notes: Flutter lifecycle override.
  @override
  ConsumerState<AiInsightCard> createState() => _AiInsightCardState();
}

class _AiInsightCardState extends ConsumerState<AiInsightCard> {
  AiInsightRequest? _request;
  bool _ensureScheduled = false;
  bool _expanded = false;
  bool _couldGenerate = false;
  Timer? _boundaryTimer;
  OnDeviceAiService? _listened;

  /// Purpose: Stop timers and listeners.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Cancels the boundary timer; removes the service listener.
  /// Notes: Flutter lifecycle override.
  @override
  void dispose() {
    _boundaryTimer?.cancel();
    _listened?.removeListener(_onServiceChanged);
    super.dispose();
  }

  /// Purpose: Rebuild when the model becomes usable.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: May call `setState`, which re-runs [_scheduleEnsure].
  /// Notes: Covers the status probe finishing after the page opened.
  void _onServiceChanged() {
    final can = _listened?.canGenerate ?? false;
    if (can && !_couldGenerate && mounted) setState(() {});
    _couldGenerate = can;
  }

  /// Purpose: Follow the right `OnDeviceAiService` instance.
  /// Inputs: `ai`.
  /// Returns: None.
  /// Side effects: Moves the listener when the provider is overridden.
  /// Notes: Internal helper used within this file only.
  void _listenTo(OnDeviceAiService ai) {
    if (identical(_listened, ai)) return;
    _listened?.removeListener(_onServiceChanged);
    _listened = ai..addListener(_onServiceChanged);
    _couldGenerate = ai.canGenerate;
  }

  /// Purpose: Rebuild at the next moment the facts change by time alone.
  /// Inputs: `now`.
  /// Returns: None.
  /// Side effects: (Re)arms a one-shot timer.
  /// Notes: Local midnight, when the date in the facts (and so the
  /// fingerprint) changes; the facts carry the date.
  void _armBoundaryTimer(DateTime now) {
    _boundaryTimer?.cancel();
    final next = DateTime(now.year, now.month, now.day + 1);
    _boundaryTimer = Timer(
      next.difference(now) + const Duration(seconds: 1),
      () {
        if (mounted) setState(() {});
      },
    );
  }

  /// Purpose: Ask the store to make this card current after the frame.
  /// Inputs: `store`.
  /// Returns: None.
  /// Side effects: Schedules one post-frame [AiInsightStore.ensure].
  /// Notes: Coalesces several builds in one frame into one call.
  void _scheduleEnsure(AiInsightStore store) {
    if (_ensureScheduled) return;
    _ensureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureScheduled = false;
      final request = _request;
      if (!mounted || request == null) return;
      unawaited(store.ensure(request));
    });
  }

  /// Purpose: Word a model status that stops the card from generating.
  /// Inputs: `status`, `l10n`.
  /// Returns: `String`.
  /// Side effects: None.
  /// Notes: Same wording as the Settings rows.
  String _statusLabel(GenAiStatus status, AppLocalizations l10n) =>
      switch (status) {
        GenAiStatus.available => l10n.aiStatusAvailable,
        GenAiStatus.unavailable => l10n.aiStatusUnavailable,
        GenAiStatus.unreachable => l10n.aiStatusUnreachable,
        GenAiStatus.unknown => l10n.aiStatusUnknown,
        GenAiStatus.downloadable => l10n.aiStatusDownloadable,
        GenAiStatus.downloading => l10n.aiStatusDownloading,
        GenAiStatus.notEnabled => l10n.aiStatusNotEnabled,
        GenAiStatus.unsupported => l10n.aiStatusUnsupportedApple,
      };

  /// Purpose: Build the card.
  /// Inputs: `context`.
  /// Returns: The card, a one-line notice, or an empty box.
  /// Side effects: Rebuilds the request and schedules [AiInsightStore.ensure].
  /// Notes: Runs when the page rebuilds (its data changed), when settings or
  /// the locale change, at a time boundary, and when the model becomes usable.
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final ai = ref.watch(onDeviceAiServiceProvider);
    final store = ref.watch(aiInsightStoreProvider);
    _listenTo(ai);
    if (!settings.onDeviceAiEnabled) {
      _request = null;
      return const SizedBox.shrink();
    }
    final now = DateTime.now();
    _armBoundaryTimer(now);
    final language = InsightLanguage.forLocale(
      Localizations.localeOf(context),
      localeSupported: ai.coreInfo?.localeSupported,
    );
    _request = language == null ? null : widget.buildRequest(language, now);
    if (_request != null) _scheduleEnsure(store);
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([ai, store]),
      builder: (context, _) {
        final status = ai.report.status;
        if (status == GenAiStatus.unsupported) return const SizedBox.shrink();
        if (status != GenAiStatus.available) {
          return _notice(
            context,
            _statusLabel(status, l10n),
            action: TextButton(
              onPressed: () => context.go('/settings'),
              child: Text(l10n.aiOpenSettings),
            ),
          );
        }
        if (language == null) {
          return _notice(context, l10n.aiLanguageUnsupported);
        }
        final request = _request;
        if (request == null) return const SizedBox.shrink();
        return _card(context, l10n, store, request);
      },
    );
  }

  /// Purpose: Build a one-line notice in place of the card.
  /// Inputs: `context`, `text`, optional `action`.
  /// Returns: `Widget`.
  /// Side effects: None.
  /// Notes: Used when the model is not ready or cannot write the language.
  Widget _notice(BuildContext context, String text, {Widget? action}) {
    final theme = Theme.of(context);
    return Card(
      margin: widget.margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }

  /// Purpose: Build the insight card proper.
  /// Inputs: `context`, `l10n`, `store`, `request`.
  /// Returns: `Widget`.
  /// Side effects: None; the refresh button calls the store.
  /// Notes: Stale lines are dimmed while newer ones are generated.
  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    AiInsightStore store,
    AiInsightRequest request,
  ) {
    return MyAppsAiInsightCard(
      state: store.stateOf(widget.module),
      labels: AiInsightLabels(
        aiInsightTitle: l10n.aiInsightTitle,
        aiRegenerate: l10n.aiRegenerate,
        aiInsightSkipped: l10n.aiInsightSkipped,
        aiGenerating: l10n.aiGenerating,
        aiQuotaHint: l10n.aiQuotaHint,
        aiForegroundHint: l10n.aiForegroundHint,
        aiInsightFailed: l10n.aiInsightFailed,
        aiGeneratedLabel: aiGeneratedLabelFor(
          l10n,
          store.stateOf(widget.module).entry?.model,
        ),
        generatedAt: l10n.aiGeneratedAt,
      ),
      onRefresh: () => unawaited(store.ensure(request, force: true)),
      compact: widget.compact,
      expanded: _expanded,
      onToggle: () => setState(() => _expanded = !_expanded),
      sections: widget.sections,
      footnote: widget.footnote,
      margin: widget.margin,
    );
  }
}
