import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/profile_provider.dart';
import 'profile_avatar.dart';

/// The avatar-and-name row at the top of Settings (1.7.0). Tapping it opens
/// [showProfileEditDialog].
class ProfileHeader extends ConsumerWidget {
  /// Purpose: Create the profile header.
  /// Inputs: None.
  /// Returns: A new `ProfileHeader`.
  /// Side effects: None.
  /// Notes: None.
  const ProfileHeader({super.key});

  /// Purpose: Build the header row.
  /// Inputs: `context`, `ref`.
  /// Returns: A tappable list tile with a large avatar and the name.
  /// Side effects: None until tapped.
  /// Notes: Without a name the title invites the user to set one.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final name = ref.watch(profileProvider.select((p) => p.name));
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: const ProfileAvatar(radius: 28),
      title: Text(
        name ?? l10n.profileNamePlaceholder,
        style: theme.textTheme.titleLarge?.copyWith(
          color: name == null ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: Text(l10n.profileEditHint),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => showProfileEditDialog(context),
    );
  }
}

/// Purpose: Open the dialog that edits the name and avatar.
/// Inputs: `context`.
/// Returns: `Future<void>` completing when the dialog closes.
/// Side effects: Avatar changes save immediately; the name saves on Save.
/// Notes: Must be called below a `ProviderScope`.
Future<void> showProfileEditDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const _ProfileDialog());

class _ProfileDialog extends ConsumerStatefulWidget {
  /// Purpose: Create the profile edit dialog.
  /// Inputs: None.
  /// Returns: A new `_ProfileDialog`.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  const _ProfileDialog();

  /// Purpose: Create the dialog state.
  /// Inputs: None.
  /// Returns: `_ProfileDialogState`.
  /// Side effects: None.
  /// Notes: None.
  @override
  ConsumerState<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends ConsumerState<_ProfileDialog> {
  late final TextEditingController _name;
  bool _busy = false;

  /// Purpose: Seed the name field from the current profile.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Creates the text controller.
  /// Notes: None.
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: ref.read(profileProvider).name ?? '');
  }

  /// Purpose: Release the text controller.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Disposes the controller.
  /// Notes: None.
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// Purpose: Run an avatar action with a busy state and error reporting.
  /// Inputs: `action`.
  /// Returns: None.
  /// Side effects: Calls the action; shows a snack bar when it fails.
  /// Notes: Internal helper used within this file only.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileAvatarError)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Purpose: Save the name and close.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Writes `profile.json` when the name changed.
  /// Notes: Internal helper used within this file only.
  Future<void> _save() async {
    setState(() => _busy = true);
    await ref.read(profileProvider.notifier).setName(_name.text);
    if (mounted) Navigator.of(context).pop();
  }

  /// Purpose: Build the dialog.
  /// Inputs: `context`.
  /// Returns: An `AlertDialog`.
  /// Side effects: None.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasAvatar =
        ref.watch(profileProvider.select((p) => p.avatar)) != null;
    final notifier = ref.read(profileProvider.notifier);
    return AlertDialog(
      title: Text(l10n.profileTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProfileAvatar(radius: 48),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _run(() async => notifier.pickAvatar()),
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(l10n.profileChangeAvatar),
                ),
                if (hasAvatar)
                  TextButton(
                    onPressed: _busy ? null : () => _run(notifier.removeAvatar),
                    child: Text(l10n.profileRemoveAvatar),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              enabled: !_busy,
              maxLength: 40,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(labelText: l10n.profileName),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
