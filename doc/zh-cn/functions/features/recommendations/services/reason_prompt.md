# lib/features/recommendations/services/reason_prompt.dart

推荐理由的带版本提示词（1.6.0，M5），风格与 [`prompt_templates.md`](../../ai/services/prompt_templates.md) 相同：
指令用英文，要求以界面语言写作并使用 Apple 规定的语言区域措辞，以及 `reasonPromptVersion`。与分类的版本不同，它不属于
任何指纹，因为理由从不缓存——它们只在一次访问该页面期间保存在内存中。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`reasonInstructions`](#reasoninstructions) | 顶层函数 | A | 构建撰写推荐理由的系统指令。 |
| `ReasonCandidate.new` | 构造函数（`ReasonCandidate`） | B | 创建一个带编号的候选：标题、分类、制作公司和简短事实。 |
| [`reasonPrompt`](#reasonprompt) | 顶层函数 | A | 构建撰写推荐理由的提示词。 |
| [`relatedReasonInstructions`](#relatedreasoninstructions) | 顶层函数 | A | 构建说明相关记录的系统指令（1.6.2）。 |
| [`relatedReasonPrompt`](#relatedreasonprompt) | 顶层函数 | A | 构建说明相关记录的提示词（1.6.2）。 |

`reasonPromptVersion`（1）、`relatedReasonPromptVersion`（1，自 1.6.2 起）和 `ReasonCandidate` 的字段（`number`、`title`、`categories`、`studios`、`facts`）没有
`/// Purpose:` 注释，不作为行。

## 文档

### `String reasonInstructions(String localeTag, String languageName)` <a id="reasoninstructions"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/reason_prompt.dart`（约第 17 行）
- **用途：** 构建撰写推荐理由的系统指令。
- **输入：** `localeTag` — 例如 `zh_CN`、`zh_TW`、`ja_JP`、`en_US`；`languageName` — 要使用的语言的英文名，例如 `Japanese`。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 以 Apple 的措辞 "The person's locale is <tag>." 开头，然后要求模型从用户自己的列表中的带编号候选里至多挑三个，
  为每个用 `languageName` 写一句不超过 20 个词的理由，只使用给出的事实，每个选择一行 `<number>: <reason>`，不写其他内容。
- **用法：** `writeAiReasons`，作为 `OnDeviceAiService.generate` 的 `instructions`。
- **备注：** 模型只按编号挑选，从不被要求说出作品名。

### `String reasonPrompt({required List<ReasonCandidate> candidates, required List<String> topCategories, required List<String> topStudios, required List<(String, double?)> recent})` <a id="reasonprompt"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/reason_prompt.dart`（约第 62 行）
- **用途：** 构建撰写推荐理由的提示词。
- **输入：** `candidates` — 至多八个；`topCategories`、`topStudios`；`recent` — 最近看完的标题及用户评分（如有）。
- **返回：** 去掉尾部空白的 `String`。
- **副作用：** 无。
- **算法：** 先写 `Taste:`，存在时依次写 `- Likes:`、`- Studios they liked:`，以及每条一行的
  `- Finished: <title> (rated x.x/10)`；然后写 `Candidates:`，每个候选一行
  `<n>. <title> — <categories>; studio <studios>; <facts>`，省略空的部分。
- **用法：** `writeAiReasons`，作为 `OnDeviceAiService.generate` 的 `prompt`。
- **备注：** 只有精简画像——从不包含备注或逐集的观看记录。

### `String relatedReasonInstructions(String localeTag, String languageName)` <a id="relatedreasoninstructions"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/reason_prompt.dart`（约第 103 行）
- **用途：** 构建说明相关记录的系统指令（1.6.2）。
- **输入：** `localeTag`、`languageName` — 与 `reasonInstructions` 相同。
- **返回：** `String`。
- **副作用：** 无。
- **算法：** 先写 Apple 的语言区域措辞，然后要求模型：说明用户自己列表中的哪些作品与正在查看的作品相似；从带编号的候选中
  至多挑三个；为每个用 `languageName` 写一句不超过 20 个词、关于二者共同点的理由；只使用给出的事实；每个选择一行
  `<number>: <reason>`。
- **用法：** `writeRelatedAiReasons`。
- **备注：** 与 `reasonInstructions` 的约定相同：模型按编号挑选，从不说出作品名。修改措辞就要提升
  `relatedReasonPromptVersion`。这些理由会持久保存但不计入指纹，因此新版本只影响之后生成的列表。

### `String relatedReasonPrompt({required ReasonCandidate subject, required List<ReasonCandidate> candidates})` <a id="relatedreasonprompt"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/reason_prompt.dart`（约第 119 行）
- **用途：** 构建说明相关记录的提示词（1.6.2）。
- **输入：** `subject` — 其 `number` 被忽略；`candidates` — 至多五个。
- **返回：** 去掉首尾空白的 `String`。
- **副作用：** 无。
- **算法：** 先写 `Looking at: <title> — <categories>; studio <studios>`，然后写 `Candidates:`，每个候选一行
  `<n>. <title> — <categories>; studio <studios>; <facts>`，省略空的部分。
- **用法：** `writeRelatedAiReasons`。
- **备注：** 只有标题、分类、制作公司和确定性的事实。
