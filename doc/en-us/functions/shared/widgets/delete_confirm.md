# lib/shared/widgets/delete_confirm.dart

A single shared helper, `confirmDelete`, that shows a themed delete-confirmation dialog with an
optional "don't ask for 5 minutes" checkbox, backed by a module-level suppression timestamp. Used
by anime management/detail pages before destructive delete actions.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`confirmDelete`](#confirmdelete) | top-level function | A | Ask the user to confirm deletion and optionally suppress prompts briefly. |

The module-level `_suppressUntil` variable is a plain private field (a regular doc comment, not a
`/// Purpose:` block) and is not indexed as a separate row; it is `confirmDelete`'s private state.

## Documentation

### `Future<bool> confirmDelete(BuildContext context, String itemLabel)` <a id="confirmdelete"></a>
- **Kind:** top-level function
- **Source:** `lib/shared/widgets/delete_confirm.dart` (approx. line 13)
- **Purpose:** Show a delete-confirmation `AlertDialog` for `itemLabel`, optionally letting the user
  suppress the dialog for 5 minutes.
- **Inputs:** `context` — for showing the dialog and reading localizations; `itemLabel` — the
  human-readable name of the item being deleted, interpolated into the confirmation message.
- **Returns:** `Future<bool>` — `true` if the deletion should proceed, `false` if cancelled.
- **Side effects:** May show an `AlertDialog` via `showDialog`; may set the module-level
  `_suppressUntil` timestamp, which affects future calls for the remainder of the app session.
- **Algorithm:**
  1. If `_suppressUntil` is non-null and still in the future, return `true` immediately without
     showing any dialog (the user recently chose "don't ask").
  2. Otherwise, show an `AlertDialog` (via a `StatefulBuilder` so the checkbox can update its own
     state) with the item name, a "don't ask for 5 minutes" `Checkbox`, and Cancel/Delete actions.
     Cancel pops `false`; Delete pops `true`.
  3. If the dialog result is `true` and the checkbox was checked, set
     `_suppressUntil = DateTime.now().add(const Duration(minutes: 5))`.
  4. Return the dialog result, or `false` if the dialog was dismissed without a button press
     (`result ?? false`).
- **Usage:**
  ```dart
  final ok = await confirmDelete(context, anime.displayTitle);
  ```
  (from `lib/features/anime/views/management_page.dart`; also used in
  `lib/features/anime/views/anime_detail_page.dart`)
- **Notes:** `_suppressUntil` is a single global (not per-item-type) suppression window shared by
  every call site in the app — checking "don't ask" once suppresses the confirmation for any
  subsequent `confirmDelete` call anywhere, for 5 minutes. Falls back to hardcoded English strings
  (`'Confirm Delete'`, `'Delete $itemLabel?'`, etc.) when a localization lookup returns `null`.
