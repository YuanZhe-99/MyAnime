/// The contents of `recommendations.json` (1.6.2): the recommendation trash
/// bins and each record's persisted related-recommendation snapshot; since
/// 1.6.3 also the pinned recommendations and the fetched thumbnail and
/// synopsis of each missing-sequel card. The file is synced and backed up as its own module (`lib/app/data_modules.dart`),
/// so every class here keeps unknown JSON keys in `extraJson` and writes them
/// back — an older build must never delete a newer build's data.
library;

/// Purpose: Collect the keys of `json` that `known` does not list.
/// Inputs: `json`; `known`.
/// Returns: `Map<String, dynamic>` — the unknown entries.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Map<String, dynamic> _unknown(Map json, Set<String> known) => {
  for (final e in json.entries)
    if (e.key is String && !known.contains(e.key)) e.key as String: e.value,
};

/// Purpose: Read a UTC timestamp tolerantly.
/// Inputs: `value`.
/// Returns: `DateTime?` — null when missing or unparseable.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// Purpose: Parse a JSON list into a map keyed by each entry's key.
/// Inputs: `raw` — the list; `parse` — reads one entry, null when unusable;
/// `keyOf` — the entry's key.
/// Returns: `Map<String, T>` — a later duplicate key wins.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Anything that is not a
/// list reads as empty.
Map<String, T> _indexed<T>(
  Object? raw,
  T? Function(Object?) parse,
  String Function(T) keyOf,
) {
  final out = <String, T>{};
  if (raw is! List) return out;
  for (final item in raw) {
    final e = parse(item);
    if (e != null) out[keyOf(e)] = e;
  }
  return out;
}

/// Purpose: Pick the earlier of two optional timestamps.
/// Inputs: `a`, `b`.
/// Returns: `DateTime?`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
DateTime? _earlier(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isBefore(b) ? a : b;
}

/// One record in a trash bin.
class HiddenEntry {
  /// The anime id that was trashed.
  final String id;

  /// When it was trashed (UTC), if known.
  final DateTime? hiddenAt;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a trash entry.
  /// Inputs: `id`, `hiddenAt`, `extraJson`.
  /// Returns: A new `HiddenEntry`.
  /// Side effects: None.
  /// Notes: None.
  const HiddenEntry(this.id, {this.hiddenAt, this.extraJson = const {}});

  /// Purpose: Read an entry tolerantly.
  /// Inputs: `json`.
  /// Returns: `HiddenEntry?` — null without a string `id`.
  /// Side effects: None.
  /// Notes: None.
  static HiddenEntry? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return HiddenEntry(
      json['id'] as String,
      hiddenAt: _time(json['hiddenAt']),
      extraJson: _unknown(json, const {'id', 'hiddenAt'}),
    );
  }

  /// Purpose: Serialize the entry.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Unknown keys first, known keys over them.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    'hiddenAt': ?hiddenAt?.toUtc().toIso8601String(),
  };

  /// Purpose: Combine the two sides of one entry during a merge.
  /// Inputs: `other` — the remote side.
  /// Returns: `HiddenEntry` — the earlier `hiddenAt`, unknown keys unioned
  /// with this side winning.
  /// Side effects: None.
  /// Notes: Both sides agree the record is trashed; nothing can conflict.
  HiddenEntry mergedWith(HiddenEntry other) => HiddenEntry(
    id,
    hiddenAt: _earlier(hiddenAt, other.hiddenAt),
    extraJson: {...other.extraJson, ...extraJson},
  );
}

/// One "Not in your library yet" sequel card in the global trash.
class HiddenSequelEntry {
  /// The dedupe key: the canonical database key of the sequel's page, else
  /// its URL, else its title.
  final String key;

  /// The library record the sequel follows, if known.
  final String? sourceId;

  /// The sequel's title as the database listed it, for the trash view.
  final String? title;

  /// The database that listed it, for the trash view.
  final String? source;

  /// When it was trashed (UTC), if known.
  final DateTime? hiddenAt;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a trashed-sequel entry.
  /// Inputs: see fields.
  /// Returns: A new `HiddenSequelEntry`.
  /// Side effects: None.
  /// Notes: The labels are kept so the trash can still name the entry after
  /// the relation that produced it disappears.
  const HiddenSequelEntry(
    this.key, {
    this.sourceId,
    this.title,
    this.source,
    this.hiddenAt,
    this.extraJson = const {},
  });

  /// Purpose: Read an entry tolerantly.
  /// Inputs: `json`.
  /// Returns: `HiddenSequelEntry?` — null without a string `key`.
  /// Side effects: None.
  /// Notes: None.
  static HiddenSequelEntry? fromJson(Object? json) {
    if (json is! Map || json['key'] is! String) return null;
    String? s(String k) => json[k] is String ? json[k] as String : null;
    return HiddenSequelEntry(
      json['key'] as String,
      sourceId: s('sourceId'),
      title: s('title'),
      source: s('source'),
      hiddenAt: _time(json['hiddenAt']),
      extraJson: _unknown(json, const {
        'key',
        'sourceId',
        'title',
        'source',
        'hiddenAt',
      }),
    );
  }

  /// Purpose: Serialize the entry.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: None.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'key': key,
    'sourceId': ?sourceId,
    'title': ?title,
    'source': ?source,
    'hiddenAt': ?hiddenAt?.toUtc().toIso8601String(),
  };

  /// Purpose: Combine the two sides of one entry during a merge.
  /// Inputs: `other` — the remote side.
  /// Returns: `HiddenSequelEntry`.
  /// Side effects: None.
  /// Notes: Labels prefer this side, then the other; earlier `hiddenAt`.
  HiddenSequelEntry mergedWith(HiddenSequelEntry other) => HiddenSequelEntry(
    key,
    sourceId: sourceId ?? other.sourceId,
    title: title ?? other.title,
    source: source ?? other.source,
    hiddenAt: _earlier(hiddenAt, other.hiddenAt),
    extraJson: {...other.extraJson, ...extraJson},
  );
}

/// One pinned recommendation (1.6.3): a library record, or — in
/// `pinnedSequels` — a missing-sequel card keyed by its dedupe key. A pinned
/// card survives a refresh and is shown first.
class PinnedEntry {
  /// The anime id, or the missing-sequel dedupe key.
  final String key;

  /// When it was pinned (UTC), if known.
  final DateTime? pinnedAt;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a pin.
  /// Inputs: `key`, `pinnedAt`, `extraJson`.
  /// Returns: A new `PinnedEntry`.
  /// Side effects: None.
  /// Notes: The same class serves library pins (JSON key `id`) and sequel
  /// pins (JSON key `key`); `idKey` on read and write picks which.
  const PinnedEntry(this.key, {this.pinnedAt, this.extraJson = const {}});

  /// Purpose: Read a pin tolerantly.
  /// Inputs: `json`; `idKey` — `id` for library pins, `key` for sequel pins.
  /// Returns: `PinnedEntry?` — null without a string key.
  /// Side effects: None.
  /// Notes: None.
  static PinnedEntry? fromJson(Object? json, {String idKey = 'id'}) {
    if (json is! Map || json[idKey] is! String) return null;
    return PinnedEntry(
      json[idKey] as String,
      pinnedAt: _time(json['pinnedAt']),
      extraJson: _unknown(json, {idKey, 'pinnedAt'}),
    );
  }

  /// Purpose: Serialize the pin.
  /// Inputs: `idKey` — see [fromJson].
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Unknown keys first, known keys over them.
  Map<String, dynamic> toJson({String idKey = 'id'}) => {
    ...extraJson,
    idKey: key,
    'pinnedAt': ?pinnedAt?.toUtc().toIso8601String(),
  };

  /// Purpose: Combine the two sides of one pin during a merge.
  /// Inputs: `other` — the remote side.
  /// Returns: `PinnedEntry` — the earlier `pinnedAt`, unknown keys unioned
  /// with this side winning.
  /// Side effects: None.
  /// Notes: Both sides agree it is pinned; nothing can conflict.
  PinnedEntry mergedWith(PinnedEntry other) => PinnedEntry(
    key,
    pinnedAt: _earlier(pinnedAt, other.pinnedAt),
    extraJson: {...other.extraJson, ...extraJson},
  );
}

/// What was fetched about one missing sequel (1.6.3): a short synopsis and
/// a small cover thumbnail, so the "Not in your library yet" card shows more
/// than a title. Synced with the rest of the file; deleted when the card is
/// trashed, so the trash keeps only the basic labels.
class SequelInfo {
  /// The synopsis the database gave, normalised and capped.
  final String? synopsis;

  /// The full-size cover URL the thumbnail was made from.
  final String? coverUrl;

  /// A small JPEG thumbnail, base64-encoded.
  final String? coverThumb;

  /// When this was fetched (UTC).
  final DateTime? fetchedAt;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create sequel info.
  /// Inputs: see fields.
  /// Returns: A new `SequelInfo`.
  /// Side effects: None.
  /// Notes: Every field is optional: a source may report a synopsis and no
  /// cover, or the other way round.
  const SequelInfo({
    this.synopsis,
    this.coverUrl,
    this.coverThumb,
    this.fetchedAt,
    this.extraJson = const {},
  });

  /// Purpose: Read sequel info tolerantly.
  /// Inputs: `json`.
  /// Returns: `SequelInfo?` — null when not an object.
  /// Side effects: None.
  /// Notes: Non-string fields read as absent.
  static SequelInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    String? s(String k) => json[k] is String ? json[k] as String : null;
    return SequelInfo(
      synopsis: s('synopsis'),
      coverUrl: s('coverUrl'),
      coverThumb: s('coverThumb'),
      fetchedAt: _time(json['fetchedAt']),
      extraJson: _unknown(json, const {
        'synopsis',
        'coverUrl',
        'coverThumb',
        'fetchedAt',
      }),
    );
  }

  /// Purpose: Serialize the info.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Absent fields are omitted.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'synopsis': ?synopsis,
    'coverUrl': ?coverUrl,
    'coverThumb': ?coverThumb,
    'fetchedAt': ?fetchedAt?.toUtc().toIso8601String(),
  };

  /// Purpose: Combine the two sides of one entry during a merge.
  /// Inputs: `other` — the remote side.
  /// Returns: `SequelInfo` — the side fetched later (a tie keeps this side),
  /// with unknown keys unioned, this side winning.
  /// Side effects: None.
  /// Notes: The info is a cache of public data, so newer wins.
  SequelInfo mergedWith(SequelInfo other) {
    final o = other.fetchedAt;
    final t = fetchedAt;
    final newer = o != null && (t == null || o.isAfter(t)) ? other : this;
    return SequelInfo(
      synopsis: newer.synopsis,
      coverUrl: newer.coverUrl,
      coverThumb: newer.coverThumb,
      fetchedAt: newer.fetchedAt,
      extraJson: {...other.extraJson, ...extraJson},
    );
  }
}

/// One item of a persisted related-recommendation list.
class RelatedItem {
  /// The related record's anime id.
  final String id;

  /// Encoded reason chips, e.g. `categories:romance,school`, `studio:<name>`,
  /// `relation:spinOff`, `baseTitle`. Codes this build does not know are
  /// kept and not shown.
  final List<String> reasons;

  /// The generated reason, when the on-device model wrote one.
  final String? aiReason;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a related item.
  /// Inputs: see fields.
  /// Returns: A new `RelatedItem`.
  /// Side effects: None.
  /// Notes: None.
  const RelatedItem(
    this.id, {
    this.reasons = const [],
    this.aiReason,
    this.extraJson = const {},
  });

  /// Purpose: Read an item tolerantly.
  /// Inputs: `json`.
  /// Returns: `RelatedItem?` — null without a string `id`.
  /// Side effects: None.
  /// Notes: None.
  static RelatedItem? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    final raw = json['reasons'];
    return RelatedItem(
      json['id'] as String,
      reasons: [
        if (raw is List)
          for (final r in raw)
            if (r is String) r,
      ],
      aiReason: json['aiReason'] is String ? json['aiReason'] as String : null,
      extraJson: _unknown(json, const {'id', 'reasons', 'aiReason'}),
    );
  }

  /// Purpose: Serialize the item.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Empty `reasons` are omitted.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'id': id,
    if (reasons.isNotEmpty) 'reasons': reasons,
    'aiReason': ?aiReason,
  };

  /// Purpose: Copy the item with a generated reason.
  /// Inputs: `aiReason`.
  /// Returns: `RelatedItem`.
  /// Side effects: None.
  /// Notes: None.
  RelatedItem withAiReason(String? aiReason) => RelatedItem(
    id,
    reasons: reasons,
    aiReason: aiReason,
    extraJson: extraJson,
  );
}

/// One record's related recommendations: the persisted list and its own
/// trash bin.
class RelatedSnapshot {
  /// When the list was generated (UTC); null when only the trash exists.
  final DateTime? generatedAt;

  /// The persisted list, best first.
  final List<RelatedItem> items;

  /// This record's own trash bin, by anime id.
  final Map<String, HiddenEntry> hidden;

  /// Items pinned in this record's list, by anime id (1.6.3). A pinned item
  /// survives the card's refresh and is shown first.
  final Map<String, PinnedEntry> pinned;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create a snapshot.
  /// Inputs: see fields.
  /// Returns: A new `RelatedSnapshot`.
  /// Side effects: None.
  /// Notes: None.
  RelatedSnapshot({
    this.generatedAt,
    List<RelatedItem>? items,
    Map<String, HiddenEntry>? hidden,
    Map<String, PinnedEntry>? pinned,
    Map<String, dynamic>? extraJson,
  }) : items = items ?? [],
       hidden = hidden ?? {},
       pinned = pinned ?? {},
       extraJson = extraJson ?? {};

  /// Purpose: Report whether a list has been generated at all.
  /// Inputs: None.
  /// Returns: `bool` — true once `generatedAt` is set.
  /// Side effects: None.
  /// Notes: A snapshot holding only a trash bin is not generated.
  bool get isGenerated => generatedAt != null;

  /// Purpose: Report whether the snapshot carries nothing worth writing.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: Empty snapshots are dropped from the file.
  bool get isEmpty =>
      generatedAt == null &&
      items.isEmpty &&
      hidden.isEmpty &&
      pinned.isEmpty &&
      extraJson.isEmpty;

  /// Purpose: Read a snapshot tolerantly.
  /// Inputs: `json`.
  /// Returns: `RelatedSnapshot?` — null when not an object.
  /// Side effects: None.
  /// Notes: Malformed items and entries are dropped.
  static RelatedSnapshot? fromJson(Object? json) {
    if (json is! Map) return null;
    final items = json['items'];
    final hidden = json['hidden'];
    return RelatedSnapshot(
      generatedAt: _time(json['generatedAt']),
      items: [
        if (items is List)
          for (final i in items) ?RelatedItem.fromJson(i),
      ],
      hidden: _indexed(hidden, HiddenEntry.fromJson, (e) => e.id),
      pinned: _indexed(json['pinned'], PinnedEntry.fromJson, (e) => e.key),
      extraJson: _unknown(json, const {
        'generatedAt',
        'items',
        'hidden',
        'pinned',
      }),
    );
  }

  /// Purpose: Serialize the snapshot.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: The trash and the pins are sorted by id so unchanged data writes
  /// identical bytes; items keep their ranked order. Empty parts are omitted.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'generatedAt': ?generatedAt?.toUtc().toIso8601String(),
    if (items.isNotEmpty) 'items': [for (final i in items) i.toJson()],
    if (hidden.isNotEmpty)
      'hidden': [
        for (final id in hidden.keys.toList()..sort()) hidden[id]!.toJson(),
      ],
    if (pinned.isNotEmpty)
      'pinned': [
        for (final id in pinned.keys.toList()..sort()) pinned[id]!.toJson(),
      ],
  };
}

/// The whole of `recommendations.json`.
class RecommendationData {
  /// The file format version this build writes.
  static const currentVersion = 1;

  /// The version read from disk, kept so a newer file is not relabelled.
  final int version;

  /// The global trash bin, by anime id.
  final Map<String, HiddenEntry> hidden;

  /// Trashed missing-sequel cards, by dedupe key.
  final Map<String, HiddenSequelEntry> hiddenSequels;

  /// Related recommendations per record, by anime id.
  final Map<String, RelatedSnapshot> related;

  /// Pinned library cards on "What to watch next", by anime id (1.6.3).
  final Map<String, PinnedEntry> pinned;

  /// Pinned missing-sequel cards, by dedupe key (1.6.3).
  final Map<String, PinnedEntry> pinnedSequels;

  /// Fetched synopsis and thumbnail per missing sequel, by dedupe key
  /// (1.6.3).
  final Map<String, SequelInfo> sequelInfo;

  /// JSON keys this build does not know.
  final Map<String, dynamic> extraJson;

  /// Purpose: Create the store contents.
  /// Inputs: see fields.
  /// Returns: A new `RecommendationData`.
  /// Side effects: None.
  /// Notes: Collections are mutable so the store helpers can edit in place.
  RecommendationData({
    this.version = currentVersion,
    Map<String, HiddenEntry>? hidden,
    Map<String, HiddenSequelEntry>? hiddenSequels,
    Map<String, RelatedSnapshot>? related,
    Map<String, PinnedEntry>? pinned,
    Map<String, PinnedEntry>? pinnedSequels,
    Map<String, SequelInfo>? sequelInfo,
    Map<String, dynamic>? extraJson,
  }) : hidden = hidden ?? {},
       hiddenSequels = hiddenSequels ?? {},
       related = related ?? {},
       pinned = pinned ?? {},
       pinnedSequels = pinnedSequels ?? {},
       sequelInfo = sequelInfo ?? {},
       extraJson = extraJson ?? {};

  /// Purpose: Read the file tolerantly.
  /// Inputs: `json` — the decoded file.
  /// Returns: `RecommendationData`.
  /// Side effects: None.
  /// Notes: Throws `FormatException` when `json` is not an object, so the
  /// sync module's validation rejects a file that is not ours; inside the
  /// object, malformed entries are dropped.
  factory RecommendationData.fromJson(Object? json) {
    if (json is! Map) {
      throw const FormatException('recommendations.json is not an object');
    }
    final hidden = json['hidden'];
    final sequels = json['hiddenSequels'];
    final related = json['related'];
    return RecommendationData(
      version: json['version'] is int ? json['version'] as int : currentVersion,
      hidden: _indexed(hidden, HiddenEntry.fromJson, (e) => e.id),
      hiddenSequels: _indexed(
        sequels,
        HiddenSequelEntry.fromJson,
        (e) => e.key,
      ),
      related: {
        if (related is Map)
          for (final e in related.entries)
            if (e.key is String)
              e.key as String: ?RelatedSnapshot.fromJson(e.value),
      },
      pinned: _indexed(json['pinned'], PinnedEntry.fromJson, (e) => e.key),
      pinnedSequels: _indexed(
        json['pinnedSequels'],
        (j) => PinnedEntry.fromJson(j, idKey: 'key'),
        (e) => e.key,
      ),
      sequelInfo: {
        if (json['sequelInfo'] case final Map info)
          for (final e in info.entries)
            if (e.key is String) e.key as String: ?SequelInfo.fromJson(e.value),
      },
      extraJson: _unknown(json, const {
        'version',
        'hidden',
        'hiddenSequels',
        'related',
        'pinned',
        'pinnedSequels',
        'sequelInfo',
      }),
    );
  }

  /// Purpose: Serialize the file.
  /// Inputs: None.
  /// Returns: `Map<String, dynamic>`.
  /// Side effects: None.
  /// Notes: Every collection is sorted by its key, so unchanged data writes
  /// identical bytes and sync hits its raw-equality fast path. Empty
  /// snapshots are dropped. The 1.6.3 keys (`pinned`, `pinnedSequels`,
  /// `sequelInfo`) are written only when non-empty, so a file that never
  /// used them keeps its 1.6.2 bytes.
  Map<String, dynamic> toJson() => {
    ...extraJson,
    'version': version,
    'hidden': [
      for (final id in hidden.keys.toList()..sort()) hidden[id]!.toJson(),
    ],
    'hiddenSequels': [
      for (final k in hiddenSequels.keys.toList()..sort())
        hiddenSequels[k]!.toJson(),
    ],
    'related': {
      for (final id in related.keys.toList()..sort())
        if (!related[id]!.isEmpty) id: related[id]!.toJson(),
    },
    if (pinned.isNotEmpty)
      'pinned': [
        for (final id in pinned.keys.toList()..sort()) pinned[id]!.toJson(),
      ],
    if (pinnedSequels.isNotEmpty)
      'pinnedSequels': [
        for (final k in pinnedSequels.keys.toList()..sort())
          pinnedSequels[k]!.toJson(idKey: 'key'),
      ],
    if (sequelInfo.isNotEmpty)
      'sequelInfo': {
        for (final k in sequelInfo.keys.toList()..sort())
          k: sequelInfo[k]!.toJson(),
      },
  };

  /// Purpose: Read one record's snapshot, creating it when absent.
  /// Inputs: `animeId`.
  /// Returns: `RelatedSnapshot` — stored in [related].
  /// Side effects: May add an empty snapshot to [related].
  /// Notes: An empty snapshot is not written.
  RelatedSnapshot relatedFor(String animeId) =>
      related.putIfAbsent(animeId, RelatedSnapshot.new);
}
