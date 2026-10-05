# lib/features/profile/models/profile_data.dart

P3: shared declarations described below live in `myapps_profile`; this app
file is a re-export or adapter preserving its public import and constructor shape.
See [../../../../shared-ui.md](../../../../shared-ui.md).

The contents of `profile.json` (1.7.0): the user's display name and avatar, synced to every device.
Each field carries its own UTC timestamp so two devices editing different fields both keep their
change, and the newer edit of the same field wins. Unknown keys are kept in `extraJson`, so an older
build never deletes a newer build's data. The file is its own synced module — see
[`../../../app/data_modules.md`](../../../app/data_modules.md),
[`../../../../data-formats.md`](../../../../data-formats.md#profilejson) and
[`../../../../features/profile.md`](../../../../features/profile.md).

```json
{
  "version": 1,
  "displayName": "Yuan",
  "displayNameUpdatedAt": "2026-10-01T14:06:42.530801Z",
  "avatar": "images/avatar_2953ac52-337e-4271-a8e1-bcd97ee416ba.jpg",
  "avatarUpdatedAt": "2026-10-01T14:08:59.163627Z"
}
```

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `_unknown` | function | B | Collect JSON keys this build does not know. |
| `_parseTime` | function | B | Parse an optional timestamp to UTC; null when absent or malformed. |
| `ProfileData` | constructor | B | Create a profile; timestamps normalized to UTC. |
| [`ProfileData.fromJson`](#profiledatafromjson) | factory | A | Read the file tolerantly; reject a non-object. |
| [`ProfileData.toJson`](#profiledatatojson) | method | A | Serialize; a field is written only once it has a timestamp. |
| `ProfileData.name` | getter | B | The trimmed display name, or null when there is none. |
| `ProfileData.withName` | method | B | A copy with a new display name and edit time. |
| `ProfileData.withAvatar` | method | B | A copy with a new (or removed) avatar and edit time. |

`ProfileData.currentVersion` (`1`) and the six fields (`version`, `displayName`,
`displayNameUpdatedAt`, `avatar`, `avatarUpdatedAt`, `extraJson`) carry their own doc comments
but no `/// Purpose:` block. `avatar` is a path relative to the app directory of the form
`images/avatar_<uuid>.jpg`.

## ProfileData.fromJson

- **Notes:** throws `FormatException` when the input is not a JSON object, which is what the sync
  module's `validate` relies on. Inside the object it is tolerant: a wrong-typed field reads as
  unset, an empty `avatar` string reads as null, and a non-int `version` reads as `currentVersion`.
  Timestamps are parsed with `DateTime.tryParse(...).toUtc()`.

## ProfileData.toJson

- **Returns:** `extraJson` first, then `version`, then `displayName` + `displayNameUpdatedAt` only
  when the name timestamp is set, and `avatar` + `avatarUpdatedAt` only when the avatar timestamp is
  set.
- **Notes:** A removed avatar is written as an explicit `"avatar": null` with its timestamp, so the
  removal syncs instead of being taken for "never set". A field with no timestamp is omitted
  entirely, which is how "never set" is represented.
