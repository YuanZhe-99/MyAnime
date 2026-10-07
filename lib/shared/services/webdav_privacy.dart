import 'package:flutter/material.dart';
import 'package:myapps_data/myapps_data.dart';

import '../../app/data_modules.dart';
import '../../l10n/app_localizations.dart';

/// Device-local consent for this application's WebDAV inventory.
class WebDavPrivacy {
  static const noticeVersion = 1;
  static final store = WebDavPrivacyAcknowledgementStore.storageConfig(
    const AnimeStorageAdapter(),
  );

  /// Purpose: Determine whether sync may run. Inputs: None. Returns: Consent.
  /// Side effects: Reads device config. Notes: Read errors propagate; no request is made on failure.
  static Future<bool> allowed() async =>
      !needsAcknowledgement(await store.load(), noticeVersion);

  /// Purpose: Classify a configured device. Inputs: configured. Returns: Status.
  /// Side effects: Reads consent. Notes: Never changes saved sync configuration.
  static Future<WebDavPrivacyStatus> status(bool configured) async =>
      webDavPrivacyStatus(
        syncConfigured: configured,
        stored: await store.load(),
        currentVersion: noticeVersion,
      );

  /// Purpose: Obtain consent before saving or making any request.
  /// Inputs: context/config. Returns: True only on consent.
  /// Side effects: Dialog and local acknowledgement write. Notes: Decline writes nothing.
  static Future<bool> ensure(BuildContext context, WebDAVConfig config) async {
    if (await allowed()) return true;
    if (!context.mounted) return false;
    final l = AppLocalizations.of(context)!;
    final verdict = evaluateEndpointSecurity(
      Uri.tryParse(config.serverUrl) ?? Uri(),
    );
    final accepted = await showMyAppsWebDavPrivacyNotice(
      context,
      labels: MyAppsWebDavPrivacyNoticeLabels(
        title: l.webdavPrivacyTitle,
        intro: l.webdavPrivacyIntro,
        modulesHeading: l.webdavPrivacyData,
        optionalContentHeading: l.webdavPrivacyOptional,
        destinationHeading: l.webdavPrivacyDestination,
        encryptionHeading: l.webdavPrivacyEncryption,
        transportHeading: l.webdavPrivacyTransport,
        transportDescription: (_) => config.serverUrl.startsWith('https:')
            ? l.webdavPrivacyHttps
            : l.webdavPrivacyHttp,
        insecureHttpWarning: l.webdavPrivacyHttp,
        noThirdPartiesStatement: l.webdavPrivacyNoThirdParties,
        confirmLabel: l.webdavPrivacyConfirm,
        declineLabel: l.aiActionCancel,
      ),
      modules: [MyAppsWebDavPrivacyItem(title: l.webdavPrivacyInventory)],
      optionalContent: [MyAppsWebDavPrivacyItem(title: l.webdavPrivacyImages)],
      destinationHost: Uri.tryParse(config.serverUrl)?.host ?? config.serverUrl,
      encryptionStatement: l.webdavPrivacyPlaintext,
      verdict: verdict,
    );
    if (!accepted) return false;
    await store.acknowledge(noticeVersion);
    return true;
  }
}
