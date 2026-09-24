# lib/features/ai/services/on_device_ai_service.dart

`OnDeviceAiService` 于 1.6.0（M3）新增，负责端侧 AI 的策略：模型究竟能否被询问、它此刻能做什么，以及它前面
那个一次只跑一个请求的队列。**用户的开关关闭时，后端从不被调用——连状态也不查询。** 每个请求都先重新检查
状态，在 45 秒超时内运行，并在应用未处于 resumed 时等待。遇到 `busy` 后，后台任务从 5 秒开始退避，逐次翻倍，
最长 5 分钟；遇到 `quota` 后，当天剩余时间停止。该服务是一个 `ChangeNotifier` 单例，改编自 MyNihongo!!!!! 的
`AiAssistService`；`AppSettingsNotifier` 把持久化的开关值告诉它，`main` 启动它的生命周期监听器。它调用的接缝见
[`genai_backend.md`](genai_backend.md)，策略见 [`../../../../on-device-ai.md`](../../../../on-device-ai.md)。
**尚未在设备上验证**（2026-09-24）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `GenAiDownload.new` | 构造函数（`GenAiDownload`） | B | 描述下载进度。 |
| `GenAiDownload.fraction` | getter（`GenAiDownload`） | B | 返回完成比例；总数未知时为 null。 |
| `_AiJob.attempt` | 方法（`_AiJob`） | B | 带超时地运行一次任务体。 |
| `_AiJob.succeed` | 方法（`_AiJob`） | B | 以一个值结算 completer。 |
| `_AiJob.failWith` | 方法（`_AiJob`） | B | 以一个错误结算 completer。 |
| `_AiJob.fail` | 方法（`_AiJob`） | B | 不运行就以一个失败结算 completer。 |
| `OnDeviceAiService.new` | 构造函数（`OnDeviceAiService`） | B | 用可注入的后端和时钟创建服务；在 `setEnabled` 之前保持关闭。 |
| `OnDeviceAiService.setInstanceForTest` | 静态方法（`OnDeviceAiService`） | B | 为测试替换单例。 |
| `OnDeviceAiService.canGenerate` | getter（`OnDeviceAiService`） | B | 根据上次的状态报告模型此刻能否生成。 |
| [`OnDeviceAiService.setEnabled`](#ondeviceaiservice-setenabled) | 方法（`OnDeviceAiService`） | A | 开启或关闭端侧 AI。 |
| `OnDeviceAiService.setPreferFast` | 方法（`OnDeviceAiService`） | B | 选择较大或较快的模型；开启时重新探测。 |
| [`OnDeviceAiService.refreshStatus`](#ondeviceaiservice-refreshstatus) | 方法（`OnDeviceAiService`） | A | 询问设备模型能做什么。 |
| [`OnDeviceAiService.download`](#ondeviceaiservice-download) | 方法（`OnDeviceAiService`） | A | 请系统获取模型（Android）。 |
| [`OnDeviceAiService.generate`](#ondeviceaiservice-generate) | 方法（`OnDeviceAiService`） | A | 通过队列生成一个回答。 |
| `OnDeviceAiService.choose` | 方法（`OnDeviceAiService`） | B | 通过队列让模型从固定列表中选择（默认后台优先级）。 |
| `OnDeviceAiService.prewarm` | 方法（`OnDeviceAiService`） | B | 在一批请求之前预先加载模型；关闭时什么也不做。 |
| [`OnDeviceAiService.cancelBackground`](#ondeviceaiservice-cancelbackground) | 方法（`OnDeviceAiService`） | A | 停止正在运行的请求并丢弃排队的后台任务。 |
| [`OnDeviceAiService.start`](#ondeviceaiservice-start) | 方法（`OnDeviceAiService`） | A | 开始跟随应用生命周期。 |
| `OnDeviceAiService.handleLifecycle` | 方法（`OnDeviceAiService`） | B | 跟随应用生命周期：未 resumed 时暂停，resumed 时推进队列。 |
| [`OnDeviceAiService._enqueue`](#ondeviceaiservice-_enqueue) | 方法（`OnDeviceAiService`） | A | 把一个请求排入队列。 |
| [`OnDeviceAiService._pump`](#ondeviceaiservice-_pump) | 方法（`OnDeviceAiService`） | A | 运行下一个符合条件的任务。 |
| [`OnDeviceAiService._pace`](#ondeviceaiservice-_pace) | 方法（`OnDeviceAiService`） | A | 在任务结束后调整节奏。 |
| `OnDeviceAiService._failQueued` | 方法（`OnDeviceAiService`） | B | 让排队的任务失败，可选只针对后台任务。 |
| `OnDeviceAiService.dispose` | 方法（`OnDeviceAiService`） | B | 释放恢复计时器和生命周期监听器。 |

`AiPriority` 枚举（`interactive`、`background`）、常量 `timeout`、`maxBackoff` 与 `initialBackoff`、
`instance`、普通状态 getter（`enabled`、`preferFast`、`report`、`coreInfo`、`downloadProgress`、`downloading`、
`busy`、`pausedUntil`、`quotaReachedToday`）以及顶层 `onDeviceAiServiceProvider`——一个包在单例外面的普通
`Provider`，因此重建的 `ProviderScope` 永远不会 dispose 它——都没有 `/// Purpose:` 注释，不作为行。

## 文档

### `Future<void> setEnabled(bool value)` <a id="ondeviceaiservice-setenabled"></a>
- **种类：** `OnDeviceAiService` 的方法
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 200 行）
- **用途：** 开启或关闭端侧 AI。
- **输入：** `value`。
- **返回：** `Future<void>`。
- **副作用：** 开启：刷新状态。关闭：让所有排队任务以 `unavailable` 失败，把报告重置为 `unsupported`，
  忘掉核心信息，并取消正在运行的请求。通知监听者。
- **算法：** 值未变时无操作。否则设置标志并通知；开启时 await `refreshStatus()`；关闭时记下是否有任务在运行，
  让队列失败，清除状态，仅在有任务运行时调用 `backend.cancel()`，然后再次通知。
- **用法：** `AppSettingsNotifier._loadPersisted` 和 `AppSettingsNotifier.setOnDeviceAiEnabled`。
- **备注：** 持久化该选择是 `AppSettingsNotifier` 的职责。关闭过程中唯一的后端调用是 `cancel`，而且只在有
  请求进行中时才调用。

### `Future<void> refreshStatus({String? localeTag})` <a id="ondeviceaiservice-refreshstatus"></a>
- **种类：** `OnDeviceAiService` 的方法
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 237 行）
- **用途：** 询问设备模型能做什么。
- **输入：** `localeTag` —— 应用的语言区域，用于 Apple 的 `supportsLocale` 报告。
- **返回：** `Future<void>`。
- **副作用：** 一次强制的 `statusReport` 探测和一次 `coreInfo` 调用；通知监听者。
- **算法：** 关闭时直接返回。在受支持平台之外，设为 `unsupported` 并通知。否则保存
  `statusReport(force: true, preferFast: ...)` 和 `coreInfo(localeTag: ...)` 的结果。
- **用法：** `setEnabled(true)`、开启期间的 `setPreferFast`、打开设置时的 `AiSettingsTiles.initState`，以及
  「重新检查」按钮。
- **备注：** 开关关闭时什么也不做——这是那道门在状态方面的一半。

### `Future<bool> download()` <a id="ondeviceaiservice-download"></a>
- **种类：** `OnDeviceAiService` 的方法
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 255 行）
- **用途：** 请系统获取模型（Android）。
- **输入：** 无。
- **返回：** `Future<bool>` —— 之后模型是否可用。
- **副作用：** AICore 下载模型；字节到达时 `downloadProgress` 随之更新；通知监听者。
- **算法：**
  1. 关闭时、有请求在运行时或已有下载在运行时拒绝（返回 false）。
  2. 设置 `downloading` 和零进度，然后调用 `backend.download`；某次回调没有报告总数时保留上次已知的总数。
  3. 吞掉 `GenAiException`；在 `finally` 中清除进度。
  4. 重新读取状态，并返回它是否为 `available`。
- **用法：** `AiSettingsTiles` 中的「下载」按钮。
- **备注：** 只从该按钮启动，从不替用户自动发起。

### `Future<String> generate({required String instructions, required String prompt, int maxOutputTokens = 256, AiPriority priority = AiPriority.interactive})` <a id="ondeviceaiservice-generate"></a>
- **种类：** `OnDeviceAiService` 的方法
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 286 行）
- **用途：** 通过队列生成一个回答。
- **输入：** `instructions`、`prompt`、`maxOutputTokens`、`priority`（默认交互优先级）。
- **返回：** `Future<String>`；失败时抛出 `GenAiException`。
- **副作用：** 轮到它时在设备上运行模型。
- **算法：** 用 [`_enqueue`](#ondeviceaiservice-_enqueue) 包装 `backend.generate`。
- **用法：** `master` 上尚无调用方；计划中的调用方是 M5 的推荐理由。
- **备注：** 开关关闭时立即以 `unavailable` 拒绝。`choose` 形态相同，默认后台优先级。

### `Future<void> cancelBackground()` <a id="ondeviceaiservice-cancelbackground"></a>
- **种类：** `OnDeviceAiService` 的方法
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 336 行）
- **用途：** 停止正在运行的请求并丢弃排队的后台任务。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 让排队的后台任务以 `cancelled` 失败；有请求在运行且开关开启时调用 `backend.cancel()`。
- **算法：** 按原顺序保留交互任务，让其余任务失败并丢弃，然后取消正在运行的请求。
- **用法：** `master` 上尚无调用方；预期用于用户停止的批量处理。
- **备注：** 已排队的交互请求仍留在队列中。正在运行的请求无论优先级都会被取消。

### `void start()` <a id="ondeviceaiservice-start"></a>
- **种类：** `OnDeviceAiService` 的方法
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 355 行）
- **用途：** 开始跟随应用生命周期。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 注册（仅一次）一个 `AppLifecycleListener`，其 `onStateChange` 为 `handleLifecycle`。
- **算法：** `_lifecycle ??= AppLifecycleListener(onStateChange: handleLifecycle)`。
- **用法：** `main`，在 `AutoSyncService.instance.start()` 之后。
- **备注：** 不调用后端的任何东西；是否运行仍由开关决定。`handleLifecycle` 的源码注释仍写着它由 `app.dart`
  调用；实际调用它的是这里注册的监听器。

### `Future<T> _enqueue<T>(AiPriority priority, Future<T> Function(GenAiBackend backend) body)` <a id="ondeviceaiservice-_enqueue"></a>
- **种类：** `OnDeviceAiService` 的方法（私有）
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 375 行）
- **用途：** 把一个请求排入队列。
- **输入：** `priority`、`body` —— 要进行的后端调用。
- **返回：** `Future<T>` —— 该任务 completer 的 future。
- **副作用：** 加入一个任务，并在微任务中安排 `_pump`。
- **算法：**
  1. 关闭时返回 `Future.error(GenAiException(unavailable))`。
  2. 当天配额停止之后的后台请求以 `quota` 失败。
  3. 交互任务排在第一个后台任务之前、更早的交互任务之后；后台任务排到末尾。
- **用法：** `generate` 和 `choose`。
- **备注：** 无。

### `Future<void> _pump()` <a id="ondeviceaiservice-_pump"></a>
- **种类：** `OnDeviceAiService` 的方法（私有）
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 412 行）
- **用途：** 运行下一个符合条件的任务。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 一次至多运行一个任务；重新检查状态；通知监听者；可能设置恢复计时器；再次推进自身。
- **算法：**
  1. 有任务在运行、队列为空、开关关闭或应用未 resumed 时返回。
  2. 队首是后台任务时：当天配额停止之后，让所有后台任务以 `quota` 失败；忙碌退避生效期间，用计时器等待。
  3. 出队，设置 `busy`，重新读取 `statusReport(preferFast: ...)`。如果开关已关闭或模型不是 `available`，
     让任务以 `unavailable` 失败。
  4. 否则在 45 秒超时内运行 `attempt`，应用 `_pace`，再结算任务——这样看到失败的调用方也能看到它对队列的影响。
  5. 清除 `busy`，通知，再次推进。
- **用法：** `_enqueue`、resumed 时的 `handleLifecycle`、恢复计时器，以及它自身。
- **备注：** 每次使用前的状态检查就是策略第 3 条：系统可能在两次请求之间移除模型。

### `void _pace(GenAiFailure? failure)` <a id="ondeviceaiservice-_pace"></a>
- **种类：** `OnDeviceAiService` 的方法（私有）
- **来源：** `lib/features/ai/services/on_device_ai_service.dart`（约第 461 行）
- **用途：** 在任务结束后调整节奏。
- **输入：** `failure` —— 成功时为 null。
- **返回：** 无。
- **副作用：** 设置忙碌退避、配额日期或未 resumed 标志。
- **算法：** `busy` → 暂停到当前时间加当前退避，然后把退避翻倍，最长 5 分钟；`quota` → 记下今天；
  `background` → 在下一次生命周期变化之前把应用视为未 resumed；成功 → 把退避重置为 5 秒并清除暂停；
  其他失败不做改变。
- **用法：** `_pump`。
- **备注：** 忙碌暂停和配额停止只影响后台任务；交互任务照常运行。
