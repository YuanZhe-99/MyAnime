# lib/features/anime/views/category_widgets.dart

分类界面（1.6.0，M4）：给出本地化名称的 `categoryLabel`、详情页上的 `CategoryChips`，以及分类编辑器——
`showCategoryEditor`、它的私有 `_CategoryEditor`，和它返回的 sealed `CategoryEditResult`（`CategoriesChosen` 或
`CategoriesReset`）。结果如何保存见 [`anime_detail_page.md`](anime_detail_page.md#_editcategories)，功能说明见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`categoryLabel`](#categorylabel) | 顶层函数 | A | 返回分类 id 的本地化名称。 |
| `CategoryChips.new` | 构造函数（`CategoryChips`） | B | 创建分类标签（`categories`、`onEdit`）。 |
| [`CategoryChips.build`](#categorychips-build) | 方法（`CategoryChips`） | A | 构建这些标签。 |
| `CategoryEditResult.new` | 构造函数（`CategoryEditResult`） | B | 创建一个编辑结果。 |
| `CategoriesChosen.new` | 构造函数（`CategoriesChosen`） | B | 为所选 id（可以为空）创建结果，按分类表顺序。 |
| `CategoriesReset.new` | 构造函数（`CategoriesReset`） | B | 创建「恢复自动」结果。 |
| [`showCategoryEditor`](#showcategoryeditor) | 顶层函数 | A | 让用户选择一条记录的分类。 |
| `_CategoryEditor.createState` | 方法（`_CategoryEditor`） | B | 创建状态对象。 |
| [`_CategoryEditorState.build`](#_categoryeditorstate-build) | 方法（`_CategoryEditorState`） | A | 构建标签网格与操作按钮。 |

## 文档

### `String categoryLabel(String id, AppLocalizations l10n)` <a id="categorylabel"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/category_widgets.dart`（约第 14 行）
- **用途：** 返回分类 id 的本地化名称。
- **输入：** `id`、`l10n`。
- **返回：** `String` — 对应的 `category*` 字符串；本构建不认识的 id 则返回 id 本身。
- **副作用：** 无。
- **用法：** `CategoryChips`、编辑器、管理页的分类筛选菜单。
- **备注：** `animeCategories` 中的每个 id 在全部四种界面语言中都有名称；`test/categories_test.dart` 会检查这一点。

### `Widget build(BuildContext context)`（`CategoryChips`） <a id="categorychips-build"></a>
- **种类：** `CategoryChips` 的方法
- **来源：** `lib/features/anime/views/category_widgets.dart`（约第 67 行）
- **用途：** 构建这些标签。
- **输入：** `context`。
- **返回：** 一个 `Wrap`。
- **副作用：** 无。
- **算法：** 每个生效 id 一个 `Chip`；来源为 `ai` 时，每个标签带 `auto_awesome` 闪光图标和 `aiGeneratedLabel` 提示
  （「在本设备上生成——可能有误」）；来源为 `user` 时，带 `person_outline` 图标和 `categoriesYours` 提示（「由你选择」）；映射得到的标签两者都没有，也没有提示。没有 id → 一个 `categoriesNone` 标签。最后总有一个调用 `onEdit` 的*编辑分类*
  `ActionChip`。
- **用法：** [`anime_detail_page.md`](anime_detail_page.md) 中的 `_buildHeaderChildren`，仅在自动分类开启时。
- **备注：** 用户的分类和映射得出的分类外观相同。

### `Future<CategoryEditResult?> showCategoryEditor(BuildContext context, {required List<String> initial, required bool hasOverride})` <a id="showcategoryeditor"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/category_widgets.dart`（约第 135 行）
- **用途：** 让用户选择一条记录的分类。
- **输入：** `initial` — 起始 id；`hasOverride` — 记录是否已经有用户自己的列表。
- **返回：** `Future<CategoryEditResult?>` — 被关闭或取消时为 `null`。
- **副作用：** 屏幕满足 [`canSplitLayout`](../../../shared/utils/adaptive_layout.md#cansplitlayout) 时显示对话框（最大宽度
  560），否则在安全区内显示可控滚动的模态底部面板。
- **用法：** [`anime_detail_page.md`](anime_detail_page.md#_editcategories) 中的 `_editCategories`。
- **备注：** 不提供本构建不认识的 id；调用方会把它们保留在记录上。见
  [`../../../../adaptive-layout.md`](../../../../adaptive-layout.md)。

### `Widget build(BuildContext context)`（`_CategoryEditorState`） <a id="_categoryeditorstate-build"></a>
- **种类：** `_CategoryEditorState` 的方法
- **来源：** `lib/features/anime/views/category_widgets.dart`（约第 185 行）
- **用途：** 构建标签网格与操作按钮。
- **输入：** `context`。
- **返回：** 组件树。
- **副作用：** 无；按钮带着结果弹出路由。
- **算法：** 一个 `categoriesTitle` 标题，分类表中每个 id 一个切换选中与否的 `FilterChip`，然后一行按钮：*恢复自动*
  （仅当 `hasOverride`）弹出 `CategoriesReset`，*取消* 弹出 `null`，*保存* 弹出按分类表顺序带所选 id 的
  `CategoriesChosen`。
- **用法：** 由 `showCategoryEditor` 构建。
- **备注：** 什么都不选就保存会返回 `CategoriesChosen([])`，详情页把它存为 `[]`——表示「无分类」，而不是自动。
