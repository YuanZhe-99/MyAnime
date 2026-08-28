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

Since 1.5.4 the page is adaptive: on a window the app-wide split rule allows, and wide enough to
hold two tables, it lays its sections out in two columns and puts the script switch beside the
search field. Two file-level constants carry the minimums — `_kanaTableMinWidth` (330) and
`_kanaRuleMinWidth` (320) — and both are fed to the shared `columnCapacity`. This is also where
the hardcoded `constraints.maxWidth >= 720` that `adaptive-layout.md` used to record as a known
exception went; there is no longer a second layout rule in `lib/`. See
[`../../../../adaptive-layout.md`](../../../../adaptive-layout.md).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `KanaPage.new` | constructor (`KanaPage`) | B | Create a `KanaPage` instance. |
| `KanaPage.createState` | method (`KanaPage`) | B | Create the mutable state object for this widget. |
| `_KanaPageState.dispose` | method (`_KanaPageState`) | B | Dispose the search text controller. |
| [`_KanaPageState.build`](#kanabuild) | method (`_KanaPageState`, widget build) | A | Build the page scaffold in one or two columns: script switch, search field, and either the static tables or search results, plus the rule cards. |
| [`_KanaPageState._matchingEntries`](#_matchingentries) | method (`_KanaPageState`) | A | Find every unique kana entry across all tables that matches a search query. |
| `_KanaPageState._buildKanaTable` | method (widget helper) | B | Render one titled kana table (header row + data rows) for a column set. |
| `_KanaPageState._buildHeaderRow` | method (widget helper) | B | Render a table's column-label header row. |
| `_KanaPageState._buildKanaRow` | method (widget helper) | B | Render one consonant-row of kana cells plus its row label. |
| `_KanaPageState._buildKanaCell` | method (widget helper) | B | Render one kana/romaji cell, or a blank placeholder for a missing combination. |
| `_KanaPageState._buildSearchResults` | method (widget helper) | B | Render the search-results grid, or an empty-state message when there are no matches. |
| `_KanaPageState._buildResultTile` | method (widget helper) | B | Render one kana entry as a search-result tile. |
| [`_KanaPageState._buildRules`](#kanabuildrules) | method (widget helper) | A | Lay out the pronunciation-rule cards in a responsive 1- or 2-column wrap. |
| `_KanaPageState._buildRuleCard` | method (widget helper) | B | Render one pronunciation-rule card (icon, title, body). |
| `_KanaPageState._sectionTitle` | method (widget helper) | B | Render a section heading (icon + label) shared by the tables and rules sections. |
| `_KanaEntry.new` | constructor (`_KanaEntry`) | B | Create a kana entry (hiragana, katakana, and romaji forms). |
| [`_KanaEntry.kana`](#kana) | method (`_KanaEntry`) | A | Select the hiragana or katakana rendering of this entry for the active script. |
| [`_KanaEntry.matches`](#matches) | method (`_KanaEntry`) | A | Test whether a lowercased search query matches this entry's hiragana, katakana, or romaji. |
| `_KanaRow.new` | constructor (`_KanaRow`) | B | Create a labeled row of up to five kana entries (some slots may be `null`). |
| `_KanaRule.new` | constructor (`_KanaRule`) | B | Create a pronunciation-rule card's display data (icon, title, body, colors). |

## Documentation

### `Widget build(BuildContext context)` <a id="kanabuild"></a>
- **Kind:** method of `_KanaPageState` (widget build)
- **Source:** `lib/features/kana/views/kana_page.dart` (approx. line 63)
- **Purpose:** Build the page in one or two columns, according to the window.
- **Inputs:** `context`.
- **Returns:** The page's widget tree.
- **Side effects:** None beyond building widgets.
- **Algorithm:**
  1. Content width is `shellContentWidth(screen.width) - 32`, capped at the page's own 1080 maximum.
  2. `twoColumn` is `canSplitLayout(screen.width, screen.height)` **and**
     `columnCapacity(contentWidth, minItemWidth: _kanaTableMinWidth, maxColumns: 2) >= 2`.
  3. Build the script picker, the search field, the three tables and the rules section as locals.
  4. Header: side by side in a `Row` when `twoColumn`, otherwise stacked as before.
  5. Body: the search results plus the rules when a query is active; otherwise a two-column `Row`
     of (basic, yoon) and (voiced, rules) when `twoColumn`; otherwise the original stacked order.
- **Usage:**
  ```dart
  GoRoute(path: '/kana', builder: (context, state) => const KanaPage()),
  ```
  (from `appRouter` in `lib/app/router.dart`)
- **Notes:** **Gated twice, on purpose.** The first gate is the app-wide shape rule; the second asks
  whether two tables of at least 330 logical pixels actually fit. The second is what keeps the
  narrower unfolded foldables — a Z Fold 5 has 546 of content, and two tables need 672 — on one
  column without needing a breakpoint of their own. The Z Fold 8 Ultra and the Pixel 10 Pro Fold do
  fit, at about 58 logical pixels per cell, level with what a phone gives in one column.

  The columns are assigned rather than flowed so they balance: the tall basic and yoon tables on
  the left against the short voiced table plus the rules on the right.

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

### `Widget _buildRules(ThemeData theme, AppLocalizations l10n)` <a id="kanabuildrules"></a>
- **Kind:** method of `_KanaPageState` (widget helper)
- **Source:** `lib/features/kana/views/kana_page.dart` (approx. line 445)
- **Purpose:** Lay out the seven pronunciation-rule cards across one or two columns.
- **Inputs:** `theme`, `l10n`.
- **Returns:** `Widget` — a section title above a `Wrap` of fixed-width cards.
- **Side effects:** None beyond building widgets.
- **Algorithm:** Inside a `LayoutBuilder`, take
  `columnCapacity(constraints.maxWidth, minItemWidth: _kanaRuleMinWidth, maxColumns: 2)`, divide the
  available width by it net of the gaps, and give every card that width in a `Wrap`.
- **Usage:**
  ```dart
  final rules = _buildRules(theme, l10n);
  ```
  (from `_KanaPageState.build`, same file)
- **Notes:** Measured against whatever this section is actually given — a whole page width in one
  column and half of one in two — so the cards reflow on their own rather than needing to know which
  mode the page is in.

  This replaced a hardcoded `constraints.maxWidth >= 720` in 1.5.4, and the change **preserved**
  behaviour rather than altering it. The navigation rail leaves a tablet in portrait 655 logical
  pixels of rule width, which the `720` literal would now fail and the shared arithmetic passes.
  Capped at two columns because these are paragraphs: a third would fall below a comfortable
  reading measure.

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
