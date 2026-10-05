import 'package:flutter/material.dart';
import 'package:myapps_profile/myapps_profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';
import '../services/profile_store.dart';

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

/// App-compatible rendering adapter over the shared avatar component.
class ProfileAvatarView extends StatelessWidget {
  final ProfileData profile;
  final double radius;

  /// Purpose: Create an avatar using the application's image resolver.
  /// Inputs: `profile`, `radius`.
  /// Returns: Avatar adapter.
  /// Side effects: None.
  /// Notes: Public constructor retained.
  const ProfileAvatarView({super.key, required this.profile, this.radius = 18});

  /// Purpose: Render the shared image or placeholder.
  /// Inputs: `context`.
  /// Returns: Avatar circle.
  /// Side effects: Resolves an image file.
  /// Notes: Sync refresh remains in the app provider.
  @override
  Widget build(BuildContext context) => MyAppsProfileAvatar(
    profile: profile,
    radius: radius,
    resolveImage: ProfileStore.resolveImage,
  );
}
