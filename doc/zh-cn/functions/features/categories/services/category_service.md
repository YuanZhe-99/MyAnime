# lib/features/categories/services/category_service.dart

自动分类（1.6.0，M4）：如何解析一条记录的分类、端侧模型可以看到什么、如何为一次分类请求计算指纹，以及填补类型标签
映射留下的空缺的 `CategoryClassifier`。`CategoryOrigin`（`user`、`mapped`、`ai`）记录一条记录的 `EffectiveCategories`
由哪个来源产生。模型的结果只写入 [`ai_insights.json`](../../ai/services/ai_insights_cache.md)；这里从不写记录本身。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md)
和 [`../../../../on-device-ai.md`](../../../../on-device-ai.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `EffectiveCategories.new` | 构造函数（`EffectiveCategories`） | B | 创建生效的分类（`ids`、`origin`）。 |
| [`resolveCategories`](#resolvecategories) | 顶层函数 | A | 解析一条记录的分类。 |
| [`classificationInputOf`](#classificationinputof) | 顶层函数 | A | 收集模型可以知道的关于一部作品的信息。 |
| [`modelIdentityOf`](#modelidentityof) | 顶层函数 | A | 为指纹和缓存命名将要回答的模型。 |
| [`classificationFingerprint`](#classificationfingerprint) | 顶层函数 | A | 为一次分类请求计算指纹。 |
| [`needsClassification`](#needsclassification) | 顶层函数 | A | 判断一条记录是否需要 AI 分类。 |
| `CategoryClassifier.new` | 构造函数（`CategoryClassifier`） | B | 创建分类器；AI 服务、片库加载器和缓存的加载/保存都可为测试注入。 |
| `CategoryClassifier.setInstanceForTest` | 静态方法（`CategoryClassifier`），`@visibleForTesting` | B | 为测试替换单例。 |
| [`CategoryClassifier.start`](#categoryclassifier-start) | 方法（`CategoryClassifier`） | A | 每次回到前台时启动本次会话的细流。 |
| [`CategoryClassifier.trickle`](#categoryclassifier-trickle) | 方法（`CategoryClassifier`） | A | 在后台为少量记录分类。 |
| [`CategoryClassifier.classifyAll`](#categoryclassifier-classifyall) | 方法（`CategoryClassifier`） | A | 立即为每条待分类记录分类（「立即分类」）。 |
| [`CategoryClassifier.refreshCounts`](#categoryclassifier-refreshcounts) | 方法（`CategoryClassifier`） | A | 不运行模型地刷新待分类计数。 |
| [`CategoryClassifier._run`](#categoryclassifier-_run) | 方法（`CategoryClassifier`） | A | 运行一轮分类。 |
| `CategoryClassifier.dispose` | 方法（`CategoryClassifier`） | B | 释放生命周期监听器。 |

`CategoryOrigin`、`EffectiveCategories.empty`、`CategoryClassifier.instance`、`sessionLimit`（20）、`enabled`、`pending`、
`candidates` 和 `running` getter 没有 `/// Purpose:` 注释，不作为行。

## 文档

### `EffectiveCategories resolveCategories(Anime anime, {AiInsights? insights})` <a id="resolvecategories"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/categories/services/category_service.dart`（约第 59 行）
- **用途：** 解析一条记录的分类。
- **输入：** `anime`；`insights` — AI 缓存，为 `null` 时忽略它。
- **返回：** `EffectiveCategories` — id 加 `CategoryOrigin`，或 `EffectiveCategories.empty`。
- **副作用：** 无。
- **算法：** 第一个给出结果的来源胜出：
  1. **用户** — 只要 `anime.categories` 非 null，*即使为空*；未知 id 从结果中去掉（仍留在记录上）。
  2. **映射** — `externalMeta.genres` 的
     [`mapGenresToCategories`](../../anime/models/anime_category.md#mapgenrestocategories)，非空时。
  3. **AI** — `anime.id` 的缓存条目，状态为 `ok` 时，收窄为按分类表顺序的已知 id。
- **用法：** 详情页的 `_load`、管理页的分类筛选。
- **备注：** AI 这一步只在条目的指纹仍与当前输入相符时（用条目自身的 `model` 重新计算）才使用它，因此过时的条目会被隐藏，直到分类器替换它。调用方只在端侧 AI 开启时传入 `insights`，因此 AI 建议的分类会随开关关闭而消失。

### `ClassificationInput classificationInputOf(Anime anime)` <a id="classificationinputof"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/categories/services/category_service.dart`（约第 88 行）
- **用途：** 收集模型可以知道的关于一部作品的信息。
- **输入：** `anime`。
- **返回：** [`ClassificationInput`](../../ai/services/prompt_templates.md)。
- **副作用：** 无。
- **算法：** 来自 `seriesTitlesOf` 的至多五个标题、`externalMeta.format`、`firstAirDate` 的年份、`effectiveType.name`、
  `totalEpisodes`、`externalMeta.studios` 和 `externalMeta.genres`。
- **用法：** `needsClassification`、`CategoryClassifier._run`。
- **备注：** 从不包含备注、评分或观看进度——只包含描述作品本身的事实。

### `String modelIdentityOf(GenAiStatusReport report)` <a id="modelidentityof"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/categories/services/category_service.dart`（约第 107 行）
- **用途：** 为指纹和缓存命名将要回答的模型。
- **输入：** `report` — AI 服务当前的状态报告。
- **返回：** `String` — `variant · baseModelName`（如 `stable/full · nano-v3`），两者都未知时为 `apple`。
- **副作用：** 无。
- **用法：** `refreshCounts`、`_run`。
- **备注：** 模型会随系统和 AICore 更新而变，因此新的身份会让分类重新排队。

### `String classificationFingerprint(ClassificationInput input, String model)` <a id="classificationfingerprint"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/categories/services/category_service.dart`（约第 118 行）
- **用途：** 为一次分类请求计算指纹。
- **输入：** `input`、`model`。
- **返回：** `String` — 十六进制 SHA-256。
- **副作用：** 无。
- **算法：** 对 `input.canonical()`、`taxonomy:<categoryTaxonomyVersion>`、`prompt:<classificationPromptVersion>` 和
  `model:<model>` 以换行连接后求哈希。
- **用法：** `needsClassification`、`_run`。
- **备注：** 四者任一变化都会让记录重新排队。

### `bool needsClassification(Anime anime, AiInsights insights, String model)` <a id="needsclassification"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/categories/services/category_service.dart`（约第 134 行）
- **用途：** 判断一条记录是否需要 AI 分类。
- **输入：** `anime`、`insights`、`model`。
- **返回：** `bool` — 仅当用户没有自选分类、类型标签映射不到任何分类、且没有缓存条目带当前指纹时为 true。
- **副作用：** 无。
- **用法：** `refreshCounts`、`_run`。
- **备注：** 任何状态都算已完成，因此带当前指纹的 `skipped` 或 `none` 条目不会重试。

### `void start()` <a id="categoryclassifier-start"></a>
- **种类：** `CategoryClassifier` 的方法
- **来源：** `lib/features/categories/services/category_service.dart`（约第 211 行）
- **用途：** 每次回到前台时启动本次会话的细流。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 注册一个 `AppLifecycleListener`。
- **算法：** 每次进入 `resumed` 状态时，重置会话计数并不 await 地启动 `trickle()`。幂等。
- **用法：** `main()`（见 [`../../../main.md`](../../../main.md)）。
- **备注：** 启动时的第一次细流来自 `AppSettingsNotifier._loadPersisted`，而不是来自回到前台。

### `Future<int> trickle()` <a id="categoryclassifier-trickle"></a>
- **种类：** `CategoryClassifier` 的方法
- **来源：** `lib/features/categories/services/category_service.dart`（约第 227 行）
- **用途：** 在后台为少量记录分类。
- **输入：** 无。
- **返回：** `Future<int>` — 分类了多少条。
- **副作用：** 运行模型；写入 `ai_insights.json`。
- **算法：** `_run(sessionLimit - thisSession, countSession: true)`。
- **用法：** `start`、`AppSettingsNotifier`（加载时、开启自动分类时、开启端侧 AI 之后）。
- **备注：** 每次前台会话至多 `sessionLimit`（20）条记录。

### `Future<int> classifyAll()` <a id="categoryclassifier-classifyall"></a>
- **种类：** `CategoryClassifier` 的方法
- **来源：** `lib/features/categories/services/category_service.dart`（约第 236 行）
- **用途：** 立即为每条待分类记录分类。
- **输入：** 无。
- **返回：** `Future<int>` — 分类了多少条。
- **副作用：** 运行模型；写入 `ai_insights.json`。
- **用法：** [`CategorizeNowTile`](../widgets/categorize_now_tile.md)（「立即分类」）。
- **备注：** 不计入会话细流。遇到第一个不属于单条记录拒绝的失败时停止。

### `Future<void> refreshCounts()` <a id="categoryclassifier-refreshcounts"></a>
- **种类：** `CategoryClassifier` 的方法
- **来源：** `lib/features/categories/services/category_service.dart`（约第 243 行）
- **用途：** 不运行模型地刷新待分类计数。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 读取片库和缓存（按片库 id 修剪）；通知监听者。
- **算法：** `candidates` 统计没有用户自选分类、也没有类型标签映射的记录；`pending` 统计其中 `needsClassification`
  为 true 的记录。
- **用法：** `CategorizeNowTile`（首次构建时和一轮结束后）——即「N / M」计数。
- **备注：** 无。

### `Future<int> _run(int budget, {required bool countSession})` <a id="categoryclassifier-_run"></a>
- **种类：** `CategoryClassifier` 的方法
- **来源：** `lib/features/categories/services/category_service.dart`（约第 270 行）
- **用途：** 运行一轮分类。
- **输入：** `budget` — 最多分类多少条；`countSession` — 是否计入会话上限。
- **返回：** `Future<int>` — 分类了多少条。
- **副作用：** 经 `OnDeviceAiService.choose` 运行模型；每分类一条记录后保存缓存；开始和结束时通知监听者。
- **算法：**
  1. 除非 `enabled`、服务 `canGenerate`、没有正在运行的一轮且 `budget > 0`，否则返回 0。
  2. 加载片库和缓存（已修剪），计算模型身份，把每条 `needsClassification` 为 true 的记录排入队列。队列非空时预热模型。
  3. 对队列中每条记录，只要仍在预算内且两个开关都开着：以 `classificationInstructions` 和 `classificationPrompt`
     在这些 id 加 `none` 中 `choose`（至多三个）。按分类表顺序保留已知 id，至多三个；状态为 `ok`，一个不剩时为 `none`。
  4. `guardrail` 或 `unsupportedLanguage` 的 `GenAiException` 存为 `skipped`；其他任何失败都会停止这一轮，把该记录留到下次。
  5. 存入条目、保存、计数。
- **用法：** `trickle`、`classifyAll`。
- **备注：** 批大小 1：每个提示词一条记录。从不写记录，只写缓存。
