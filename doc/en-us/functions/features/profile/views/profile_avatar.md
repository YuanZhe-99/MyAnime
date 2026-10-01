# lib/features/profile/views/profile_avatar.dart

The user's avatar drawn in a circle (1.7.0), as shown on the Home app bar, at the top of Settings and
in the profile edit dialog. `ProfileAvatar` watches the profile provider; `ProfileAvatarView` is the
stateless rendering behind it, taking the profile as an argument so tests and previews need no
provider. See [`../providers/profile_provider.md`](../providers/profile_provider.md),
[`profile_header.md`](profile_header.md) and
[`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ProfileAvatar` | constructor (`ProfileAvatar`) | B | Create a profile avatar; `radius` defaults to 18. |
| [`ProfileAvatar.build`](#profileavatarbuild) | method (`ProfileAvatar`, widget build) | A | Build the circle for the current profile. |
| `ProfileAvatarView` | constructor (`ProfileAvatarView`) | B | Create an avatar view for a given profile and radius. |
| [`ProfileAvatarView._placeholder`](#placeholder) | method (`ProfileAvatarView`) | A | Build the circle shown without an image. |
| [`ProfileAvatarView.build`](#profileavatarviewbuild) | method (`ProfileAvatarView`, widget build) | A | Build the image circle, or the placeholder. |

## ProfileAvatar.build

- **Notes:** A `ConsumerWidget`: reads `profileProvider` and returns
  `ProfileAvatarView(profile: profile, radius: radius)`.

## _placeholder

- **Returns:** A `CircleAvatar` with `primaryContainer` background and `onPrimaryContainer`
  foreground, showing the first letter of the display name upper-cased, or a person icon when there
  is no name.

## ProfileAvatarView.build

- **Algorithm:** With no avatar path, return the placeholder. Otherwise a `FutureBuilder<File>`
  (keyed on the avatar path) resolves the file through `ImageService.resolve`; while the file is
  unresolved it shows the placeholder, then a `ClipOval` holding `Image.file` (`radius * 2` square,
  `BoxFit.cover`, `gaplessPlayback`, `errorBuilder` falling back to the placeholder).
- **Notes:** The placeholder is also what shows when the avatar file has not arrived yet from sync;
  it falls back the same way and the image appears once a later rebuild finds the file.
