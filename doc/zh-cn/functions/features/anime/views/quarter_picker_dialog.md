# lib/features/anime/views/quarter_picker_dialog.dart

一个小的可复用年/季选择器对话框：按年（行）× `Q1`–`Q4`（列）的可滚动网格，带可选尾部"其他"行，逐格计数由调用方提供。它对 `Anime` 模型本身没有依赖——调用方（`ManagementPage` [`management_page.md`](management_page.md)，以及可能其他面向季度的视图）传入一个决定每格计数含义的 `countBuilder`。这个选择器导航的年/季（"cour"）概念见 [`../../../../features/anime-tracking.md`](../../../../features/anime-tracking.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `QuarterSelection.new` | 构造函数（`QuarterSelection`） | B | 把年和季度编号配对作为选择器的结果类型。 |
| `isOther` | getter（`QuarterSelection`） | B | 该选择是否表示"其他"（无日期）选项。 |
| `q` | getter（`QuarterSelection`） | B | `quarter` 的别名。 |
| [`showQuarterPickerDialog`](#showquarterpickerdialog) | 顶层函数 | A | 显示年/季选择器对话框并返回所选选择。 |
| `_quarterGridCell` | 函数（组件辅助） | B | 渲染一个带计数和选择状态的年/季网格格。 |

## 文档

### `Future<QuarterSelection?> showQuarterPickerDialog({required BuildContext context, required String title, required int minYear, required int maxYear, QuarterSelection? current, QuarterCountBuilder? countBuilder, bool includeOther = false, String? otherLabel, int otherCount = 0, bool isOtherSelected = false})` <a id="showquarterpickerdialog"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/views/quarter_picker_dialog.dart`（约第 36 行）
- **用途：** 显示一个含可滚动 `minYear..maxYear` × `Q1..Q4` 网格（外加可选"其他"行）的模态 `AlertDialog`，预滚动到 `current` 附近，并以用户点击的格（或 `null`，若被关闭）解析。
- **输入：** `context`；`title`；`minYear`/`maxYear` — 要渲染的闭区间年份范围；`current` — 要高亮并滚动到附近的选择；`countBuilder` — 用于渲染逐格计数并点亮有数据的格的 `int Function(int year, int quarter)`；`includeOther` — 为 `true` 时显示尾部"其他"行；`otherLabel`/`otherCount`/`isOtherSelected` — 该行的文本、计数和高亮状态。
- **返回：** `Future<QuarterSelection?>` — 被点击格的 `(year, quarter)`，点击"其他"行为 `QuarterSelection(0, 0)`（`isOther == true`），经取消或遮罩关闭对话框为 `null`。
- **副作用：** 显示模态对话框（`showDialog`）；创建并释放 `ScrollController`。
- **算法：**
  1. 计算初始滚动偏移，使 `current` 的行在顶部往下几行：`((currentRow - 3) * rowHeight).clamp(0.0, double.infinity)`，其中 `currentRow = current.year - minYear`（`current` 为 `null` 时 `0`）。
  2. 构建一个带 `Q1..Q4` 页头行、按年每行一个 `ListView.builder`（每年行由四次 `_quarterGridCell` 组件辅助调用构建，每季一次）的 `AlertDialog`，`includeOther` 为 true 时再加一个弹出 `const QuarterSelection(0, 0)` 的可点"其他"行。
  3. Await 对话框结果，释放 `ScrollController`，返回结果。
- **用法：**
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
  （`ManagementPage._showQuarterPicker`，[`management_page.md`](management_page.md#_showquarterpicker)）
- **备注：** "其他"哨兵是字面值 `QuarterSelection(0, 0)`——因为真实年份总是远大于 `0`，它永远不可能与实际的 `(year, quarter)` 选择碰撞。
