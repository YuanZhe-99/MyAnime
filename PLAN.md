# PLAN.md — series linking, optional Kana tab, on-device categories and recommendations

> **This file is temporary.** It is the implementation plan for three changes requested on
> 2026-09-24. The agent that finishes the last milestone **must delete `PLAN.md`** once everything of
> lasting value in it has been moved into `doc/en-us/` and `doc/zh-cn/`, and no later than the 1.6.0
> release commit, so that the `v1.6.0` tag does not contain it. Until then, tick each checklist item
> in the same commit that lands it. The file is English-only on purpose: it is not part of the
> mirrored `doc/` tree.

**Baseline:** `master` at `2c956a7`, app `1.5.7+60`, `packages/myapps_data` at `v1.0.2`, Flutter
`3.44.2` (the CI pin). Nothing in this plan has been implemented yet.

**Target release: 1.6.0** (build 61), confirmed by the user on 2026-09-24. Every milestone ships in
it. The user also accepted every recommendation in [§9](#9-decisions) on the same day.

## How to use this plan

1. Follow `AGENTS.md` for every milestone: fetch both remotes first, read `doc/en-us/` before code,
   update the docs in both languages in the same commit, give every new declaration the Function
   Explanation Layer (Dart, Kotlin and Swift alike), and verify with `flutter analyze` — compared
   against the pre-change count, because there is pre-existing info-level noise — and `flutter test`.
2. Milestones are ordered by dependency. Each one leaves `master` consistent — code, tests and both
   doc trees — without needing a later one.
3. The version is settled: everything here ships as **1.6.0** ([§10](#10-finishing-and-releasing-160)).
   Milestones land on `master` as ordinary commits, with no version bump and no tag. Pushes still
   follow `AGENTS.md`: ask the user before every push, the release push included. Nothing in this
   plan authorises one.
4. Where this plan and the code disagree, the code wins: verify, then correct the plan and the docs.
5. The facts about Android AICore and Apple's Foundation Models framework were checked on 2026-09-24
   (sources in [§4.2](#42-platform-facts-checked-2026-09-24)). These APIs are beta or revised every
   year. Re-check them before starting M3, and update the date when you do.

## 0. Summary

| # | Request (2026-09-24) | What gets built | Milestones |
|---|---|---|---|
| 1 | Different seasons of one series are linked automatically, and the linking can be customised | A series index derived from titles and, later, from database relations; manual link, unlink and reorder, persisted per record | M1, M2 |
| 2 | The kana quick reference is off by default, now that MyNihongo!!!!! exists as its own app | The Kana tab is hidden unless the user turns it on in Settings | M0 |
| 3 | Automatic categorisation and recommendations through Android AICore and Apple Intelligence, off by default, built from the official docs and MyNihongo's implementation because there is no device to test on | Deterministic categories and recommendations, with an optional on-device model that fills gaps and writes reasons | M3, M4, M5 |

### Milestone checklist

- [x] **M0** Kana tab off by default ([§1](#1-m0--kana-tab-off-by-default))
- [x] **M1** Series linking core: model field, series index, series card, manual curation ([§2](#2-m1--series-linking-core))
- [x] **M2** Relation metadata from AniList, MyAnimeList and bangumi.tv feeding the series index; full builds ([§3](#3-m2--relation-metadata-full-builds))
- [x] **M3** On-device AI layer: Android AICore bridge, Apple Foundation Models bridge, Dart seam, Settings ([§4](#4-m3--on-device-ai-layer))
- [x] **M4** Automatic categories: taxonomy, genre mapping, AI gap-filling, user overrides, filter ([§5](#5-m4--automatic-categories))
- [ ] **M5** Recommendations: deterministic ranking, series continuation, AI reasons ([§6](#6-m5--recommendations))
- [ ] **M6** Wrap-up and the **1.6.0 release**: CI, privacy policy, glossary, version history, final doc pass, **delete `PLAN.md`**, version bump and tag ([§7](#7-ci-and-build)–[§10](#10-finishing-and-releasing-160))

**Release:** all milestones ship together as 1.6.0, as the user decided on 2026-09-24. If the user
later wants part of the work released sooner, ask which version that release gets; do not assume.

### Rules for every milestone

- **No sync-layer change.** All new synced data is new optional fields on the `Anime` record, which
  ride the existing whole-record three-way merge. No new `DataModule`, no new remote file, no change
  to `myapps_data` or to the four facades. `autoResolve` stays `false`.
- **Omit when empty.** A record that never touches a new feature serializes byte-identically to
  1.5.7, so `test/golden/goldens/myanime/` does not change. Unknown and unparseable values go to
  `extraJson`, including inside every new nested object. (§5.5 has the one deliberate exception.)
- **Derived data is never written in the background.** Automatic series grouping, category mapping
  and recommendations are computed when they are read. Only a user action writes a record, and every
  such write stamps `modifiedAt` with `DateTime.now().toUtc()` explicitly (mind the `copyWith` trap
  noted in `sync.md`). Cached public data fetched in the background goes through
  `AnimeStorage.patchExternalMeta`, which leaves `modifiedAt` alone.
- **Everything new is off by default**, except the series index, which replaces the existing
  prev/next-season navigation.
- **Generated text is never synced or backed up.** It lives in a per-device cache that is not
  registered in `lib/app/data_modules.dart`, exactly like `metadata_updates.json`.
- **Flavor gating is unchanged.** Every new *network* call (M2 only) is full-flavor and is reached only
  through paths already gated on `AppFlavor.isFull`. On-device AI makes no network call of its own,
  and it ships in both flavors (D2).
- **No new inline width breakpoints.** New pages and sheets take their layout from
  `shared/utils/adaptive_layout.dart`, and the decision is recorded in `adaptive-layout.md`.
- **New terms** go into `translation-guide.md` §5.2 in both languages ([§8.2](#82-glossary)).
- **Other clients.** Older MyAnime builds keep the new keys in `extraJson` and ignore them. If the
  SwiftUI port described in the MySeriesData repository is active, it must learn `seriesLink`,
  `categories` and `externalMeta.relations` as well. Remind the user of this when 1.6.0 ships.

### Non-goals

- No cloud model of any kind: no chat UI, and not Apple's Private Cloud Compute.
- No recommending titles outside the library, beyond the relation-backed "missing sequel" of M2.
- No on-device model on Windows (for example Windows AI APIs); the AI rows are absent there.
- No change to the WebDAV wire format, the remote layout, the backup format, or `.lock` semantics.
- Grouping the Manage list by series and a statistics breakdown by category are possible follow-ups,
  not part of this plan.

---

## 1. M0 — Kana tab off by default

### 1.1 Behaviour

- New device-local preference `kanaTabEnabled` in `storage_config.json`. Absent means **off**. The key
  is written as `true` when the user turns the tab on and removed when they turn it off, following the
  habit of storing only non-default preferences.
- The default applies to existing installs as well: after the update the tab disappears until it is
  turned back on. The 1.6.0 entry in `version-history.md` must say so (D3, [§9](#9-decisions)).
- Settings › General gains a switch, *Kana quick reference*, described as "Show the Kana tab. For kana
  practice and more, see MyNihongo!!!!!, a separate app." Text only, no store link (D6).
- Navigation shows **four** destinations by default (Home, Manage, Stats, Settings) and five, in the
  old order, when the tab is on.
- `/kana` is unreachable while the tab is off: the route redirects to `/home`.
- `kana_page.dart` itself does not change.

### 1.2 Implementation

| File | Change |
|---|---|
| `lib/features/anime/services/anime_storage.dart` | `getKanaTabEnabled()` / `setKanaTabEnabled(bool)` over `storage_config.json`, shaped like `getMetadataPrefetchCovers` |
| `lib/shared/providers/app_settings.dart` | `AppSettings.kanaTabEnabled` (default `false`) in the constructor, `copyWith` and `_loadPersisted`; `AppSettingsNotifier.setKanaTabEnabled` |
| `lib/shared/widgets/shell_scaffold.dart` | Becomes a `ConsumerWidget`. Replace the parallel `_routes` / `_destinations` pair with **one** list of destination records that carry their `path`, filtered by `kanaTabEnabled`; `_currentIndex` and `select` index into the filtered list. This keeps the existing invariant that a single list feeds both the bar and the rail. Update the "five destinations" comments. |
| `lib/app/router.dart` | The `/kana` route gets `redirect: (context, state) => ProviderScope.containerOf(context, listen: false).read(appSettingsProvider).kanaTabEnabled ? null : '/home'` |
| `lib/features/settings/views/settings_page.dart` | The switch, in the General section |
| `lib/l10n/app_*.arb` and the generated files | Two keys (`settingsKanaTab`, `settingsKanaTabDesc`) in en, ja, zh and zh_TW; run `flutter gen-l10n` |

Settings load asynchronously, so the first frame sees `kanaTabEnabled == false`. That is harmless:
the initial location is `/home`, so no real visit to `/kana` can be bounced before the value loads,
and `_currentIndex` is derived from the location rather than remembered.

### 1.3 Tests

- `test/shell_nav_ui_test.dart`: four destinations by default in both the bar and the rail; five, in
  order, with the preference on (override `appSettingsProvider`); the correct selected index for
  `/settings` in both cases; `/kana` redirects while off.
- Re-run `test/settings_two_pane_ui_test.dart`; the new row must not break its layout assertions.
- `test/kana_layout_ui_test.dart` stays as it is, since the page still exists.

### 1.4 Docs (both languages)

`architecture.md` (the app shell and the "five bottom tabs" core rule), `functions/app/router.md`,
`functions/shared/widgets/shell_scaffold.md`, `features/kana-reference.md` (off by default, how to
turn it on, and why), `functions/shared/providers/app_settings.md`,
`functions/features/settings/views/settings_page.md`,
`functions/features/anime/services/anime_storage.md`, `data-formats.md` (the inventory row and the
`storage_config.json` key list), `adaptive-layout.md` (the rail's destination count),
`doc/*/README.md`, and the `functions/INDEX.md` rows.

---

## 2. M1 — Series linking core

### 2.1 What exists today

`AnimeDetailPage._load` finds the previous and next "season" as records with an **identical
`displayTitle`** and a different `season` label, ordered by plain `String.compareTo`. So
`"Season 10"` sorts before `"Season 2"`, and a sequel whose title differs at all is never found —
`进击的巨人` against `进击的巨人 第二季`, or a Japanese title on one season and a Chinese one on the
next. There is no way to correct a wrong link or add a missing one.

### 2.2 Concepts

| Term | Meaning |
|---|---|
| **Series** | An ordered group of records that belong to one work: its seasons, split cours, films and OVAs. |
| **Curated series** | Records that share a `seriesLink.seriesId` created by a user action. Membership is exactly what the user said. |
| **Derived series** | A group the app computed from titles or relations. Nothing about it is stored. |
| **Auto record** | A record without a `seriesLink`. The app may place it in a derived or a curated series. |
| **Standalone record** | `seriesLink.standalone == true`: the user took it out of every series. It never joins a series, and nothing joins it. |

Curated series are fixed. Automatic grouping never moves a curated record and never merges two
curated series; it can only attach **auto** records to a series.

### 2.3 Data model

A new optional object on `Anime`, JSON key `seriesLink`, class `AnimeSeriesLink`:

```json
"seriesLink": {
  "seriesId": "0b5d0c1e-7f59-4f3e-9d5e-2a1c1b9e8f00",
  "order": 2
}
```

```json
"seriesLink": { "standalone": true }
```

- `seriesId` — a lowercase UUID v4, shared by every member of one curated series.
- `order` — an optional positive integer: the member's position after the user reordered the series.
- `standalone` — written only when `true`. If a hand-edited file carries both `standalone` and
  `seriesId`, `standalone` wins and `seriesId` is preserved untouched.
- The object is omitted when there is nothing to store (`hasAnyData`), like `localArchive`.
- It has its own `extraJson`, which `Anime.withPreservedUnknownJson` deep-merges the way it does for
  the other nested objects. Unparseable values — a numeric `seriesId`, a string `order` — are
  preserved verbatim and treated as absent.
- `Anime.copyWith` gains `seriesLink` and `clearSeriesLink`.

Why a shared group id rather than prev/next pointers: membership never references another record's
`id`. Deleting, merging or importing a record therefore cannot leave a dangling pointer, and linking
A to B never requires a second write to B to say that A comes next.

Where the field travels:

| Surface | Included? |
|---|---|
| `anime_data.json`, WebDAV sync, backups, ZIP export and import | **Yes**, verbatim |
| Local HTTP API | An optional, additive `series` summary ([§2.7](#27-interactions-to-handle)) |
| `.myanimeitem` share files | **No.** Stripped on export **and dropped on import.** A foreign `seriesId` means nothing in another library and would pin the imported record out of automatic grouping. (This differs from `localArchive`, which import carries through.) |
| Shared image cards | No |

No migration is needed. A 1.5.7 library gets derived series the first time a detail page opens, and
nothing is written.

### 2.4 The series index (automatic grouping)

A new pure-Dart service, `lib/features/anime/services/series_service.dart`, builds a `SeriesIndex`
from the whole library when asked. It writes nothing.

**Shared helpers.** Move `Anime1Service.seasonOrdinal` into a shared utility, for example
`lib/shared/utils/season_label.dart`, and have `Anime1Service` call it; its existing tests must keep
passing. Next to it, add `stripSeasonMarkers(String)`, which removes 第N季 / 第N期 / 第N部 / 第Nクール,
`N期`, `Season N`, `Nth Season`, `S2`, `Part N`, `Cour N`, `The Final Season`, 最终季 / 最終季 /
完结篇 / 完結編, 続編 / 续篇, the bracketed forms of all of these, and a trailing Roman numeral II–IV. It
must normalise full-width letters and digits first (`ゆるキャン△ SEASON２`).

A record's **season ordinal** is read from its titles when any title carries one, otherwise from its
`season` label, otherwise it is 1. Titles come first because most users never change the label from
the default `Season 1`.

A record's **base keys** are `AnimeSearchService.foldTitle(stripSeasonMarkers(t))` for every
non-empty title it has — `title`, `titleJa`, `externalMeta.titleRomaji`, `externalMeta.titleEn`, and
each synonym — keeping only keys of at least 2 Han or kana characters, or at least 4 Latin letters or
digits.

**Edges**, strongest first. An edge joins an auto record to another auto record or to a curated
record; standalone records get none, and two curated records never need one:

| Edge | Condition |
|---|---|
| E1 relation (from M2) | One record's `externalMeta.relations` names the other through a same-series relation ([§3.3](#33-use)) |
| E2 legacy | Identical `displayTitle` and a different trimmed `season` label — today's rule, kept so that nothing linked now stops being linked |
| E3 base title | The two records share a base key, **unless** they look like duplicates rather than seasons: the same season ordinal, and either the same `firstAirDate` day or no `firstAirDate` on one side. Duplicates are `duplicate_service.dart`'s job. |

**Grouping** must be deterministic, so that every device computes the same result from the same data:

1. Partition the library into curated series (by `seriesId`), standalone records and auto records,
   processing records in `id` order.
2. Run union-find over the auto records using the edges between auto records. The result is a set of
   auto components.
3. For each component, collect its edges into curated series and keep the strongest edge per series.
   If exactly one series holds the strongest edge, the whole component joins it. On a tie it joins
   none, because ambiguity must never fuse two user-curated series.
4. Components that joined nothing and have at least two members become derived series, keyed in
   memory only as `auto:<smallest member id>`.

Index records by `displayTitle`, by base key and by relation target in hash maps, so the build is
linear in the size of the library rather than quadratic.

**Order within a series.** Members with an `order` come first, ascending. The rest follow by derived
key: `firstAirDate` (missing sorts last), then season ordinal, then `createdAt`, then `id`. Reordering
writes a dense `order` to every member, so a mixed state arises only when an auto record joins
afterwards; it lands at the end, where the user can move it.

**Suggestions**, which are never automatic links, feed the manage sheet: records outside the series
whose best `AnimeSearchService.similarityRaw` between base keys reaches 0.6 (tune the value against the
fixtures), plus M2's spin-off and alternative relations, labelled as such. They catch pairs that a base
key cannot and that would be wrong to link automatically: `Love Live!` against `Love Live!
Sunshine!!`, the `物語` titles, and arc subtitles such as `鬼灭之刃 游郭篇`.

### 2.5 Manual curation

Every action is a pure function in a `SeriesEditor` (in `series_service.dart` or its own file) that
returns the records to write. The caller persists them through a new
`AnimeStorage.addOrUpdateAll(Iterable<Anime>)` — one load, one save, and one auto-sync notification.

- **Materialise on the first edit.** Any manual action on a derived series first gives every current
  member the same new `seriesId`. Nothing is ever materialised without a user action.
- **Link to series…** — the user picks a target record from a search over the library, with
  suggestions first. The current record takes the target's `seriesId`, materialising the target's
  series first if it is derived. A standalone record loses `standalone`. Auto records with edges to
  the moved record may follow it into the series; say so in the docs, because it is visible.
- **Remove from series** — writes `{"standalone": true}`. The remaining members are left alone.
- **Reorder** — materialise, then write a dense `order` to every member.
- **Let the app decide** — removes `seriesLink` from this record.
- **Add next season** — opens `/anime/edit` with an `extra` prefill: the titles copied, the season
  label incremented wherever `seasonOrdinal` can read it (`Season 1` → `Season 2`, `第一季` → `第二季`),
  and a pending link. The link is written only when the new record is saved, together with the
  materialised series, in one `addOrUpdateAll`.

Materialising writes several records, each an ordinary user edit, so a concurrent edit of one of them
on another device becomes an ordinary sync conflict. The conflict dialog (`_ConflictDialog` in
`webdav_config_page.dart`) currently shows only `modifiedAt`, the episode range and the watched
count, so a conflict about the series alone would look like two identical versions. Add one line
there when the two sides' `seriesLink` differ.

### 2.6 UI

- **Detail page.** The prev/next row becomes a *Series* card in `_buildDetailChildren` — the same
  place, so in the two-pane layout it lands in the right pane. It lists the members in order, each
  with its position, title, season label, status icon and progress, highlights the current one, and
  opens a member on tap. The prev/next buttons stay, now driven by the index's neighbours, which fixes
  the `"Season 10"` ordering. A menu on the card holds the [§2.5](#25-manual-curation) actions. When the
  record belongs to no series, the card is absent and *Link to series…* is reachable from the app bar.
- **Manage sheet.** A search field, the suggestions, and the current members with reorder handles.
  It is a bottom sheet on a narrow window and a dialog on a wide one, chosen through
  `adaptive_layout.dart`.

### 2.7 Interactions to handle

- **Duplicate merge** (`DuplicateService.merge`): the primary's `seriesLink` wins; if it has none,
  take the first fallback's. Members of a series with different season labels are not duplicates
  today; add a test that keeps it that way.
- **Share export and import** (`_stripPersonalData` in `file_open_service.dart`, and the statistics
  bundle export): strip `seriesLink` on export, and drop it on import.
- **Local API** (optional): an additive `series` object on `/anime/list` items — `key` (curated
  series only), `position` and `size`. If this is added, update `platform-notes.md`.
- **Deleting a record** needs no special handling, since the group id lives on the survivors.

### 2.8 Tests

- `test/anime_json_test.dart`: round trip; omitted when empty; unknown nested keys and unparseable
  values preserved; `withPreservedUnknownJson` keeps a newer build's `seriesLink` fields.
- A new `test/series_service_test.dart` over a realistic fixture library. It must link `進撃の巨人`,
  `進撃の巨人 Season 2` and `進撃の巨人 The Final Season`; `葬送的芙莉莲` and `葬送的芙莉莲 第二季`;
  `SPY×FAMILY` and `SPY×FAMILY Season 2`; `【我推的孩子】` and `【我推的孩子】第二季`; and legacy
  identical-title records labelled `Season 2` and `Season 10`, in the right order. It must **not**
  automatically link `機動戦士ガンダムSEED` with `機動戦士ガンダム 鉄血のオルフェンズ`, `Fate/Zero` with
  `Fate/stay night`, or `Love Live!` with `Love Live! Sunshine!!` (a suggestion only). Also cover:
  curated series never fuse; a tie attaches nothing; standalone records neither join nor attract;
  ordering; identical output for shuffled input.
- The `SeriesEditor` operations, including materialisation and "add next season".
- Duplicate merge, and the share strip and drop.
- A widget test of the series card in both detail layouts.

### 2.9 Docs

A new `features/series-linking.md` in both languages, which also records the Manage-list grouping as
a possible follow-up. Update `data-formats.md` (the field and its travel table),
`features/anime-tracking.md` (the detail layout mentions season navigation),
`functions/features/anime/models/anime.md`, `functions/features/anime/views/anime_detail_page.md`
(`_load` no longer compares strings), `functions/features/anime/services/anime1_service.md`
(`seasonOrdinal` moved), `features/share-and-import.md`, `features/duplicate-detection.md`, `sync.md`
(one paragraph: the field rides the whole-record merge, and materialising writes several records),
`adaptive-layout.md` (the manage sheet), `architecture.md` (repository structure), the new function
pages and the `INDEX.md` rows.

---

## 3. M2 — Relation metadata (full builds)

Titles alone cannot link a first season recorded under its Japanese title to a sequel recorded under
its Chinese one. The databases the app already queries know the answer.

### 3.1 Data

`AnimeExternalMeta.relations`, a list of `AnimeExternalRelation`:

```json
"relations": [
  {
    "source": "AniList",
    "type": "sequel",
    "targetUrl": "https://anilist.co/anime/12345",
    "title": "Sousou no Frieren 2nd Season",
    "format": "TV"
  }
]
```

`type` is normalised to `prequel`, `sequel`, `parent`, `sideStory`, `summary`, `spinOff`,
`alternative` or `other`, and the source's raw value is kept in the entry's `extraJson` when it maps
to `other`. This is public metadata: it syncs, it is backed up, and it stays in share files, like the
rest of `externalMeta`. `mergedWith` replaces one source's relations when a fresh fetch supplies any
and keeps the other sources', as it already does for ratings.

### 3.2 Sources

| Source | How | Extra cost |
|---|---|---|
| AniList | Add `relations { edges { relationType(version: 2) node { id type format siteUrl title { romaji english native } } } }` to the **by-id** query; keep nodes whose `type` is `ANIME` | None: same request |
| MyAnimeList (Jikan) | `fetchByUrl` already calls `/anime/{id}/full`, whose `relations` the mapper ignores today; map the entries whose `type` is `anime` | None |
| bangumi.tv | `GET https://api.bgm.tv/v0/subjects/{id}/subjects`, anime (`type == 2`) only; map 前传, 续集, 主线故事, 番外篇, 总集篇, 衍生 and 不同演绎, after checking those strings against the live API | One request per refresh |

Relations arrive through `fetchByUrl` and `refreshAll` — the detail page's refresh chip and the
background updater — and are written through `AnimeStorage.patchExternalMeta`, never bumping
`modifiedAt`. Applying a search result does not fetch them; the next refresh fills them in. If that
proves too slow, one by-id fetch right after applying a result is acceptable, within the existing
rate limits. Re-check the updater's pacing with bangumi's extra request included, and run the
search-source validation script in `tool/` against the changed queries.

### 3.3 Use

- **E1 edges** ([§2.4](#24-the-series-index-automatic-grouping)): a relation of type `prequel`,
  `sequel`, `parent`, `sideStory` or `summary` whose canonical target (`anilist:<id>`, `mal:<id>` or
  `bgm:<id>`, treating bgm.tv, bangumi.tv and chii.in as one) matches another record's `infoUrl` or
  any of its `externalMeta.ratings[].sourceUrl`. `spinOff` and `alternative` produce suggestions only.
- **Missing-sequel hint** on the series card: a `sequel` whose target is not in the library, shown as
  "Next: <title> (AniList)". It opens the create page through the same `extra` prefill that M1's
  "Add next season" gives `/anime/edit` (today that route takes no `extra`; only `/anime/edit/:id`
  does, for `autoSearch`). Full builds also start the online search with the title, as `autoSearch`
  does; store builds get the title pre-filled and no search. The relation itself may reach a store
  build through sync; only the lookup is gated.

### 3.4 Tests and docs

Mapper tests for each source, extending `test/anime_search_test.dart`; `mergedWith` keeping the other
sources' relations; E1 grouping in `series_service_test.dart`; JSON preservation of unknown relation
types. Docs: `data-formats.md` (the `externalMeta` shape and field list),
`features/multi-source-search.md` (the "What each source supplies" table and the refresh section),
`features/metadata-auto-update.md`, `features/series-linking.md`, and the function pages.
`PRIVACY_POLICY.md` lists services rather than endpoints, so it needs no change unless the user wants
the bangumi endpoint named.

---

## 4. M3 — On-device AI layer

### 4.1 Policy

Adapted from MyNihongo's `doc/en-us/features/ai-assist.md`, which has run on real hardware. Every rule
is enforced in code and covered by a test, not left as a convention:

1. **Off by default.** `onDeviceAiEnabled` is absent from `storage_config.json` until the user turns
   the switch on.
2. **The switch is a gate.** While it is off, the method channel is never called, not even for status.
3. **Status is re-checked before every use.** The system can remove a model between two requests.
4. **Generated output is labelled** "Generated on this device — may be wrong", above the text.
5. **The fallback is the app.** Every AI output has a deterministic counterpart that is shown first and
   works without a model ([§5](#5-m4--automatic-categories), [§6](#6-m5--recommendations)).
6. **Nothing generated is synced or backed up.** Results live in a per-device cache ([§5.4](#54-cache)).
7. **Nothing is downloaded on the user's behalf.** On Android the model download starts only from the
   Download button and is performed by AICore. On Apple platforms the system manages the model.
8. **On-device only.** Never Apple's Private Cloud Compute (`PrivateCloudComputeLanguageModel`, new in
   OS 27) and never any other remote model. The privacy policy promises that nothing leaves the device.

### 4.2 Platform facts (checked 2026-09-24)

**Android: ML Kit GenAI over AICore (Gemini Nano).**

- `com.google.mlkit:genai-prompt:1.0.0-beta4` (2026-07-21) is the current release. It is the floor for
  Gemini Nano v4 devices such as the Pixel 11 and the Galaxy Z Flip8 / Z Fold8 family. beta3
  (2026-07-14) added system instructions, a thinking mode and a Structured Output API
  (`genai-schema` and `genai-schema-compiler` `1.0.0-alpha1`, which need KSP 2.3.6 or later). This plan
  does **not** use structured output: it is alpha, and adding KSP is build risk under
  `android.builtInKotlin=false`.
- API 26 or later. The APIs refuse to run on an unlocked bootloader. Input must stay under about 4,000
  tokens.
- Inference is allowed only while the app is the top foreground app. Background use, including from a
  foreground service, fails with `BACKGROUND_USE_BLOCKED`. AICore enforces a per-app quota: `BUSY`
  (back off exponentially) and, for sustained use, `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`.
- `Generation.getClient()` without a configuration asks for exactly one model variant (stable, full
  size). Devices serve different variants — MyNihongo measured a Pixel 10 serving only stable/full and
  a Galaxy Z Fold 8 serving only stable/fast — so **probe all four** combinations of
  `ModelReleaseStage` (STABLE, PREVIEW) and `ModelPreference` (FULL, FAST), and keep the first that
  serves.
- R8 broke ML Kit twice in MyNihongo's release builds, and both keep rules are needed ([§4.4](#44-android)).
- MyNihongo builds this client on exactly MyAnime's toolchain — AGP 9.1.1, Kotlin Gradle Plugin
  2.2.20, `android.builtInKotlin=false` — even though beta4 depends on `kotlin-stdlib` 2.3.21.
- Sources: <https://developers.google.com/ml-kit/genai>,
  <https://developers.google.com/ml-kit/genai/prompt/android/get-started>,
  <https://developers.google.com/ml-kit/genai/prompt/android/structured-output>,
  <https://developers.google.com/ml-kit/release-notes>, and MyNihongo's `doc/en-us/android-aicore.md`
  (last verified there on 2026-09-04, with field notes from two devices).

**Apple: the Foundation Models framework (Apple Intelligence).**

- iOS, iPadOS and macOS 26.0 or later. `SystemLanguageModel.default.availability` is `.available` or
  `.unavailable(reason)`, where the reason is `deviceNotEligible`, `appleIntelligenceNotEnabled` or
  `modelNotReady`. Availability also depends on the region.
- `LanguageModelSession(model:instructions:)` and `respond(to:options:)`. Guided generation uses
  `@Generable` or, for a vocabulary known only at run time,
  `DynamicGenerationSchema(name:description:anyOf:)` inside
  `DynamicGenerationSchema(arrayOf:minimumElements:maximumElements:)`.
- A `.contentTagging` use case exists, but it produces free-form tags. For a fixed vocabulary, Apple's
  guidance is to use the general model instead.
- The listed languages include en-US, ja-JP and zh-CN; Traditional Chinese is not in that list. Check
  at run time with `supportsLocale(_:)`. Input in an unsupported language throws
  `unsupportedLanguageOrLocale`. Apple recommends stating the locale in the instructions with the
  exact phrase "The person's locale is <identifier>."
- The context window is 4,096 tokens; `contextSize` and `tokenCount(for:)` exist from 26.4. Calls made
  in the background are rate limited (`rateLimited`).
- Errors on the 26 SDK are `LanguageModelSession.GenerationError`: `exceededContextWindowSize`,
  `assetsUnavailable`, `guardrailViolation`, `unsupportedGuide`, `unsupportedLanguageOrLocale`,
  `decodingFailure`, `rateLimited`, `concurrentRequests` and `refusal`. OS 27 deprecates it in favour of
  `LanguageModelError`, `SystemLanguageModel.Error` and `LanguageModelSession.Error`; Apple notes that
  apps built with Xcode 26 keep receiving the old type until they are rebuilt with Xcode 27.
- The model changes with OS updates — 26.0 to 26.3, 26.4 and 27.0 each have their own — so prompts must
  be re-checked against each model version.
- CI's `macos-latest` label is the macOS 26 arm64 image, whose default is **Xcode 26.6** (image
  `20260907`); Xcode 27 is a public preview and is not installed. **Write against the 26 SDK.** Any
  27-only symbol needs a compile-time guard that is false under Xcode 26.
- Sources: <https://developer.apple.com/documentation/foundationmodels> and its pages for
  `SystemLanguageModel`, `DynamicGenerationSchema`, `LanguageModelSession.GenerationError` and
  `LanguageModelError`; the articles "Supporting languages and locales with Foundation Models",
  "Categorizing and organizing data with content tags" and "Foundation Models updates"; Apple's
  acceptable-use requirements for the framework; and <https://github.com/actions/runner-images> for the
  Xcode versions.

**Store policy.** Google Play's AI-Generated Content policy names productivity apps that use AI to
improve an existing feature as out of scope. Labelled output and a way to hide a suggestion
([§6.4](#64-ui)) are still the right shape. Apple's acceptable-use requirements for Foundation Models
prohibit, among other things, generating adult content, so the taxonomy has no such category
([§5.1](#51-taxonomy)).

### 4.3 Architecture

| Path | Role |
|---|---|
| `lib/features/ai/services/genai_backend.dart` | The Dart seam: enums, status report, the backend interface and its `MethodChannel` implementation |
| `lib/features/ai/services/on_device_ai_service.dart` | The gate: the switch, status before every use, a single-flight queue, a 45-second timeout, lifecycle handling |
| `lib/features/ai/services/output_validation.dart` | Shared parsing: strip code fences and Markdown, read line formats, check the script |
| `lib/features/ai/services/prompt_templates.dart` | Versioned prompt templates ([§5.3](#53-ai-classification), [§6.3](#63-ai-reasons-optional)) |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | The Settings rows ([§4.6](#46-settings)) |
| `android/app/src/main/kotlin/com/yuanzhe/my_anime/GenAiChannel.kt` | The Android bridge |
| `packages/on_device_ai_apple/` | A local Flutter plugin for iOS and macOS with a shared Darwin source |

Policy — the switch, the prompts, the parsing — stays in Dart, where it can be tested without a
device; native code is a pipe. Reuse MyNihongo's names (`GenAiBackend`, `MethodChannelGenAiBackend`,
`GenAiStatus`, `GenAiFailure`, `GenAiStatusReport`) so the two apps read alike, and extend them:

- **Channel:** `com.yuanzhe.my_anime/genai` on all three platforms.
- `platformMayHaveOnDeviceModel` is true on Android, iOS and macOS. Everywhere else the backend answers
  `unsupported` without touching the channel, and Settings shows no AI rows.
- **Methods:** `status {feature, force, preferFast}`, `info`, `download` (Android only),
  `generate {instructions, prompt, maxOutputTokens, temperature, topK}`,
  `choose {instructions, prompt, options, maxItems}`, `cancel` and `prewarm`. `choose` is native on
  Apple, where it uses constrained decoding; on Android the Dart backend implements it as `generate`
  plus the line parser. Both results pass through the same Dart validation.
- **Statuses:** MyNihongo's `unsupported`, `unavailable`, `unreachable`, `downloadable`, `downloading`,
  `available` and `unknown`, plus `notEnabled` for `appleIntelligenceNotEnabled` — the user can fix that
  one in system settings, so it gets its own wording. Apple's `modelNotReady` maps to `downloading`.
- **Failures:** MyNihongo's `unavailable`, `busy`, `failed`, `cancelled`, `tooLong` and `timeout`, plus
  `background`, `quota`, `guardrail` and `unsupportedLanguage`.
- A `MissingPluginException` on iOS or macOS becomes `unreachable` with the detail "channel not
  registered", never `unsupported`. That is how a plugin that failed to register gets noticed.
- **Queue:** one request at a time. Interactive requests (recommendation reasons) go ahead of background
  ones (classification). Background work runs only while the app is `AppLifecycleState.resumed` — which
  Android's foreground rule requires and Apple's background rate limit rewards — the way
  `MetadataUpdateService` already gates itself, and it pauses otherwise. On `busy`, back off
  exponentially up to five minutes; on `quota`, stop for the day; on `background`, wait for the next
  resume.

### 4.4 Android

- In `android/app/build.gradle.kts`, add `implementation("com.google.mlkit:genai-prompt:1.0.0-beta4")`
  and `implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")`, with comments on why
  the versions are exact, as MyNihongo has. Proofreading is not needed.
- **minSdk.** The libraries require API 26, and MyAnime uses `flutter.minSdkVersion` (24). Set
  `minSdk = 26` in `defaultConfig`, with a comment saying why, as MyNihongo does — approved by the user
  (D1). This drops Android 7.0 and 7.1, and the 1.6.0 release notes must say so. Do not use
  `tools:overrideLibrary` with run-time guards instead: that risks class-verification crashes on API 24
  and 25.
- Create `android/app/proguard-rules.pro` with MyNihongo's rules and its explanatory comments, and add
  `proguardFiles("proguard-rules.pro")` to the release build type:

  ```proguard
  -keep class com.google.mlkit.** { *; }
  -keep class com.google.android.gms.internal.mlkit_** { *; }
  -dontwarn com.google.mlkit.**
  -keep class kotlinx.coroutines.** { *; }
  -dontwarn kotlinx.coroutines.**
  ```

- In `AndroidManifest.xml`, add `<queries><package android:name="com.google.android.aicore"/></queries>`
  so that `info` can report the AICore version. Without it the package is invisible on API 30 and later.
- `GenAiChannel.kt` ports MyNihongo's class: the four-variant probe, `status`, `info` (AICore version,
  device, and `GenAiUtils.isAiCoreCompatible` guarded as the internal API it is), `download` with
  progress callbacks, `generate`, `cancel`, the single in-flight job, and error mapping by
  `GenAiException.errorCode`. Before mapping `BACKGROUND_USE_BLOCKED` and
  `PER_APP_BATTERY_USE_QUOTA_EXCEEDED` to `background` and `quota`, confirm those constants exist by
  running `javap -public` against the beta4 AAR. Use the log tag `MyAnimeGenAi`, and log exceptions,
  never prompts. Close the clients from `MainActivity.onDestroy`.
- Register the channel in `MainActivity.configureFlutterEngine`, next to the share and file-open
  channels.

### 4.5 Apple (iOS and macOS)

- **Where the code lives.** A local plugin, `packages/on_device_ai_apple/`, a normal tracked directory
  rather than a submodule. Generate it with `flutter create --template=plugin --platforms=ios,macos`
  under the pinned Flutter 3.44.2, then switch it to `sharedDarwinSource: true` so one Swift source
  serves both platforms. It registers the `com.yuanzhe.my_anime/genai` handler and exposes no Dart API.
  This avoids hand-editing either `project.pbxproj` and uses the same integration path as every other
  plugin: the repo commits no Podfile and no Swift package references, and the Flutter tool adds them
  at build time. If the plugin does not integrate in CI, fall back to hosting the handler in each
  Runner's app delegate, the way the macOS `dock` channel already works; that needs no project-file
  edits either.
- **Deployment targets stay** at iOS 13.0 and macOS 13.0. Every FoundationModels reference sits inside
  `#if canImport(FoundationModels)` and `@available(iOS 26.0, macOS 26.0, *)`. Older systems answer
  `unsupported`, which Settings words as "Needs iOS 26 or macOS 26 with Apple Intelligence".
- **Weak linking must be verified, not assumed.** An app that strong-links FoundationModels will not
  launch on iOS 18 or macOS 15 and earlier. Declare `s.weak_frameworks = 'FoundationModels'` in the
  podspec, plus the equivalent linker setting if the build uses Swift Package Manager, and then check
  the built binaries: `otool -l` must list FoundationModels under `LC_LOAD_WEAK_DYLIB`. Add that check
  to CI ([§7](#7-ci-and-build)). If the runner has an iOS 18 simulator runtime, a boot-and-launch smoke
  test is worth one `workflow_dispatch` run.
- **Status:** map `availability`, and report in `info` whether `supportsLocale()` accepts the app's
  current locale, along with the OS version.
- **Generation:** a new `LanguageModelSession` for every request, so earlier turns cannot leak into
  later answers; greedy sampling for classification; `prewarm` before a batch; and, whenever prose is
  requested, instructions that include "The person's locale is <identifier>."
- **`choose`:** a `GenerationSchema` built from
  `DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(name:description:anyOf: options),
  minimumElements: 0, maximumElements: n)`, read back from the returned `GeneratedContent`. Verify the
  exact initializer and accessor names, and the `GenerationOptions` sampling API, against the
  Xcode 26.6 SDK.
- **Errors:** map `GenerationError` to the Dart failures — `rateLimited` → `quota`,
  `concurrentRequests` → `busy`, `guardrailViolation` and `refusal` → `guardrail`,
  `unsupportedLanguageOrLocale` → `unsupportedLanguage`, `exceededContextWindowSize` → `tooLong`, and
  anything else → `failed`.
- No entitlement, `Info.plist` key or usage description is needed. Do **not** add the Private Cloud
  Compute entitlement.

### 4.6 Settings

A new section after General, *Categories & recommendations*:

| Row | `storage_config.json` key | Platforms |
|---|---|---|
| Switch: Automatic categories | `autoCategoriesEnabled` | All |
| Switch: Recommendations | `recommendationsEnabled` | All |
| Switch: Use on-device AI, with a body saying what it is used for and that nothing leaves the device | `onDeviceAiEnabled` | Android, iOS, macOS |
| Model status row: Download (Android, when downloadable, with progress in MB), Check again (unavailable, unreachable, notEnabled), and "Turn on Apple Intelligence in Settings" (notEnabled) | — | Android, iOS, macOS |
| Switch: Prefer the faster model — shown only when the probe found both sizes | `onDeviceAiPreferFast` | Android |
| Notes: who downloads the model, and why there is no Remove button (the model belongs to AICore or to Apple Intelligence and is shared with other apps) | — | Android, iOS, macOS |
| A collapsed *Technical details* tile: raw status, detail, variant, model name, token limit, AICore or OS version | — | Android, iOS, macOS |
| *Categorise now*, with an "N of M" count, once M4 lands | — | Android, iOS, macOS |

All keys are device-local, written only when on, and exposed through `AppSettings`. The AI switch is
enabled only while at least one of the two feature switches is on. The section follows the existing
two-pane Settings rules. M3 builds the AI rows and M4 and M5 add their own switches; until M4 lands,
keep the section hidden on `master`, because an AI switch that nothing uses is noise.

### 4.7 Tests

Use a fake backend throughout, as MyNihongo's `test/genai_backend_test.dart` and
`test/ai_assist_service_test.dart` do: with the switch off there are zero channel calls; status mapping
for every reply shape, including unknown values and missing fields; `MissingPluginException` handling;
queue priority; pausing and resuming with the lifecycle; the timeout; backoff and the quota stop; and
the Settings rows per platform (`debugDefaultTargetPlatformOverride`), including that Windows shows no
AI rows.

### 4.8 Verification without devices

There is no test device for either platform. What can be verified, and how:

- Everything in Dart, with `flutter test`.
- Android: `flutter build apk --release --dart-define=FLAVOR=full` and
  `flutter build appbundle --release --dart-define=FLAVOR=store` on the Windows host. Together they
  check the Kotlin compile, dependency resolution, the manifest merge against minSdk, and R8 with the
  keep rules. An emulator is not expected to serve Gemini Nano, so at most it exercises the
  unavailable path.
- iOS and macOS: a `workflow_dispatch` run of the CI jobs, which checks the compile under Xcode 26.6,
  plugin registration, and the weak-link check.
- The docs must say plainly that the features are off by default and **not verified on a device**,
  with the date. Put a manual device checklist in `doc/en-us/on-device-ai.md` for when hardware
  becomes available: status rows, the download, one categorisation, recommendation reasons in all four
  UI languages, nothing running with the switch off, a release build (R8), and the app sent to the
  background mid-request.

### 4.9 Docs

A new `doc/en-us/on-device-ai.md` in both languages, holding the platform facts above with a **Last
verified** date and a "how to refresh this page" section, as MyNihongo's `android-aicore.md` does — plus
the Apple half that MyNihongo does not have. Update `platform-notes.md` (Android dependencies, minSdk,
R8, the `<queries>` entry; the Apple plugin, weak linking, the Xcode requirement), `ci-cd.md` (the
weak-link step and the release-build verification), `architecture.md` (the new directories and the
plugin), `data-formats.md` (the new keys), the function pages and `INDEX.md`.

---

## 5. M4 — Automatic categories

### 5.1 Taxonomy

`lib/features/anime/models/anime_category.dart` holds a const, versioned list
(`categoryTaxonomyVersion = 1`) of stable ids, each with a one-line English description for prompts.
Localized labels live in the ARB files. The v1 list, approved as proposed (D4):

`action`, `adventure`, `comedy`, `drama`, `romance`, `slice_of_life`, `fantasy`, `isekai`, `sci_fi`,
`mecha`, `mystery`, `suspense`, `horror`, `psychological`, `supernatural`, `sports`, `music` (idols
included), `school`, `historical`, `military`, `gourmet`, `healing` (iyashikei), `magical_girl`.

There is no adult or fan-service category, for Apple's acceptable-use rules and the models'
guardrails.

### 5.2 Resolution, per record

1. **User override:** the record's `categories` field ([§5.5](#55-user-override-field)), whenever it
   is present, even empty.
2. **Mapped:** `externalMeta.genres` through a synonym table covering AniList's fixed genre list,
   MyAnimeList's genres and themes, and common bangumi.tv tags (恋爱 → romance, 校园 → school,
   日常 → slice_of_life, 异世界 → isekai, 机战 → mecha, 治愈 → healing, 美食 → gourmet, and so on). Unknown
   tags are ignored. This works on every platform, including Windows, and in store builds that received
   `externalMeta` through sync.
3. **AI-suggested:** only for records where the first two give nothing, and only while AI is on and a
   model is serving.

The effective list remembers which of the three produced it. AI-suggested chips carry a sparkle icon
and the "may be wrong" tooltip.

### 5.3 AI classification

- **Input:** the work only — every known title (capped), format, year, `AnimeType`, episode count,
  studios, raw genres and synonyms. Never notes, never ratings.
- **Prompt:** a versioned template in `prompt_templates.dart`, with instructions in English: choose at
  most three ids from the list, use only the facts given, answer `NONE` when unsure, one line per item.
- **Output:** Android parses `<item>: <id>, <id>` lines; Apple uses `choose` with the ids plus `none`.
  Either way, Dart keeps only known ids, removes duplicates and caps the list at three. A reply that
  ignores the format is dropped whole.
- **Batch size 1** on both platforms to begin with. MyNihongo measured roughly 20–30 seconds for a
  short Prompt API answer on a Pixel 10. Classifying several records per prompt is a tunable to revisit
  once latency has been measured on a device, not a starting assumption.
- **When:** while the app is resumed, with automatic categories and AI both on and a model available,
  a trickle of at most 20 records per foreground session, plus *Categorise now* in Settings. A record
  is queued again whenever its input fingerprint changes.

### 5.4 Cache

`ai_insights.json`, under `AnimeStorage.getAppDir()`, is owned by one class in the style of
`MetadataCache`: tolerant load, atomic pretty-printed writes, no call to
`AutoSyncService.notifySaved`, and no registration in `data_modules.dart` — so it is neither synced nor
backed up — while still moving with a storage-path change.

```json
{
  "version": 1,
  "categories": {
    "<animeId>": {
      "fingerprint": "<sha256 of the inputs, taxonomy version, prompt version and model identity>",
      "ids": ["romance", "school"],
      "status": "ok",
      "model": "stable/full · nano-v3",
      "generatedAt": "2026-10-01T12:00:00.000Z"
    }
  },
  "hiddenRecommendations": ["<animeId>"]
}
```

`status` is `ok`, `none` (the model answered NONE) or `skipped` (a guardrail or an unsupported
language — not retried until the fingerprint changes). Entries for deleted records are pruned on load.

### 5.5 User override field

`Anime.categories` is a JSON list of id strings. **Absent** means automatic. **Present, even as
`[]`,** means this is the user's own classification, and it wins. This is the one new field whose
empty value is meaningful, so the omit-when-empty habit does not apply to it; document the exception.
Ids this build does not know are kept and written back, but not shown. The field is not personal
data: it syncs, it is backed up, and it stays in share files (D5).

Editing: a *Categories* row on the detail page — with the other chips in `_buildHeaderChildren`, or as
a card; decide against the two-pane layout — opens a sheet of `FilterChip`s. Saving writes
`categories` as a user edit, and *Reset to automatic* removes the key. Duplicate merge takes the
primary's value, or else the first fallback's.

### 5.6 UI

- Category chips on the detail page, only while automatic categories are on.
- On the management page, a category filter next to the local-archive filter, behaving the same way:
  view state only, applied to the quarter pages, "Other" and search results.

### 5.7 Tests and docs

Taxonomy and ARB completeness (every id has a label in all four languages); the mapping table; the
resolution order; golden prompt strings; the parser, against malformed, partial, unknown-id and NONE
replies; fingerprinting; cache load, save and prune; the `categories` JSON round trip, including `[]`
and unknown ids; a widget test of the filter. Docs: a new `features/categories-and-recommendations.md`
in both languages, `data-formats.md` (the field, the cache file row, the keys),
`features/home-management-statistics.md`, `features/share-and-import.md`,
`features/duplicate-detection.md`, `backup-restore.md` (the cache is not backed up), and the function
pages.

---

## 6. M5 — Recommendations

### 6.1 Scope

Recommendations answer "what should I watch next **from my library**". The model is never asked to
name titles: a small on-device model does not reliably know what exists, and anything it invented would
be a dead end. Two library-adjacent sources are in scope because they are facts rather than guesses:
the next member of a series (M1) and, in full builds, a missing sequel from relation data (M2).

### 6.2 Deterministic ranking

`lib/features/recommendations/services/recommendation_service.dart`, in pure Dart. The weights are
named constants in one place, with tests.

- **Preference signal** per record: with a rating, `(effectiveOverall − 6) / 4`, clamped to −1…1;
  without one, completed counts `+0.5`, dropped `−0.7`, and anything else 0.
- **Taste profile:** the preference-weighted sum of the effective category vectors, normalised. Studio
  affinity is the preference sum per studio.
- **Candidates:** records not started, or being watched with aired but unwatched episodes, that are not
  hidden. Within a series, only its earliest unfinished member is a candidate — never recommend season
  3 to someone who has not started season 1.
- **Score:** `3.0` when the previous member of its series is completed (`+1.0` more if that member was
  rated 8 or higher); `2.0 ×` the cosine of profile and categories; `0.5 ×` studio affinity, capped at
  1; `0.3 ×` (external average − 7), clamped to ±2; `0.8` when being watched with aired unwatched
  episodes; `0.4` when currently airing.
- **Cold start** (no ratings and nothing completed): series continuation first, then the external
  score, then the most recently added.
- **Reason chips** come from the largest contributions: "Next after <title>", "Like titles you rated
  highly: romance, school", "Same studio as <title>", "AniList 8.9".

### 6.3 AI reasons (optional)

With AI on and a model available, the top eight candidates and a compact profile (the top categories
and studios, and the three most recently completed titles with their ratings) go to the model, which
picks up to three by number and writes one short reason for each in the UI language. Dart validates the
reply: known numbers only, no duplicates, at most 140 characters, Markdown stripped, and a script check
(CJK for zh, zh_TW and ja; mostly Latin for en). When the script is right but the Chinese variant is
not, convert with the existing `chinese_convert.dart` instead of discarding the reason. On Apple, when
`supportsLocale` rejects Traditional Chinese but accepts Simplified, ask for Simplified and convert;
when it rejects the UI language outright, skip AI reasons. Anything invalid falls back to the
deterministic list and chips. The deterministic list renders at once and the reasons fill in when they
arrive; nothing waits on the model. Reasons are kept in memory for the session only.

### 6.4 UI

- An app-bar action on Home, next to the list-columns button and shown only while recommendations are
  on, opens `/recommendations`.
- That page is a list of cards — cover, title, reason chips, and the labelled AI reason when there is
  one — laid out with `listColumnCount` like the other lists. A tap opens the detail page. *Not
  interested* hides a candidate; hidden ids live in `ai_insights.json`, so hiding is per device, and
  the docs must say so.
- A missing-sequel card (M2) can appear in the same list, clearly marked as not in the library.

### 6.5 Tests and docs

Scoring on fixture libraries, including cold start and the earliest-unfinished-member rule; reason
chips; validation of AI replies, including the script and variant checks; a widget test of the page with
and without AI. Docs: `features/categories-and-recommendations.md`, `architecture.md` (the route and the
directory), the router docs, the function pages, and `adaptive-layout.md` (the new page).

---

## 7. CI and build

- Android needs no workflow change beyond what minSdk and the new dependencies require; the release APK
  and AAB jobs already exercise R8.
- iOS and macOS: after each build, add a step that fails unless `otool -l` lists FoundationModels as
  `LC_LOAD_WEAK_DYLIB` in the app binary. Quote the macOS app name carefully, because it contains
  `!!!!!`. Keep building with the runner's Xcode 26.x until the user decides to move to Xcode 27.
- As `ci-cd.md` asks, validate any workflow change with a `workflow_dispatch` run before the next tag.

## 8. Cross-cutting

### 8.1 Privacy policy

Update `PRIVACY_POLICY.md` and the in-app policy page (`privacy_policy_page.dart`) together when M3
ships. They should say: the feature is optional and off by default; inference stays on the device; which
text is given to the model (titles, genres and studios, plus ratings and viewing status for
recommendations); on Android the model download is performed by AICore from Google, and only when the
user taps Download; on Apple devices the model is part of Apple Intelligence and managed by the system;
generated results stay on the device and are neither synced nor backed up; no cloud model is used. No
change to the store privacy declarations is expected, since no data leaves the device; re-read them when
shipping.

### 8.2 Glossary

For `translation-guide.md` §5.2, in both languages:

| English | 简体中文 | Note |
|---|---|---|
| series | 系列 | A work's seasons, films and OVAs. Not the anime1.me "series index" (系列索引). |
| curated series | 手动关联的系列 | Membership set by the user |
| standalone | 独立（不归入系列） | Taken out of every series |
| next season | 下一季 | |
| category | 分类 | This app's taxonomy; distinct from genre (类型标签), a source's own tag |
| automatic categories | 自动分类 | The Settings switch |
| recommendation | 推荐 | |
| on-device AI | 端侧 AI | Matches MyNihongo |
| Apple Intelligence, AICore, Foundation Models | not translated | Product and framework names |

The Japanese and Traditional Chinese ARB strings should reuse MyNihongo's wording wherever MyNihongo
already has the same string.

### 8.3 Version history

One `version-history.md` entry for 1.6.0, in both languages and in the existing style. Call out: the
Kana tab is now off, and how to turn it back on; series linking replaces the old prev/next rule; the new
synced fields; that the AI features are off by default and not yet verified on a device; and the new
Android 8.0 minimum (D1).

### 8.4 Docs index

`doc/*/README.md` lists every new page. `AGENTS.md`'s "Where to read what" table already covers
`features/*.md`, but the new top-level `on-device-ai.md` needs its own row — "On-device AI platform
facts: AICore, Foundation Models, device checklist" — and a place in the concept-doc list under
"Documentation maintenance".

## 9. Decisions

On 2026-09-24 the user accepted every recommendation this plan made, so each row is now a requirement.
If implementation turns up a reason to revisit one, stop and ask the user rather than deviating.

| # | Question | Decision | Why |
|---|---|---|---|
| D1 | Raise Android `minSdk` from 24 to 26 for ML Kit GenAI, dropping Android 7.0 and 7.1? | **Yes** | As MyNihongo did; the alternative risks crashes on API 24–25 ([§4.4](#44-android)) |
| D2 | Offer categories, recommendations and on-device AI in the store flavor too? | **Yes** | The app makes no network call for them; AICore's model download is the system's |
| D3 | Hide the Kana tab for existing users as well as new installs? | **Yes** | An absent key means off; the 1.6.0 notes say how to turn it back on |
| D4 | Is the v1 category list in [§5.1](#51-taxonomy) right? | **Yes, as proposed** | Ids are stable once shipped |
| D5 | Keep `categories` in `.myanimeitem` share files? (`seriesLink` is always stripped.) | **Yes** | It holds no personal data |
| D6 | Mention MyNihongo!!!!! in the Kana switch's description, without a store link? | **Yes** | Points learners to the full app without a store dependency |

## 10. Finishing and releasing 1.6.0

**Before the release**, all of these must hold:

1. Every checklist item above is ticked, and every milestone's docs exist in both `doc/en-us/` and
   `doc/zh-cn/`, with matching headings and tables.
2. Everything in this file that is still true and useful — the platform facts, the device checklist,
   the decisions in [§9](#9-decisions) and their reasons — is in `doc/`, not only here.
3. `flutter analyze` shows no new issues against the baseline, `flutter test` passes, the Android
   release builds succeed, and a `workflow_dispatch` CI run is green, weak-link check included.

**The release**, following "Release, version, commit, tag, push" in `AGENTS.md`. The version is
already confirmed; do these steps only once the user has also confirmed pushing the release:

4. Move every version location from `1.5.7` (all six are aligned today) to `1.6.0`:
   - `pubspec.yaml`: `version: 1.6.0+61` and `msix_config.msix_version: 1.6.0.0`;
   - `installer.iss`: `AppVersion=1.6.0`, `VersionInfoVersion=1.6.0.0` and
     `VersionInfoProductVersion=1.6.0`, with the output file names still derived from
     `{#SetupSetting("AppVersion")}`;
   - `lib/features/anime/services/anime_search_service.dart`: the `userAgent` literal becomes
     `'MyAnime/1.6.0 (anime tracker)'`.
5. Add the 1.6.0 `version-history.md` entry in both languages ([§8.3](#83-version-history)), then re-run
   the verification from step 3.
6. **Delete `PLAN.md`** no later than this release commit, so that the `v1.6.0` tag does not contain it,
   and say so in the report.
7. Commit, create the annotated tag `v1.6.0`, and push the commit first and then the tag to both
   `origin` and `github`. Check both with `git ls-remote`. The tag push to `github` starts the release
   builds.
