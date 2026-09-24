# 端侧 AI

MyAnime!!!!! 可以使用设备自带的语言模型——通过 Android AICore 使用 Gemini Nano，或通过 Foundation Models 框架使用
Apple Intelligence 的模型——为自动分类补缺，并为推荐写简短的理由。本页记录其背后的平台事实、代码的布局，以及
仍需在设备上检查的内容。

> **最后核实：** 2026-09-24，依据官方文档和已发布的库（来源见下文）。**尚未在设备上验证。** 带 AICore 的
> Android 设备和带 Apple Intelligence 的 Apple 设备都还没有运行过这段代码；有设备时按
> [设备检查清单](#device-checklist) 操作。Android 桥接移植自 MyNihongo!!!!!，后者已在 Pixel 10 和
> Galaxy Z Fold 8 上运行过。

## 策略

第 1–3、7 和 8 条在 `master` 的代码中强制执行，并由 `test/on_device_ai_test.dart` 和
`test/ai_settings_tiles_ui_test.dart` 覆盖。第 4–6 条约束使用模型的功能，这些功能由里程碑 M4 和 M5 加入；
`master` 上目前还不生成任何内容。

1. **默认关闭。** 在用户打开开关之前，`storage_config.json` 中没有 `onDeviceAiEnabled`。
2. **开关就是一道门。** 开关关闭时从不调用方法通道，连状态也不查询。
3. **每次请求前都重新检查状态。** 系统可能在两次请求之间移除模型。
4. **生成的输出带标注**「在本设备上生成——可能有误」。
5. **回退方案就是应用本身。** 分类和推荐先走确定性逻辑；模型只负责补缺和添加理由。
6. **生成的内容不同步也不备份。** 结果将存放在 `ai_insights.json` 中，该文件不会登记到
   `lib/app/data_modules.dart`。
7. **绝不替用户下载任何东西。** 在 Android 上，模型下载只从设置中的「下载」按钮开始，并由 AICore 执行；在
   Apple 平台上由系统管理模型。
8. **只在端侧。** 绝不使用 Apple 的 Private Cloud Compute，也绝不使用任何其他远程模型。

两种 flavor 都包含此功能：它自身不发起任何网络调用。

## 布局

| 路径 | 作用 |
|---|---|
| `lib/features/ai/services/genai_backend.dart` | Dart 接缝：`GenAiStatus`、`GenAiFailure`、`GenAiStatusReport`、`GenAiCoreInfo`、`GenAiBackend` 接口和 `MethodChannelGenAiBackend` |
| `lib/features/ai/services/on_device_ai_service.dart` | `OnDeviceAiService`：开关、每次使用前的状态检查、单请求优先级队列、45 秒超时、生命周期、忙碌退避和每日配额停止 |
| `lib/features/ai/services/output_validation.dart` | 解析选择应答、去除 Markdown、文字系统检查、清理单句 |
| `lib/features/ai/widgets/ai_settings_tiles.dart` | `AiSettingsTiles`：开关、状态行、尺寸偏好、说明和技术详情 |
| `android/app/src/main/kotlin/com/yuanzhe/my_anime/GenAiChannel.kt` | 通往 ML Kit GenAI 的 Android 桥接 |
| `packages/on_device_ai_apple/` | 一个本地 Flutter 插件，iOS 和 macOS 共用一份 Darwin 源码 |

设置中的各行已经构建但**尚未显示**：`AiSettingsTiles` 没有放入 `settings_page.dart`，「分类与推荐」分区在
`master` 上保持隐藏，直到 M4 加入一个让 AI 开关有所服务的功能开关。这两个开关以 `onDeviceAiEnabled` 和
`onDeviceAiPreferFast` 存放在 `storage_config.json` 中（见 [`data-formats.md`](data-formats.md)）。

三个平台上的通道都是 `com.yuanzhe.my_anime/genai`。它的方法有 `status`（`force`、`preferFast`）、`info`
（`locale`）、`download`（仅 Android）、`generate`（`instructions`、`prompt`、`maxOutputTokens`、`temperature`、
`topK`）、`choose`（`instructions`、`prompt`、`options`、`maxItems`；仅 Apple——在 Android 上由 Dart 后端运行
`generate` 并逐行解析）、`prewarm` 和 `cancel`。`platformMayHaveOnDeviceModel` 在 Android、iOS 和 macOS 上为
true；在其他所有平台上，后端不触碰通道就回答 `unsupported`，设置中也不显示任何 AI 行。iOS 或 macOS 上的
`MissingPluginException` 报告为 `unreachable`，detail 为「channel not registered」，绝不报告为 `unsupported`，
这样注册失败的插件才会被发现。

### 状态与失败 <a id="statuses-and-failures"></a>

| 状态 | 含义 |
|---|---|
| `unsupported` | 本平台没有端侧模型（Windows、Linux、26 之前的 iOS 或 macOS） |
| `unavailable` | 已询问系统，系统表示不行 |
| `unreachable` | 根本无法询问系统 |
| `notEnabled` | Apple Intelligence 在系统设置中已关闭 |
| `downloadable` | Android：模型可由 AICore 获取 |
| `downloading` | 模型正在获取或准备中（也包括 Apple 的 `modelNotReady`） |
| `available` | 就绪 |
| `unknown` | 本版本没有对应名称的状态 |

失败类型有 `unavailable`、`busy`、`failed`、`cancelled`、`tooLong`、`timeout`、`background`、`quota`、
`guardrail` 和 `unsupportedLanguage`。

Apple 插件在 26 之前的 iOS 和 macOS 上回答 `unsupported`，设置页将其表述为"需要支持 Apple Intelligence 的
iOS 26 或 macOS 26"。

### 队列 <a id="the-queue"></a>

一次只运行一个请求。交互请求（推荐理由）排在后台请求（分类）之前。应用不处于
`AppLifecycleState.resumed` 时什么都不运行。遇到 `busy` 后，后台任务等待 5 秒，逐次翻倍，最长 5 分钟；遇到
`quota` 后，后台任务在当天剩余时间停止；遇到 `background` 后，队列等待下一次 resume。

## Android：基于 AICore 的 ML Kit GenAI <a id="android-ml-kit-genai-over-aicore"></a>

- 使用的版本是 `com.google.mlkit:genai-prompt:1.0.0-beta4`（2026-07-21），截至 2026-09-24 仍是 Google Maven
  上的最新版。它是 Gemini Nano v4 设备的最低版本，也是第一个能请求指定模型变体的客户端。beta3 中加入的
  Structured Output API（`genai-schema`，alpha，需要 KSP 2.3.6+）**没有**使用。
- 要求 API 26 或以上，因此自 1.6.0 起应用的 `minSdk` 为 26（放弃 Android 7.0 和 7.1）。这些 API 在已解锁
  bootloader 的设备上拒绝运行。输入必须保持在约 4,000 token 以下。
- 只有应用是最前台应用时才允许推理；后台使用会以 `BACKGROUND_USE_BLOCKED` 失败。AICore 实行按应用的配额：
  `BUSY` 和 `PER_APP_BATTERY_USE_QUOTA_EXCEEDED`。这两个常量已用 `javap` 在 beta4 AAR 中确认（值为 30 和 27），
  分别映射为 `background` 和 `quota`。
- 不同设备提供不同的模型变体，因此 `GenAiChannel.probePrompt` 尝试 `ModelReleaseStage`（STABLE、PREVIEW）与
  `ModelPreference`（FULL、FAST）的全部四种组合，保留第一个能提供服务的组合。只有两种尺寸都有提供时，设置才
  提供「使用更快的模型」。
- 模型报告 `isSystemPromptAvailable` 时，instructions 作为 `SystemInstruction` 发送；否则拼接在 prompt 前面。
- R8 曾两次在 MyNihongo 的 release 构建中破坏 ML Kit；`android/app/proguard-rules.pro` 带有这两条保留规则及其
  说明。
- `AndroidManifest.xml` 为 `com.google.android.aicore` 加了 `<queries>` 条目，使 `info` 能读取 AICore 的版本。
- 工具链与 MyNihongo 相同：AGP 9.1.1、Kotlin Gradle Plugin 2.2.20、`android.builtInKotlin=false`。
- 日志标签：`MyAnimeGenAi`。记录异常，从不记录 prompt。

来源：<https://developers.google.com/ml-kit/genai>、
<https://developers.google.com/ml-kit/genai/prompt/android/get-started>、
<https://developers.google.com/ml-kit/release-notes>，以及 MyNihongo 的 `doc/en-us/android-aicore.md`。

## Apple：Foundation Models 框架 <a id="apple-the-foundation-models-framework"></a>

- iOS、iPadOS 和 macOS 26.0 或以上。`SystemLanguageModel.default.availability` 为 `.available` 或
  `.unavailable(reason)`，原因是 `deviceNotEligible`、`appleIntelligenceNotEnabled` 或 `modelNotReady`；可用性
  还取决于地区。
- 每个请求新建一个 `LanguageModelSession(instructions:)`，使前面的对话轮次不会泄漏到后面的回答中；分类使用
  贪婪采样。
- `choose` 使用带运行时词表的引导式生成：
  `DynamicGenerationSchema(arrayOf: DynamicGenerationSchema(name:description:anyOf:),
  minimumElements: 0, maximumElements: n)`，并通过 `GeneratedContent.jsonString` 读回。
- 列出的语言包括 en-US、ja-JP 和 zh-CN；繁体中文不在列表中。`info` 会报告应用语言区域的 `supportsLocale`。
- 上下文窗口为 4,096 token。后台调用会被限速。
- 26 SDK 上的错误类型是 `LanguageModelSession.GenerationError`：`rateLimited` → `quota`，
  `concurrentRequests` → `busy`，`guardrailViolation` 和 `refusal` → `guardrail`，
  `unsupportedLanguageOrLocale` → `unsupportedLanguage`，`exceededContextWindowSize` → `tooLong`，
  `assetsUnavailable` → `unavailable`，其他一律 → `failed`。OS 27 弃用了该类型，但用 Xcode 26 构建的应用仍会
  收到它。
- CI 使用 `macos-latest` 镜像默认的 Xcode 26.6 构建。所有代码都针对 26 SDK 编写；只在 27 中存在的符号需要
  编译期守卫。
- 模型随系统更新而变化，因此 prompt 必须针对每个模型版本重新检查。
- 不需要任何 entitlement、`Info.plist` 键或使用说明，并且刻意没有 Private Cloud Compute 的 entitlement。

### 弱链接 <a id="weak-linking"></a>

部署目标保持为 iOS 13.0 和 macOS 13.0。每处 FoundationModels 引用都位于 `#if canImport(FoundationModels)` 和
`@available(iOS 26.0, macOS 26.0, *)` 之后，podspec 声明了 `s.weak_frameworks = 'FoundationModels'`。强链接该
框架的应用无法在 iOS 18 或 macOS 15 及更早版本上启动，因此这一点**经过检查，而不是假设**：只要有任何链接
FoundationModels 的二进制没有使用 `LC_LOAD_WEAK_DYLIB`，`tool/check_weak_link.sh` 就让 CI 构建失败；没有任何
二进制链接它时（插件没有进入构建）也会失败。见 [`ci-cd.md`](ci-cd.md)。

来源：<https://developer.apple.com/documentation/foundationmodels> 及其关于 `SystemLanguageModel`、
`DynamicGenerationSchema` 和 `LanguageModelSession.GenerationError` 的页面；「Supporting languages and locales
with Foundation Models」；Apple 对该框架的可接受使用要求；Xcode 版本见 <https://github.com/actions/runner-images>。

## 商店政策 <a id="store-policy"></a>

Google Play 的 AI 生成内容政策把使用 AI 改进现有功能的效率类应用列为不在适用范围内；输出仍然带标注，推荐也
可以隐藏。Apple 对 Foundation Models 的可接受使用要求禁止生成成人内容等，因此分类体系中没有这类分类。

## 设备检查清单 <a id="device-checklist"></a>

有设备时执行以下步骤，并更新上文的**最后核实**。

1. 开关关闭时，确认没有任何东西触碰模型（logcat 标签 `MyAnimeGenAi` 保持安静）。
2. 打开开关；检查状态行、技术详情，以及 Android 上的 AICore 版本和已提供与被拒绝的变体。
3. Android：点「下载」，进度以 MB 显示；状态变为可用。
4. 对一条没有类型标签的记录进行分类；chip 显示闪光图标和提示。
5. 在全部四种界面语言下打开推荐；理由以正确的文字系统到达，模型用简体回答时繁体中文会被转换。
6. 请求进行中把应用切到后台；恢复后正常继续。
7. 在 **release** 构建（R8）上重复第 2–5 步。
8. Apple：在系统设置中关闭 Apple Intelligence；状态行如实说明。
9. Apple：在 iOS 18 或 macOS 15 设备上安装，或在模拟器中启动一台，确认应用能启动。

## 如何刷新本页 <a id="how-to-refresh-this-page"></a>

1. 对照 Google Maven 分组索引（`https://dl.google.com/android/maven2/com/google/mlkit/group-index.xml`）和
   ML Kit 发布说明检查 `genai-prompt`。
2. 针对当前 SDK 重读 Foundation Models 文档，并确认 runner 镜像的默认 Xcode。
3. 重新检查错误码：对 `genai-common` AAR 中的 `GenAiException$ErrorCode` 运行 `javap -public -constants`。
4. 在两种语言中更新**最后核实**和上面的事实。
