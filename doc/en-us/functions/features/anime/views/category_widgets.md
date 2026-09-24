# lib/features/anime/views/category_widgets.dart

The category UI (1.6.0, M4): `categoryLabel` for localized names, `CategoryChips` on the detail
page, and the category editor — `showCategoryEditor`, its private `_CategoryEditor`, and the sealed
`CategoryEditResult` it returns (`CategoriesChosen` or `CategoriesReset`). See
[`anime_detail_page.md`](anime_detail_page.md#_editcategories) for how a result is saved and
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
for the feature.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| [`categoryLabel`](#categorylabel) | top-level function | A | Return the localized label of a category id. |
| `CategoryChips.new` | constructor (`CategoryChips`) | B | Create the category chips (`categories`, `onEdit`). |
| [`CategoryChips.build`](#categorychips-build) | method (`CategoryChips`) | A | Build the chips. |
| `CategoryEditResult.new` | constructor (`CategoryEditResult`) | B | Create an edit result. |
| `CategoriesChosen.new` | constructor (`CategoriesChosen`) | B | Create the result for the chosen ids (possibly none), in taxonomy order. |
| `CategoriesReset.new` | constructor (`CategoriesReset`) | B | Create the "Reset to automatic" result. |
| [`showCategoryEditor`](#showcategoryeditor) | top-level function | A | Let the user pick a record's categories. |
| `_CategoryEditor.createState` | method (`_CategoryEditor`) | B | Create the state object. |
| [`_CategoryEditorState.build`](#_categoryeditorstate-build) | method (`_CategoryEditorState`) | A | Build the chip grid and actions. |

## Documentation

### `String categoryLabel(String id, AppLocalizations l10n)` <a id="categorylabel"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/category_widgets.dart` (approx. line 14)
- **Purpose:** Return the localized label of a category id.
- **Inputs:** `id`, `l10n`.
- **Returns:** `String` — the `category*` string, or the id itself for an id this build does not
  know.
- **Side effects:** None.
- **Usage:** `CategoryChips`, the editor, the management page's category filter menu, and the recommendations page's category reason chip (1.6.0, M5).
- **Notes:** Every id in `animeCategories` has a label in all four UI languages;
  `test/categories_test.dart` checks that.

### `Widget build(BuildContext context)` (`CategoryChips`) <a id="categorychips-build"></a>
- **Kind:** method of `CategoryChips`
- **Source:** `lib/features/anime/views/category_widgets.dart` (approx. line 67)
- **Purpose:** Build the chips.
- **Inputs:** `context`.
- **Returns:** A `Wrap`.
- **Side effects:** None.
- **Algorithm:** One `Chip` per effective id; when the origin is `ai`, each chip carries the
  `auto_awesome` sparkle and the `aiGeneratedLabel` tooltip ("Generated on this device — may be
  wrong"); when it is `user`, a `person_outline` icon and the `categoriesYours` tooltip ("Chosen by
  you"); mapped chips carry neither and no tooltip. No ids → a `categoriesNone` chip. Always ends with an *Edit categories* `ActionChip`
  calling `onEdit`.
- **Usage:** `_buildHeaderChildren` in [`anime_detail_page.md`](anime_detail_page.md), only while
  automatic categories are on.
- **Notes:** User and mapped chips look the same.

### `Future<CategoryEditResult?> showCategoryEditor(BuildContext context, {required List<String> initial, required bool hasOverride})` <a id="showcategoryeditor"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/views/category_widgets.dart` (approx. line 135)
- **Purpose:** Let the user pick a record's categories.
- **Inputs:** `initial` — the ids to start from; `hasOverride` — whether the record already has the
  user's own list.
- **Returns:** `Future<CategoryEditResult?>` — `null` when dismissed or cancelled.
- **Side effects:** Shows a dialog (max width 560) when
  [`canSplitLayout`](../../../shared/utils/adaptive_layout.md#cansplitlayout) allows for the screen, otherwise a
  scroll-controlled modal bottom sheet in the safe area.
- **Usage:** `_editCategories` in [`anime_detail_page.md`](anime_detail_page.md#_editcategories).
- **Notes:** Ids this build does not know are not offered; the caller keeps them on the record. See
  [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md).

### `Widget build(BuildContext context)` (`_CategoryEditorState`) <a id="_categoryeditorstate-build"></a>
- **Kind:** method of `_CategoryEditorState`
- **Source:** `lib/features/anime/views/category_widgets.dart` (approx. line 185)
- **Purpose:** Build the chip grid and actions.
- **Inputs:** `context`.
- **Returns:** The widget tree.
- **Side effects:** None; the buttons pop the route with a result.
- **Algorithm:** A `categoriesTitle` heading, one `FilterChip` per taxonomy id toggling membership
  in the chosen set, then a row: *Reset to automatic* (only when `hasOverride`) pops
  `CategoriesReset`, *Cancel* pops `null`, *Save* pops `CategoriesChosen` with the chosen ids in
  taxonomy order.
- **Usage:** Built by `showCategoryEditor`.
- **Notes:** Saving with nothing selected returns `CategoriesChosen([])`, which the detail page
  stores as `[]` — "no categories", not automatic.
