import 'package:flutter/material.dart';
import 'package:myapps_ai/myapps_ai.dart';
import 'package:myapps_ai_online_ui/myapps_ai_online_ui.dart';
import 'package:myapps_ui/myapps_ui.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';

/// Purpose: Build online provider management with app-owned wording.
/// Inputs: context/controller. Returns: Page. Side effects: Explicit editor operations.
/// Notes: Privacy consent precedes saving; only selected providers receive prompts.
Widget onlineSourcesPage(
  BuildContext context,
  OnlineSourcesController controller,
) {
  final l = AppLocalizations.of(context)!;
  return MyAppsOnlineSourcesPage(
    title: l.aiOnlineSources,
    editorTitle: l.aiOnlineSources,
    controller: controller,
    bottomPadding: navBarAwarePadding(context, EdgeInsets.zero).bottom,
    labels: MyAppsOnlineLabels(
      empty: l.aiOnlineEmpty,
      add: l.aiOnlineAdd,
      templateName: (t) => t.name,
      status: (p, gaps) => gaps.isEmpty
          ? '${p.models.length} · ${l.aiOnlineModels}'
          : l.aiSourceNeedsPreparation,
      remove: l.aiModelRemove,
      removeTitle: (_) => l.aiModelRemove,
      removeBody: l.aiOnlineRemoveBody,
      removeConfirm: l.aiModelRemove,
      cancel: l.aiActionCancel,
      name: l.aiOnlineName,
      model: l.aiOnlineModel,
      save: l.aiOnlineSave,
      saveFailed: l.aiModelFailed,
      invalidEndpoint: l.aiOnlineInvalidEndpoint,
      testResult: (r) => r.status == GenAiStatus.available
          ? l.aiOnlineTestSuccess
          : l.aiOnlineTestFailed,
      privacyTitle: l.aiOnlinePrivacyTitle,
      privacyIntro: (host, _) => '${l.aiOnlineRecipient}: $host',
      dataItem: (_) => l.aiOnlineSentData,
      keySync: (_) => l.aiOnlineKeyLocal,
      onlyWhenSelected: l.aiOnlineSelectedOnly,
      privacyConfirm: l.webdavPrivacyConfirm,
      addSourceTitle: l.aiOnlineAddTitle,
      searchHint: l.aiOnlineSearch,
      endpointLabel: l.aiOnlineEndpointChoice,
      customEndpoint: l.aiOnlineCustomEndpoint,
      docs: l.aiOnlineDocs,
      models: l.aiOnlineModels,
      noModels: l.aiOnlineNoModels,
      fetchModels: l.aiOnlineFetchModels,
      fetchFailed: l.aiOnlineFetchFailed,
      fromCatalog: l.aiOnlineFromCatalog,
      addModelId: l.aiOnlineAddModelId,
      modelIdHint: l.aiOnlineModelIdHint,
      alias: l.aiOnlineAlias,
      aliasHint: l.aiOnlineAliasHint,
      originalId: l.aiOnlineOriginalId,
      showAllModels: l.aiOnlineShowAll,
      contextTokens: (t) =>
          l.aiOnlineContext(t >= 1000 ? '${(t / 1000).round()}K' : '$t'),
      selectModels: l.aiOnlineSelectModels,
      done: l.aiOnlineDone,
      removeModel: l.aiOnlineRemoveModel,
      localServer: l.aiOnlineLocalServer,
    ),
    fields: MyAppsOnlineFieldBuilders(
      endpoint: (_, c, error) => MyAppsEndpointField(
        label: l.aiOnlineEndpoint,
        invalidText: l.aiOnlineInvalidEndpoint,
        controller: c,
        errorText: error,
      ),
      secret: (_, c, saved, clear) => MyAppsSecretField(
        label: 'API Key',
        showTooltip: l.aiOnlineShowKey,
        hideTooltip: l.aiOnlineHideKey,
        controller: c,
        hasSavedValue: saved,
        clearTooltip: l.aiModelRemove,
        savedPlaceholder: l.aiOnlineSavedKey,
        onClear: clear,
      ),
      connectionTest: (_, state, message, test) => MyAppsConnectionTestRow(
        title: l.aiOnlineTest,
        testLabel: l.aiOnlineTest,
        status: MyAppsConnectionTestStatus.values.byName(state.name),
        message: message,
        onTest: test,
      ),
    ),
  );
}
