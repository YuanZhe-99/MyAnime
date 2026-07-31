# AGENTS.md

Operating guide for agents working on **MyAnime!!!!!**. This file holds **only** rules about how to
work here. Everything describing what the code *is* or *does* lives in `doc/en-us/` — see
[Where to read what](#where-to-read-what).

MyAnime!!!!! is a privacy-first anime tracking app (Flutter; Windows, Android, iOS, macOS). Treat the
user's message as the change request: plan, implement, verify, report.

## Reading order

When you need to understand code, read in this order and stop as soon as you have what you need:

1. **`doc/en-us/`** — start here, always. `architecture.md` for shape and rules;
   `functions/<mirrored path>.md` for a specific file's declarations; `functions/INDEX.md` to find
   the right page; the concept docs for behavior.
2. **Comments in the source** — the Function Explanation Layer above each declaration.
3. **The implementation** — only when the docs and comments are insufficient, or when you must
   confirm actual behavior before changing it.

Do not jump straight to reading source bodies. Where docs and code disagree on something you are
about to change, verify against the code, then fix the docs in the same commit.

## Where to read what

| Question | Read |
|---|---|
| App shell, flavors, repository layout, core rules, shared package | `doc/en-us/architecture.md` |
| What a file or function does | `doc/en-us/functions/<mirrored path>.md` |
| Which page covers which source file | `doc/en-us/functions/INDEX.md` |
| WebDAV sync flow, lock, conflicts | `doc/en-us/sync.md` |
| Backup, restore, blob store | `doc/en-us/backup-restore.md` |
| Files on disk, what syncs, `storage_config.json` keys | `doc/en-us/data-formats.md` |
| Per-feature behavior | `doc/en-us/features/*.md` |
| Merge algorithm details | `doc/en-us/algorithms/three-way-merge.md` |
| Worked end-to-end scenarios | `doc/en-us/examples/*.md` |
| Windows/macOS/iOS/Android specifics, `file_picker` pin, Gradle/AGP state | `doc/en-us/platform-notes.md` |
| CI jobs, build commands, `tool/` scripts, fresh-clone steps | `doc/en-us/ci-cd.md` |
| Why a behavior exists; past releases | `doc/en-us/version-history.md` |
| English→Chinese terminology | `doc/en-us/translation-guide.md` |

The shared sync/backup/ZIP engines are **not in this repo** — they live in `myapps_data`, embedded at
`packages/myapps_data`. Their documentation is at `packages/myapps_data/doc/en-us/`.

## Required workflow

1. Treat the user's message as the modification request.
2. Before editing, fetch the relevant remote(s) and check whether the local branch is behind. Do not
   start until any divergence is understood.
3. Read per [Reading order](#reading-order).
4. Plan when the work is non-trivial, then implement it in this workspace.
5. Keep changes scoped. Do not revert unrelated work in the tree.
6. Update documentation in the same change set — see [Documentation maintenance](#documentation-maintenance).
7. Verify with the narrowest meaningful checks, usually `flutter analyze` plus the relevant
   `flutter test` targets.
8. Report briefly, in English and Chinese: what changed, what was verified, the current/pre-change
   version, the configured remotes, and anything that could not be done.
9. For normal code changes, ask whether to push to all remotes. The user must confirm the release
   version before a release push.

## Documentation maintenance

**Docs are the primary artifact. Update them first, and never let them drift.**

Any change that adds, removes, or changes the behavior or signature of a function, a data format, a
sync rule, or a feature must update, in the same commit:

- the per-file page under `doc/en-us/functions/` and its `INDEX.md` row,
- every affected concept doc (`architecture.md`, `data-formats.md`, `sync.md`,
  `backup-restore.md`, `features/*.md`, `algorithms/*.md`, `platform-notes.md`, `ci-cd.md`).

Every language directory under `doc/` (currently `en-us` and `zh-cn`) mirrors the others exactly —
same files, headings, tables, and examples. `doc/en-us/` is authoritative: any documentation change
updates **all** language directories in the same commit, translated per `translation-guide.md`.
Adding a new language means creating a complete mirror of `doc/en-us/` in the same change. New
terminology goes into the glossary in `translation-guide.md`: cross-cutting terms into Section 5.1
in **all four** sibling repos (MyAnime, MyDay, MyDevice, MyApps-DATA), app-specific terms into this
repo's Section 5.2 only.

**Put explanation in the docs, not here.** This file is for agent instructions only. If you are about
to add a paragraph describing how the code works, it belongs in `doc/en-us/`. Only add to this file
when the rule is about how an agent should behave.

Add a `doc/en-us/version-history.md` entry for each release. Documentation-only commits do not bump
versions or create tags.

## Authoring rules

**Function Explanation Layer.** Every function, method, significant callback helper, constructor,
getter, and setter carries a structured comment immediately above it:

- `Purpose: <one short sentence describing what the declaration is responsible for>`
- `Inputs: <important parameters only; omit obvious ones if trivial>`
- `Returns: <what the caller receives, or None>`
- `Side effects: <state changes, file/network/database/UI effects, logging, mutation, or None>`
- `Notes: <important assumptions, edge cases, invariants, or when the declaration should be used;
  prefer None when there is nothing special to add>`

Keep each explanation concise. Add one when adding a declaration, and update it in the same change
when editing an existing one. Use `///` doc comments in Dart, and matching doc comments in other
languages. Keep tracked generated localization files aligned when they are intentionally updated in
the same change.

These comments are the second layer of the [Reading order](#reading-order), so they have to stay
accurate: an agent that trusts a stale comment will make a wrong change. Still verify important
behavior in the implementation before relying on a comment for anything load-bearing.

Other conventions:

- **UTC timestamps** for anything compared across devices (`modifiedAt`). Local-time values break
  sync conflict detection.
- **Pretty-printed JSON** via `JsonEncoder.withIndent('  ')` for anything written to disk — sync
  relies on it so an unchanged file hits the raw-equality fast path.
- **Preserve unknown JSON fields** with the `extraJson` pattern, so an older build never deletes a
  newer build's data.
- **File I/O goes through `AnimeStorage.getAppDir()`** so custom storage paths keep working.

## Behavior contract

Do not change these without the user explicitly deciding to:

- The **WebDAV wire format**, remote layout, and `.lock` semantics are a compatibility contract with
  builds already in the field.
- Local formats — `webdav_config.json`, `.sync_base/`, `backups/` bundles and blobs — likewise.
- Conflicts are **never** silently auto-resolved; `autoResolve` stays false at every call site.
- Restore disables WebDAV auto-sync before the first write and re-enables it only if nothing was
  written.
- **Online anime search stays hidden from store builds.** Every new store-reachable caller must gate
  on `AppFlavor.isFull`; `AnimeSearchService` itself does not enforce gating.
- **The shared-service facades keep their public shape.** `WebDAVService`, `BackupService`,
  `ImportExportService`, and `AutoSyncService` are thin wrappers over `myapps_data`. If a change
  seems to require editing a facade's public API, stop — the facade exists so call sites and tests
  keep working, and behavior changes belong in the package.
- `lib/app/data_modules.dart` is the single source of truth for data-file names and backup module
  keys. Never hardcode them elsewhere.
- `sync_progress.dart`, `sync_wake_lock.dart`, and the generic half of `sync_merge.dart` are
  re-export shims. Do not reintroduce implementations in them.

## Working with the shared package

The submodule uses the **relative** URL `../MyApps-DATA.git`, so it resolves against whichever remote
this clone tracks. Never write a host name into `.gitmodules`.

Consume a newer shared version:

```bash
cd packages/myapps_data
git fetch origin --tags && git checkout vX.Y.Z
cd ../..
flutter analyze && flutter test
git add packages/myapps_data && git commit -m "Bump myapps_data to vX.Y.Z"
```

To change shared code: the submodule checks out detached, so `git switch main` inside it first, then
commit and **push to both remotes before** committing the pointer bump here. A pointer to an unpushed
commit breaks every other clone and CI.

## Release, version, commit, tag, push

For ordinary feature/fix work, do not bump versions or tag until the user confirms the release
version and confirms pushing.

When the user confirms:

1. Update every version location:
   - `pubspec.yaml`: `version: X.Y.Z+N` (`N` increments for releases)
   - `pubspec.yaml`: `msix_config.msix_version: X.Y.Z.0`
   - `installer.iss`: `AppVersion=X.Y.Z`, `VersionInfoVersion=X.Y.Z.0`,
     `VersionInfoProductVersion=X.Y.Z`
   - `installer.iss` output filenames stay derived from `{#SetupSetting("AppVersion")}` for both x64
     and ARM64
   - Never hand-edit the settings-page version display; it reads `PackageInfo.fromPlatform()`
2. If MSIX ever diverges from the other locations, realign at the next bump rather than making a
   version-only edit.
3. Re-run verification.
4. Commit all intended changes, and add the `doc/en-us/version-history.md` entry.
5. Create an annotated tag `vX.Y.Z`.
6. Push **the commit first**, then the tag, to both `origin` and `github`.

This repo's branch is `master` (MyDay uses `main` — do not assume). Push `HEAD` or check
`git branch --show-current` first, and verify with `git ls-remote`.

GitHub Actions release builds trigger on tag pushes to `github`. Tags must be pushed explicitly.

Documentation-only maintenance the user says needs no release: commit and push without changing
versions or creating a tag.

## Agent co-author attribution

An agent that made a real, material contribution to a commit may add its own accurate
`Co-authored-by:` trailer. Attribution is per commit: do not add an agent merely because it reviewed,
observed, or continued another agent's work, and never copy a trailer automatically from an earlier
commit. When multiple agents materially contributed, include one accurate trailer each. Use the
agent's actual documented identity; never invent a provider, model, name, or email. Approved
examples are `Co-authored-by: Codex <noreply@openai.com>` and, for Claude Code,
`Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>` with the model name replaced by the actual
model that did the work. For another agent, use its verified documented identity; if none is
verified, omit the AI trailer unless the repository owner approves one.

## Remotes and secrets

- `origin` → `<local_gitea_address>` (private Gitea)
- `github` → `git@github.com:YuanZhe-99/MyAnime.git`

Determine the repository path from the runtime workspace; do not hardcode a machine-specific absolute
path here.

**Masking rule:** keep the `origin` URL written as `<local_gitea_address>` in every committed file.
Never write the underlying Tailscale host or port anywhere in the repo, including `.gitmodules`.

**Never commit:** secrets, credentials, WebDAV configuration, signing keys, private personal anime
data, generated app data, or local-only machine addresses.
