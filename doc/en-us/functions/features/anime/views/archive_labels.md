# lib/features/anime/views/archive_labels.dart

Three pure label helpers that turn the `ArchiveSource` / `ArchiveResolution` enums from
[`../models/anime.md`](../models/anime.md) into user-facing text. They exist as one shared file
rather than as private methods on each page because three call sites need them —
[`anime_edit_page.md`](anime_edit_page.md) (the two dropdowns),
[`anime_detail_page.md`](anime_detail_page.md) (the read-only archive card), and any future
archive-aware view — and the older `_typeLabel` helper is already duplicated across
`anime_edit_page.dart`, `anime_detail_page.dart`, and `share_service.dart`, which is exactly the
drift this file avoids.

**Deliberate translation policy.** `BD`, `DVD`, `WEB`, `TV`, `2160p`, `1080p`, `720p`, and `480p`
are returned as hardcoded literals: they are international technical tokens that read identically in
every supported locale, so putting them in the ARB catalogs would add four identical copies of each
with no translator decision to make. Only the `other` member of each enum resolves through the
string catalog, via `l10n.animeArchiveOther`. See
[`../../../../translation-guide.md`](../../../../translation-guide.md).

Enum member names are storage identifiers, not display strings — `fhd1080p` is what lands in
`anime_data.json`, `1080p` is what the user sees. Renaming a member is a data-format change; changing
its label here is not.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`archiveSourceLabel`](#archivesourcelabel) | top-level function | A | Render an `ArchiveSource` as user-facing text. |
| [`archiveResolutionLabel`](#archiveresolutionlabel) | top-level function | A | Render an `ArchiveResolution` as user-facing text. |
| [`archiveQualityLabel`](#archivequalitylabel) | top-level function | A | Join an archive's source and resolution into one `BD · 1080p` label, or `null`. |

## Documentation

### `String archiveSourceLabel(ArchiveSource source, AppLocalizations l10n)` <a id="archivesourcelabel"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/archive_labels.dart` (line 10)
- **Purpose:** Map an `ArchiveSource` enum value to the text shown in dropdowns and on the detail card.
- **Inputs:** `source`; `l10n` — used only for the `other` member.
- **Returns:** `String` — `'BD'`, `'DVD'`, `'WEB'`, `'TV'`, or `l10n.animeArchiveOther`.
- **Side effects:** None.
- **Algorithm:** Exhaustive `switch` over `ArchiveSource.values` (no `default`, so adding an enum member is a compile error here rather than a silently missing label).
- **Usage:**
  ```dart
  ...ArchiveSource.values.map(
    (s) => DropdownMenuItem(value: s, child: Text(archiveSourceLabel(s, l10n))),
  ),
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, the Local Archive source dropdown)

### `String archiveResolutionLabel(ArchiveResolution resolution, AppLocalizations l10n)` <a id="archiveresolutionlabel"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/archive_labels.dart` (line 31)
- **Purpose:** Map an `ArchiveResolution` enum value to the text shown in dropdowns and on the detail card.
- **Inputs:** `resolution`; `l10n` — used only for the `other` member.
- **Returns:** `String` — `'2160p'`, `'1080p'`, `'720p'`, `'480p'`, or `l10n.animeArchiveOther`.
- **Side effects:** None.
- **Algorithm:** Exhaustive `switch`, same shape as `archiveSourceLabel`.
- **Notes:** The enum members carry a quality-tier prefix (`uhd`/`fhd`/`hd`/`sd`) that the label deliberately drops — the prefix disambiguates the identifiers, the number is what a user recognizes.

### `String? archiveQualityLabel(AnimeLocalArchive archive, AppLocalizations l10n)` <a id="archivequalitylabel"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/archive_labels.dart` (line 55)
- **Purpose:** Produce the single combined quality string shown on the anime detail page.
- **Inputs:** `archive`; `l10n`.
- **Returns:** `String?` — `'BD · 1080p'` when both halves are set, just the set half when only one
  is, and `null` when neither is, so callers never render a dangling `·` separator.
- **Side effects:** None.
- **Algorithm:** Collects the non-null halves into a list via collection-`if`, then returns `null` for an empty list or `parts.join(' · ')` otherwise.
- **Usage:**
  ```dart
  final details = <String>[
    ?archiveQualityLabel(archive, l10n),
    if (archive.copies != null) l10n.animeArchiveCopiesValue(archive.copies!),
    if (archive.location != null && archive.location!.isNotEmpty) archive.location!,
  ];
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, `_buildLocalArchiveCard` — the leading `?` is
  Dart's null-aware element, dropping the entry when the label is `null`)
