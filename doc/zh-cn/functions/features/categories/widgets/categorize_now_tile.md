# lib/features/categories/widgets/categorize_now_tile.dart

`CategorizeNowTile`（1.6.0，M4）是立即为每条待分类记录分类的设置行，带「N / M」计数。设置页只在自动分类开启时
把它显示在「分类与推荐」分区中，而且除非平台可能有端侧模型且端侧 AI 已开启，该行本身什么也不渲染。见
[`../services/category_service.md`](../services/category_service.md) 和
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `CategorizeNowTile.new` | 构造函数（`CategorizeNowTile`） | B | 创建该行；`classifier` 和 `ai` 可为测试注入。 |
| `CategorizeNowTile.createState` | 方法（`CategorizeNowTile`） | B | 创建状态对象。 |
| `_CategorizeNowTileState.initState` | 方法（`_CategorizeNowTileState`） | B | 该行出现时读取待分类计数（`refreshCounts`）。 |
| [`_CategorizeNowTileState.build`](#_categorizenowtilestate-build) | 方法（`_CategorizeNowTileState`） | A | 构建该行。 |

## 文档

### `Widget build(BuildContext context)` <a id="_categorizenowtilestate-build"></a>
- **种类：** `_CategorizeNowTileState` 的方法
- **来源：** `lib/features/categories/widgets/categorize_now_tile.dart`（约第 58 行）
- **用途：** 构建该行。
- **输入：** `context`。
- **返回：** 一个 `ListTile`；`platformMayHaveOnDeviceModel` 为 false 或 AI 关闭时返回 `SizedBox.shrink()`。
- **副作用：** 无；按钮先调用 `classifyAll` 再调用 `refreshCounts`。
- **算法：** 在监听分类器和 AI 服务的 `ListenableBuilder` 内：标题 `aiCategorizeNow`，副标题
  `aiCategorizeProgress(pending, candidates)`，一轮运行期间尾部显示转圈，否则显示一个 tonal 按钮。
- **用法：** `settings_page.dart`，`if (settings.autoCategoriesEnabled) const CategorizeNowTile()`。
- **备注：** 只有模型可以生成且有待分类记录时按钮才可用。
