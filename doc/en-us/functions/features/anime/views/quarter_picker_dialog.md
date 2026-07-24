# lib/features/anime/views/quarter_picker_dialog.dart

A small reusable year/quarter picker dialog: a scrollable grid of years (rows) by `Q1`–`Q4`
(columns), with an optional trailing "Other" row, and per-cell counts supplied by the caller. It has
no dependency on the `Anime` model itself — callers (`ManagementPage`
[`management_page.md`](management_page.md), and potentially other quarter-oriented views) pass in a
`countBuilder` that decides what each cell's count means. See
[`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md) for the
year/quarter ("cour") concept this picker navigates.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `QuarterSelection.new` | constructor (`QuarterSelection`) | B | Pair a year and quarter number as the picker's result type. |
| `isOther` | getter (`QuarterSelection`) | B | Whether this selection represents the "Other" (no-date) option. |
| `q` | getter (`QuarterSelection`) | B | Alias for `quarter`. |
| [`showQuarterPickerDialog`](#showquarterpickerdialog) | top-level function | A | Show the year/quarter picker dialog and return the chosen selection. |
| `_quarterGridCell` | function (widget helper) | B | Render one year/quarter grid cell with its count and selection state. |

## Documentation

### `Future<QuarterSelection?> showQuarterPickerDialog({required BuildContext context, required String title, required int minYear, required int maxYear, QuarterSelection? current, QuarterCountBuilder? countBuilder, bool includeOther = false, String? otherLabel, int otherCount = 0, bool isOtherSelected = false})` <a id="showquarterpickerdialog"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/quarter_picker_dialog.dart` (approx. line 36)
- **Purpose:** Show a modal `AlertDialog` containing a scrollable `minYear..maxYear` × `Q1..Q4` grid
  (plus an optional "Other" row), pre-scrolled near `current`, and resolve with whichever cell the
  user taps (or `null` if dismissed).
- **Inputs:** `context`; `title`; `minYear`/`maxYear` — inclusive year range to render;
  `current` — the selection to highlight and scroll near; `countBuilder` — `int Function(int year,
  int quarter)` used to render a per-cell count and light up cells with data; `includeOther` — shows
  a trailing "Other" row when `true`; `otherLabel`/`otherCount`/`isOtherSelected` — text, count, and
  highlight state for that row.
- **Returns:** `Future<QuarterSelection?>` — the tapped cell's `(year, quarter)`, `QuarterSelection(0,
  0)` (`isOther == true`) if the "Other" row was tapped, or `null` if the dialog was dismissed via
  Cancel or the scrim.
- **Side effects:** Shows a modal dialog (`showDialog`); creates and disposes a `ScrollController`.
- **Algorithm:**
  1. Compute an initial scroll offset so `current`'s row is a few rows from the top:
     `((currentRow - 3) * rowHeight).clamp(0.0, double.infinity)`, where `currentRow = current.year -
     minYear` (or `0` if `current` is `null`).
  2. Build an `AlertDialog` with a `Q1..Q4` header row, a `ListView.builder` of one row per year
     (each year's row built from four `_quarterGridCell` widget-helper calls, one per quarter), and,
     if `includeOther`, a trailing tappable "Other" row that pops `const QuarterSelection(0, 0)`.
  3. Await the dialog's result, dispose the `ScrollController`, and return the result.
- **Usage:**
  ```dart
  final result = await showQuarterPickerDialog(
    context: context,
    title: l10n.manageJumpToQuarter,
    minYear: minYear,
    maxYear: maxYear,
    current: current != null
        ? QuarterSelection(current.year, current.q)
        : null,
    countBuilder: (year, q) =>
        _allAnime.where((a) => a.airsInQuarter(year, q)).length,
    includeOther: true,
    otherLabel: l10n.manageOther,
    otherCount: _otherAnime.length,
    isOtherSelected: _isOtherPage,
  );
  ```
  (`ManagementPage._showQuarterPicker`, [`management_page.md`](management_page.md#_showquarterpicker))
- **Notes:** The "Other" sentinel is the literal value `QuarterSelection(0, 0)` — since real years are
  always far greater than `0`, this can never collide with an actual `(year, quarter)` selection.
