# lib/features/ai/services/output_validation.dart

端侧模型输出的共享解析与检查，1.6.0（M3）新增。模型说的每句话在显示或缓存之前都经过这里，两个平台都一样：
小模型会无视格式、把回答包进 Markdown，有时还会用错文字。这里不信任任何应答；不符合的内容直接丢弃，而不是
修补。所有函数都是纯函数。`parseChoiceReply` 由 Android 上的
`MethodChannelGenAiBackend.choose` 调用；自 1.6.0（M5）起，`ai_reason_service.dart` 中的 `parseReasonReply` 用
`stripMarkdown`、`matchesScript` 和 `cleanSentence` 处理推荐理由。见 [`../../../../on-device-ai.md`](../../../../on-device-ai.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`stripMarkdown`](#stripmarkdown) | 顶层函数 | A | 从应答中去除代码围栏和 Markdown 修饰。 |
| `ChoiceParse.new` | 构造函数（`ChoiceParse`） | B | 创建一个选择解析结果（`ids`、`none`、`valid`）。 |
| [`parseChoiceReply`](#parsechoicereply) | 顶层函数 | A | 从选项列表中读出模型选中的 id。 |
| `_normalizeId` | 顶层函数（私有） | B | 把词元转小写并修剪，去掉两端的引号和句号，把空格和连字符变成下划线。 |
| [`matchesScript`](#matchesscript) | 顶层函数 | A | 检查生成的文字是否使用界面语言对应的文字系统。 |
| [`cleanSentence`](#cleansentence) | 顶层函数 | A | 清理一句生成的句子以供显示。 |

`ChoiceParse` 的字段与 `ChoiceParse.invalid`，以及私有正则表达式，都没有 `/// Purpose:` 注释，不作为行。

## 文档

### `String stripMarkdown(String text)` <a id="stripmarkdown"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/output_validation.dart`（约第 23 行）
- **用途：** 从应答中去除代码围栏和 Markdown 修饰。
- **输入：** `text`。
- **返回：** `String` —— 修剪后的纯文本。
- **副作用：** 无。
- **算法：** 去除代码围栏（连同语言标记），再去除粗体和斜体标记、行内代码反引号、标题符号，以及行首的
  项目符号和列表编号；修剪。
- **用法：** `parseChoiceReply`、`cleanSentence` 和 `parseReasonReply`。
- **备注：** 保留换行，因为选择解析器按每行一个 id 读取。

### `ChoiceParse parseChoiceReply(String reply, List<String> options, {int maxItems = 3})` <a id="parsechoicereply"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/output_validation.dart`（约第 58 行）
- **用途：** 从选项列表中读出模型选中的 id。
- **输入：** `reply` —— 原始文本；`options` —— 允许的 id；`maxItems`。
- **返回：** `ChoiceParse` —— 按应答顺序、去重并截断的已知 id；明确回答 `NONE` 时 `none: true`；应答无视格式
  时为 `ChoiceParse.invalid`。
- **副作用：** 无。
- **算法：**
  1. 建立从每个选项的归一化形式到该选项的映射。
  2. 去除 Markdown；结果为空则无效。
  3. 对每一行，去掉开头的 `<label>:`（ASCII 或全角冒号，至多 40 个字符），再按逗号、分号、斜杠、竖线和
     中日文列举符号拆分。
  4. 归一化每个词元；记下 `none`；保留尚未见过的已知 id。
  5. 没有 id：见过 `NONE` 则为有效的空回答，否则无效。否则截断到 `maxItems`。
- **用法：** Android 上的 `MethodChannelGenAiBackend.choose`。
- **备注：** 匹配不区分大小写，并把空格和连字符视同下划线，因此 `slice of life` 读作 `slice_of_life`。未知 id
  被静默丢弃。

### `bool matchesScript(String text, String languageCode)` <a id="matchesscript"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/output_validation.dart`（约第 115 行）
- **用途：** 检查生成的文字是否使用界面语言对应的文字系统。
- **输入：** `text`；`languageCode` —— `en`、`ja` 或 `zh`（两种中文变体皆可）。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** 统计汉字、假名和拉丁字母。没有字母时为 false。`zh`：汉字加假名至少占字母的 60%，且有汉字。
  `ja`：同样的 60%，且至少一个假名。其他语言：拉丁字母至少占 60%。
- **用法：** `lib/features/recommendations/services/ai_reason_service.dart` 中的 `parseReasonReply`（1.6.0，M5）。
- **备注：** 用比例而不是绝对规则，因为理由里可能引用另一种文字的标题。它分辨不出简体和繁体中文。

### `String? cleanSentence(String text, {int maxLength = 140})` <a id="cleansentence"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/ai/services/output_validation.dart`（约第 138 行）
- **用途：** 清理一句生成的句子以供显示。
- **输入：** `text`；`maxLength` —— 可接受结果的最大长度，按 rune 计。
- **返回：** `String?` —— 单行、无 Markdown 的句子；为空或过长时为 null。
- **副作用：** 无。
- **算法：** 去除 Markdown，把所有空白折叠为单个空格，修剪，然后检查长度。
- **用法：** `lib/features/recommendations/services/ai_reason_service.dart` 中的 `parseReasonReply`（1.6.0，M5）。
- **备注：** 过长的输出被丢弃而不是截断，因为被截断的句子读起来像是错的。
