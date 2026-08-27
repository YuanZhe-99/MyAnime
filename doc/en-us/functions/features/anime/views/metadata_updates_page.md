# lib/features/anime/views/metadata_updates_page.dart

`MetadataUpdatesPage` is the review screen for metadata the background updater downloaded but has
not applied. It is reached from a badge in the management page's app bar, which appears only when
something is pending and only in full builds.

See [`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md)
for the feature and [`../services/metadata_update_service.md`](../services/metadata_update_service.md)
for the service behind it.

## Design points

- **The diff is recomputed on every load**, never read from the cache. A record edited since its
  proposal was made shows an accurate before/after, and one whose changes the user has since made by
  hand simply drops off the list.
- **Every field has its own checkbox**, so a user can accept a corrected episode count and refuse
  the fetched synopsis.
- **"Update all" asks twice.** This deliberately does not reuse `confirmDelete`'s "don't ask for 5
  minutes" suppression, which would defeat the second prompt entirely.
- **Batch actions skip `needsManualPick` entries.** A batch must never guess between candidates the
  service itself could not separate; the count of skipped entries is shown in the first
  confirmation.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_Proposal` | typedef | B | Record, cache entry, and live diff for one reviewable item. |
| `MetadataUpdatesPage` | constructor | B | Create the page, taking the management page's scope. |
| `createState` | method | B | Flutter lifecycle. |
| `initState` | method | B | Start the first load. |
| `dispose` | method | B | Unregister the service callback. |
| [`_onServiceChanged`](#_onservicechanged) | method | A | Rebuild as the service publishes proposals. |
| [`_startScan`](#_startscan) | method | A | Run a check of the whole library and report the outcome. |
| `_openManualSearch` | method | B | Hand an unmatched record to the edit page's search. |
| [`_load`](#_load) | method | A | Rebuild the proposal list from storage and cache. |
| [`_batchable`](#_batchable) | method | A | List the proposals a batch action may apply. |
| `_apply` | method | B | Apply one reviewed proposal. |
| `_dismiss` | method | B | Reject one proposal. |
| [`_applyBatch`](#_applybatch) | method | A | Apply a scope's proposals after confirmation. |
| `_confirm` | method | B | Show a yes/no dialog. |
| `_fieldLabel` | method | B | Localize a proposable field's name. |
| [`_formatValue`](#_formatvalue) | method | A | Render a value for the before/after columns. |
| `_weekdayLabel` | method | B | Localize a weekday. |
| `build` | method | B | Build the screen. |
| `_buildEmpty` | method | B | Render the empty state. |
| [`_buildProposalCard`](#_buildproposalcard) | method | A | Render one proposal. |
| `_buildChangeRow` | method | B | Render one field's checkbox and values. |
| [`_buildThumbnail`](#_buildthumbnail) | method | A | Render the candidate's cover. |
| `_buildScanBanner` | method | B | Show how far a running scan has got. |

## Documentation

### `Future<void> _load()` <a id="_load"></a>
- **Side effects:** Reloads the update cache and reads `anime_data.json`.
- **Algorithm:**
  1. Reload the service's cache so a sync that replaced the anime file is reflected.
  2. Index the stored anime by id.
  3. For each pending entry, recompute `diffCandidate` against the **stored** record.
  4. Drop entries whose diff is now empty, unless they are `needsManualPick`.
  5. Sort by display title and default every field to selected.
- **Notes:** Step 3 is why this screen cannot show stale values, and step 4 is why a proposal the
  user already satisfied by hand disappears on its own.

### `List<_Proposal> _batchable(List<String>)` <a id="_batchable"></a>
- **Inputs:** `scopeIds` — restrict to these anime, or empty for the whole library.
- **Notes:** Includes only `proposed` entries with a non-empty diff. `needsManualPick` is excluded
  by construction, which is the property that makes offering "update all" defensible.

### `Future<void> _applyBatch(List<String>, {required bool requireSecondConfirm})` <a id="_applybatch"></a>
- **Side effects:** Shows one or two confirmation dialogs, then writes each accepted record.
- **Notes:** "Update this page" confirms once; "update all" passes `requireSecondConfirm: true`,
  because a single mis-tap must not be able to rewrite the whole library. The first dialog also
  reports how many `needsManualPick` entries were excluded, so the user is not left wondering why
  the count is lower than the list length.

### `String _formatValue(MetadataField, Object?, AppLocalizations)` <a id="_formatvalue"></a>
- **Notes:** Dates use `DateFormat.yMd()`, weekdays use the same names the settings page shows, and
  a fetched synopsis is truncated to 120 characters so one long value cannot dominate the card.
  Null and blank render as a localized "(empty)" rather than as nothing, so a fill-a-blank proposal
  reads as a change.

### `Widget _buildProposalCard(_Proposal, ThemeData, AppLocalizations)` <a id="_buildproposalcard"></a>
- **Notes:** A `needsManualPick` entry renders an explanation instead of a field list and offers
  only "Ignore" — there is nothing to apply, because the service could not decide which candidate
  was right.

### `Widget _buildThumbnail(_Proposal)` <a id="_buildthumbnail"></a>
- **Side effects:** May issue a network image request.
- **Notes:** Uses the prefetched file when cover prefetch is on, and otherwise streams the source
  URL. That fallback is why prefetch can stay **off by default** without costing this screen
  anything.

### `void _onServiceChanged()` <a id="_onservicechanged"></a>
- **Kind:** method
- **Purpose:** Rebuild the list when the service publishes new proposals.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Re-reads `anime_data.json`.
- **Notes:** Calls `_load(reloadCache: false)`, not plain `_load()`. `MetadataUpdateService.reload()`
  notifies its listeners, so asking it to re-read the cache from inside a listener would call this
  callback again, and again, forever. The in-memory store is already current here — the service just
  wrote it.

  During a manual scan this is what makes proposals appear one at a time as they are found, instead
  of all at once when the scan ends.

### `Future<void> _startScan()` <a id="_startscan"></a>
- **Kind:** method
- **Purpose:** Run a check of the whole library on the user's request and report what happened.
- **Inputs:** None.
- **Returns:** None.
- **Side effects:** Drives `MetadataUpdateService.startManualScan`, then shows a snack bar.
- **Algorithm:** Await the scan, then pick one of three messages from the final progress snapshot:
  offline (nothing ran), empty queue (already up to date), stopped early, or finished with a count.
- **Notes:** The awaited future covers the **entire** scan, which can run for minutes. Leaving the
  page only means the snack bar is skipped — the scan itself lives in the service and carries on.

  An empty queue is reported as "everything is already up to date" rather than "no updates found":
  the two are different answers, and only the first one is true when nothing was checked because
  nothing needed checking.
