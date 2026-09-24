# lib/features/ai/services/prompt_templates.dart

端侧模型的带版本提示词模板（1.6.0，M4）：分类指令与提示词、`classificationPromptVersion`，以及
`ClassificationInput`——分类可以使用的关于一部作品的事实。所有平台上指令都用英文：小模型最可靠地遵循英文指令，
而且答案是 id 列表而不是文字。

修改模板措辞就要提升 `classificationPromptVersion`。该版本是每个缓存结果指纹的一部分
（[`classificationFingerprint`](../../categories/services/category_service.md#classificationfingerprint)），
因此旧结果会重新排队。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`classificationInstructions`](#classificationinstructions) | 顶层函数 | A | 构建为一部作品分类的系统指令。 |
| `ClassificationInput.new` | 构造函数（`ClassificationInput`） | B | 创建分类输入。 |
| [`ClassificationInput.canonical`](#classificationinput-canonical) | 方法（`ClassificationInput`） | A | 为计算指纹序列化输入。 |
| [`classificationPrompt`](#classificationprompt) | 顶层函数 | A | 构建为一部作品分类的提示词。 |

`classificationPromptVersion` 和 `ClassificationInput` 的字段（`titles`、`format`、`year`、`type`、`episodes`、
`studios`、`genres`）没有 `/// Purpose:` 注释，不作为行。

## 文档

### `String classificationInstructions()` <a id="classificationinstructions"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/prompt_templates.dart`（约第 25 行）
- **用途：** 构建为一部作品分类的系统指令。
- **输入：** 无。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 把每个分类列为 `- <id>: <description>`，然后要求至多选三个能清楚描述作品的 id，只使用给出的事实，
  以逗号分隔写成一行，不确定时回答 `NONE`。
- **用法：** `CategoryClassifier._run`，作为 `OnDeviceAiService.choose` 的 `instructions`。
- **备注：** 在 Apple 上答案还受 `choose` 的 schema（这些 id 加 `none`）约束；在 Android 上由逐行解析器强制。无论哪种，
  Dart 都只保留已知 id。

### `String canonical()` <a id="classificationinput-canonical"></a>
- **种类：** `ClassificationInput` 的方法
- **来源：** `lib/features/ai/services/prompt_templates.dart`（约第 80 行）
- **用途：** 为计算指纹序列化输入。
- **输入：** 无。
- **返回：** `String` — 每次运行都稳定。
- **副作用：** 无。
- **算法：** 按固定顺序把 `titles`（用 `|` 连接）、`format`、`year`、`type`、`episodes`、`studios` 和 `genres`
  （列表都用 `|` 连接）各占一行拼接起来；缺失的值为空行。
- **用法：** `classificationFingerprint`。
- **备注：** 字段和列表项的顺序是固定的，因此未改动的记录指纹总是相同。

### `String classificationPrompt(ClassificationInput input)` <a id="classificationprompt"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/prompt_templates.dart`（约第 97 行）
- **用途：** 构建为一部作品分类的提示词。
- **输入：** `input`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 先写 `Anime:`，然后每个已知事实一行 `- Label: value`——Titles（用 ` / ` 连接）、Format、Year、
  Length（`AnimeType` 名称）、Episodes、Studios、Tags——最后以 `Category ids:` 结尾。
- **用法：** `CategoryClassifier._run`，作为 `OnDeviceAiService.choose` 的 `prompt`。
- **备注：** 在设备上测得延迟之前，每个提示词只含一部作品（批大小 1）。输入从不包含备注、评分或观看进度；见
  [`classificationInputOf`](../../categories/services/category_service.md#classificationinputof)。
