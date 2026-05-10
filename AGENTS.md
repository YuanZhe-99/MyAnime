# AGENTS.md

This file is the operating guide for agents working on **MyAnime!!!!!**. Read it before editing anything, then read the relevant code and the user's request carefully. The user's message is the change request: plan the work, execute it in this workspace, verify it, and keep this document current when the project changes.

## Project Snapshot

- **Name:** MyAnime!!!!!, with five exclamation marks in user-facing app names, installer metadata, macOS bundle names, iOS display names, and window titles.
- **Description:** A privacy-first anime tracking app with a JST-aware calendar, seasonal quarter management, statistics, multi-source anime search, watch-progress tracking, daily reminders, share/export flows, WebDAV sync, local backup, a desktop local API server, tray behavior, launch-at-startup, and a kana quick-reference module.
- **Author / package id:** `yuanzhe`, `com.yuanzhe.my_anime`.
- **License:** GPL-3.0.
- **Current version:** `0.7.1+31` in `pubspec.yaml`, `0.7.1.0` for MSIX, and `0.7.1` in `installer.iss`.
- **Framework:** Flutter with Dart SDK `^3.11.3`; CI uses Flutter `3.41.6`.
- **Platforms:** Windows, Android, iOS, macOS. Linux project files exist and desktop services include Linux branches, but Linux is not a primary release target. Web is not targeted.
- **Repository:** `C:\Users\yuanzhe\src\MyAnime`.
- **Remotes:**
  - `origin` -> `<local_gitea_address>`
  - `github` -> `git@github.com:YuanZhe-99/MyAnime.git`

Do not include secrets, credentials, WebDAV configuration, signing keys, private personal anime data, generated app data, or local-only machine addresses in commits or in this file. Keep the `origin` URL masked as `<local_gitea_address>` in public documentation; do not write the underlying Tailscale host here.

## Required Agent Workflow

1. Treat the user's message as the modification request.
2. Before making any modification, fetch from the relevant remotes and verify whether the remote branch has new commits. Do not start editing until remote updates have been checked and any divergence is understood.
3. Read this `AGENTS.md`, inspect the relevant source files, and understand the current behavior before editing.
4. Make a concise plan when the work is non-trivial, then implement the requested changes directly in the workspace.
5. Keep changes scoped. Do not revert unrelated user work in the tree.
6. Update `AGENTS.md` in the same change set whenever architecture, behavior, data formats, commands, release process, version locations, remotes, caveats, or project descriptions change. This document replaces the older role of an external summary and must stay current and complete.
7. Verify with the narrowest meaningful checks for the change, usually `flutter analyze` and relevant `flutter test` targets for Dart changes.
8. When the work is complete, report briefly in both English and Chinese:
   - what changed,
   - what was verified,
   - the current/pre-change version,
   - the configured remotes,
   - whether anything could not be done.
9. For normal code changes, ask whether the user wants to push to all remotes. The user must provide or confirm the release version before a release push.

## Release, Version, Commit, Tag, and Push Flow

For ordinary feature/fix work, do not bump versions or tag until the user confirms the release version and confirms pushing.

When the user confirms the version and wants to push:

1. Update every version location:
   - `pubspec.yaml`: `version: X.Y.Z+N`, where `N` is the Flutter build number and increments for releases.
   - `pubspec.yaml`: `msix_config.msix_version: X.Y.Z.0`.
   - `installer.iss`: `AppVersion=X.Y.Z`.
   - `installer.iss`: `OutputBaseFilename=MyAnime_X.Y.Z_Setup`.
   - `installer.iss`: `OutputBaseFilename=MyAnime_X.Y.Z_arm64_Setup`.
   - `installer.iss`: `VersionInfoVersion=X.Y.Z.0`.
   - `installer.iss`: `VersionInfoProductVersion=X.Y.Z`.
   - Do not manually edit the settings page version display; `settings_page.dart` reads `PackageInfo.fromPlatform()`.
2. If the MSIX version ever differs from the other version locations, keep versions aligned starting with the next version bump instead of making an unrelated version-only edit.
3. Re-run appropriate verification.
4. Commit all intended changes.
5. Create an annotated tag named `vX.Y.Z`.
6. Push the commit to both `origin` and `github`.
7. Push the tag to both `origin` and `github`.

GitHub Actions release builds are triggered by tag pushes to `github`. Tags must be pushed explicitly, either with `git push <remote> <tag>` or an intentional `--tags`.

For documentation-only maintenance that the user explicitly says does not require a release, commit and push the documentation change to the requested remotes without changing versions or creating a tag.

## Build Flavors

Flavor logic lives in `lib/app/flavor.dart`.

| Flavor | Dart define | Online search | Distribution |
| --- | --- | --- | --- |
| `full` | `--dart-define=FLAVOR=full` | Enabled | GitHub Releases, sideload builds, direct APK, desktop installers |
| `store` | `--dart-define=FLAVOR=store` | Disabled in store-facing UI | Google Play and App Store builds |

Online anime search must stay hidden from store builds. Existing UI gates use `AppFlavor.isFull` in `anime_edit_page.dart` for search actions. `AnimeSearchService` itself is a shared utility and does not enforce flavor gating, so every new store-reachable caller must gate access. The desktop local API server can call `AnimeSearchService.searchAll()` and is a desktop feature, not a store/mobile surface.

## Repository Structure

```text
lib/
  main.dart
  app/
    app.dart
    flavor.dart
    router.dart
    theme.dart
  features/
    anime/
      models/anime.dart
      services/
        anime_search_service.dart
        anime_storage.dart
      views/
        home_page.dart
        management_page.dart
        statistics_page.dart
        quarter_picker_dialog.dart
        anime_detail_page.dart
        anime_edit_page.dart
        anime_search_dialog.dart
    kana/views/kana_page.dart
    settings/views/
      backup_page.dart
      license_page.dart
      privacy_policy_page.dart
      settings_page.dart
  shared/
    providers/app_settings.dart
    services/
      auto_sync_service.dart
      backup_service.dart
      file_open_service.dart
      image_service.dart
      import_export_service.dart
      local_api_server.dart
      reminder_service.dart
      share_service.dart
      sync_merge.dart
      tray_service.dart
      webdav_service.dart
    utils/
      chinese_convert.dart
      jst_time.dart
    views/webdav_config_page.dart
    widgets/
  l10n/
```

Primary tests currently include:

- `test/anime_json_test.dart`: unknown JSON preservation and auto-resolved sync merge behavior.
- `test/widget_test.dart`: basic widget smoke coverage.

The `tool/` directory contains ad hoc scripts such as icon generation and search-source validation. Prefer focused tests for production behavior and keep tool scripts out of release-critical paths unless the user asks for them.

## Core Architecture

- State management uses `flutter_riverpod`; do not introduce Provider or Bloc for normal changes.
- Navigation uses `go_router` with a `ShellRoute` and five bottom tabs: Home, Manage, Stats, Kana, Settings.
- The visual system uses Material 3 through `flex_color_scheme`.
- L10n supports English, Japanese, Simplified Chinese, and Traditional Chinese. The ARB template is `lib/l10n/app_en.arb`; generated localization files live under `lib/l10n/`.
- File I/O should go through `AnimeStorage.getAppDir()` so custom storage paths work.
- JSON output is pretty-printed with `JsonEncoder.withIndent('  ')`.
- Timestamps in the anime model use UTC, usually `DateTime.now().toUtc()`. Local-time `modifiedAt` values break sync conflict detection.
- Calendar and airing logic are JST-aware through `shared/utils/jst_time.dart`. Reminder time comparison is local system time, not JST.
- Preserve unknown JSON fields with the existing `extraJson` pattern so older versions do not delete newer fields during normal saves, imports, or sync merges.

## Feature Areas

### Anime Model and Tracking

The core data model is `Anime` in `lib/features/anime/models/anime.dart`.

Important fields and concepts:

- Identity: UUID `id`, main `title`, optional Japanese `titleJa`.
- URLs: `infoUrl` for source/reference pages and `watchUrl` for streaming/watch pages.
- Schedule: `airDayOfWeek` where Monday is 1 and Sunday is 7, `airTime` with late-night values such as `25:00`, and optional `firstAirDate`.
- Episodes: `startEpisode`, `endEpisode`, `episodeStatuses`, and `episodeWeekOffsets` for batch premieres, delays, and schedule corrections.
- Status: derived from episode statuses, not stored as a separate status field. Completed, watching, dropped/abandoned, and not-started states are computed.
- Type: `AnimeType` can be auto-detected from episode count or manually overridden. Manual type must take precedence when set.
- Rating: optional `AnimeRating` stores a manual overall score plus visual/direction, story, character, music/sound, and enjoyment/recommendation sub-scores on a 0-10 scale. Manual overall wins; if empty, the effective overall score is the average of filled sub-scores.
- Compatibility: `Anime`, `AnimeRating`, and `AnimeData` preserve unknown per-anime, per-rating, and top-level JSON fields.

Quarter placement uses Japanese anime cour conventions. When `manualType` is set, it determines the quarter span. Without `manualType`, placement estimates the actual run based on episode count and `episodeWeekOffsets`, with long-running fallback behavior.

### Home, Management, and Statistics

- `home_page.dart`: JST-aware calendar and unwatched aired episodes.
- `management_page.dart`: seasonal quarter browser, global search, dynamic year/quarter picker, and an Other page for anime without `firstAirDate`.
- `statistics_page.dart`: quarter/year/all scopes, summary counts, trend charts, expandable lists grouped by derived status, and a separate Ranking view for rating-based ranking. Ranking supports all/quarter/year/custom-quarter-range filters, type filtering, overall or sub-score sorting, ascending/descending order, direct quarter/year pickers, and cover thumbnails.
- Creating a new anime navigates to the detail page and returns management to the anime's quarter when applicable.

### Kana Quick Reference

`lib/features/kana/views/kana_page.dart` is a UI-only reference module. It does not read or write anime data and is not synced.

It includes:

- Hiragana and katakana segmented switching.
- Kana and romaji search.
- Basic gojuon table.
- Dakuten and handakuten table.
- Yoon combinations.
- Pronunciation rule cards for mora rhythm, stable vowels, sokuon, long vowels, and nasal sounds.

### Multi-Source Search

`anime_search_service.dart` searches or scrapes multiple sources in full builds:

- `bangumi.tv` legacy search API.
- MyAnimeList via Jikan v4.
- AniList GraphQL API.
- `acgsecrets.hk` seasonal page JSON-LD.
- `filmarks.com` HTML.
- `anime1.me` for watch URL lookup.

Features include result deduplication, Simplified/Traditional Chinese variants for Chinese-language sources, fuzzy matching, cover image extraction, and saving search result source URLs into `infoUrl`. Keep public data-source behavior reflected in `PRIVACY_POLICY.md` when sources change.

### Share and File Import

`share_service.dart` supports sharing an anime as an image card.

- The share flow first asks whether to share as an image or as a data file.
- Image cards include cover art, titles, season/type/schedule, broadcast progress, notes, selected info/watch URLs as QR codes, the app logo, and the MyAnime!!!!! watermark.
- Android uses a custom `MethodChannel` named `com.yuanzhe.my_anime/share` and `FLAG_ACTIVITY_NEW_TASK` so share targets open outside the MyAnime task stack.
- iOS uses the system share sheet.
- Desktop shows a preview dialog and can copy or save the generated image.

`file_open_service.dart` supports `.myanimeitem` export/import.

`.myanimeitem` files are JSON with version, anime metadata, optional base64 cover image, and cover extension. Export strips personal viewing data such as `episodeStatuses` and `episodeWeekOffsets`. Import always creates a new UUID and never overwrites an existing anime.

Platform file association is configured on Android, iOS, macOS, and Windows. Windows registration lives in `installer.iss`.

### Backup, Export, Import, and Images

- `backup_service.dart`: local auto-backup once per day, manual backups, retention, and selective restore.
- `import_export_service.dart`: ZIP export/import and Markdown export.
- ZIP export includes `anime_data.json` and `images/`.
- ZIP import must keep path traversal protection.
- Markdown export is LLM-friendly, sorted by `firstAirDate` with nulls last, and includes titles, type, air schedule, episode range, derived viewing status, watched/total counts, URLs, and notes.
- `image_service.dart`: image download and caching. Cover images live under `images/`.

### Reminder Notifications

- Reminder settings are stored in `storage_config.json`.
- Android/iOS use `flutter_local_notifications` with `zonedSchedule()` and `DateTimeComponents.time` for OS-level daily scheduling.
- Desktop uses a 60-second periodic check through `local_notifier`.
- Reminder counts include today's JST airing episodes and unwatched episodes that have already aired.
- `lastReminderDate` prevents duplicate reminders.
- Android requires notification, boot, and exact alarm permissions, plus `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver` in `AndroidManifest.xml`.
- When reminder settings change, call `ReminderService.startPeriodicCheck()` to reschedule.

### Desktop API, Tray, and Startup

`local_api_server.dart` is a desktop-only Shelf server. It is disabled by default and controlled from settings.

- Default listen address: `localhost`.
- Default port: `7788`.
- Users may set `0.0.0.0` for LAN access.
- Non-loopback listening requires API credentials; unsafe non-localhost startup without credentials is refused.
- CORS is permissive.
- Loopback requests skip Basic Auth; non-loopback requests require configured HTTP Basic Auth.
- Endpoints include `GET /ping`, `POST /anime/search`, `POST /anime/add`, `GET /anime/list`, `GET /anime/unwatched`, and `GET /anime/history`.
- `/anime/list` and `/anime/history` return objects with `total`, `counts`, and `data`.
- Season filters include `current`, `YYYYQn`, `unassigned`, and `all`; `all` may sample returned rows while keeping full counts.
- API date serialization converts JST-derived episode dates to UTC strings with `Z`.

`tray_service.dart` handles desktop tray behavior: Show, Quit, minimize-to-tray, close-to-tray, and macOS/Linux/Windows branches. `launch_at_startup` handles desktop auto-start.

## WebDAV Sync Rules

WebDAV sync is per-record three-way merge, not whole-file replacement.

Flow:

1. Download remote `anime_data.json`.
2. Load local `anime_data.json` and `.sync_base/anime_data.json`.
3. Merge per anime using `modifiedAt`.
4. Auto-resolve when only one side changed.
5. Detect conflict when the same anime changed on both sides after the last sync.
6. Upload merged data.
7. Save the new base snapshot only after upload succeeds.

Manual sync uses `autoResolve: false` and shows conflict dialogs. Auto-sync uses `autoResolve: true` and last-writer-wins per record without blocking the UI.

Important sync constraints:

- `anime_data.json` merges `Anime` records by `id` and `modifiedAt`.
- Unknown top-level and per-anime JSON fields must survive parsing, editing, importing, exporting, and sync merging.
- `_syncing` prevents concurrent syncs.
- `_atomicWrite()` uses tmp-then-rename to avoid corrupting local files.
- Local files are re-read after network I/O to detect concurrent user edits during sync.
- Images sync additively and only for cover images referenced by local or remote anime records.
- The referenced image set is the union of `coverImage` basenames from local and remote anime data.
- Orphaned images are not uploaded or downloaded, but they are also not automatically deleted.
- Sync errors and image transfer warnings should be visible in dialogs, not only snackbars.

Auto-sync triggers include app launch, app resume, a 30-second debounce after storage saves, immediate sync after enabling/saving auto-sync config, and a 15-minute timer while the app process is alive. Mobile OS suspension may delay timers until resume. Storage-layer `save()` methods should notify auto-sync so non-UI writes are covered.

## Persisted Data Inventory

Default app data directory is `Documents/MyAnime` on desktop or the platform app documents directory on mobile. Custom storage paths are stored in `storage_config.json`; path changes migrate data files, backups, and images.

| Data | File | Synced | Notes |
| --- | --- | --- | --- |
| Anime records | `anime_data.json` | Yes | Per-record by `id` and `modifiedAt`; unknown fields preserved |
| Cover images | `images/` | Yes | Referenced-only additive sync by filename |
| Theme mode | `storage_config.json` | No | Device-specific preference |
| Locale | `storage_config.json` | No | Device-specific preference |
| Storage path override | `storage_config.json` | No | Device-specific path |
| Auto-backup enabled | `storage_config.json` | No | Device-specific config |
| Backup retention days | `storage_config.json` | No | Device-specific config |
| Reminder enabled/time/last reminder date | `storage_config.json` | No | Device-specific local-time reminder config and internal state |
| API server enabled/listen address/port/credentials | `storage_config.json` | No | Local desktop config; credentials must not be committed |
| Tray and launch-at-startup preferences | `storage_config.json` | No | Local desktop config |
| WebDAV configuration | `webdav_config.json` | No | Local secret/config only |
| Sync base snapshot | `.sync_base/anime_data.json` | No | Local merge tracking |
| Local backups | `backups/backup_*.json` | No | Local recovery |

## Platform Caveats

### Windows

- Inno Setup installer is defined in `installer.iss`; output goes to `build/installer/`.
- The installer creates Start Menu shortcuts. Do not create shortcuts programmatically.
- App icon: `windows/runner/resources/app_icon.ico`.
- File association: `.myanimeitem` -> `MyAnimeItem` -> `my_anime.exe "%1"` via registry entries in `installer.iss`.
- Inno uses `#ifdef ARM64` to build both x64 and ARM64 installers from one script.

### macOS

- App name is `MyAnime!!!!!` in `macos/Runner/Configs/AppInfo.xcconfig`.
- `com.apple.security.network.client` must be present in both `DebugProfile.entitlements` and `Release.entitlements` for network access.
- Custom app icons are generated with `flutter_launcher_icons`.
- `.myanimeitem` file association uses UTI `com.yuanzhe.my-anime.myanimeitem` in `Info.plist`.

### iOS

- `CFBundleDisplayName` is `MyAnime!!!!!` in `Info.plist`.
- HTTPS network access needs no special entitlement.
- `.myanimeitem` file association uses the same UTI declarations as macOS.
- App Store IPA requires signing/provisioning and is not built by CI.

### Android

- `android/app/build.gradle.kts` should use `import java.util.Properties`.
- Use `kotlin { jvmToolchain(17) }`, not deprecated `kotlinOptions`.
- Keystore properties should use nullable casts such as `as String?`.
- Core library desugaring is enabled.
- Signing is optional locally via `key.properties`; CI uses GitHub Secrets.
- FileProvider and `FLAG_ACTIVITY_NEW_TASK` support share/import flows.

## CI/CD

`.github/workflows/build.yml` runs on `v*` tag pushes and `workflow_dispatch`.

Jobs:

- Android APK full flavor and AAB store flavor.
- Windows x64 full installer on `windows-latest`.
- Windows ARM64 full installer on `windows-11-arm`; this currently uses cached Flutter master because stable ARM64 engine support was not yet available when the workflow was written.
- iOS full sideload IPA without codesign.
- macOS full DMG via `create-dmg`.
- GitHub Release artifact upload on tag push.

Important workflow caveats:

- Keep workflow Flutter version aligned with the Dart SDK constraint.
- GitHub `secrets` cannot be used directly in step `if` expressions; route through job-level `env`.
- Windows ARM64 output is controlled by `iscc /DARM64 installer.iss`.
- The ARM64 Flutter master cache is weekly so Windows Defender reputation can accumulate for reused DLL hashes. Once stable Flutter ships suitable ARM64 support, switch this job back to a stable-channel setup.

## Useful Commands

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/anime_json_test.dart
flutter gen-l10n
flutter build apk --release --dart-define=FLAVOR=full
flutter build appbundle --release --dart-define=FLAVOR=store
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss
iscc /DARM64 installer.iss
```

Use the narrowest relevant command set for verification. For model/sync changes, include `flutter test test/anime_json_test.dart`. Full `flutter analyze` has previously reported pre-existing info/warning items and pub advisory decode warnings; distinguish pre-existing noise from regressions introduced by the current change.

## Git History and Version Reference

The latest release tag before this documentation guide was `v0.6.7`, and both `origin/master` and `github/master` were aligned there before the guide was added. There is an early-history caveat: two root commits had the same content after an early `git commit --amend`, and tag `v0.1.0` points to the later root. Avoid `git commit --amend` on root commits.

Version highlights:

- `v0.1.0`: Initial anime tracker.
- `v0.1.1`: Store/full flavors, daily reminders, JST calendar note, macOS support, CI/CD, platform naming and icons.
- `v0.1.2`: Per-record three-way WebDAV merge, conflict resolution UI, sync base tracking.
- `v0.1.3`: UTC `modifiedAt` fixes and schedule validation fixes.
- `v0.2.0`: Share anime as image card with cover, info, QR code, and watermark.
- `v0.2.1`: Share card broadcast-progress improvements and app logo.
- `v0.2.2`: Higher-resolution share card, truncation indicator, add-anime validation, desktop preview dialog.
- `v0.3.0`: AniList source, `infoUrl`, share URL options.
- `v0.3.1`: Android share target opens in its own task.
- `v0.4.0`: Statistics page, management global search, quarter jump picker.
- `v0.4.1`: Navigate to detail after creation and return to the anime quarter.
- `v0.4.2`: Redesigned quarter picker and scrollable statistics trend chart.
- `v0.4.3`: Year-by-quarter grid picker, wider quarter range, sticky Y-axis, default scroll to latest stats.
- `v0.4.4`: Quarter jump fix, optional `firstAirDate`, Japanese title fallback, Other page.
- `v0.5.0`: Comprehensive i18n cleanup for day names, season names, notifications, sync conflicts, and search labels.
- `v0.5.1`: Share as `.myanimeitem` data file and file-open support on all platforms.
- `v0.5.2`: Import `.myanimeitem` from add menus, strip personal viewing data from export, better filenames, manual type override fix, installer metadata.
- `v0.5.3`: `airsInQuarter()` respects `manualType` and episode week offsets.
- `v0.5.4`: Markdown export option for LLM personalization.
- `v0.6.0`: Local HTTP API server, system tray service, desktop settings UI.
- `v0.6.1`: API server enable/disable toggle and configurable listen address.
- `v0.6.2`: Launch at startup, corrected unwatched endpoint, season filters for list/history.
- `v0.6.3`: API `nextEpisodeAirDate` and improved abandoned/not-yet-aired classification.
- `v0.6.4`: API list/history return `total`, `counts`, and `data`; abandoned classification fix.
- `v0.6.5`: Referenced-only image sync and detailed sync error/warning reporting.
- `v0.6.6`: Periodic auto-sync and forward-compatible JSON field preservation.
- `v0.6.7`: Kana quick reference module, l10n updates, remotes synchronized to both `origin` and `github`.
- `v0.7.0`: Optional anime rating system and statistics ranking view with rating filters and sorting.
- `v0.7.1`: Ranking filter UX improvements with reusable quarter/year pickers, quarter-range custom filters, corrected top selection state, and cover thumbnails.
