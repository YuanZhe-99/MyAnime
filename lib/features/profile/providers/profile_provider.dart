import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/auto_sync_service.dart';
import '../models/profile_data.dart';
import '../services/profile_store.dart';

/// Holds the current [ProfileData] for the UI (1.7.0).
///
/// Loads `profile.json` once, reloads whenever sync or a restore rewrites
/// local data, and routes every edit through [ProfileStore] so the file stays
/// the single source of truth.
class ProfileNotifier extends StateNotifier<ProfileData> {
  /// Purpose: Create the notifier and start loading the profile.
  /// Inputs: None.
  /// Returns: A new `ProfileNotifier`.
  /// Side effects: Reads `profile.json` and subscribes to local-data-changed
  /// events from auto-sync.
  /// Notes: Starts empty; the loaded profile replaces it a moment later.
  ProfileNotifier() : super(ProfileData()) {
    AutoSyncService.instance.addOnLocalDataChanged(reload);
    reload();
  }

  /// Purpose: Create a notifier with a fixed profile and no I/O.
  /// Inputs: `profile`.
  /// Returns: A new `ProfileNotifier`.
  /// Side effects: None.
  /// Notes: For tests that override [profileProvider]. Edits still go
  /// through [ProfileStore].
  ProfileNotifier.fixed(super.profile);

  /// Purpose: Re-read `profile.json`.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Reads the file and replaces the state.
  /// Notes: Safe to call after dispose; the result is then dropped.
  Future<void> reload() async {
    final data = await ProfileStore.load();
    if (mounted) state = data;
  }

  /// Purpose: Save a new display name.
  /// Inputs: `name`.
  /// Returns: None.
  /// Side effects: Writes `profile.json`; notifies auto-sync.
  /// Notes: Empty clears the name.
  Future<void> setName(String name) async {
    final data = await ProfileStore.setName(name);
    if (mounted) state = data;
  }

  /// Purpose: Save an avatar produced by the avatar editor (1.7.2).
  /// Inputs: `jpeg` — the edited square JPEG.
  /// Returns: None.
  /// Side effects: See [ProfileStore.setAvatarJpeg].
  /// Notes: Picking and editing happen in the UI before this is called.
  Future<void> setAvatarJpeg(Uint8List jpeg) async {
    final data = await ProfileStore.setAvatarJpeg(jpeg);
    if (mounted) state = data;
  }

  /// Purpose: Remove the avatar.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: See [ProfileStore.removeAvatar].
  /// Notes: None.
  Future<void> removeAvatar() async {
    final data = await ProfileStore.removeAvatar();
    if (mounted) state = data;
  }

  /// Purpose: Stop listening for local data changes.
  /// Inputs: None.
  /// Returns: None.
  /// Side effects: Unsubscribes from auto-sync.
  /// Notes: None.
  @override
  void dispose() {
    AutoSyncService.instance.removeOnLocalDataChanged(reload);
    super.dispose();
  }
}

/// The app-wide profile.
final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileData>(
  (ref) => ProfileNotifier(),
);
