/// The user profile kept in `profile.json` (1.7.0): a display name and an
/// avatar image, synced to every device.
///
/// Each field carries its own UTC timestamp so two devices editing different
/// fields both keep their change, and the newer edit of the same field wins.
/// Unknown keys are preserved so an older build never deletes a newer build's
/// data.
library;

/// Purpose: Collect the keys a model does not know.
/// Inputs: `json`, `known`.
/// Returns: `Map<String, dynamic>` — every other string key with its value.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _unknown(Map json, Set<String> known) => {
  for (final e in json.entries)
    if (e.key is String && !known.contains(e.key)) e.key as String: e.value,
};

/// Purpose: Parse an optional timestamp.
/// Inputs: `value`.
/// Returns: `DateTime?` — UTC, or null when absent or malformed.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

class ProfileData {
  /// Schema version written by this build.
  static const currentVersion = 1;

  /// Schema version of the file; the higher side wins on merge.
  final int version;

  /// The name shown beside the avatar; null or empty when unset.
  final String? displayName;

  /// When [displayName] last changed (UTC); null when never set.
  final DateTime? displayNameUpdatedAt;

  /// The avatar as a path relative to the app directory
  /// (`images/avatar_<uuid>.jpg`); null when unset or removed.
  final String? avatar;

  /// When [avatar] last changed (UTC), including a removal; null when never
  /// set.
  final DateTime? avatarUpdatedAt;

  /// Top-level keys this build does not know, written back unchanged.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a profile.
  /// Inputs: All fields; every one optional.
  /// Returns: A new `ProfileData` instance.
  /// Side effects: None.
  /// Notes: Timestamps are normalised to UTC.
  ProfileData({
    this.version = currentVersion,
    this.displayName,
    DateTime? displayNameUpdatedAt,
    this.avatar,
    DateTime? avatarUpdatedAt,
    Map<String, dynamic>? extraJson,
  }) : displayNameUpdatedAt = displayNameUpdatedAt?.toUtc(),
       avatarUpdatedAt = avatarUpdatedAt?.toUtc(),
       extraJson = extraJson ?? {};

  /// Purpose: Parse the file's JSON.
  /// Inputs: `json` — the decoded file.
  /// Returns: `ProfileData`.
  /// Side effects: None.
  /// Notes: Tolerant inside the object: wrong-typed fields read as unset.
  /// Throws a [FormatException] when `json` is not a JSON object.
  factory ProfileData.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('profile.json is not a JSON object');
    }
    final name = json['displayName'];
    final avatar = json['avatar'];
    final version = json['version'];
    return ProfileData(
      version: version is int ? version : currentVersion,
      displayName: name is String ? name : null,
      displayNameUpdatedAt: _parseTime(json['displayNameUpdatedAt']),
      avatar: avatar is String && avatar.isNotEmpty ? avatar : null,
      avatarUpdatedAt: _parseTime(json['avatarUpdatedAt']),
      extraJson: _unknown(json, const {
        'version',
        'displayName',
        'displayNameUpdatedAt',
        'avatar',
        'avatarUpdatedAt',
      }),
    );
  }

  /// Purpose: Serialise for `profile.json`.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: A field is written only once it has a timestamp. A removed
  /// avatar is written as an explicit `null` with its timestamp, so the
  /// removal syncs instead of being taken for "never set".
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'version': version,
    if (displayNameUpdatedAt != null) ...{
      'displayName': displayName,
      'displayNameUpdatedAt': displayNameUpdatedAt!.toIso8601String(),
    },
    if (avatarUpdatedAt != null) ...{
      'avatar': avatar,
      'avatarUpdatedAt': avatarUpdatedAt!.toIso8601String(),
    },
  };

  /// Purpose: Return the trimmed display name, or null when there is none.
  /// Inputs: None.
  /// Returns: `String?`.
  /// Side effects: None.
  /// Notes: Use this for display rather than [displayName].
  String? get name {
    final trimmed = displayName?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Purpose: Return the profile with a new display name.
  /// Inputs: `name`; `at` — the edit time (UTC).
  /// Returns: `ProfileData`.
  /// Side effects: None.
  /// Notes: None.
  ProfileData withName(String? name, DateTime at) => ProfileData(
    version: version,
    displayName: name,
    displayNameUpdatedAt: at,
    avatar: avatar,
    avatarUpdatedAt: avatarUpdatedAt,
    extraJson: extraJson,
  );

  /// Purpose: Return the profile with a new or removed avatar.
  /// Inputs: `avatar` — relative image path, or null to remove; `at`.
  /// Returns: `ProfileData`.
  /// Side effects: None.
  /// Notes: None.
  ProfileData withAvatar(String? avatar, DateTime at) => ProfileData(
    version: version,
    displayName: displayName,
    displayNameUpdatedAt: displayNameUpdatedAt,
    avatar: avatar,
    avatarUpdatedAt: at,
    extraJson: extraJson,
  );
}
