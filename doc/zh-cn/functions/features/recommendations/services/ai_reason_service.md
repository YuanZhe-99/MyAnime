# lib/features/recommendations/services/ai_reason_service.dart

推荐中可选的 AI 那一半（1.6.0，M5）：把排名靠前的候选交给端侧模型，校验 `<number>: <reason>` 形式的回复，并返回
以动画 id 为键的至多三条简短理由。不做任何缓存；任何失败都得到空映射，页面保留确定性的标签。见
[`recommendation_service.md`](recommendation_service.md)、[`reason_prompt.md`](reason_prompt.md)、
[`../../ai/services/output_validation.md`](../../ai/services/output_validation.md) 和
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`parseReasonReply`](#parsereasonreply) | 顶层函数 | A | 读取模型的 `<number>: <reason>` 行。 |
| `ReasonLanguage.new` | 构造函数（`ReasonLanguage`） | B | 创建请求语言：语言区域标签、英文名、文字系统代码和中文转换标志。 |
| [`ReasonLanguage.forLocale`](#reasonlanguage-forlocale) | 静态方法（`ReasonLanguage`） | A | 为界面语言区域挑选请求语言。 |
| `ReasonLanguage.finish` | 方法（`ReasonLanguage`） | B | 对通过校验的理由做后处理：用 `ChineseConvert` 转成界面使用的中文变体，否则原样返回。 |
| [`writeAiReasons`](#writeaireasons) | 顶层函数 | A | 请端侧模型写至多三条简短理由。 |

`aiReasonCandidates`（8）、`aiReasonMaxLength`（140）、私有的 `_answerLine` 模式以及 `ReasonLanguage` 的字段
（`localeTag`、`name`、`code`、`toTraditional`、`toSimplified`）没有 `/// Purpose:` 注释，不作为行。

## 文档

### `Map<int, String> parseReasonReply(String reply, int count, String languageCode)` <a id="parsereasonreply"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/ai_reason_service.dart`（约第 27 行）
- **用途：** 读取模型的 `<number>: <reason>` 行。
- **输入：** `reply`；`count` — 提供了多少个候选；`languageCode` — `en`、`ja` 或 `zh`。
- **返回：** `Map<int, String>` — 从 1 开始的候选编号到理由，至多三条。
- **副作用：** 无。
- **算法：** 先去掉 Markdown（[`stripMarkdown`](../../ai/services/output_validation.md#stripmarkdown)），再逐行匹配
  一个数字后跟 `:`、`：`、`.`、`)` 或 `、`。丢弃 1…`count` 之外的编号和重复编号；用
  [`cleanSentence`](../../ai/services/output_validation.md#cleansentence) 按 `aiReasonMaxLength` 清理文本（为空或过长时
  为 null）；除非 [`matchesScript`](../../ai/services/output_validation.md#matchesscript) 认可，否则丢弃。满三条即停。
- **用法：** `writeAiReasons`；`test/recommendations_test.dart`。
- **备注：** 文字系统检查接受任一中文变体；变体随后由 `ReasonLanguage.finish` 修正。

### `static ReasonLanguage? forLocale(Locale locale, {bool? localeSupported})` <a id="reasonlanguage-forlocale"></a>
- **种类：** `ReasonLanguage` 的静态方法
- **来源：** `lib/features/recommendations/services/ai_reason_service.dart`（约第 85 行）
- **用途：** 为界面语言区域挑选请求语言。
- **输入：** `locale`；`localeSupported` — Apple 对界面语言区域的 `supportsLocale` 回答，未知时为 null（Android 上始终如此）。
- **返回：** `ReasonLanguage?` — 应跳过 AI 理由时为 null。
- **副作用：** 无。
- **算法：**

  | 界面语言区域 | `localeSupported` | 请求 | 后处理 |
  |---|---|---|---|
  | `zh_TW` / `zh_HK` | `false` | `zh_CN`，简体中文 | 转繁体 |
  | `zh_TW` / `zh_HK` | `true` 或 null | `zh_TW`，繁体中文 | 转繁体 |
  | 其他 `zh` | 不为 `false` | `zh_CN`，简体中文 | 转简体 |
  | `ja` | 不为 `false` | `ja_JP`，日语 | — |
  | 其他 | 不为 `false` | `en_US`，英语 | — |
  | 非繁体中文 | `false` | —（null：跳过） | — |

- **用法：** `_RecommendationsPageState._requestAiReasons`；`test/recommendations_test.dart`。
- **备注：** 中文输出总会转成界面使用的变体，因此另一种变体的回复会被修正而不是丢弃。

### `Future<Map<String, String>> writeAiReasons(OnDeviceAiService ai, {required List<Recommendation> ranked, required List<Anime> library, required ReasonLanguage language})` <a id="writeaireasons"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/recommendations/services/ai_reason_service.dart`（约第 134 行）
- **用途：** 请端侧模型写至多三条简短理由。
- **输入：** `ai`；`ranked` — 确定性列表；`library`；`language`；`insights` — AI 缓存，使 AI 得出的分类在此与在排序中一样被计入。
- **返回：** `Future<Map<String, String>>` — 动画 id 到理由；模型无法生成、列表为空或任何环节失败时为空。
- **副作用：** 通过 [`OnDeviceAiService.generate`](../../ai/services/on_device_ai_service.md#ondeviceaiservice-generate)
  以 `AiPriority.interactive` 和 `maxOutputTokens: 256` 运行一次模型。
- **算法：**
  1. 取前 `aiReasonCandidates`（8）个，作为带编号的 `ReasonCandidate`，包含标题、生效分类（带 `insights` 的 `resolveCategories`）、制作公司，以及每个 `NextAfterReason`
     对应的 `next after <title>` 事实。
  2. 从 `preferenceOf` 为正的记录构建精简画像：按偏好之和排名前三的分类（同样带 `insights`）和前三的制作公司，以及 `modifiedAt` 最新的三条
     已看完记录及其评分。
  3. 用 [`reasonInstructions`](reason_prompt.md#reasoninstructions) 和 [`reasonPrompt`](reason_prompt.md#reasonprompt)
     生成，用 [`parseReasonReply`](#parsereasonreply) 解析，把编号映射回 id，并应用 `language.finish`。
- **用法：** `_RecommendationsPageState._requestAiReasons`；由 `test/recommendations_page_ui_test.dart` 通过页面间接覆盖。
- **备注：** 从不抛出。页面先渲染确定性列表；这些理由到达时再填入，并且只保存在内存中。
