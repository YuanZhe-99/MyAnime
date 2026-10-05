# lib/features/profile/services/profile_merge.dart

P3: shared declarations described below live in `myapps_profile`; this app
file is a re-export or adapter preserving its public import and constructor shape.
See [../../../../shared-ui.md](../../../../shared-ui.md).

The merge for `profile.json` (1.7.0). It never produces a conflict: the name and the avatar are
merged independently, each keeping the side with the later timestamp, and no base is needed. See
[`../../../../sync.md`](../../../../sync.md#the-profile-file) and
[`../../../app/data_modules.md`](../../../app/data_modules.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`encodeProfile`](#encodeprofile) | function | A | Encode a profile the way `ProfileStore` writes it (two-space pretty JSON). |
| `_remoteWins` | function | B | Whether the remote side of one field is strictly newer. |
| [`mergeProfile`](#mergeprofile) | function | A | Merge a local and a remote profile, last writer wins per field. |
| `mergeProfileJson` | function | B | Merge raw JSON for the sync engine; throws when either side is not a JSON object. |

## encodeProfile

- **Returns:** `JsonEncoder.withIndent('  ')` output of `ProfileData.toJson()`.
- **Notes:** Merge output and local saves must be byte-identical for the same data, or an unchanged
  file would miss the raw-equality fast path and re-upload on every sync.

## mergeProfile

- **Algorithm:** `_remoteWins(local, remote)` is true only when the remote timestamp is strictly
  later; a tie keeps local, and a side that never set the field (null timestamp) always loses to one
  that did. The name (`displayName` + `displayNameUpdatedAt`) and the avatar (`avatar` +
  `avatarUpdatedAt`) are decided independently, so a name changed on one device and an avatar changed
  on another both survive. Unknown top-level keys are unioned with local winning; the higher
  `version` is kept.
- **Notes:** The base is not needed: a removal is an explicit timestamped `null`, never a missing
  key, so "removed here" and "never set here" cannot be confused. `mergeProfileJson` is what
  `buildProfileModule` passes to the engine; `baseJson` and `autoResolve` are ignored.
