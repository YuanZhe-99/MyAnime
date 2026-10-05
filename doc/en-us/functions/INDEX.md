# MyAnime `lib/` Function Index

WebDAVConfigPage.build delegates generic settings controls to myapps_data.
Its declarations are unchanged; application operation callbacks remain here.

Settings rendering delegates to the shared UI components; see [shared-ui.md](../shared-ui.md).

Profile rows now document shared exports and app adapters; implementation ownership is in [shared-ui.md](../shared-ui.md).

Vendored platform repair (outside `lib/` totals): [macOS WebView](packages/flutter_inappwebview_macos.md).

This is the top-level index of the hand-written Function Explanation Layer documentation for
`lib/` in the MyAnime repo. Each row links to a per-source-file page under `doc/en-us/functions/`
mirroring the `lib/` tree (with `.dart` replaced by `.md`).

**Totals:** the repo's `/// Purpose:` comment count is **1567** (per the Function Explanation Layer
convention in `AGENTS.md`, excluding generated `lib/l10n/` code â see [l10n/INDEX.md](l10n/INDEX.md)).
The rows below sum to **1549** documented declarations.

| Tier | Count |
|---|---|
| Tier A (full entry: Purpose/Inputs/Returns/Side effects/Algorithm/Usage/Notes) | 820 |
| Tier B (index row only) | 729 |
| **Total** | **1549** |

**Known gap.** These two numbers do not match: 18 declarations carry a `/// Purpose:` comment in
source but have no row here, so the index under-covers `lib/` by that much. The 1.5.7 recount found
that the 864 recorded through 1.5.6 was itself stale â the same command measured 901 on the 1.5.6
tree â so most of this gap accumulated unnoticed over earlier releases rather than being new. It
was 10 until 1.5.6,
when `adaptive_layout.dart`'s row was found still reading `4 | 4` â the count it had in 1.5.3,
before the module grew from the detail page's own helper into the app-wide policy. Its page has
documented twelve declarations since 1.5.5; only this row had not followed. The gap is not evenly
distributed and has not been audited file by file. One file goes the *other* way and carries one
more row than its source's `Purpose:` count â see the note under the `features/` section below.

These totals were recomputed against the actual source tree in 1.4.0, again in 1.5.0 (93 new
declarations across four new files and five changed ones), and again in 1.5.1, which added 24
across five changed files, again in 1.5.2, which added 15 across one new file and four changed
ones, again in 1.5.3, which added 22 across three new files and six changed ones, and again
in 1.5.4, which added 11 across three changed files and promoted three more rows from Tier B to
Tier A without adding any file, and again in 1.5.5, which added 9 across four changed files and
promoted five more rows from Tier B to Tier A, also without adding a file, and again in 1.5.6, which added 2 across two changed files and
corrected `adaptive_layout.dart`'s long-stale row from 4 to 12, and again in 1.5.7, which added 18
across two new files and eight changed ones and corrected the stale 864 total to the measured 919, and again in 1.6.0 (M0, the optional Kana
tab), which added 5 across three changed files and found the 1.5.7 tree actually measured 918, and
again in 1.6.0 (M1, series linking), which added 56 across three new files and seven changed ones â
net of the two `Anime1Service` helpers that moved into `season_label.dart` â and, while there, gave
`anime.dart`'s page the `_parseCalendarDate` row it had lacked since 1.5.7 and corrected
`anime_edit_page.dart`'s stale Tier A count from 9 to the 13 its page already documented; the gap
stayed at 18, and again in 1.6.0 (M3, on-device AI), which added 67 across four new files and two
changed ones (`app_settings.dart` and `anime_storage.dart`; `main.dart` changed without a new
declaration); the gap stayed at 18, and again in 1.6.0 (M2, relation metadata), which added 15
across four changed files (`anime.dart`, `anime_search_service.dart`, `series_service.dart` and
`anime_detail_page.dart`; `anime_edit_page.dart` and `series_widgets.dart` changed without a new
declaration); the gap stayed at 18, and again in 1.6.0 (M4, automatic categories), which added
48 across six new files and four changed ones (`anime_storage.dart`, `app_settings.dart`,
`anime_detail_page.dart` and `webdav_config_page.dart`; `anime.dart`, `management_page.dart`, `settings_page.dart`,
`duplicate_service.dart`, `file_open_service.dart` and `main.dart` changed without a new
declaration); the gap stayed at 18, and again in 1.6.0 (M5, recommendations), which added 37
across four new files and two changed ones (`anime_storage.dart` and `app_settings.dart`;
`router.dart`, `home_page.dart` and `settings_page.dart` changed without a new declaration); the gap
stayed at 18, and again in 1.6.1, which added 14 across six changed files (`anime_search_service.dart`
â seven added, `_recentSeasons` removed â `anime_storage.dart`, `series_service.dart`,
`season_label.dart`, `anime_detail_page.dart` and `anime_edit_page.dart`; `router.dart`,
`anime_search_dialog.dart`, `home_page.dart`, `management_page.dart` and `file_open_service.dart`
changed without a new declaration); the gap stayed at 18, and again in 1.6.2, which added 105
across seven new files (`manage_grouping.dart`, `recommendation_data.dart`,
`recommendation_merge.dart`, `recommendation_store.dart`, `reason_labels.dart`,
`recommendation_trash_page.dart` and `related_card.dart`) and eight changed ones (`data_modules.dart`,
`anime_storage.dart`, `management_page.dart`, `ai_reason_service.dart`, `reason_prompt.dart`,
`recommendation_service.dart`, `recommendations_page.dart` â `_reasonLabel` moved out to
`reason_labels.dart` â and `app_settings.dart`; `router.dart`, `anime_detail_page.dart` and
`backup_page.dart` changed without a new declaration); the gap stayed at 18, and again in 1.6.3,
which added 36 across one new file (`sequel_info_service.dart`) and six changed ones
(`anime_detail_page.dart`, `recommendation_data.dart`, `recommendation_store.dart`,
`recommendation_merge.dart`, `recommendations_page.dart` and `related_card.dart`;
`recommendation_service.dart`, `category_widgets.dart` and `privacy_policy_page.dart` changed
without a new declaration) and found that the `recommendation_store.dart` and `related_card.dart`
rows had each claimed one Tier A entry more than their pages documented since 1.6.2 â the new
entries on those pages now make the old figures true; the gap stayed at 18, and again in 1.6.5,
which added 101 across six new files (`playback_progress.dart`, `playback_progress_merge.dart`,
`playback_progress_store.dart`, `playback_progress_service.dart`, `anime_player_controls.dart` and
`playback_time.dart`) and four changed ones (`data_modules.dart`, `anime_episode_page.dart`,
`anime_player_page.dart` and `anime_native_player.dart`; `adaptive_layout.dart` and
`backup_page.dart` changed without a new declaration); the gap stayed at 18, and again in 1.6.6,
which added none: `anime_detail_page.dart` replaced three helpers with three (`_hasHeaderActions`,
`_buildHeaderActions` and `_watchProgressChipLabel` became `_hasMetaActions`, `_buildWatchRow` and
`_buildSiteProgress`), and `anime_episode_service.dart`, `anime1_service.dart` and
`metadata_update_service.dart` changed without a new declaration; the totals and the gap of 18 are
unchanged. The
pre-1.4.0 figures (682
`Purpose:` comments and 685 documented declarations) had drifted far from both the source and this
file's own per-file rows, which summed to 615 at the time. If you change these numbers, measure
them rather than adjusting them by hand:

```bash
find lib -name "*.dart" -not -path "lib/l10n/*" | xargs grep -h '/// Purpose:' | wc -l
```

**1.6.7 recount.** The measured `/// Purpose:` count is 1477 (1460 before) and the rows sum to 1459, so the gap stays 18. The release added 17 declarations across nine changed files: `anime_storage.dart` +7 (two write queues, `_writeData`, `_exclusiveData`, `updateRecord`, `updateLibrary`, `_writeConfig`, `updateConfig`; `_atomicWrite` removed), `file_open_service.dart` +3 (`safeCoverExt`, `isSafeCoverPath`, `discardUnusedCovers`), `local_api_server.dart` +2 (`buildHandler`, `isAllowedOrigin`; `_corsMiddleware` became `_originMiddleware`), `anime_detail_page.dart` +2 (`dispose`, `_reloadRecord`), and one each in `anime.dart` (`_plusDays`), `home_page.dart` (`buildAiringIndex`; `_getEpisodeCalendarDate` became the top-level `airingCalendarDate`), `anime_edit_page.dart` (`resolveEndEpisode`) and `playback_progress_service.dart` (`_tryStore`), while `metadata_cache.dart` lost `_atomicWrite`. Fifteen of the new declarations are Tier B rows; Tier A gained `_writeData`, `updateRecord`, `updateLibrary` and `updateConfig` and lost the two `_atomicWrite` entries (`AnimeStorage`, `MetadataCache`), a net two.

**1.7.0 recount.** The measured `/// Purpose:` count is 1533 (1477 before) and the rows sum to 1515, so the gap stays 18. The release added 56 declarations: seven new files (`status_colors.dart` +2 and the six `features/profile/` files +44 â `profile_data.dart` 8, `profile_merge.dart` 4, `profile_store.dart` 10, `profile_provider.dart` 7, `profile_avatar.dart` 5, `profile_header.dart` 10) and five changed ones: `data_modules.dart` +3 (`validateProfileJson`, `profileReferencedImages`, `buildProfileModule`), `theme.dart` +2 (`scheme` and `build` are new, `light` and `dark` became methods, and the new `seedColor` constant is documented on its page without a `Purpose:` comment), `anime_storage.dart` +2 (`getFloatingNavBar`, `setFloatingNavBar`), `shell_scaffold.dart` +2 (the private `_FloatingNavBar` constructor and `build`) and `app_settings.dart` +1 (`setFloatingNavBar`). `app.dart`, `home_page.dart`, `statistics_page.dart`, `share_service.dart`, `settings_page.dart` and `backup_page.dart` changed without a new declaration. Twenty-eight of the new rows are Tier A and 28 are Tier B.

**1.7.1 recount.** The measured `/// Purpose:` count is 1536 (1533 before) and the rows sum to 1518, so the gap stays 18. The release added 3 declarations, all in `theme.dart` (`_morphingButtonStyle`, `_emphasized` and `_expressive`, all Tier A; its row goes from `5 | 4` to `8 | 7`). The new `AppUiStyle` enum and the private `_morphDuration` constant are documented on the page but carry no `Purpose:` comment (like `seedColor`), so they are not counted. `anime_storage.dart` swapped `getFloatingNavBar`/`setFloatingNavBar` for `getUiStyle`/`setUiStyle` and `app_settings.dart` swapped `setFloatingNavBar` for `setUiStyle`, so both keep their counts; `app.dart`, `shell_scaffold.dart` and `settings_page.dart` changed without a new declaration. Tier A rose from 798 to 801; Tier B stays 717.

**1.7.2 recount.** The measured `/// Purpose:` count is 1567 (1536 before) and the rows sum to 1549, so the gap stays 18. The release added 31 declarations: two new files, `avatar_image.dart` (7) and `avatar_editor.dart` (13), and six changed ones: `anime_storage.dart` +4 (`getNavPlacement`, `setNavPlacement`, `getNavRailRight`, `setNavRailRight`), `shell_scaffold.dart` +2 (the private `_FloatingNavBar` constructor and `build` are replaced by the constructors and `build` methods of `_ExpressiveNavBar` and `_ExpressiveNavItem`; its row goes from `5 | 1` to `7 | 2`), `app_settings.dart` +2 (`setNavPlacement`, `setNavRailOnRight`), `adaptive_layout.dart` +1 (`navBarAwarePadding`; `13 | 13`), `profile_store.dart` +1 (`pickAvatar` and `squareAvatarJpeg` are out, `pickAvatarSource`, `readAvatarBytes` and `setAvatarJpeg` are in; `squareAvatarJpeg` now lives in `avatar_image.dart`) and `profile_header.dart` +1 (`_editAvatar`). `profile_provider.dart` swapped `pickAvatar` for `setAvatarJpeg`, so it keeps its count. The new `NavPlacement` enum in `theme.dart` is documented on its page but carries no `Purpose:` comment (like `AppUiStyle`), so it is not counted; `management_page.dart`, `statistics_page.dart`, `kana_page.dart` and `settings_page.dart` changed without a new declaration. Tier A rose from 801 to 820 and Tier B from 717 to 729 (19 and 12 of the 31). The *Area totals* table was recomputed from the rows too: it had still read 1515 / 798 / 717 since 1.7.0.

## Root (`lib/`)

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/main.dart` | [main.md](main.md) | 1 | 1 |

## app/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/app/app.dart` | [app/app.md](app/app.md) | 3 | 0 |
| `lib/app/flavor.dart` | [app/flavor.md](app/flavor.md) | 1 | 0 |
| `lib/app/router.dart` | [app/router.md](app/router.md) | 1 | 1 |
| `lib/app/data_modules.dart` | [app/data_modules.md](app/data_modules.md) | 20 | 17 |
| `lib/app/theme.dart` | [app/theme.md](app/theme.md) | 8 | 7 |

`app/router.dart` has one row, `kanaRouteRedirect` (1.6.0). Its other top-level declaration
(`appRouter`, a `GoRouter` config value) carries no `/// Purpose:` comment and falls outside the
Function Explanation Layer convention (function/method/constructor/getter/setter); see that page for
detail.

## features/ai/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/ai/services/ai_insights_cache.dart` | [features/ai/services/ai_insights_cache.md](features/ai/services/ai_insights_cache.md) | 10 | 4 |
| `lib/features/ai/services/genai_backend.dart` | [features/ai/services/genai_backend.md](features/ai/services/genai_backend.md) | 3 | 0 |
| `lib/features/ai/services/on_device_ai_service.dart` | [features/ai/services/on_device_ai_service.md](features/ai/services/on_device_ai_service.md) | 4 | 0 |
| `lib/features/ai/services/output_validation.dart` | [features/ai/services/output_validation.md](features/ai/services/output_validation.md) | 0 | 0 |
| `lib/features/ai/services/prompt_templates.dart` | [features/ai/services/prompt_templates.md](features/ai/services/prompt_templates.md) | 4 | 3 |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | [features/ai/widgets/ai_settings_tiles.md](features/ai/widgets/ai_settings_tiles.md) | 6 | 0 |

The on-device AI layer (1.6.0, M3). `prompt_templates.dart` and `ai_insights_cache.dart` arrived with automatic
categories (M4). Rows include the private `_AiJob` helpers and state methods
that carry a `/// Purpose:` comment. See [../on-device-ai.md](../on-device-ai.md).

## features/anime/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/anime/models/anime.dart` | [features/anime/models/anime.md](features/anime/models/anime.md) | 84 | 68 |
| `lib/features/anime/models/anime_category.dart` | [features/anime/models/anime_category.md](features/anime/models/anime_category.md) | 2 | 1 |
| `lib/features/anime/models/metadata_update.dart` | [features/anime/models/metadata_update.md](features/anime/models/metadata_update.md) | 22 | 9 |
| `lib/features/anime/services/anime_storage.dart` | [features/anime/services/anime_storage.md](features/anime/services/anime_storage.md) | 70 | 54 |
| `lib/features/anime/services/manage_grouping.dart` | [features/anime/services/manage_grouping.md](features/anime/services/manage_grouping.md) | 5 | 1 |
| `lib/features/anime/services/anime1_service.dart` | [features/anime/services/anime1_service.md](features/anime/services/anime1_service.md) | 31 | 17 |
| `lib/features/anime/services/anime_search_service.dart` | [features/anime/services/anime_search_service.md](features/anime/services/anime_search_service.md) | 71 | 48 |
| `lib/features/anime/services/metadata_cache.dart` | [features/anime/services/metadata_cache.md](features/anime/services/metadata_cache.md) | 9 | 6 |
| `lib/features/anime/services/metadata_update_service.dart` | [features/anime/services/metadata_update_service.md](features/anime/services/metadata_update_service.md) | 44 | 27 |
| `lib/features/anime/services/series_service.dart` | [features/anime/services/series_service.md](features/anime/services/series_service.md) | 32 | 20 |
| `lib/features/anime/views/anime1_labels.dart` | [features/anime/views/anime1_labels.md](features/anime/views/anime1_labels.md) | 5 | 4 |
| `lib/features/anime/views/anime_detail_page.dart` | [features/anime/views/anime_detail_page.md](features/anime/views/anime_detail_page.md) | 40 | 16 |
| `lib/features/anime/views/anime_edit_page.dart` | [features/anime/views/anime_edit_page.md](features/anime/views/anime_edit_page.md) | 31 | 15 |
| `lib/features/anime/views/anime_search_dialog.dart` | [features/anime/views/anime_search_dialog.md](features/anime/views/anime_search_dialog.md) | 34 | 17 |
| `lib/features/anime/views/archive_labels.dart` | [features/anime/views/archive_labels.md](features/anime/views/archive_labels.md) | 3 | 3 |
| `lib/features/anime/views/category_widgets.dart` | [features/anime/views/category_widgets.md](features/anime/views/category_widgets.md) | 9 | 4 |
| `lib/features/anime/views/home_page.dart` | [features/anime/views/home_page.md](features/anime/views/home_page.md) | 25 | 9 |
| `lib/features/anime/views/management_page.dart` | [features/anime/views/management_page.md](features/anime/views/management_page.md) | 31 | 15 |
| `lib/features/anime/views/metadata_updates_page.dart` | [features/anime/views/metadata_updates_page.md](features/anime/views/metadata_updates_page.md) | 23 | 9 |
| `lib/features/anime/views/quarter_picker_dialog.dart` | [features/anime/views/quarter_picker_dialog.md](features/anime/views/quarter_picker_dialog.md) | 5 | 1 |
| `lib/features/anime/views/series_widgets.dart` | [features/anime/views/series_widgets.md](features/anime/views/series_widgets.md) | 13 | 5 |
| `lib/features/anime/views/statistics_page.dart` | [features/anime/views/statistics_page.md](features/anime/views/statistics_page.md) | 70 | 29 |

Note: `anime.dart` has one more row than its source's `Purpose:` comment count â the `AnimeData`
default constructor has no doc comment at all in source but is a real, documented declaration (see
that page's own note). `anime_search_service.dart` used to share this property because
`searchAnime1` carried a plain (non-`Purpose:`) comment; that method moved to `anime1_service.dart`
in 1.5.7 with a full block, so the two now agree. `chinese_convert_data.dart` is generated data
with no declarations of the documented kinds, hence its `0 | 0` row.

## features/categories/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/categories/services/category_service.dart` | [features/categories/services/category_service.md](features/categories/services/category_service.md) | 14 | 10 |
| `lib/features/categories/widgets/categorize_now_tile.dart` | [features/categories/widgets/categorize_now_tile.md](features/categories/widgets/categorize_now_tile.md) | 4 | 1 |

Automatic categories (1.6.0, M4). See
[../features/categories-and-recommendations.md](../features/categories-and-recommendations.md).

## features/kana/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/kana/views/kana_page.dart` | [features/kana/views/kana_page.md](features/kana/views/kana_page.md) | 19 | 3 |

## features/profile/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/profile/models/profile_data.dart` | [features/profile/models/profile_data.md](features/profile/models/profile_data.md) | 8 | 2 |
| `lib/features/profile/services/profile_merge.dart` | [features/profile/services/profile_merge.md](features/profile/services/profile_merge.md) | 4 | 2 |
| `lib/features/profile/services/avatar_image.dart` | [features/profile/services/avatar_image.md](features/profile/services/avatar_image.md) | 7 | 5 |
| `lib/features/profile/services/profile_store.dart` | [features/profile/services/profile_store.md](features/profile/services/profile_store.md) | 11 | 7 |
| `lib/features/profile/providers/profile_provider.dart` | [features/profile/providers/profile_provider.md](features/profile/providers/profile_provider.md) | 7 | 2 |
| `lib/features/profile/views/avatar_editor.dart` | [features/profile/views/avatar_editor.md](features/profile/views/avatar_editor.md) | 13 | 6 |
| `lib/features/profile/views/profile_avatar.dart` | [features/profile/views/profile_avatar.md](features/profile/views/profile_avatar.md) | 5 | 3 |
| `lib/features/profile/views/profile_header.dart` | [features/profile/views/profile_header.md](features/profile/views/profile_header.md) | 11 | 5 |

The synced profile (1.7.0): display name and avatar. See [../features/profile.md](../features/profile.md).

## features/recommendations/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/recommendations/models/recommendation_data.dart` | [features/recommendations/models/recommendation_data.md](features/recommendations/models/recommendation_data.md) | 33 | 6 |
| `lib/features/recommendations/services/ai_reason_service.dart` | [features/recommendations/services/ai_reason_service.md](features/recommendations/services/ai_reason_service.md) | 6 | 4 |
| `lib/features/recommendations/services/reason_prompt.dart` | [features/recommendations/services/reason_prompt.md](features/recommendations/services/reason_prompt.md) | 5 | 4 |
| `lib/features/recommendations/services/recommendation_merge.dart` | [features/recommendations/services/recommendation_merge.md](features/recommendations/services/recommendation_merge.md) | 6 | 6 |
| `lib/features/recommendations/services/recommendation_service.dart` | [features/recommendations/services/recommendation_service.md](features/recommendations/services/recommendation_service.md) | 22 | 10 |
| `lib/features/recommendations/services/recommendation_store.dart` | [features/recommendations/services/recommendation_store.md](features/recommendations/services/recommendation_store.md) | 22 | 8 |
| `lib/features/recommendations/services/sequel_info_service.dart` | [features/recommendations/services/sequel_info_service.md](features/recommendations/services/sequel_info_service.md) | 9 | 4 |
| `lib/features/recommendations/views/reason_labels.dart` | [features/recommendations/views/reason_labels.md](features/recommendations/views/reason_labels.md) | 1 | 1 |
| `lib/features/recommendations/views/recommendation_trash_page.dart` | [features/recommendations/views/recommendation_trash_page.md](features/recommendations/views/recommendation_trash_page.md) | 12 | 4 |
| `lib/features/recommendations/views/recommendations_page.dart` | [features/recommendations/views/recommendations_page.md](features/recommendations/views/recommendations_page.md) | 21 | 9 |
| `lib/features/recommendations/views/related_card.dart` | [features/recommendations/views/related_card.md](features/recommendations/views/related_card.md) | 16 | 7 |

Recommendations (1.6.0, M5); the synced trash bins, the related list and the trash page (1.6.2). See
[../features/categories-and-recommendations.md](../features/categories-and-recommendations.md).

## features/settings/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/settings/views/backup_page.dart` | [features/settings/views/backup_page.md](features/settings/views/backup_page.md) | 16 | 7 |
| `lib/features/settings/views/license_page.dart` | [features/settings/views/license_page.md](features/settings/views/license_page.md) | 2 | 0 |
| `lib/features/settings/views/privacy_policy_page.dart` | [features/settings/views/privacy_policy_page.md](features/settings/views/privacy_policy_page.md) | 3 | 1 |
| `lib/features/settings/views/settings_page.dart` | [features/settings/views/settings_page.md](features/settings/views/settings_page.md) | 28 | 20 |

## l10n/

`lib/l10n/` is already documented at [l10n/INDEX.md](l10n/INDEX.md) (generated code, not part of
the 771 hand-documented declarations above).

## shared/

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/shared/providers/app_settings.dart` | [shared/providers/app_settings.md](shared/providers/app_settings.md) | 29 | 18 |
| `lib/shared/utils/adaptive_layout.dart` | [shared/utils/adaptive_layout.md](shared/utils/adaptive_layout.md) | 13 | 13 |
| `lib/shared/utils/calendar_preferences.dart` | [shared/utils/calendar_preferences.md](shared/utils/calendar_preferences.md) | 4 | 4 |
| `lib/shared/utils/chinese_convert.dart` | [shared/utils/chinese_convert.md](shared/utils/chinese_convert.md) | 5 | 4 |
| `lib/shared/utils/chinese_convert_data.dart` | [shared/utils/chinese_convert_data.md](shared/utils/chinese_convert_data.md) | 0 | 0 |
| `lib/shared/utils/detail_layout.dart` | [shared/utils/detail_layout.md](shared/utils/detail_layout.md) | 3 | 3 |
| `lib/shared/utils/jst_time.dart` | [shared/utils/jst_time.md](shared/utils/jst_time.md) | 5 | 4 |
| `lib/shared/utils/season_label.dart` | [shared/utils/season_label.md](shared/utils/season_label.md) | 10 | 8 |
| `lib/shared/utils/status_colors.dart` | [shared/utils/status_colors.md](shared/utils/status_colors.md) | 2 | 2 |
| `lib/shared/widgets/adaptive_tile_grid.dart` | [shared/widgets/adaptive_tile_grid.md](shared/widgets/adaptive_tile_grid.md) | 3 | 3 |
| `lib/shared/widgets/anime_actions_sheet.dart` | [shared/widgets/anime_actions_sheet.md](shared/widgets/anime_actions_sheet.md) | 1 | 1 |
| `lib/shared/widgets/delete_confirm.dart` | [shared/widgets/delete_confirm.md](shared/widgets/delete_confirm.md) | 1 | 1 |
| `lib/shared/widgets/duplicate_check_page.dart` | [shared/widgets/duplicate_check_page.md](shared/widgets/duplicate_check_page.md) | 10 | 3 |
| `lib/shared/widgets/import_bundle_dialog.dart` | [shared/widgets/import_bundle_dialog.md](shared/widgets/import_bundle_dialog.md) | 6 | 2 |
| `lib/shared/widgets/shell_scaffold.dart` | [shared/widgets/shell_scaffold.md](shared/widgets/shell_scaffold.md) | 5 | 3 |
| `lib/shared/services/webdav_service.dart` | [shared/services/webdav_service.md](shared/services/webdav_service.md) | 12 | 12 |
| `lib/shared/services/sync_merge.dart` | [shared/services/sync_merge.md](shared/services/sync_merge.md) | 4 | 4 |
| `lib/shared/services/sync_progress.dart` | [shared/services/sync_progress.md](shared/services/sync_progress.md) | 0 | 0 |
| `lib/shared/services/sync_wake_lock.dart` | [shared/services/sync_wake_lock.md](shared/services/sync_wake_lock.md) | 0 | 0 |
| `lib/shared/services/auto_sync_service.dart` | [shared/services/auto_sync_service.md](shared/services/auto_sync_service.md) | 15 | 15 |
| `lib/shared/services/backup_service.dart` | [shared/services/backup_service.md](shared/services/backup_service.md) | 12 | 12 |
| `lib/shared/services/share_service.dart` | [shared/services/share_service.md](shared/services/share_service.md) | 33 | 25 |
| `lib/shared/services/duplicate_service.dart` | [shared/services/duplicate_service.md](shared/services/duplicate_service.md) | 17 | 12 |
| `lib/shared/services/file_open_service.dart` | [shared/services/file_open_service.md](shared/services/file_open_service.md) | 21 | 17 |
| `lib/shared/services/reminder_service.dart` | [shared/services/reminder_service.md](shared/services/reminder_service.md) | 9 | 8 |
| `lib/shared/services/import_export_service.dart` | [shared/services/import_export_service.md](shared/services/import_export_service.md) | 6 | 4 |
| `lib/shared/services/tray_service.dart` | [shared/services/tray_service.md](shared/services/tray_service.md) | 16 | 8 |
| `lib/shared/services/image_service.dart` | [shared/services/image_service.md](shared/services/image_service.md) | 6 | 6 |
| `lib/shared/services/local_api_server.dart` | [shared/services/local_api_server.md](shared/services/local_api_server.md) | 47 | 36 |
| `lib/shared/views/webdav_config_page.dart` | [shared/views/webdav_config_page.md](shared/views/webdav_config_page.md) | 24 | 14 |

## Area totals

| Area | Files | Declarations | Tier A | Tier B |
|---|---|---|---|---|
| Root (`lib/`) | 1 | 1 | 1 | 0 |
| `app/` | 5 | 33 | 25 | 8 |
| `features/ai/` | 6 | 75 | 29 | 46 |
| `features/anime/` | 33 | 813 | 387 | 426 |
| `features/categories/` | 2 | 18 | 11 | 7 |
| `features/kana/` | 1 | 19 | 3 | 16 |
| `features/profile/` | 8 | 66 | 32 | 34 |
| `features/recommendations/` | 11 | 153 | 63 | 90 |
| `features/settings/` | 4 | 49 | 28 | 21 |
| `shared/` (utils, widgets, providers, services, views) | 31 | 322 | 241 | 81 |
| **Total** | **102** | **1549** | **820** | **729** |


## Anime1 episode playback (1.6.4)

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/anime/models/anime_episode.dart` | [features/anime/models/anime_episode.md](features/anime/models/anime_episode.md) | 12 | 0 |
| `lib/features/anime/services/anime_episode_service.dart` | [features/anime/services/anime_episode_service.md](features/anime/services/anime_episode_service.md) | 10 | 0 |
| `lib/features/anime/services/anime_media_service.dart` | [features/anime/services/anime_media_service.md](features/anime/services/anime_media_service.md) | 3 | 0 |
| `lib/features/anime/views/anime_episode_page.dart` | [features/anime/views/anime_episode_page.md](features/anime/views/anime_episode_page.md) | 19 | 0 |
| `lib/features/anime/views/anime_player_page.dart` | [features/anime/views/anime_player_page.md](features/anime/views/anime_player_page.md) | 12 | 0 |
| `lib/features/anime/views/anime_native_player.dart` | [features/anime/views/anime_native_player.md](features/anime/views/anime_native_player.md) | 42 | 0 |

## Playback progress and player controls (1.6.5)

| Source file | Page | Declarations | Tier A count |
|---|---|---|---|
| `lib/features/anime/models/playback_progress.dart` | [features/anime/models/playback_progress.md](features/anime/models/playback_progress.md) | 15 | 3 |
| `lib/features/anime/services/playback_progress_merge.dart` | [features/anime/services/playback_progress_merge.md](features/anime/services/playback_progress_merge.md) | 3 | 1 |
| `lib/features/anime/services/playback_progress_store.dart` | [features/anime/services/playback_progress_store.md](features/anime/services/playback_progress_store.md) | 7 | 1 |
| `lib/features/anime/services/playback_progress_service.dart` | [features/anime/services/playback_progress_service.md](features/anime/services/playback_progress_service.md) | 6 | 2 |
| `lib/features/anime/views/anime_player_controls.dart` | [features/anime/views/anime_player_controls.md](features/anime/views/anime_player_controls.md) | 25 | 2 |
| `lib/shared/utils/playback_time.dart` | [shared/utils/playback_time.md](shared/utils/playback_time.md) | 1 | 0 |
