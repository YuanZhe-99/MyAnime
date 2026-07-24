# lib/features/anime/models/anime.dart

The core data model: `Anime` (one tracked series), `AnimeRating` (optional personal rating),
`AnimeData` (the top-level `{animes: [...]}` persisted container), plus the `AnimeType`,
`EpisodeStatus`, `AnimeViewingStatus`, and `AnimeRatingField` enums. This file owns
`fromJson`/`toJson` for all three classes, the `extraJson` unknown-field-preservation pattern used
by sync merges, and the quarter-placement / episode-air-date logic that drives the home calendar
and management-by-quarter views. Field-by-field reference (identity, schedule, episodes,
`AnimeType` thresholds, `AnimeRating` scoring, `extraJson`) lives in
[`../../../../data-formats.md`](../../../../data-formats.md); the tracking/quarter-placement
algorithms built on top of these fields are walked through in
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md). Consumers
include `AnimeStorage` ([`../services/anime_storage.md`](../services/anime_storage.md)),
`WebDAVService`/`sync_merge.dart` (three-way sync,
[`../../../../algorithms/three-way-merge.md`](../../../../algorithms/three-way-merge.md)), and
every view under `lib/features/anime/views/`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`_unknownJson`](#unknownjson) | top-level function | A | Compute the "keys not recognized by this type" map for `extraJson`. |
| [`_stringKeyedMap`](#stringkeyedmap) | top-level function | A | Normalize a `Map<dynamic, dynamic>` (from JSON decode) into `Map<String, dynamic>`. |
| [`_mergeJsonMaps`](#mergejsonmaps) | top-level function | A | Deep-merge a list of JSON maps, later maps' scalar values winning, nested maps merging recursively. |
| [`_parseAnimeType`](#parseanimetype) | top-level function | A | Parse a JSON string into an `AnimeType`, or `null` if unrecognized. |
| [`_parseEpisodeStatus`](#parseepisodestatus) | top-level function | A | Parse a JSON string into an `EpisodeStatus`, or `null` if unrecognized. |
| [`AnimeRating(...)`](#animerating-new) | constructor (`AnimeRating`) | A | Create a personal rating value (manual overall + five sub-scores). |
| `hasManualOverall` | getter (`AnimeRating`) | B | Whether `overall` is set. |
| `hasAnyScore` | getter (`AnimeRating`) | B | Whether any of `overall`/`visual`/`story`/`character`/`music`/`enjoyment` is set. |
| `hasAnyData` | getter (`AnimeRating`) | B | Whether there's any score or preserved `extraJson`. |
| [`effectiveOverall`](#effectiveoverall) | getter (`AnimeRating`) | A | Manual `overall` if set, else the average of filled sub-scores. |
| [`scoreFor`](#scorefor) | method (`AnimeRating`) | A | Look up the score for a given `AnimeRatingField`. |
| [`withExtraJson`](#withextrajson-animerating) | method (`AnimeRating`) | A | Copy with `extraJson` replaced. |
| [`toJson`](#tojson-animerating) | method (`AnimeRating`) | A | Serialize to the JSON shape stored under `Anime.rating`. |
| [`AnimeRating.fromJson`](#animerating-fromjson) | factory constructor | A | Parse a rating from JSON, routing non-numeric scores into `extraJson`. |
| [`_parseScore`](#parsescore) | top-level function | A | Parse a JSON value into a `double` score, or `null`. |
| [`_writeScore`](#writescore) | top-level function | A | Write (or remove) one score key in a JSON map being built. |
| [`Anime(...)`](#anime-new) | constructor (`Anime`) | A | Create an anime record with all persisted fields. |
| [`displayTitle`](#displaytitle) | getter (`Anime`) | A | Best available title: `title`, else `titleJa`, else empty string. |
| [`totalEpisodes`](#totalepisodes) | getter (`Anime`) | A | `endEpisode - startEpisode + 1`, or `null` if open-ended. |
| [`autoType`](#autotype) | getter (`Anime`) | A | Infer `AnimeType` from episode count thresholds. |
| [`effectiveType`](#effectivetype) | getter (`Anime`) | A | `manualType` if set, else `autoType`. |
| [`airsInQuarter`](#airsinquarter) | method (`Anime`) | A | Whether this anime should appear in a given `(year, quarter)` listing. |
| [`startQuarter`](#startquarter) | getter (`Anime`) | A | `(year, quarter)` derived from `firstAirDate`'s month. |
| [`weekOffsetFor`](#weekoffsetfor) | method (`Anime`) | A | Sum cumulative `episodeWeekOffsets` entries up to an episode number. |
| [`getEpisodeAirDate`](#getepisodeairdate) | method (`Anime`) | A | JST air timestamp for an episode, with late-night (`25:00`-style) rollover. |
| [`getEpisodeCalendarDate`](#getepisodecalendardate) | method (`Anime`) | A | JST calendar date for an episode, without rollover. |
| [`nextUnwatchedEpisode`](#nextunwatchedepisode) | getter (`Anime`) | A | First episode number still unwatched. |
| [`isCompleted`](#iscompleted) | getter (`Anime`) | A | Whether every episode up to `endEpisode` is watched. |
| [`viewingStatus`](#viewingstatus) | getter (`Anime`) | A | Derived `AnimeViewingStatus` (completed/watching/dropped/notStarted). |
| [`copyWith`](#copywith) | method (`Anime`) | A | Create a copy with selected fields replaced (with `clearXxx` flags for nullable fields). |
| [`withExtraJson`](#withextrajson-anime) | method (`Anime`) | A | Copy with `extraJson` replaced. |
| [`withPreservedUnknownJson`](#withpreservedunknownjson-anime) | method (`Anime`) | A | Merge `extraJson` (including nested rating `extraJson`) from fallback sources. |
| [`toJson`](#tojson-anime) | method (`Anime`) | A | Serialize to the JSON shape stored in `anime_data.json`. |
| [`Anime.fromJson`](#anime-fromjson) | factory constructor | A | Parse an anime record from JSON, preserving unrecognized fields. |
| [`Anime.create`](#anime-create) | factory constructor | A | Build a brand-new record with a fresh UUID and UTC timestamps. |
| `animeList` | getter (`AnimeData`) | B | Alias for `animes`. |
| `AnimeData(...)` | constructor (`AnimeData`) | B | Plain default-value constructor (`animes`/`extraJson`, both default to empty). |
| [`withExtraJson`](#withextrajson-animedata) | method (`AnimeData`) | A | Copy with `extraJson` replaced. |
| [`withPreservedUnknownJson`](#withpreservedunknownjson-animedata) | method (`AnimeData`) | A | Merge top-level `extraJson` from fallback sources. |
| [`toJson`](#tojson-animedata) | method (`AnimeData`) | A | Serialize to `{...extraJson, animes: [...]}`. |
| [`AnimeData.fromJson`](#animedata-fromjson) | factory constructor | A | Parse the `{animes: [...]}` container from JSON. |

Note on the verification count: the source file has 40 `/// Purpose:` doc comments, but this table
has 41 rows — the `AnimeData` default constructor (line 1063) has no doc comment at all in source
(unlike every other constructor in this file), yet is still a real declaration and is indexed above
(Tier B: a plain default-value constructor with no logic).

## Documentation

### `Map<String, dynamic> _unknownJson(Map<String, dynamic> json, Set<String> knownKeys)` <a id="unknownjson"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 41)
- **Purpose:** Compute the subset of a raw JSON map whose keys this app version doesn't recognize, for a given type's known-key set.
- **Inputs:** `json` — the raw decoded map; `knownKeys` — the field names this type does understand (`_animeJsonKeys`, `_ratingJsonKeys`, or `_animeDataJsonKeys`).
- **Returns:** `Map<String, dynamic>` — a copy of `json` with every key in `knownKeys` removed.
- **Side effects:** None.
- **Algorithm:** Copies `json` into a new map, then `removeWhere` on any key present in `knownKeys`.
- **Usage:**
  ```dart
  final extraJson = _unknownJson(json, _animeJsonKeys);
  ```
  (`Anime.fromJson`, same file)
- **Notes:** This is the foundation of the `extraJson` forward-compatibility pattern described in
  [`../../../../data-formats.md`](../../../../data-formats.md) — every `fromJson` in this file starts
  by calling this, then individual fields may add more entries back into `extraJson` (e.g. when a
  value fails to parse as its expected type).

### `Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> map)` <a id="stringkeyedmap"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 55)
- **Purpose:** Coerce a dynamically-keyed map (as produced by `jsonDecode` for nested objects) into a `Map<String, dynamic>`.
- **Inputs:** `map`.
- **Returns:** `Map<String, dynamic>` with every key converted via `.toString()`.
- **Side effects:** None.
- **Algorithm:** Single comprehension over `map.entries`, mapping each key through `.toString()`.
- **Usage:**
  ```dart
  final rawStatuses = _stringKeyedMap(rawStatusesValue);
  ```
  (`Anime.fromJson`, same file — `rawStatusesValue` is typed `Map<dynamic, dynamic>` straight out of `jsonDecode`)
- **Notes:** Needed because `dart:convert`'s `jsonDecode` types nested object values as `Map<dynamic, dynamic>`, not `Map<String, dynamic>`, so a direct cast would throw for any anime with an `episodeStatuses`, `episodeWeekOffsets`, or `rating` sub-object.

### `Map<String, dynamic> _mergeJsonMaps(Iterable<Map<String, dynamic>> maps)` <a id="mergejsonmaps"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 64)
- **Purpose:** Deep-merge any number of JSON maps in order, so `extraJson` fields from multiple candidate sources (e.g. local and remote copies of a record) combine instead of the later source blowing away the earlier one's nested keys.
- **Inputs:** `maps` — merged left-to-right, later entries taking precedence for scalar values.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:**
  1. Walk each map in `maps`, in order.
  2. For each key, if both the already-merged value and the incoming value are `Map`s, recursively merge them (via `_stringKeyedMap` to normalize each side first) instead of overwriting.
  3. Otherwise, the incoming value simply overwrites the merged value at that key.
- **Usage:**
  ```dart
  extraJson: _mergeJsonMaps([
    for (final source in sources)
      if (source != null) source.extraJson,
    extraJson,
  ]),
  ```
  (`Anime.withPreservedUnknownJson`, same file)
- **Notes:** Recursion has no depth limit; `extraJson` payloads in this app are small hand-authored-shape JSON, so this is not a practical concern, but a pathologically deep/cyclic-shaped map (impossible via normal `jsonDecode` output, which can't be cyclic) is not specifically guarded against.

### `AnimeType? _parseAnimeType(Object? value)` <a id="parseanimetype"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 88)
- **Purpose:** Parse a raw JSON value into an `AnimeType` enum, tolerating anything that isn't a recognized string.
- **Inputs:** `value` — typically `json['manualType']`.
- **Returns:** `AnimeType?` — `null` if `value` isn't a `String` or doesn't match any enum name.
- **Side effects:** None.
- **Algorithm:** Returns `null` immediately if `value is! String`; otherwise linearly scans `AnimeType.values` for a `.name` match.
- **Usage:**
  ```dart
  final manualType = _parseAnimeType(json['manualType']);
  if (json.containsKey('manualType') && manualType == null) {
    extraJson['manualType'] = json['manualType'];
  }
  ```
  (`Anime.fromJson`, same file)
- **Notes:** An unparseable-but-present `manualType` (e.g. a future enum value this app version doesn't know) is preserved verbatim in `extraJson` by the caller rather than silently dropped — see the usage above.

### `EpisodeStatus? _parseEpisodeStatus(Object? value)` <a id="parseepisodestatus"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 101)
- **Purpose:** Parse a raw JSON value into an `EpisodeStatus` enum.
- **Inputs:** `value` — one entry's value from the `episodeStatuses` JSON map.
- **Returns:** `EpisodeStatus?` — `null` if `value` isn't a recognized status string.
- **Side effects:** None.
- **Algorithm:** Same shape as `_parseAnimeType`: type-guard then linear scan of `EpisodeStatus.values` by `.name`.
- **Usage:**
  ```dart
  final status = _parseEpisodeStatus(entry.value);
  if (ep != null && status != null) {
    statuses[ep] = status;
  } else {
    unknownStatuses[entry.key] = entry.value;
  }
  ```
  (`Anime.fromJson`, same file)
- **Notes:** Entries that fail to parse (bad episode-number key or unrecognized status string) are collected into `unknownStatuses` and end up in `extraJson['episodeStatuses']` instead of being lost.

### `const AnimeRating({overall, visual, story, character, music, enjoyment, extraJson = const {}})` <a id="animerating-new"></a>
- **Kind:** constructor of `AnimeRating`
- **Source:** `lib/features/anime/models/anime.dart` (line 154)
- **Purpose:** Hold a personal rating: an optional manual overall score plus five optional 0–10 sub-scores (visual, story, character, music, enjoyment).
- **Inputs:** All six score fields optional; `extraJson` defaults to `{}`.
- **Returns:** A new `AnimeRating`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment via `const` constructor.
- **Usage:**
  ```dart
  final rating = AnimeRating(
    overall: _parseScore(_ratingOverallController),
    visual: _parseScore(_ratingVisualController),
    story: _parseScore(_ratingStoryController),
    character: _parseScore(_ratingCharacterController),
    music: _parseScore(_ratingMusicController),
    enjoyment: _parseScore(_ratingEnjoymentController),
  );
  return rating.hasAnyData ? rating : null;
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, `_buildRating`)
- **Notes:** See [`../../../../data-formats.md`](../../../../data-formats.md) for the scoring scale and `effectiveOverall` fallback rule.

### `double? get effectiveOverall` <a id="effectiveoverall"></a>
- **Kind:** getter of `AnimeRating`
- **Source:** `lib/features/anime/models/anime.dart` (line 196)
- **Purpose:** Return the manual overall score when set, otherwise the average of whichever sub-scores are filled in.
- **Inputs:** None.
- **Returns:** `double?` — `null` only when `overall` is unset and every sub-score is also unset.
- **Side effects:** None.
- **Algorithm:**
  1. If `overall != null`, return it directly.
  2. Otherwise collect the non-null values of `visual`/`story`/`character`/`music`/`enjoyment` into a list.
  3. If that list is empty, return `null`.
  4. Otherwise return `sum / count` (a straight average of whichever sub-scores exist).
- **Usage:**
  ```dart
  if (anime.rating?.effectiveOverall != null) ...[
    const SizedBox(height: 12),
  ```
  (`lib/features/anime/views/anime_detail_page.dart`)
- **Notes:** Manual `overall` always wins outright; there is no blending between a manual overall and the sub-score average.

### `double? scoreFor(AnimeRatingField field)` <a id="scorefor"></a>
- **Kind:** method of `AnimeRating`
- **Source:** `lib/features/anime/models/anime.dart` (line 215)
- **Purpose:** Look up this rating's value for a given sortable/displayable field, routing `AnimeRatingField.overall` through `effectiveOverall` rather than the raw `overall` field.
- **Inputs:** `field`.
- **Returns:** `double?`.
- **Side effects:** None.
- **Algorithm:** A `switch` over `AnimeRatingField`: `overall` maps to `effectiveOverall`; every other case returns the matching field directly (`visual`, `story`, `character`, `music`, `enjoyment`).
- **Usage:**
  ```dart
  return anime.rating?.scoreFor(query.field) != null;
  ```
  (`lib/shared/services/local_api_server.dart`, ranking-query filter)
- **Notes:** This is why ranking/sorting by "overall" in the local API and UI reflects the same effective-overall fallback as display, rather than excluding anime that only have sub-scores.

### `AnimeRating withExtraJson(Map<String, dynamic> extraJson)` <a id="withextrajson-animerating"></a>
- **Kind:** method of `AnimeRating`
- **Source:** `lib/features/anime/models/anime.dart` (line 237)
- **Purpose:** Return a copy of this rating with only `extraJson` replaced.
- **Inputs:** `extraJson`.
- **Returns:** A new `AnimeRating` with every score field unchanged.
- **Side effects:** None.
- **Algorithm:** Rebuilds an `AnimeRating` reusing all six score fields and substituting the given `extraJson`.
- **Usage:**
  ```dart
  final preservedRating = rating != null
      ? rating!.withExtraJson(mergedRatingExtraJson)
      : (mergedRatingExtraJson.isNotEmpty
            ? AnimeRating(extraJson: mergedRatingExtraJson)
            : null);
  ```
  (`Anime.withPreservedUnknownJson`, same file)
- **Notes:** None.

### `Map<String, dynamic> toJson()` (`AnimeRating`) <a id="tojson-animerating"></a>
- **Kind:** method of `AnimeRating`
- **Source:** `lib/features/anime/models/anime.dart` (line 252)
- **Purpose:** Serialize the rating to the JSON shape stored under `Anime.rating`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `extraJson` overlaid with each known score key.
- **Side effects:** None.
- **Algorithm:** Starts from a copy of `extraJson`, then calls [`_writeScore`](#writescore) for each of the six score fields, which sets the key when the score is non-null and otherwise leaves any existing `extraJson` value alone (see `_writeScore`'s own notes).
- **Usage:**
  ```dart
  if (rating != null && rating!.hasAnyData) {
    json['rating'] = rating!.toJson();
  } else if (!extraJson.containsKey('rating')) {
    json.remove('rating');
  }
  ```
  (`Anime.toJson`, same file)
- **Notes:** None.

### `factory AnimeRating.fromJson(Map<String, dynamic> json)` <a id="animerating-fromjson"></a>
- **Kind:** factory constructor of `AnimeRating`
- **Source:** `lib/features/anime/models/anime.dart` (line 268)
- **Purpose:** Reconstruct a rating from its persisted JSON form, preserving any key that isn't a recognized score name and any score value that isn't numeric.
- **Inputs:** `json`.
- **Returns:** A new `AnimeRating`.
- **Side effects:** None.
- **Algorithm:**
  1. Compute `extraJson` as every key in `json` outside `_ratingJsonKeys` via [`_unknownJson`](#unknownjson).
  2. For each of the six score keys, call an inline `readScore` closure: parse via [`_parseScore`](#parsescore); if the key is present in `json` but failed to parse as a `num` (`score == null` while `json.containsKey(key)`), stash the raw value into `extraJson[key]` instead of discarding it.
  3. Construct `AnimeRating` from the six parsed scores plus the accumulated `extraJson`.
- **Usage:**
  ```dart
  rating = AnimeRating.fromJson(_stringKeyedMap(rawRatingValue));
  if (!rating.hasAnyData) rating = null;
  ```
  (`Anime.fromJson`, same file — a rating with no scores and no extra data collapses back to `null`)
- **Notes:** A `rating` JSON value that isn't a `Map` at all is handled by the caller (`Anime.fromJson`), not here — it's preserved into the parent's `extraJson['rating']` instead of calling this factory.

### `double? _parseScore(Object? value)` <a id="parsescore"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 296)
- **Purpose:** Parse a raw JSON value into a `double` score.
- **Inputs:** `value`.
- **Returns:** `double?` — `value.toDouble()` if `value is num`, else `null`.
- **Side effects:** None.
- **Algorithm:** Single type check and conversion.
- **Usage:**
  ```dart
  double? readScore(String key) {
    final score = _parseScore(json[key]);
    ...
  ```
  (`AnimeRating.fromJson`, same file)
- **Notes:** None.

### `void _writeScore(Map<String, dynamic> json, String key, double? score)` <a id="writescore"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/models/anime.dart` (line 306)
- **Purpose:** Set or clear one score key while building a rating's JSON map.
- **Inputs:** `json` (mutated in place), `key`, `score`.
- **Returns:** None.
- **Side effects:** Mutates `json` — sets `json[key] = score` when `score != null`.
- **Algorithm:** If `score` is non-null, write it. Otherwise, only if `json` does **not** already contain `key`, it would remove it — but the `remove` call is guarded by `!json.containsKey(key)`, so in practice a pre-existing `extraJson[key]` value (e.g. a non-numeric score preserved by `fromJson`) is left completely untouched rather than cleared.
- **Usage:**
  ```dart
  _writeScore(json, 'overall', overall);
  ```
  (`AnimeRating.toJson`, same file)
- **Notes:** The `else if (!json.containsKey(key)) json.remove(key);` branch is a no-op by construction (you only reach `remove` when the key is already absent) — the practical effect is simply "don't touch an existing unrecognized value when the typed field is null."

### `const Anime({required id, title, titleJa, season = 'Season 1', startEpisode = 1, endEpisode = 13, manualType, airDayOfWeek, airTime, firstAirDate, episodeStatuses = const {}, coverImage, infoUrl, watchUrl, episodeWeekOffsets = const {}, notes, rating, required createdAt, required modifiedAt, extraJson = const {}})` <a id="anime-new"></a>
- **Kind:** constructor of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 384)
- **Purpose:** Construct an `Anime` record from every persisted field directly.
- **Inputs:** `id`, `createdAt`, `modifiedAt` required; `season` defaults to `'Season 1'`, `startEpisode` to `1`, `endEpisode` to `13` (a fresh single-cour assumption), `episodeStatuses`/`episodeWeekOffsets`/`extraJson` default to empty; everything else optional.
- **Returns:** A new `Anime`.
- **Side effects:** None.
- **Algorithm:** Plain field assignment via `const` constructor; no derived state or validation (e.g. it does not enforce that at least one of `title`/`titleJa` is set — that's a documented invariant, not a checked one).
- **Usage:**
  ```dart
  return Anime(
    id: const Uuid().v4(),
    title: parsed.title,
    titleJa: parsed.titleJa,
    season: parsed.season,
    startEpisode: parsed.startEpisode,
    endEpisode: parsed.endEpisode,
    ...
  );
  ```
  (`lib/shared/services/file_open_service.dart`, `_importOne` — reassigns a fresh UUID when importing a shared `.myanimeitem` record)
- **Notes:** `endEpisode` defaulting to `13` (rather than `null`) means constructing `Anime` with only `id`/`createdAt`/`modifiedAt` produces a single-cour-shaped record, not an open-ended one; `Anime.create` relies on this same default.

### `String get displayTitle` <a id="displaytitle"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 412)
- **Purpose:** Return the best available title for display.
- **Inputs:** None.
- **Returns:** `String` — `title` if non-empty, else `titleJa` if non-empty, else `''`.
- **Side effects:** None.
- **Algorithm:** Two nested ternary checks on `.isNotEmpty == true` (tolerating `null` receivers).
- **Usage:**
  ```dart
  final aTitle = _normalizeTitle(a.displayTitle);
  ```
  (`lib/shared/services/duplicate_service.dart`, title-similarity comparison — see
  [`../../../../features/duplicate-detection.md`](../../../../features/duplicate-detection.md))
- **Notes:** Never throws or returns `null` even when both `title` and `titleJa` are `null` — callers can rely on a plain (possibly empty) `String`.

### `int? get totalEpisodes` <a id="totalepisodes"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 421)
- **Purpose:** Return the total episode count when the run length is known.
- **Inputs:** None.
- **Returns:** `int?` — `endEpisode! - startEpisode + 1` when `endEpisode` is set, else `null`.
- **Side effects:** None.
- **Algorithm:** Single conditional expression.
- **Usage:**
  ```dart
  final total = anime.totalEpisodes;
  ```
  (`lib/shared/services/import_export_service.dart`, Markdown export watching-status line)
- **Notes:** `null` specifically means long-running/unknown-end, distinct from a legitimate small episode count.

### `AnimeType get autoType` <a id="autotype"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 429)
- **Purpose:** Infer the broadcast type from the current episode count alone, ignoring any manual override.
- **Inputs:** None.
- **Returns:** `AnimeType`.
- **Side effects:** None.
- **Algorithm:** If `totalEpisodes` is `null`, returns `longRunning`; else an if-chain over the thresholds documented in [`../../../../data-formats.md`](../../../../data-formats.md): `<=13` → `singleCour`, `<=26` → `halfYear`, `<=52` → `fullYear`, otherwise `longRunning`.
- **Usage:**
  ```dart
  AnimeType get effectiveType {
    if (manualType != null) return manualType!;
    return autoType;
  }
  ```
  (`Anime.effectiveType`, same file)
- **Notes:** `allAtOnce` is never produced by `autoType` — it can only be reached via `manualType`.

### `AnimeType get effectiveType` <a id="effectivetype"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 443)
- **Purpose:** Return the `AnimeType` that should actually drive app behavior (calendar rendering, quarter placement, episode-date rollover), applying the manual override when present.
- **Inputs:** None.
- **Returns:** `AnimeType`.
- **Side effects:** None.
- **Algorithm:** Returns `manualType!` if `manualType != null`, else `autoType`.
- **Usage:**
  ```dart
  if (anime.effectiveType == AnimeType.allAtOnce) {
    return anime.getEpisodeCalendarDate(episode);
  }
  ```
  (`lib/features/anime/views/home_page.dart`, `_effectiveEpisodeDate`)
- **Notes:** This precedence — manual always wins — is consistent everywhere `effectiveType` is read, including [`airsInQuarter`](#airsinquarter), [`getEpisodeAirDate`](#getepisodeairdate), and [`getEpisodeCalendarDate`](#getepisodecalendardate).

### `bool airsInQuarter(int year, int quarter)` <a id="airsinquarter"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 453)
- **Purpose:** Decide whether this anime should appear in a given `(year, quarter)` listing (the "cour" grouping used by the management and statistics pages).
- **Inputs:** `year`, `quarter` (1–4).
- **Returns:** `bool`.
- **Side effects:** None.
- **Algorithm:** Full three-branch logic (manual-type cour span, estimated-weeks span, long-running date-overlap fallback) is walked through in detail in
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md#quarter-placement).
  In short:
  1. Returns `false` immediately if `firstAirDate` or `startQuarter` is unavailable.
  2. If `manualType` is set (and isn't `longRunning`), uses a fixed span from `startQuarter` (`allAtOnce`/`singleCour` → 1 quarter, `halfYear` → 2, `fullYear` → 4) and checks whether `(year, quarter)` falls in that span.
  3. Otherwise, if `endEpisode` is known, estimates actual run weeks as `(episodeCount - 1) + weekOffsetFor(lastEpisode)` and maps that to a quarter span with ~2-week tolerance per boundary (`<=15`→1, `<=28`→2, `<=41`→3, `<=54`→4, else `ceil(weeks/13)`).
  4. Otherwise (long-running, no manual type), falls back to a simple date-overlap check between `[firstAirDate, firstAirDate + 51 weeks]` and the requested quarter's date range.
- **Usage:**
  ```dart
  return _allAnime.where((a) {
    return a.airsInQuarter(quarter.year, quarter.q);
  }).toList()..sort((a, b) { ... });
  ```
  (`lib/features/anime/views/management_page.dart`, `_animeForQuarter`)
- **Notes:** The `AnimeType.longRunning` case inside the manual-type switch (`spanQuarters = 0`) is unreachable in practice, because the surrounding `if` already excludes `manualType == AnimeType.longRunning`.

### `(int, int)? get startQuarter` <a id="startquarter"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 518)
- **Purpose:** Return the starting broadcast quarter derived from `firstAirDate`'s month.
- **Inputs:** None.
- **Returns:** `(int, int)?` — `(year, quarter)`, `null` when `firstAirDate` is unset.
- **Side effects:** None.
- **Algorithm:** Maps `firstAirDate!.month` to a quarter: 1–3 → Q1, 4–6 → Q2, 7–9 → Q3, else (10–12) → Q4.
- **Usage:**
  ```dart
  final sq = anime.startQuarter;
  if (sq == null) {
    // No date — jump to "Other" page
  ```
  (`lib/features/anime/views/management_page.dart`)
- **Notes:** None.

### `int weekOffsetFor(int episodeNumber)` <a id="weekoffsetfor"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 533)
- **Purpose:** Sum every configured week adjustment that affects a given episode.
- **Inputs:** `episodeNumber`.
- **Returns:** `int` — total weeks to shift (positive = delay, negative = earlier).
- **Side effects:** None.
- **Algorithm:** Iterates `episodeWeekOffsets.entries`, accumulating `entry.value` for every entry whose key is `<= episodeNumber` (cumulative, not a single override).
- **Usage:**
  ```dart
  final totalWeeks = episodeOffset + weekOffsetFor(episodeNumber);
  final baseDate = firstAirDate!.add(Duration(days: totalWeeks * 7));
  ```
  (`Anime.getEpisodeAirDate`, same file)
- **Notes:** Feeds directly into both episode-date getters and into [`airsInQuarter`](#airsinquarter)'s
  estimated-weeks branch — see
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md).

### `DateTime? getEpisodeAirDate(int episodeNumber)` <a id="getepisodeairdate"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 546)
- **Purpose:** Compute the JST air timestamp for an episode, including late-night broadcast-slot rollover (e.g. `"25:00"` = 01:00 the next day).
- **Inputs:** `episodeNumber`.
- **Returns:** `DateTime?` — `null` when scheduling data is incomplete (`firstAirDate` or `airDayOfWeek` missing, or `episodeNumber < startEpisode`).
- **Side effects:** None.
- **Algorithm:**
  1. Returns `null` if `firstAirDate` is unset.
  2. If `effectiveType == AnimeType.allAtOnce`, returns `firstAirDate` unchanged (every episode "airs" the same instant).
  3. Returns `null` if `airDayOfWeek` is unset, or if `episodeNumber < startEpisode`.
  4. Computes `totalWeeks = (episodeNumber - startEpisode) + weekOffsetFor(episodeNumber)` and a base date `firstAirDate + totalWeeks weeks`.
  5. Snaps the base date forward to the next occurrence of `airDayOfWeek` (`diff = airDayOfWeek - baseDate.weekday`, `+7` if negative), so the result never precedes `firstAirDate` even when `airDayOfWeek` disagrees with its actual weekday.
  6. Applies `airTime`: if set, parses `HH:MM` (tolerating hours `>= 24`, e.g. `"25:00"`, by adding the parsed `Duration` to midnight of the snapped date) — a malformed hour/minute falls back to `23`/`59`. If `airTime` is `null`, sets the time to `23:59`.
- **Usage:**
  ```dart
  final airDate = anime.getEpisodeAirDate(ep);
  if (airDate != null && !airDate.isAfter(JstTime.now())) {
    episodes.add(_AiringEpisode(anime: anime, episode: ep));
  }
  ```
  (`lib/features/anime/views/home_page.dart`, `_getUnwatchedEpisodes`)
- **Notes:** See [`../../../../data-formats.md`](../../../../data-formats.md) for why `"25:00"`-style
  times are a real convention this method has to support, and
  [`getEpisodeCalendarDate`](#getepisodecalendardate) for the rollover-free sibling used where a plain
  calendar day (not a JST instant) is needed.

### `DateTime? getEpisodeCalendarDate(int episodeNumber)` <a id="getepisodecalendardate"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 592)
- **Purpose:** Compute the JST calendar broadcast date for an episode, deliberately without applying `airTime`'s late-night rollover.
- **Inputs:** `episodeNumber`.
- **Returns:** `DateTime?` — same null conditions as [`getEpisodeAirDate`](#getepisodeairdate).
- **Side effects:** None.
- **Algorithm:** Mirrors `getEpisodeAirDate` through the same week-offset/day-of-week-snap logic, but stops at the snapped calendar date (`DateTime(year, month, day)`) — it never reads `airTime`, so a `"24:00"`/`"25:00"` broadcast slot stays attributed to its scheduled date rather than rolling to the next calendar day.
- **Usage:**
  ```dart
  final airDate = anime.getEpisodeCalendarDate(ep);
  final airStr = airDate != null
      ? DateFormat.MMMd().format(airDate)
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, episode list rendering)
- **Notes:** Use this over `getEpisodeAirDate` anywhere the app needs "which calendar day is this
  episode's broadcast day" (e.g. matching against a reminder's local date) rather than "what
  instant does it air at" — see
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md).

### `int? get nextUnwatchedEpisode` <a id="nextunwatchedepisode"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 623)
- **Purpose:** Return the first episode number that is still unwatched.
- **Inputs:** None.
- **Returns:** `int?` — `null` when every tracked episode (up to `endEpisode`, or `startEpisode + 999` for open-ended series) is already `watched` or `skippedThisWeek`.
- **Side effects:** None.
- **Algorithm:** Linear scan from `startEpisode` to `endEpisode ?? startEpisode + 999`; returns the first episode whose status is missing or `unwatched`.
- **Usage:**
  ```dart
  final nxt = a.nextUnwatchedEpisode;
  ```
  (`lib/shared/services/local_api_server.dart`, `_animeToJson`)
- **Notes:** For a long-running series with no `endEpisode`, the scan is capped at 999 episodes past `startEpisode` rather than being truly unbounded.

### `bool get isCompleted` <a id="iscompleted"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 639)
- **Purpose:** Whether every episode has been watched.
- **Inputs:** None.
- **Returns:** `bool` — always `false` when `endEpisode` is `null` (open-ended series can never be "complete").
- **Side effects:** None.
- **Algorithm:** Returns `false` immediately if `endEpisode == null`; otherwise loops `startEpisode..endEpisode` and returns `false` on the first episode whose status isn't `watched`; `true` if the loop completes.
- **Usage:**
  ```dart
  final allWatched = _anime!.isCompleted;
  ```
  (`lib/features/anime/views/anime_detail_page.dart`, toggling "mark all watched/unwatched")
- **Notes:** None.

### `AnimeViewingStatus get viewingStatus` <a id="viewingstatus"></a>
- **Kind:** getter of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 652)
- **Purpose:** Derive the viewing status shown throughout the UI, computed from `episodeStatuses` rather than stored separately.
- **Inputs:** None.
- **Returns:** `AnimeViewingStatus` — one of `completed`, `watching`, `dropped`, `notStarted`.
- **Side effects:** None.
- **Algorithm:**
  1. `isCompleted` → `completed`.
  2. If `endEpisode == null` (long-running): `watching` if any tracked episode is `watched`, else `notStarted`.
  3. Otherwise, scan `startEpisode..endEpisode`, tracking whether any episode is `unwatched`, `watched`, or `skippedThisWeek` (defaulting missing entries to `unwatched`).
  4. `dropped` if there's at least one `skippedThisWeek` and no remaining `unwatched` episode; else `watching` if any episode is `watched`; else `notStarted`.
- **Usage:**
  ```dart
  switch (a.viewingStatus) {
    case AnimeViewingStatus.completed:
  ```
  (`lib/shared/services/local_api_server.dart`, status tallying)
- **Notes:** "Dropped" specifically requires *zero* remaining unwatched episodes alongside at least one skip — an anime with both unwatched and skipped episodes is still `watching`, not `dropped`. See
  [`../../../../data-formats.md`](../../../../data-formats.md) and
  [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md).

### `Anime copyWith({...})` <a id="copywith"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 685)
- **Purpose:** Create a copy with selected fields replaced, using `clearXxx` boolean flags to explicitly null out an otherwise-nullable field (since passing `null` for a parameter is indistinguishable from "not supplied").
- **Inputs:** One optional parameter per mutable field, plus `clearEndEpisode`/`clearManualType`/`clearAirDayOfWeek`/`clearAirTime`/`clearFirstAirDate`/`clearCoverImage`/`clearInfoUrl`/`clearWatchUrl`/`clearNotes`/`clearRating` (all default `false`); `modifiedAt` optional (defaults to `DateTime.now().toUtc()` if not supplied).
- **Returns:** A new `Anime`; `id`, `createdAt`, and `extraJson` are always carried over unchanged.
- **Side effects:** None (though calling it without an explicit `modifiedAt` reads the current time).
- **Algorithm:** For each nullable field with a `clearXxx` flag: if the flag is `true`, the field becomes `null`; else the supplied value is used if non-null, else the existing value is kept (`value ?? this.value`). Non-nullable fields (`season`, `startEpisode`) and `episodeStatuses`/`episodeWeekOffsets` just use `?? this.field` directly with no clear flag.
- **Usage:**
  ```dart
  final updated = _existing!.copyWith(
    title: _titleController.text.trim(),
    ...
    rating: rating,
    clearRating: rating == null,
    modifiedAt: DateTime.now().toUtc(),
  );
  await AnimeStorage.addOrUpdate(updated);
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, saving an edited anime)
- **Notes:** `modifiedAt` always advances to "now" unless the caller passes an explicit value — every edit path in the UI passes `DateTime.now().toUtc()` explicitly so sync conflict detection (which compares `modifiedAt`) sees the edit.

### `Anime withExtraJson(Map<String, dynamic> extraJson)` (`Anime`) <a id="withextrajson-anime"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 747)
- **Purpose:** Return a copy of this anime with only `extraJson` replaced.
- **Inputs:** `extraJson`.
- **Returns:** A new `Anime` with every other field unchanged.
- **Side effects:** None.
- **Algorithm:** Rebuilds an `Anime` reusing every field except `extraJson`.
- **Usage:** Not called directly from outside this file at present — `withPreservedUnknownJson` (below) is the entry point every caller actually uses; it builds the merged `extraJson` and constructs the final `Anime` inline rather than calling this helper. Direct use would look like:
  ```dart
  final copy = anime.withExtraJson({'newField': 'value'});
  ```
- **Notes:** Kept parallel to `AnimeRating.withExtraJson`/`AnimeData.withExtraJson` for consistency across the three JSON-preserving types, even though its only current caller path is conceptual (`withPreservedUnknownJson` re-implements the same field list directly rather than delegating to this method).

### `Anime withPreservedUnknownJson(Iterable<Anime?> fallbackSources)` <a id="withpreservedunknownjson-anime"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 775)
- **Purpose:** Merge this record's `extraJson` (and its rating's `extraJson`) with the `extraJson` of one or more fallback candidates — typically the local and remote copies of the same record during a sync merge — so a field unknown to *this* app version but present on either side survives.
- **Inputs:** `fallbackSources` — an iterable of `Anime?` (nulls are skipped).
- **Returns:** A new `Anime` with `extraJson` and `rating.extraJson` each replaced by their merged form; every other field is copied from `this` unchanged.
- **Side effects:** None (pure).
- **Algorithm:**
  1. Merge `rating.extraJson` across every source that has a non-null `rating`, plus this record's own `rating?.extraJson`, via [`_mergeJsonMaps`](#mergejsonmaps).
  2. If `this.rating` is non-null, produce `rating!.withExtraJson(mergedRatingExtraJson)`; else, if the merged map is non-empty, synthesize a scores-empty `AnimeRating(extraJson: ...)` so a rating known only via `extraJson` on another device doesn't vanish; else `null`.
  3. Merge top-level `extraJson` the same way across all sources plus `this.extraJson`.
  4. Return a full copy of `this` with the merged `rating` and `extraJson`.
- **Usage:**
  ```dart
  all.add(chosen.withPreservedUnknownJson([c.localRecord, c.remoteRecord]));
  ```
  (`lib/shared/services/sync_merge.dart`, `AnimeMergeResult.buildResolved` — see
  [`../services/sync_merge.md`](../../../shared/services/sync_merge.md) if documented, or
  [`../../../../algorithms/three-way-merge.md`](../../../../algorithms/three-way-merge.md))
- **Notes:** This is the specific mechanism referenced throughout
  [`../../../../data-formats.md`](../../../../data-formats.md)'s `extraJson` section and
  [`../../../../algorithms/three-way-merge.md`](../../../../algorithms/three-way-merge.md) for why an
  older app version editing a record doesn't erase a field introduced by a newer version.

### `Map<String, dynamic> toJson()` (`Anime`) <a id="tojson-anime"></a>
- **Kind:** method of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 821)
- **Purpose:** Serialize this record to the JSON shape persisted in `anime_data.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>`.
- **Side effects:** None.
- **Algorithm:**
  1. Start from a copy of `extraJson`.
  2. Build `episodeStatuses`'/`episodeWeekOffsets`' JSON by starting from any unknown entries preserved in `extraJson['episodeStatuses']`/`extraJson['episodeWeekOffsets']` (via [`_stringKeyedMap`](#stringkeyedmap)), then overlaying every known entry (`k.toString(): v.name` / `k.toString(): v`).
  3. Write every scalar field (`id`, `title`, `titleJa`, `season`, `startEpisode`, `endEpisode`, `manualType`, `airDayOfWeek`, `airTime`, `firstAirDate`, `coverImage`, `infoUrl`, `watchUrl`, `notes`, `createdAt`, `modifiedAt`) — nullable fields are written when non-null and otherwise `json.remove(key)`'d, except `manualType`/`rating` which are left alone (not removed) when the field is null but the key already survives via `extraJson`.
  4. `episodeStatuses` is always written (even if empty); `episodeWeekOffsets` is only written when non-empty.
  5. `rating` is written via `rating!.toJson()` only when `rating != null && rating!.hasAnyData`.
- **Usage:**
  ```dart
  final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
  ```
  (`AnimeStorage.save`, [`../services/anime_storage.md`](../services/anime_storage.md#save) — via
  `AnimeData.toJson`, which maps this over every anime)
- **Notes:** See [`../../../../data-formats.md`](../../../../data-formats.md) for why the app always
  uses `JsonEncoder.withIndent('  ')` around this output (byte-identical re-saves avoid a spurious
  sync re-upload).

### `factory Anime.fromJson(Map<String, dynamic> json)` <a id="anime-fromjson"></a>
- **Kind:** factory constructor of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 922)
- **Purpose:** Reconstruct an `Anime` from its persisted JSON form, preserving every field this app version doesn't recognize or can't parse.
- **Inputs:** `json`.
- **Returns:** A new `Anime`.
- **Side effects:** None.
- **Algorithm:**
  1. `extraJson` starts as every key outside `_animeJsonKeys` (via [`_unknownJson`](#unknownjson)).
  2. `manualType` parses via [`_parseAnimeType`](#parseanimetype); an unparseable-but-present value is preserved into `extraJson['manualType']`.
  3. `episodeStatuses` parses each `episodeStatuses` entry via [`_parseEpisodeStatus`](#parseepisodestatus); entries that don't parse (bad key or value) collect into `extraJson['episodeStatuses']` instead of the typed map; if the raw value isn't a `Map` at all, the whole raw value is preserved instead.
  4. `episodeWeekOffsets` follows the identical pattern, requiring `int` values.
  5. `rating` parses via [`AnimeRating.fromJson`](#animerating-fromjson) when the raw value is a `Map` and collapses to `null` if the parsed rating has no data; a non-`Map` raw value is preserved into `extraJson['rating']`.
  6. Required scalar fields (`id`, `createdAt`, `modifiedAt`) are read with `as` casts (throwing if absent/wrong-typed); everything else uses `as Type?` with sensible defaults (`season` → `'Season 1'`, `startEpisode` → `1`).
- **Usage:**
  ```dart
  final data = AnimeData.fromJson(jsonDecode(json) as Map<String, dynamic>);
  ```
  (`lib/shared/services/webdav_service.dart`, extracting referenced cover-image names — internally calls `Anime.fromJson` once per array element via `AnimeData.fromJson`)
- **Notes:** `createdAt`/`modifiedAt`/`firstAirDate` parsing uses `DateTime.parse` (throws on malformed input) rather than `DateTime.tryParse` — a corrupt timestamp in `anime_data.json` fails the whole load rather than silently dropping just that field.

### `factory Anime.create({title, titleJa, season, startEpisode = 1, endEpisode = 13, manualType, airDayOfWeek, airTime, firstAirDate, coverImage, infoUrl, watchUrl, notes, rating})` <a id="anime-create"></a>
- **Kind:** factory constructor of `Anime`
- **Source:** `lib/features/anime/models/anime.dart` (line 1012)
- **Purpose:** Create a brand-new anime record for manual entry or import, generating a fresh UUID and UTC creation/modification timestamps.
- **Inputs:** Same optional fields as the default constructor, minus `id`/`createdAt`/`modifiedAt`/`episodeStatuses`/`episodeWeekOffsets`/`extraJson` (none of which make sense to seed on creation).
- **Returns:** A new `Anime` with `id = const Uuid().v4()` and `createdAt == modifiedAt == DateTime.now().toUtc()`.
- **Side effects:** None beyond reading the current time and generating a UUID (no I/O).
- **Algorithm:** Computes `now` once (so `createdAt` and `modifiedAt` are identical), then delegates to the default `Anime(...)` constructor.
- **Usage:**
  ```dart
  final anime = Anime.create(
    title: title,
    titleJa: _titleJaController.text.trim().isEmpty ? null : _titleJaController.text.trim(),
    ...
  );
  await AnimeStorage.addOrUpdate(anime);
  ```
  (`lib/features/anime/views/anime_edit_page.dart`, creating a new anime from the edit form)
- **Notes:** This is the only place in the model layer that generates a UUID for a brand-new record; imports of existing records (`file_open_service.dart`) call the default `Anime(...)` constructor directly with their own fresh `const Uuid().v4()` instead of going through `create`.

### `AnimeData withExtraJson(Map<String, dynamic> extraJson)` (`AnimeData`) <a id="withextrajson-animedata"></a>
- **Kind:** method of `AnimeData`
- **Source:** `lib/features/anime/models/anime.dart` (line 1070)
- **Purpose:** Return a copy of this container with only `extraJson` replaced.
- **Inputs:** `extraJson`.
- **Returns:** A new `AnimeData` with the same `animes` list.
- **Side effects:** None.
- **Algorithm:** Single-expression rebuild.
- **Usage:**
  ```dart
  AnimeData withPreservedUnknownJson(Iterable<AnimeData?> fallbackSources) =>
      withExtraJson(
        _mergeJsonMaps([...]),
      );
  ```
  (`AnimeData.withPreservedUnknownJson`, same file — its only call site in this file)
- **Notes:** None.

### `AnimeData withPreservedUnknownJson(Iterable<AnimeData?> fallbackSources)` <a id="withpreservedunknownjson-animedata"></a>
- **Kind:** method of `AnimeData`
- **Source:** `lib/features/anime/models/anime.dart` (line 1078)
- **Purpose:** Merge this container's top-level `extraJson` with that of one or more fallback candidates (e.g. the remote `AnimeData` during a sync merge).
- **Inputs:** `fallbackSources`.
- **Returns:** A new `AnimeData` via [`withExtraJson`](#withextrajson-animedata).
- **Side effects:** None.
- **Algorithm:** Delegates to [`_mergeJsonMaps`](#mergejsonmaps) over every non-null source's `extraJson` followed by `this.extraJson` (so `this` wins on scalar conflicts), then wraps the result with `withExtraJson`.
- **Usage:**
  ```dart
  final extraJson = localData.withPreservedUnknownJson([remoteData]).extraJson;
  ```
  (`lib/shared/services/sync_merge.dart`, `mergeAnimeData` — merging the two top-level containers' unknown fields before building the final `AnimeMergeResult`)
- **Notes:** This is the top-level-container counterpart to `Anime.withPreservedUnknownJson`; per-record `extraJson` is handled separately per anime, not through this method.

### `Map<String, dynamic> toJson()` (`AnimeData`) <a id="tojson-animedata"></a>
- **Kind:** method of `AnimeData`
- **Source:** `lib/features/anime/models/anime.dart` (line 1092)
- **Purpose:** Serialize the whole container to the JSON shape written to `anime_data.json`.
- **Inputs:** None.
- **Returns:** `Map<String, dynamic>` — `{...extraJson, 'animes': [...]}`.
- **Side effects:** None.
- **Algorithm:** Spreads `extraJson` first, then overwrites/adds `'animes'` with `animes.map((a) => a.toJson()).toList()`.
- **Usage:**
  ```dart
  static Future<void> save(AnimeData data) async {
    final file = await _getFile(_dataFileName);
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data.toJson());
  ```
  (`AnimeStorage.save`, [`../services/anime_storage.md`](../services/anime_storage.md#save))
- **Notes:** Because `extraJson` is spread *before* `'animes'` is set, a legacy/foreign top-level `animes` key inside `extraJson` (which shouldn't normally exist, since `'animes'` is a known key excluded by `_unknownJson`) would be overwritten by the real list rather than the other way around.

### `factory AnimeData.fromJson(Map<String, dynamic> json)` <a id="animedata-fromjson"></a>
- **Kind:** factory constructor of `AnimeData`
- **Source:** `lib/features/anime/models/anime.dart` (line 1102)
- **Purpose:** Parse the top-level `{animes: [...]}` container from JSON.
- **Inputs:** `json` — a decoded `anime_data.json` (or backup/import bundle) map.
- **Returns:** A new `AnimeData`.
- **Side effects:** None.
- **Algorithm:** Maps `json['animes']` (a `List<dynamic>?`) through [`Anime.fromJson`](#anime-fromjson) per element, defaulting to `[]` if `animes` is missing; `extraJson` is computed via [`_unknownJson`](#unknownjson) against `_animeDataJsonKeys` (`{'animes'}`).
- **Usage:**
  ```dart
  static Future<AnimeData> load() async {
    final file = await _getFile(_dataFileName);
    if (!await file.exists()) return const AnimeData();
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const AnimeData();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AnimeData.fromJson(json);
  }
  ```
  (`AnimeStorage.load`, [`../services/anime_storage.md`](../services/anime_storage.md#load))
- **Notes:** A missing `animes` key parses to an empty list rather than throwing, but a malformed individual anime entry propagates whatever exception `Anime.fromJson` throws (e.g. a missing `id`) — there is no per-record error isolation at this layer.
