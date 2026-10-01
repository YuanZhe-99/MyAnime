/// The merge for `profile.json` (1.7.0). It never produces a conflict: the
/// name and the avatar are merged independently, each keeping the side with
/// the later timestamp.
library;

import 'dart:convert';

import '../models/profile_data.dart';

const _prettyJson = JsonEncoder.withIndent('  ');

/// Purpose: Encode the profile the way `ProfileStore` writes it.
/// Inputs: `data`.
/// Returns: Pretty-printed JSON.
/// Side effects: None.
/// Notes: Merge output and local saves must be byte-identical for the same
/// data, or an unchanged file would re-upload on every sync.
String encodeProfile(ProfileData data) => _prettyJson.convert(data.toJson());

/// Purpose: Decide whether the remote side of one field is newer.
/// Inputs: `local`, `remote` — the field's timestamps.
/// Returns: `bool` — true only when remote is strictly later.
/// Side effects: None.
/// Notes: Internal helper used within this file only. A tie keeps local; a
/// side that never set the field always loses to one that did.
bool _remoteWins(DateTime? local, DateTime? remote) {
  if (remote == null) return false;
  if (local == null) return true;
  return remote.isAfter(local);
}

/// Purpose: Merge local and remote profiles.
/// Inputs: `local`, `remote`.
/// Returns: `ProfileData`.
/// Side effects: None.
/// Notes: Last writer wins per field, so a name changed on one device and an
/// avatar changed on another both survive. Unknown keys are unioned with
/// local winning, and the higher `version` is kept. The base is not needed:
/// a removal is an explicit timestamped value, never a missing key.
ProfileData mergeProfile(ProfileData local, ProfileData remote) {
  final nameFromRemote = _remoteWins(
    local.displayNameUpdatedAt,
    remote.displayNameUpdatedAt,
  );
  final avatarFromRemote = _remoteWins(
    local.avatarUpdatedAt,
    remote.avatarUpdatedAt,
  );
  final name = nameFromRemote ? remote : local;
  final avatar = avatarFromRemote ? remote : local;
  return ProfileData(
    version: local.version > remote.version ? local.version : remote.version,
    displayName: name.displayName,
    displayNameUpdatedAt: name.displayNameUpdatedAt,
    avatar: avatar.avatar,
    avatarUpdatedAt: avatar.avatarUpdatedAt,
    extraJson: {...remote.extraJson, ...local.extraJson},
  );
}

/// Purpose: Merge the raw JSON of both sides for the sync engine.
/// Inputs: `localJson`, `remoteJson`.
/// Returns: The merged file as pretty-printed JSON.
/// Side effects: None.
/// Notes: Throws when either side is not a JSON object.
String mergeProfileJson(String localJson, String remoteJson) => encodeProfile(
  mergeProfile(
    ProfileData.fromJson(jsonDecode(localJson)),
    ProfileData.fromJson(jsonDecode(remoteJson)),
  ),
);
