# lib/features/profile/services/profile_store.dart

P3: shared declarations described below live in `myapps_profile`; this app
file is a re-export or adapter preserving its public import and constructor shape.
See [../../../../shared-ui.md](../../../../shared-ui.md).

`ProfileStore` (1.7.0) owns `profile.json` under `AnimeStorage.getAppDir()`: the user's display name
and avatar. It follows the same pattern as the playback progress store: a read-modify-write queue,
atomic writes, no write when the bytes are unchanged, and `AutoSyncService.notifySaved` after each
real write. The avatar image itself lives in `images/` beside the covers, which is how it reaches
other devices. See [`../../../app/data_modules.md`](../../../app/data_modules.md) and
[`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ProfileStore._` | constructor | B | Prevent instantiation. |
| `resolveImage` | static method | A | Resolve an image through the app adapter. |
| [`load`](#load) | static method | A | Load the profile; empty when absent or unreadable. |
| [`update`](#update) | static method | A | Apply one queued change and save it. |
| [`setName`](#setname) | static method | A | Set or clear the display name. |
| [`pickAvatarSource`](#pickavatarsource) | static method | A | Let the user pick an image to edit into an avatar (1.7.2; replaces `pickAvatar`). |
| [`readAvatarBytes`](#readavatarbytes) | static method | A | Read the current avatar image, to adjust it again (1.7.2). |
| [`setAvatarJpeg`](#setavatarjpeg) | static method | A | Store an edited avatar as a fresh file and update the profile (1.7.2). |
| [`removeAvatar`](#removeavatar) | static method | A | Remove the avatar with a timestamped removal. |

`fileName` (`profile.json`, which must match `profileFileName` in `data_modules.dart`), `avatarSize`
(`512`) and the queue `_tail` carry no `/// Purpose:` comment.

## load

- **Returns:** The stored `ProfileData`; an empty one when the file is absent, blank or unreadable.

## update

- **Inputs:** `mutate` — returns the new profile from the loaded one.
- **Side effects:** Reads, then (only when the encoded bytes differ) writes the file with
  `atomicWriteString` and calls `AutoSyncService.instance.notifySaved()`.
- **Notes:** Calls are queued through `_tail`, so concurrent updates apply one after another. When
  the file exists but cannot be parsed, `_apply` throws `FormatException` and leaves the bytes on
  disk untouched, because saving over it would erase the profile on every device once synced; a blank
  file counts as empty. Encoding goes through `encodeProfile`, so the bytes match the merge output.

## setName

- **Inputs:** `name` — trimmed; empty clears it.
- **Notes:** An unchanged name keeps its old timestamp, so it does not win a merge it should not.

## pickAvatarSource

- **Returns:** `Uint8List?` — the picked file's bytes; null when the picker was cancelled (or no bytes were available).
- **Side effects:** Opens `FilePicker` (image, `withData`); falls back to reading `picked.path` when the platform returns no bytes.
- **Notes:** Nothing is saved. The bytes go to the avatar editor ([`../views/avatar_editor.md`](../views/avatar_editor.md)), whose result is stored with [`setAvatarJpeg`](#setavatarjpeg). It replaces the 1.7.0 `pickAvatar`, which picked, cropped to the centre and saved in one step; that centred crop survives as `squareAvatarJpeg` in [`avatar_image.md`](avatar_image.md).

## readAvatarBytes

- **Returns:** `Uint8List?` — the avatar file's bytes; null when there is no avatar or its file has not arrived on this device yet (or cannot be read).
- **Side effects:** Reads `profile.json` and one file under `images/`, resolved through `ImageService.resolve`.
- **Notes:** The stored avatar is already a 512-pixel square, so adjusting it can only zoom further in, rotate or re-centre.

## setAvatarJpeg

- **Inputs:** `jpeg` — the editor's square JPEG (`avatarSize` pixels).
- **Returns:** `ProfileData` — the new profile.
- **Side effects:** Writes a fresh `images/avatar_<uuid>.jpg`, updates `profile.json` through `update` with `withAvatar(rel, now)`, then deletes the previous avatar file on this device.
- **Notes:** Every avatar gets a **fresh file name**, because image sync never overwrites an existing local or remote file of the same name, so re-using one name would leave other devices with the old picture. The old avatar files stay on the WebDAV server and on other devices, because image sync is additive and never deletes — a known limitation.

## removeAvatar

- **Side effects:** Writes `profile.json` with an explicit, timestamped removal
  (`"avatar": null`) and deletes the local avatar file.
- **Notes:** The removal is timestamped so it syncs to other devices.

## _deleteQuietly

- **Notes:** Only basenames starting with `avatar_` are ever deleted, so a cover can never be
  removed by this path. Failures are ignored.
