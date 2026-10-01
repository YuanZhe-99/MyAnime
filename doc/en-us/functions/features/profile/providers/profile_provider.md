# lib/features/profile/providers/profile_provider.dart

The Riverpod provider for the current `ProfileData` (1.7.0). It loads `profile.json` once, reloads
whenever sync or a restore rewrites local data, and routes every edit through `ProfileStore`, so the
file stays the single source of truth. See
[`../services/profile_store.md`](../services/profile_store.md) and
[`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`ProfileNotifier.new`](#profilenotifier-new) | constructor (`ProfileNotifier`) | A | Create the notifier, subscribe to local-data changes, and start loading. |
| `ProfileNotifier.fixed` | constructor (`ProfileNotifier`) | B | Create a notifier with a fixed profile and no I/O; for tests. |
| [`reload`](#reload) | method (`ProfileNotifier`) | A | Re-read `profile.json` into the state. |
| `setName` | method (`ProfileNotifier`) | B | Save a new display name; empty clears it. |
| `pickAvatar` | method (`ProfileNotifier`) | B | Pick and save a new avatar; false when the picker was cancelled. |
| `removeAvatar` | method (`ProfileNotifier`) | B | Remove the avatar. |
| `dispose` | method (`ProfileNotifier`) | B | Unsubscribe from local-data changes. |

`profileProvider` (`StateNotifierProvider<ProfileNotifier, ProfileData>`) is a plain provider
declaration without a `/// Purpose:` comment.

## ProfileNotifier.new

- **Side effects:** Calls `AutoSyncService.instance.addOnLocalDataChanged(reload)` and `reload()`.
- **Notes:** Starts with an empty `ProfileData()`; the loaded profile replaces it a moment later.
  Because the listener fires after a sync or restore changes local files, a profile edited on another
  device appears without a restart.

## reload

- **Side effects:** Reads the file and replaces the state, only while the notifier is still `mounted`.
- **Notes:** Safe to call after dispose; the result is then dropped.

## Edits

`setName`, `pickAvatar` and `removeAvatar` call the matching `ProfileStore` method and then replace
the state with the returned profile. `pickAvatar` returns `false` when the picker was cancelled; an
unreadable image propagates as an exception for the dialog to report. `dispose` calls
`removeOnLocalDataChanged(reload)`.
