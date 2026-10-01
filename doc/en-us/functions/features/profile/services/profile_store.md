# lib/features/profile/services/profile_store.dart

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
| `_file` | static method | B | Resolve the file under the app directory. |
| [`load`](#load) | static method | A | Load the profile; empty when absent or unreadable. |
| [`update`](#update) | static method | A | Apply one queued change and save it. |
| `_apply` | static method | B | Run one queued update. |
| [`setName`](#setname) | static method | A | Set or clear the display name. |
| [`pickAvatar`](#pickavatar) | static method | A | Let the user pick an image and make it the avatar. |
| [`removeAvatar`](#removeavatar) | static method | A | Remove the avatar with a timestamped removal. |
| `_deleteQuietly` | static method | B | Delete a replaced avatar file, ignoring failures. |
| [`squareAvatarJpeg`](#squareavatarjpeg) | top-level function | A | Turn any decodable image into a centred square JPEG. |

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

## pickAvatar

- **Returns:** `ProfileData?` — null when the picker was cancelled (or no bytes were available).
- **Side effects:** Opens `FilePicker` (image, `withData`), crops and scales in an isolate
  (`Isolate.run(squareAvatarJpeg(bytes, 512))`), writes `images/avatar_<uuid>.jpg`, updates
  `profile.json` through `update` with `withAvatar(rel, now)`, then deletes the previous avatar file
  on this device.
- **Notes:** Throws when the picked file is not a decodable image. Every avatar gets a **fresh file
  name**, because image sync never overwrites an existing local or remote file of the same name, so
  re-using one name would leave other devices with the old picture. The old avatar files stay on the
  WebDAV server and on other devices, because image sync is additive and never deletes — a known
  limitation.

## removeAvatar

- **Side effects:** Writes `profile.json` with an explicit, timestamped removal
  (`"avatar": null`) and deletes the local avatar file.
- **Notes:** The removal is timestamped so it syncs to other devices.

## _deleteQuietly

- **Notes:** Only basenames starting with `avatar_` are ever deleted, so a cover can never be
  removed by this path. Failures are ignored.

## squareAvatarJpeg

- **Inputs:** `bytes` — the source image; `size` — output edge in pixels.
- **Returns:** `Uint8List` — JPEG bytes.
- **Algorithm:** `img.decodeImage` (any decoder exception becomes `FormatException('Not a supported
  image')`), `bakeOrientation` (applies EXIF orientation so phone photos are upright),
  `copyResizeCropSquare(size: size, interpolation: average)`, then `encodeJpg(quality: 88)`.
- **Notes:** Pure and safe to run in another isolate. The store passes `avatarSize` (512), so every
  avatar is a 512 x 512 JPEG.
