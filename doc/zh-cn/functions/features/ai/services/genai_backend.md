# lib/features/ai/services/genai_backend.dart

`OnDeviceAiService` 与平台端侧模型之间的 Dart 接缝，1.6.0（M3）新增。它包含 `GenAiStatus` 与 `GenAiFailure`
两个枚举、平台用来应答的 `GenAiStatusReport` 与 `GenAiCoreInfo` 值类、测试中用假实现替换的抽象接口
`GenAiBackend`，以及 `MethodChannelGenAiBackend`——它通过 `com.yuanzhe.my_anime/genai` 与 Android 上的
`GenAiChannel.kt` 以及 iOS 和 macOS 上的 `on_device_ai_apple` 插件通信。策略（开关、队列、解析）都在服务一侧，
因此所有值得测试的内容都无需设备即可运行。平台事实、通道方法和状态表见
[`../../../../on-device-ai.md`](../../../../on-device-ai.md)。**尚未在设备上验证**（2026-09-24）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`platformMayHaveOnDeviceModel`](#platformmayhaveondevicemodel) | 顶层 getter | A | 报告本平台是否可能拥有端侧模型。 |
| `GenAiException.new` | 构造函数（`GenAiException`） | B | 创建一个生成失败。 |
| `GenAiException.toString` | 方法（`GenAiException`） | B | 为日志描述该失败。 |
| `GenAiStatusReport.new` | 构造函数（`GenAiStatusReport`） | B | 描述模型的可用性。 |
| [`GenAiStatusReport.hasSizeChoice`](#genaistatusreport-hassizechoice) | getter（`GenAiStatusReport`） | A | 说明已提供的变体是否同时包含两种模型尺寸。 |
| [`GenAiStatusReport.fromJson`](#genaistatusreport-fromjson) | 静态方法（`GenAiStatusReport`） | A | 读取平台通道发来的映射。 |
| `GenAiCoreInfo.new` | 构造函数（`GenAiCoreInfo`） | B | 描述设备的模型系统。 |
| `GenAiCoreInfo.fromJson` | 静态方法（`GenAiCoreInfo`） | B | 读取平台通道发来的映射；没有可用内容时为 null。 |
| `GenAiBackend.statusReport` | 抽象方法（`GenAiBackend`） | B | 询问模型能做什么，以及设备对此的说法。 |
| `GenAiBackend.coreInfo` | 抽象方法（`GenAiBackend`） | B | 描述设备的模型系统。 |
| `GenAiBackend.download` | 抽象方法（`GenAiBackend`） | B | 请系统获取模型（仅 Android）。 |
| `GenAiBackend.generate` | 抽象方法（`GenAiBackend`） | B | 生成一个回答。 |
| `GenAiBackend.choose` | 抽象方法（`GenAiBackend`） | B | 从 `options` 中至多选出 `maxItems` 项。 |
| `GenAiBackend.prewarm` | 抽象方法（`GenAiBackend`） | B | 在一批请求之前预先加载模型。 |
| `GenAiBackend.cancel` | 抽象方法（`GenAiBackend`） | B | 停止正在运行的请求。 |
| `MethodChannelGenAiBackend.new` | 构造函数（`MethodChannelGenAiBackend`） | B | 创建通道后端；通道可为测试注入。 |
| [`MethodChannelGenAiBackend.statusReport`](#methodchannelgenaibackend-statusreport) | 方法（`MethodChannelGenAiBackend`） | A | 向平台询问模型状态。 |
| `MethodChannelGenAiBackend.coreInfo` | 方法（`MethodChannelGenAiBackend`） | B | 读取设备模型系统的详情；调用失败时一律为 null。 |
| [`MethodChannelGenAiBackend.download`](#methodchannelgenaibackend-download) | 方法（`MethodChannelGenAiBackend`） | A | 请系统获取模型。 |
| `MethodChannelGenAiBackend.generate` | 方法（`MethodChannelGenAiBackend`） | B | 通过通道生成一个回答。 |
| [`MethodChannelGenAiBackend.choose`](#methodchannelgenaibackend-choose) | 方法（`MethodChannelGenAiBackend`） | A | 从 `options` 中至多选出 `maxItems` 项。 |
| `MethodChannelGenAiBackend.prewarm` | 方法（`MethodChannelGenAiBackend`） | B | 在一批请求之前预先加载模型；错误被吞掉。 |
| `MethodChannelGenAiBackend.cancel` | 方法（`MethodChannelGenAiBackend`） | B | 停止正在运行的请求；错误被吞掉。 |
| `MethodChannelGenAiBackend._handlePlatformCall` | 方法（`MethodChannelGenAiBackend`） | B | 接收平台发来的下载进度。 |
| [`MethodChannelGenAiBackend.failureForCode`](#methodchannelgenaibackend-failureforcode) | 静态方法（`MethodChannelGenAiBackend`） | A | 把平台错误码映射为失败类型。 |

`GenAiStatus` 与 `GenAiFailure` 枚举、`GenAiStatusReport` 与 `GenAiCoreInfo` 的值字段、
`GenAiStatusReport.unsupported` 以及 `MethodChannelGenAiBackend.channelName` 没有 `/// Purpose:` 注释，
不作为行。状态与失败的取值列在 [`../../../../on-device-ai.md`](../../../../on-device-ai.md#statuses-and-failures)。

## 文档

### `bool get platformMayHaveOnDeviceModel` <a id="platformmayhaveondevicemodel"></a>
- **种类：** 顶层 getter
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 15 行）
- **用途：** 报告本平台是否可能拥有端侧模型。
- **输入：** 无。
- **返回：** `bool` —— 在 Android、iOS 和 macOS 上为 true；在 Windows、Linux 和 Web 上为 false。
- **副作用：** 无。
- **算法：** `!kIsWeb`，且 `defaultTargetPlatform` 是 Android、iOS 或 macOS。
- **用法：** `MethodChannelGenAiBackend` 的每个方法都先检查它；`OnDeviceAiService.refreshStatus` 和
  `AiSettingsTiles.build` 也检查它。
- **备注：** 这是一道粗粒度的门：在这些平台之外，后端不触碰通道就回答 `unsupported`，设置中也不显示任何
  AI 行。因为它读取 `defaultTargetPlatform`，测试用 `debugDefaultTargetPlatformOverride` 切换它。

### `bool get hasSizeChoice` <a id="genaistatusreport-hassizechoice"></a>
- **种类：** `GenAiStatusReport` 的 getter
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 164 行）
- **用途：** 说明已提供的变体是否同时包含两种模型尺寸。
- **输入：** 无。
- **返回：** `bool` —— `served` 同时含 `/full` 和 `/fast` 时为 true。
- **副作用：** 无。
- **算法：** 对 Android 探测报告的逗号分隔 `served` 列表做子串检查。
- **用法：** 只有它为 true 时，`AiSettingsTiles.build` 才显示「使用更快的模型」。
- **备注：** 不能改变任何东西的控件不显示。Apple 从不报告 `served`。

### `static GenAiStatusReport fromJson(Map<Object?, Object?>? answer)` <a id="genaistatusreport-fromjson"></a>
- **种类：** `GenAiStatusReport` 的静态方法
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 176 行）
- **用途：** 读取平台通道发来的映射。
- **输入：** `answer` —— `status` 的应答，可能为 null。
- **返回：** `GenAiStatusReport`。
- **副作用：** 无。
- **算法：**
  1. 按名称把 `status` 字符串映射为 `GenAiStatus`。其他任何字符串变为 `unknown`；缺失或非字符串的值变为
     `unavailable`。
  2. `code` 和 `tokenLimit` 只在是 `int` 时采用（`code` 默认 -1）。
  3. `detail`、`variant`、`served`、`refused` 和 `baseModelName` 用 `toString()` 取值。
- **用法：** `MethodChannelGenAiBackend.statusReport`。
- **备注：** 未知状态按原样报告，而不是并入 `unavailable`，因此较新平台的取值能在技术详情中看到。缺失的字段
  是缺失，而不是错误。`unsupported` 是 Apple 插件在 26 之前的 iOS 和 macOS 上的应答。

### `Future<GenAiStatusReport> statusReport({bool force = false, bool preferFast = false})` <a id="methodchannelgenaibackend-statusreport"></a>
- **种类：** `MethodChannelGenAiBackend` 的方法
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 375 行）
- **用途：** 向平台询问模型状态。
- **输入：** `force` —— 重新探测，而不是信任已在提供服务的模型；`preferFast` —— 在设备同时提供两种尺寸时
  请求较小的模型。
- **返回：** `Future<GenAiStatusReport>`；从不抛出。
- **副作用：** 一次 `status` 通道调用，参数为 `{feature: 'prompt', force, preferFast}`。
- **算法：**
  1. 在受支持平台之外，不调用就返回 `GenAiStatusReport.unsupported`。
  2. 调用 `status`，用 `GenAiStatusReport.fromJson` 解析应答。
  3. `MissingPluginException` → `unreachable`，detail 为 `channel not registered`；
     `PlatformException` → `unreachable`，detail 为 `code: message`；其他任何错误 → `unreachable`，detail
     为错误的类型名。
- **用法：** `OnDeviceAiService.refreshStatus`、`download` 和 `_pump`。
- **备注：** 缺失的插件从不报告为 `unsupported`：iOS 或 macOS 上注册失败的插件正是这样被发现的。

### `Future<bool> download({void Function(int bytes, int total)? onProgress})` <a id="methodchannelgenaibackend-download"></a>
- **种类：** `MethodChannelGenAiBackend` 的方法
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 431 行）
- **用途：** 请系统获取模型。
- **输入：** `onProgress` —— 目前的字节数和总数，未知时为 -1。
- **返回：** `Future<bool>` —— 下载完成时为 true。
- **副作用：** AICore 下载模型；进度以平台发来的 `downloadProgress` 方法调用送达。只注册一次通道的调用处理器。
- **算法：**
  1. 在受支持平台之外，抛出 `GenAiException(unavailable)`。
  2. 保存 `onProgress`；首次使用时把 `_handlePlatformCall` 安装为方法调用处理器。
  3. 以 `{feature: 'prompt'}` 调用 `download`；`PlatformException` 经 `failureForCode` 映射，
     `MissingPluginException` 映射为 `unavailable`。
  4. 在 `finally` 中清除保存的回调。
- **用法：** `OnDeviceAiService.download`，由设置中的「下载」按钮触发。
- **备注：** 应用自己从不下载任何东西。Apple 插件没有 `download`；该按钮只在 Android 上显示。

### `Future<List<String>> choose({required String instructions, required String prompt, required List<String> options, int maxItems = 3})` <a id="methodchannelgenaibackend-choose"></a>
- **种类：** `MethodChannelGenAiBackend` 的方法
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 497 行）
- **用途：** 从 `options` 中至多选出 `maxItems` 项。
- **输入：** `instructions`、`prompt`、`options` —— 允许的 id、`maxItems`。
- **返回：** `Future<List<String>>` —— 选中的 id，可能为空。
- **副作用：** 在设备上运行模型。
- **算法：**
  1. 在受支持平台之外，抛出 `GenAiException(unavailable)`。
  2. 在 Android 上，以 `maxOutputTokens: 64` 调用 `generate`，用
     [`parseChoiceReply`](output_validation.md#parsechoicereply) 读取应答，无效时抛出
     `GenAiException(failed, 'unparseable reply')`。
  3. 其他平台调用原生 `choose`（在 Apple 上是约束解码），保留应答中的字符串项。
- **用法：** `OnDeviceAiService.choose`。
- **备注：** 两条路径返回的 id 都由调用方再次按自己的列表校验。

### `static GenAiFailure failureForCode(String code)` <a id="methodchannelgenaibackend-failureforcode"></a>
- **种类：** `MethodChannelGenAiBackend` 的静态方法（`@visibleForTesting`）
- **来源：** `lib/features/ai/services/genai_backend.dart`（约第 588 行）
- **用途：** 把平台错误码映射为失败类型。
- **输入：** `code` —— `GenAiChannel` 或 Apple 插件发来的 `PlatformException.code`。
- **返回：** `GenAiFailure`。
- **副作用：** 无。
- **算法：** 对失败名 `unavailable`、`busy`、`cancelled`、`tooLong`、`background`、`quota`、`guardrail` 和
  `unsupportedLanguage` 做 `switch`；其他一律为 `failed`。
- **用法：** 同一类中的 `download`、`generate` 和 `choose`。
- **备注：** 平台从不发送 `timeout`；它由 `OnDeviceAiService` 自己产生。
