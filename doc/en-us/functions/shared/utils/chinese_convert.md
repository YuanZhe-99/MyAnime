# lib/shared/utils/chinese_convert.dart

A static-only `ChineseConvert` utility providing character-by-character Simplified ↔ Traditional
Chinese conversion, backed by two parallel hardcoded character-array tables (`_simplified` and
`_traditional`, indexed 1:1). Used exclusively by
`lib/features/anime/services/anime_search_service.dart` to generate alternate-script query variants
when searching Chinese-language anime sources (see `AGENTS.md`'s "Multi-Source Search" section).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ChineseConvert._` | constructor (`ChineseConvert`) | B | Prevent direct instantiation and expose only static members. |
| [`ChineseConvert.toTraditional`](#chineseconvert-totraditional) | method (`ChineseConvert`) | A | Convert simplified Chinese characters to their traditional variants. |
| [`ChineseConvert.toSimplified`](#chineseconvert-tosimplified) | method (`ChineseConvert`) | A | Convert traditional Chinese characters to their simplified variants. |

The `_simplified` and `_traditional` static const character-array fields have no `/// Purpose:`
comments and are not indexed as separate rows; they are the data tables both methods look up
against.

## Documentation

### `static String toTraditional(String text)` <a id="chineseconvert-totraditional"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (approx. line 15)
- **Purpose:** Convert every Simplified Chinese character in `text` to its Traditional Chinese
  variant, leaving all other characters unchanged.
- **Inputs:** `text` — arbitrary string, typically a search query or title fragment.
- **Returns:** `String` with matched characters replaced.
- **Side effects:** None.
- **Algorithm:**
  1. Iterate `text.runes` (so multi-byte/surrogate-pair characters are handled correctly rather than
     iterating UTF-16 code units directly).
  2. For each rune, convert it back to a single-character `String` and look up its index in the
     `_simplified` table via `String.indexOf`.
  3. If found (`i >= 0`), write the character at the same index in `_traditional`; otherwise write
     the original character unchanged.
  4. Return the accumulated `StringBuffer` contents.
- **Usage:**
  ```dart
  final querySimp = ChineseConvert.toSimplified(query);
  final queryTrad = ChineseConvert.toTraditional(query);
  ```
  (from `lib/features/anime/services/anime_search_service.dart`, generating both script variants of
  a search query before querying Chinese-language sources)
- **Notes:** Lookup is a linear `String.indexOf` scan per character against a several-hundred-entry
  table, run once per character in the input — fine for search-query-length strings, but not
  intended for converting large documents. Characters not present in the table (e.g. punctuation,
  non-Chinese scripts, already-Traditional characters not in the simplified table) pass through
  unchanged.

### `static String toSimplified(String text)` <a id="chineseconvert-tosimplified"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (approx. line 30)
- **Purpose:** Convert every Traditional Chinese character in `text` to its Simplified Chinese
  variant, leaving all other characters unchanged.
- **Inputs:** `text` — arbitrary string, typically a search query or title fragment.
- **Returns:** `String` with matched characters replaced.
- **Side effects:** None.
- **Algorithm:** Mirror image of `toTraditional`: iterate `text.runes`, look each character up in
  `_traditional` via `indexOf`, and if found, substitute the character at the same index in
  `_simplified`; otherwise keep the original character.
- **Usage:**
  ```dart
  final simplified = ChineseConvert.toSimplified(query);
  ```
  (from `lib/features/anime/services/anime_search_service.dart`, e.g. when building fuzzy-match
  normalization candidates)
- **Notes:** Same linear-scan cost characteristics and pass-through behavior for unmapped
  characters as `toTraditional`.
