# MyAnime!!!!! Documentation (Concepts)

**MyAnime!!!!!** (five exclamation marks in every user-facing name — app title, installer
metadata, macOS bundle name, iOS display name, and window titles) is a privacy-first anime
tracking app. It combines a JST-aware calendar, seasonal quarter management, statistics,
multi-source anime search, watch-progress tracking, daily reminders, share/export flows, WebDAV
sync, local backup, a desktop local API server, tray behavior, launch-at-startup, and a kana
quick-reference module.

- **Author / package id:** `yuanzhe`, `com.yuanzhe.my_anime`
- **License:** GPL-3.0
- **Platforms:** Windows, Android, iOS, macOS (Linux project files exist and some desktop services
  have Linux branches, but Linux is not a primary release target; Web is not targeted)
- **Framework:** Flutter, Dart SDK `^3.11.3`; CI uses Flutter `3.44.2`

This tree holds **concept** documentation — architecture, data formats, algorithms, and worked
examples — written for humans and agents who need to understand *why* the app behaves the way it
does. Function-by-function API documentation lives separately under
[`functions/`](functions/) (not covered by this index) and translation notes live in
[`translation-guide.md`](translation-guide.md).

**These docs are the authoritative description of the code.** The repository's `AGENTS.md` is
deliberately limited to instructions for agents — workflow, authoring rules, the behavior contract,
and the release process — and points here for everything else. When code changes, these pages are
updated first; when docs and code disagree, verify against the code and then fix the page.

The shared WebDAV sync, backup, and ZIP engines are not in this repository. They live in the
`myapps_data` package embedded at `packages/myapps_data`, documented at
`packages/myapps_data/doc/en-us/`.

## Contents

### Core concepts

- [`architecture.md`](architecture.md) — app shell, state management, navigation, l10n, repository
  layout, and the core architectural rules the whole codebase follows.
- [`data-formats.md`](data-formats.md) — the `Anime` model's fields, on-disk JSON formats, and the
  full persisted-data inventory (what's synced, what's device-local).
- [`sync.md`](sync.md) — the WebDAV sync algorithm end to end: locking, download, three-way merge,
  conflict handling, retries, heartbeats, image sync, and auto-sync triggers.
- [`backup-restore.md`](backup-restore.md) — local backup format v2 (content-addressed image
  blobs, GC, retention), restore safety rules, and ZIP/Markdown import-export.
- [`platform-notes.md`](platform-notes.md) — Windows/macOS/iOS/Android platform caveats and the
  desktop local API server, tray, and launch-at-startup behavior.
- [`ci-cd.md`](ci-cd.md) — CI jobs and workflow caveats, the build/verify command set, `tool/`
  scripts, and fresh-clone (submodule) steps.
- [`version-history.md`](version-history.md) — release-by-release summary. Worth checking before
  changing a behavior that looks odd; several entries record deliberate safety fixes.

### Feature areas

- [`features/anime-tracking.md`](features/anime-tracking.md) — the `Anime` model and quarter
  placement/tracking logic.
- [`features/home-management-statistics.md`](features/home-management-statistics.md) — the Home,
  Manage, and Stats tabs.
- [`features/kana-reference.md`](features/kana-reference.md) — the UI-only kana quick-reference
  module.
- [`features/multi-source-search.md`](features/multi-source-search.md) — multi-source anime
  search, dedup, fuzzy matching, and flavor gating.
- [`features/share-and-import.md`](features/share-and-import.md) — share/export flows and
  `.myanimeitem` file import/export.
- [`features/duplicate-detection.md`](features/duplicate-detection.md) — duplicate grouping and
  merge logic.
- [`features/reminders.md`](features/reminders.md) — mobile/desktop reminder notification
  scheduling.

### Algorithms

- [`algorithms/three-way-merge.md`](algorithms/three-way-merge.md) — a deep dive on the generic
  `mergeRecords<T>` engine that backs WebDAV sync.

### Worked examples

- [`examples/sync-walkthrough.md`](examples/sync-walkthrough.md) — a concrete two-device sync
  scenario, from auto-resolve through to a manual conflict resolution.
- [`examples/backup-restore-walkthrough.md`](examples/backup-restore-walkthrough.md) — a concrete
  backup/corruption/restore scenario, including the WebDAV auto-sync interplay.

## Not covered here

- `doc/en-us/functions/` — per-source-file function-index pages (Tier A/B declaration tables).
  Maintained separately.
- `doc/zh-cn/` — a planned future translation pass; out of scope for this documentation batch.
