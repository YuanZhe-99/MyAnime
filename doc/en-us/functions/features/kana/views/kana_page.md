# lib/features/kana/views/kana_page.dart

`KanaPage` is the fourth bottom-navigation tab: a UI-only hiragana/katakana quick reference. It
reads no anime data, has no persisted state, and is not part of sync — see
[`../../../../features/kana-reference.md`](../../../../features/kana-reference.md) for the feature
overview and [`../../../../architecture.md`](../../../../architecture.md) for how it sits in the
`go_router` shell. The file defines one private `_KanaScript` enum (hiragana/katakana) and three
small data classes (`_KanaEntry`, `_KanaRow`, `_KanaRule`) backing three top-level `const` tables —
`_basicRows`, `_voicedRows`, `_yoonRows` — that hold the actual gojuon/dakuten/yoon kana data. The
rest of the file is `_KanaPageState`, which renders the script switch, the search field, the three
static tables (when the search query is empty), the search-results grid (when it isn't), and a set
of pronunciation-rule cards.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `KanaPage.new` | constructor (`KanaPage`) | B | Create a `KanaPage` instance. |
| `KanaPage.createState` | method (`KanaPage`) | B | Create the mutable state object for this widget. |
| `_KanaPageState.dispose` | method (`_KanaPageState`) | B | Dispose the search text controller. |
| `_KanaPageState.build` | method (`_KanaPageState`, widget build) | B | Build the page scaffold: script switch, search field, and either the static tables or search results, plus the rule cards. |
| [`_KanaPageState._matchingEntries`](#_matchingentries) | method (`_KanaPageState`) | A | Find every unique kana entry across all tables that matches a search query. |
| `_KanaPageState._buildKanaTable` | method (widget helper) | B | Render one titled kana table (header row + data rows) for a column set. |
| `_KanaPageState._buildHeaderRow` | method (widget helper) | B | Render a table's column-label header row. |
| `_KanaPageState._buildKanaRow` | method (widget helper) | B | Render one consonant-row of kana cells plus its row label. |
| `_KanaPageState._buildKanaCell` | method (widget helper) | B | Render one kana/romaji cell, or a blank placeholder for a missing combination. |
| `_KanaPageState._buildSearchResults` | method (widget helper) | B | Render the search-results grid, or an empty-state message when there are no matches. |
| `_KanaPageState._buildResultTile` | method (widget helper) | B | Render one kana entry as a search-result tile. |
| `_KanaPageState._buildRules` | method (widget helper) | B | Lay out the pronunciation-rule cards in a responsive 1- or 2-column wrap. |
| `_KanaPageState._buildRuleCard` | method (widget helper) | B | Render one pronunciation-rule card (icon, title, body). |
| `_KanaPageState._sectionTitle` | method (widget helper) | B | Render a section heading (icon + label) shared by the tables and rules sections. |
| `_KanaEntry.new` | constructor (`_KanaEntry`) | B | Create a kana entry (hiragana, katakana, and romaji forms). |
| [`_KanaEntry.kana`](#kana) | method (`_KanaEntry`) | A | Select the hiragana or katakana rendering of this entry for the active script. |
| [`_KanaEntry.matches`](#matches) | method (`_KanaEntry`) | A | Test whether a lowercased search query matches this entry's hiragana, katakana, or romaji. |
| `_KanaRow.new` | constructor (`_KanaRow`) | B | Create a labeled row of up to five kana entries (some slots may be `null`). |
| `_KanaRule.new` | constructor (`_KanaRule`) | B | Create a pronunciation-rule card's display data (icon, title, body, colors). |

## Documentation

### `List<_KanaEntry> _matchingEntries(String query)` <a id="_matchingentries"></a>
- **Kind:** method of `_KanaPageState`
- **Source:** `lib/features/kana/views/kana_page.dart` (line 140)
- **Purpose:** Collect every kana entry across the basic, voiced, and yoon tables whose hiragana,
  katakana, or romaji matches the current search query, without duplicates.
- **Inputs:** `query` — already trimmed and lowercased by the caller (`build`).
- **Returns:** `List<_KanaEntry>` — matching entries in table order (basic rows, then voiced rows,
  then yoon rows), first occurrence kept on duplicates.
- **Side effects:** None.
- **Algorithm:**
  1. Track seen entries in a `Set<String>` keyed by `'${entry.hiragana}:${entry.romaji}'`.
  2. Iterate `[..._basicRows, ..._voicedRows, ..._yoonRows]`, then each row's `entries` (some slots
     are `null` for kana that don't exist, e.g. `wi`/`wu`/`we`).
  3. Skip `null` slots and any entry whose `matches(query)` (see [`_KanaEntry.matches`](#matches))
     is false.
  4. Add the entry to the result list only if its dedup key was not already in `seen` — this
     matters because `_basicRows`/`_voicedRows`/`_yoonRows` are only ever searched as three
     independent lists, so the same underlying kana never repeats in practice today, but the guard
     makes the function safe if a future table reused an entry.
- **Usage:**
  ```dart
  final matches = query.isEmpty ? <_KanaEntry>[] : _matchingEntries(query);
  ```
  (from `_KanaPageState.build`, same file, line 50)
- **Notes:** The query is expected pre-lowercased; this function does not lowercase it itself
  (case-folding happens once in `build`, and again per-field in `matches` for the romaji comparison).

### `String kana(_KanaScript script)` <a id="kana"></a>
- **Kind:** method of `_KanaEntry`
- **Source:** `lib/features/kana/views/kana_page.dart` (line 553)
- **Purpose:** Return this entry's hiragana or katakana spelling depending on which script is
  currently selected.
- **Inputs:** `script` — the active `_KanaScript` (hiragana or katakana).
- **Returns:** `String` — `hiragana` or `katakana`, whichever the switch selects.
- **Side effects:** None.
- **Algorithm:** A `switch` expression on `script` returning the matching stored field.
- **Usage:**
  ```dart
  Text(
    entry.kana(_script),
    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
  ),
  ```
  (from `_KanaPageState._buildKanaCell`, same file, line 274)
- **Notes:** None.

### `bool matches(String query)` <a id="matches"></a>
- **Kind:** method of `_KanaEntry`
- **Source:** `lib/features/kana/views/kana_page.dart` (line 565)
- **Purpose:** Decide whether this entry should show up in search results for a given query.
- **Inputs:** `query` — the search text, expected already lowercased by the caller.
- **Returns:** `bool` — true if `query` is found in `hiragana`, `katakana`, or a lowercased
  `romaji`.
- **Side effects:** None.
- **Algorithm:** `hiragana.contains(query) || katakana.contains(query) ||
  romaji.toLowerCase().contains(query)` — a plain substring test on each of the three fields;
  `hiragana`/`katakana` are compared as-is (they have no case), while `romaji` is lowercased before
  the comparison so the query need not match the stored romaji's case.
- **Usage:**
  ```dart
  if (entry == null || !entry.matches(query)) continue;
  ```
  (from `_KanaPageState._matchingEntries`, same file, line 145)
- **Notes:** Substring match only — no romaji normalization beyond lowercasing (e.g. searching `"si"`
  does not match the entry stored as `"shi"`).
