import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/image_service.dart';
import '../models/profile_data.dart';
import '../providers/profile_provider.dart';

/// The user's avatar in a circle (1.7.0), as shown on the Home app bar and
/// at the top of Settings.
///
/// Shows the avatar image when one is set and its file is on this device;
/// otherwise the first letter of the display name, or a person icon when
/// there is no name either. A file that has not arrived yet from sync falls
/// back the same way and appears once the next rebuild finds it.
class ProfileAvatar extends ConsumerWidget {
  /// Circle radius in logical pixels.
  final double radius;

  /// Purpose: Create a profile avatar.
  /// Inputs: `radius`.
  /// Returns: A new `ProfileAvatar`.
  /// Side effects: None.
  /// Notes: Reads [profileProvider].
  const ProfileAvatar({super.key, this.radius = 18});

  /// Purpose: Build the circle for the current profile.
  /// Inputs: `context`, `ref`.
  /// Returns: The avatar widget.
  /// Side effects: Resolves the avatar file path asynchronously.
  /// Notes: None.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return ProfileAvatarView(profile: profile, radius: radius);
  }
}

/// The stateless rendering behind [ProfileAvatar], taking the profile as an
/// argument so tests and previews need no provider.
class ProfileAvatarView extends StatelessWidget {
  final ProfileData profile;
  final double radius;

  /// Purpose: Create an avatar view for a given profile.
  /// Inputs: `profile`, `radius`.
  /// Returns: A new `ProfileAvatarView`.
  /// Side effects: None.
  /// Notes: None.
  const ProfileAvatarView({super.key, required this.profile, this.radius = 18});

  /// Purpose: Build the placeholder shown without an image.
  /// Inputs: `context`.
  /// Returns: A filled circle with an initial or a person icon.
  /// Side effects: None.
  /// Notes: Internal helper used within this file only.
  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = profile.name;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: name == null
          ? Icon(Icons.person, size: radius * 1.2)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w500,
              ),
            ),
    );
  }

  /// Purpose: Build the avatar circle.
  /// Inputs: `context`.
  /// Returns: The image in a circle, or the placeholder.
  /// Side effects: Resolves the avatar file path asynchronously.
  /// Notes: None.
  @override
  Widget build(BuildContext context) {
    final avatar = profile.avatar;
    if (avatar == null) return _placeholder(context);
    return FutureBuilder<File>(
      key: ValueKey(avatar),
      future: ImageService.resolve(avatar),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _placeholder(context);
        return ClipOval(
          child: Image.file(
            file,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, _, _) => _placeholder(context),
          ),
        );
      },
    );
  }
}
