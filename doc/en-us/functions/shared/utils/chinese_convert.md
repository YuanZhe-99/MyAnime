# lib/shared/utils/chinese_convert.dart

A static-only `ChineseConvert` utility providing character-by-character Simplified ↔ Traditional
Chinese conversion, backed by two rune→rune maps built lazily from the generated pair strings in
[`chinese_convert_data.md`](chinese_convert_data.md). Used by
`lib/features/anime/services/anime_search_service.dart` to generate alternate-script query variants
and — since 1.5.7 — to fold titles onto a Simplified key for matching (see
[`../../../features/watch-url-lookup.md`](../../../features/watch-url-lookup.md#matching-on-a-folded-simplified-key)),
and by `anime1_service.dart`'s scrape fallback.

Through 1.5.6 the tables were two hand-typed parallel strings of about 1,200 characters, looked up
with a linear `indexOf` per character, and missing 干/乾/幹, 髮, 裏, 臺, 徵, 迴 and hundreds more.
They are now generated from OpenCC's character dictionaries merged with that legacy table, and
looked up in O(1).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `ChineseConvert._` | constructor (`ChineseConvert`) | B | Prevent direct instantiation and expose only static members. |
| [`ChineseConvert.toTraditional`](#chineseconvert-totraditional) | method (`ChineseConvert`) | A | Convert simplified Chinese characters to their traditional variants. |
| [`ChineseConvert.toSimplified`](#chineseconvert-tosimplified) | method (`ChineseConvert`) | A | Convert traditional Chinese characters to their simplified variants. |
| [`_table`](#chineseconvert-table) | method (`ChineseConvert`) | A | Build a rune→rune map from an interleaved pair string. |
| [`_convert`](#chineseconvert-convert) | method (`ChineseConvert`) | A | Map every rune of a string through a table, passing others through. |

The two `static Map<int, int>?` cache fields carry no `/// Purpose:` comments and are not indexed as
separate rows; they hold the tables once built.

## Documentation

### `static String toTraditional(String text)` <a id="chineseconvert-totraditional"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (approx. line 29)
- **Purpose:** Convert every Simplified Chinese character in `text` to a Traditional variant,
  leaving all other characters unchanged.
- **Inputs:** `text` — arbitrary string, typically a search query or title fragment.
- **Returns:** `String` with matched characters replaced.
- **Side effects:** Builds the lookup table on first use.
- **Algorithm:** [`_convert`](#chineseconvert-convert) with the Simplified→Traditional table,
  built on first use by [`_table`](#chineseconvert-table) from `kSimplifiedToTraditionalPairs`.
- **Usage:**
  ```dart
  final querySimp = ChineseConvert.toSimplified(query);
  final queryTrad = ChineseConvert.toTraditional(query);
  ```
  (from `lib/features/anime/services/anime_search_service.dart`, generating both script variants of
  a search query before querying Chinese-language sources)
- **Notes:** This direction is one-to-many, so the result is a *plausible* Traditional form, not a
  guaranteed regional one: one-to-many characters take the legacy table's choice where it had one
  (里→裡, 着→著) and OpenCC's first candidate otherwise (干→幹). Never normalize on this side when
  comparing titles — use `toSimplified`.

### `static String toSimplified(String text)` <a id="chineseconvert-tosimplified"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** `lib/shared/utils/chinese_convert.dart` (approx. line 39)
- **Purpose:** Convert every Traditional Chinese character in `text` to its Simplified variant,
  leaving all other characters unchanged.
- **Inputs:** `text`.
- **Returns:** `String` with matched characters replaced.
- **Side effects:** Builds the lookup table on first use.
- **Algorithm:** [`_convert`](#chineseconvert-convert) with the Traditional→Simplified table.
- **Usage:**
  ```dart
  return ChineseConvert.toSimplified(stripped);
  ```
  (from `AnimeSearchService.foldTitle`, the last step of the matching key)
- **Notes:** Many-to-one (乾 and 幹 both become 干; 髮 and 發 both become 发), which is why this is
  the direction titles are normalized on. Kanji shared with Japanese fold too (滅 → 灭).

### `static Map<int, int> _table(String pairs)` <a id="chineseconvert-table"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** approx. line 49
- **Purpose:** Build a rune→rune map from an interleaved pair string.
- **Inputs:** `pairs` — one of the two generated constants.
- **Returns:** `Map<int, int>`.
- **Side effects:** None.
- **Algorithm:** `pairs.runes.toList()`, then every even index becomes a key and the following rune
  its value; an assertion checks the rune count is even.
- **Notes:** Internal helper used within this file only. Iterates `runes`, not code units — OpenCC
  includes CJK Extension B characters, which are surrogate pairs in UTF-16.

### `static String _convert(String text, Map<int, int> table)` <a id="chineseconvert-convert"></a>
- **Kind:** static method of `ChineseConvert`
- **Source:** approx. line 61
- **Purpose:** Map every rune of `text` through `table`, passing unmapped runes through.
- **Returns:** `String`.
- **Side effects:** None.
- **Algorithm:** Iterate `text.runes`, `writeCharCode(table[rune] ?? rune)` into a `StringBuffer`.
- **Notes:** Internal helper used within this file only. Punctuation, kana, Latin and characters
  absent from the table pass through unchanged.
