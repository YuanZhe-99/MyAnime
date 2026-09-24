# lib/features/ai/widgets/ai_settings_tiles.dart

`AiSettingsTiles` 于 1.6.0（M3）新增，构建「分类与推荐」设置分区里的端侧 AI 行：「使用端侧 AI」开关、
带操作的模型状态行、「使用更快的模型」（Android，仅当两种尺寸都有提供时）、关于模型归属的说明，以及一个折叠的
「技术详情」。在 Windows、Linux 和 Web 上它什么也不渲染。自 1.6.0（M4）起，`settings_page.dart` 把它放在功能开关之后；自 M5 起传入
`featuresOn: autoCategoriesEnabled || recommendationsEnabled`，因此只有在自动分类或推荐开启时才能打开 AI 开关，关闭其中最后一个开着的功能也会关闭 AI。见 [`../services/on_device_ai_service.md`](../services/on_device_ai_service.md)
和 [`../../../../on-device-ai.md`](../../../../on-device-ai.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiSettingsTiles.new` | 构造函数（`AiSettingsTiles`） | B | 创建 AI 设置行；`featuresOn` 表示是否有使用模型的功能处于开启状态。 |
| `AiSettingsTiles.createState` | 方法（`AiSettingsTiles`） | B | 创建状态对象。 |
| [`_AiSettingsTilesState.initState`](#_aisettingstilesstate-initstate) | 方法（`_AiSettingsTilesState`） | A | 打开设置时刷新模型状态。 |
| `_AiSettingsTilesState._localeTag` | 方法（`_AiSettingsTilesState`） | B | 以 `zh_TW` 这样的标签返回应用当前的语言区域。 |
| `_AiSettingsTilesState._statusLabel` | 方法（`_AiSettingsTilesState`） | B | 用 `aiStatus*` 字符串表述模型状态。 |
| [`_AiSettingsTilesState.build`](#_aisettingstilesstate-build) | 方法（`_AiSettingsTilesState`） | A | 构建这些行。 |

`featuresOn` 字段没有 `/// Purpose:` 注释，不作为行。

## 文档

### `void initState()` <a id="_aisettingstilesstate-initstate"></a>
- **种类：** `_AiSettingsTilesState` 的方法（Flutter 生命周期覆写）
- **来源：** `lib/features/ai/widgets/ai_settings_tiles.dart`（约第 46 行）
- **用途：** 打开设置时刷新模型状态。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 第一帧之后进行一次强制状态探测——仅在开关开启时。
- **算法：** 在帧后回调中，若仍 mounted 且 `OnDeviceAiService.enabled`，调用
  `refreshStatus(localeTag: _localeTag())`。
- **用法：** 这些行首次插入时由 Flutter 调用。
- **备注：** 需要帧后回调，因为 `_localeTag` 读取 `Localizations`。

### `Widget build(BuildContext context)` <a id="_aisettingstilesstate-build"></a>
- **种类：** `_AiSettingsTilesState` 的方法
- **来源：** `lib/features/ai/widgets/ai_settings_tiles.dart`（约第 90 行）
- **用途：** 构建这些行。
- **输入：** `context`。
- **返回：** 一个由各行组成的 `Column`；`platformMayHaveOnDeviceModel` 为 false 时返回 `SizedBox.shrink()`。
- **副作用：** 无；按钮调用 `OnDeviceAiService` 和 `AppSettingsNotifier`。
- **算法：** 在监听该服务的 `ListenableBuilder` 内：
  1. 开关，绑定到 `AppSettings.onDeviceAiEnabled` 和 `setOnDeviceAiEnabled`。当 `featuresOn` 为 false 且开关
     关闭时它被禁用，副标题追加 `aiNeedsFeature`。开启状态下它保持可用，因此总能关掉。
  2. 仅在开启时：状态行。`notEnabled` 追加「开启 Apple Intelligence」一行；下载进行中时显示已下载的 MB。
     它的操作在 Android 上的 `downloadable` 时为「下载」，在 `unavailable`、`unreachable`、`notEnabled`、
     `unknown` 和 `downloading` 时为「重新检查」。
  3. 「使用更快的模型」，仅在 Android 上且 `report.hasSizeChoice` 时显示。
  4. 说明：在 Android 上说明谁下载模型、为何不能在这里删除；在 Apple 上说明由系统管理。
  5. 一个折叠的「技术详情」，内容为可选中的文本：状态名和代码、detail、变体、已提供和被拒绝的变体、模型名、
     token 上限、AICore 版本（或「未安装」）、SDK、设备、兼容性、系统版本和语言区域支持，各项只在已知时显示。
- **用法：** `settings_page.dart` 的「分类与推荐」分区（`AiSettingsTiles(featuresOn: settings.autoCategoriesEnabled || settings.recommendationsEnabled)`）；
  `test/ai_settings_tiles_ui_test.dart`（用 `debugDefaultTargetPlatformOverride` 按平台测试）。
- **备注：** `unsupported` 表述为需要支持 Apple Intelligence 的 iOS 26 或 macOS 26。这正是 Apple 插件在
  26 之前的 iOS 和 macOS 上报告的状态。
