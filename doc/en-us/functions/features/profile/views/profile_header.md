# lib/features/profile/views/profile_header.dart

The avatar-and-name row at the top of Settings (1.7.0), and the dialog it opens to edit them.
`SettingsPage` places `const ProfileHeader()` as the first child of its list, so it appears in both
the one-pane and the two-pane layout
([`../../settings/views/settings_page.md`](../../settings/views/settings_page.md)). See
[`profile_avatar.md`](profile_avatar.md), [`../providers/profile_provider.md`](../providers/profile_provider.md)
and [`../../../../features/profile.md`](../../../../features/profile.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ProfileHeader` | constructor (`ProfileHeader`) | B | Create the profile header. |
| [`ProfileHeader.build`](#profileheaderbuild) | method (`ProfileHeader`, widget build) | A | Build the tappable avatar-and-name row. |
| [`showProfileEditDialog`](#showprofileeditdialog) | top-level function | A | Open the dialog that edits the name and avatar. |
| `_ProfileDialog` | constructor (`_ProfileDialog`) | B | Create the edit dialog. |
| `_ProfileDialog.createState` | method (widget lifecycle) | B | Create the dialog state. |
| `_ProfileDialogState.initState` | method (widget lifecycle) | B | Seed the name field from the current profile. |
| `_ProfileDialogState.dispose` | method (widget lifecycle) | B | Release the text controller. |
| [`_ProfileDialogState._run`](#_run) | method (`_ProfileDialogState`) | A | Run an avatar action with a busy state and error reporting. |
| [`_ProfileDialogState._save`](#_save) | method (`_ProfileDialogState`) | A | Save the name and close. |
| `_ProfileDialogState.build` | method (widget build) | B | Build the dialog. |

## ProfileHeader.build

- **Returns:** A `ListTile` with `ProfileAvatar(radius: 28)` as leading, the name (or the
  `profileNamePlaceholder` "Set your name", in the muted `onSurfaceVariant` color) as the title, the
  `profileEditHint` as the subtitle, and an edit icon as trailing. Tapping calls
  `showProfileEditDialog(context)`.
- **Notes:** Watches only the name (`profileProvider.select((p) => p.name)`).

## showProfileEditDialog

- **Side effects:** Shows the dialog; avatar changes save immediately, the name saves on **Save**.
- **Notes:** Must be called below a `ProviderScope`.

## Dialog layout

An `AlertDialog` titled `profileTitle` holding a large `ProfileAvatar(radius: 48)`; a *Choose avatar*
`FilledButton.tonalIcon` (`profileChangeAvatar`) and, only while an avatar is set, a *Remove* button
(`profileRemoveAvatar`); and a name `TextField` (`profileName`, `maxLength: 40`, submitting saves).
Actions are **Cancel** and **Save**. Everything is disabled while `_busy`.

## _run

- **Side effects:** Sets `_busy`, awaits the action, and on any error shows a `SnackBar` with
  `profileAvatarError` ("This image could not be used"). Used for choosing and removing the avatar.

## _save

- **Side effects:** Sets `_busy`, calls `ProfileNotifier.setName(text)` (trimmed by the store; empty
  clears the name; an unchanged name writes nothing), then closes the dialog.
