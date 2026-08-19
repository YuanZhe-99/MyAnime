import '../../../l10n/app_localizations.dart';
import '../models/anime.dart';

/// Purpose: Render an [ArchiveSource] as a user-facing label.
/// Inputs: `source`, `l10n`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: `bd`, `dvd`, `web`, and `tv` are international technical tokens and
/// deliberately stay untranslated; only `other` comes from the string catalog.
String archiveSourceLabel(ArchiveSource source, AppLocalizations l10n) {
  switch (source) {
    case ArchiveSource.bd:
      return 'BD';
    case ArchiveSource.dvd:
      return 'DVD';
    case ArchiveSource.web:
      return 'WEB';
    case ArchiveSource.tv:
      return 'TV';
    case ArchiveSource.other:
      return l10n.animeArchiveOther;
  }
}

/// Purpose: Render an [ArchiveResolution] as a user-facing label.
/// Inputs: `resolution`, `l10n`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Resolution names are international technical tokens and deliberately
/// stay untranslated; only `other` comes from the string catalog.
String archiveResolutionLabel(
  ArchiveResolution resolution,
  AppLocalizations l10n,
) {
  switch (resolution) {
    case ArchiveResolution.uhd2160p:
      return '2160p';
    case ArchiveResolution.fhd1080p:
      return '1080p';
    case ArchiveResolution.hd720p:
      return '720p';
    case ArchiveResolution.sd480p:
      return '480p';
    case ArchiveResolution.other:
      return l10n.animeArchiveOther;
  }
}

/// Purpose: Join the source and resolution of a local archive into one label.
/// Inputs: `archive`, `l10n`.
/// Returns: `String?`.
/// Side effects: None.
/// Notes: Returns `null` when neither half is set, and a single term when only
/// one is, so callers never render a dangling separator. Example: `BD · 1080p`.
String? archiveQualityLabel(AnimeLocalArchive archive, AppLocalizations l10n) {
  final parts = <String>[
    if (archive.source != null) archiveSourceLabel(archive.source!, l10n),
    if (archive.resolution != null)
      archiveResolutionLabel(archive.resolution!, l10n),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}
