# lib/features/settings/views/home_widget_settings_page.dart

`HomeWidgetSettingsPage`（1.9.7）是设置第一层中唯一一行「桌面小组件」背后的二级页面（仅 Android 与 iOS；见
[`settings_page.md`](settings_page.md)）。窄窗口上全屏推入，宽窗口上寄宿于设置的详情栏（`_SettingsDetail.widgets`）。
该页每个小组件一个 `MyAppsSettingsSection`——*大号小组件*（`settingsWidgetLarge`）和*横条小组件*（`settingsWidgetStrip`）——
每个分区都有 `myapps_widget_ui` 的共享 `WidgetTextScaleControl`（「小组件字号」及其说明），以及该小组件的
[`HomeWidgetPreview`](../widgets/home_widget_preview.md)。大号分区绑定 `AppSettings.widgetTextScale` / `setWidgetTextScale`，
横条分区绑定 `AppSettings.widgetStripTextScale` / `setWidgetStripTextScale`（见
[`../../../shared/providers/app_settings.md`](../../../shared/providers/app_settings.md)）。1.9.7 之前，设置第一层的同一个滑块
同时缩放两个小组件。见
[`../../../../features/home-screen-widgets.md`](../../../../features/home-screen-widgets.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `HomeWidgetSettingsPage({super.key})` | 构造函数（`HomeWidgetSettingsPage`） | B | 创建小组件设置页。 |
| `createState` | 方法（组件生命周期） | B | 为此组件创建可变状态对象。 |
| [`build`](#build) | 方法（`_HomeWidgetSettingsPageState`） | A | 构建大号小组件和横条两个分区。 |

`_data` 字段没有 `/// Purpose:` 注释，不单列一行。

## 文档

### `Widget build(BuildContext context)` <a id="build"></a>
- **种类：** `_HomeWidgetSettingsPageState` 的方法
- **来源：** `lib/features/settings/views/home_widget_settings_page.dart`（约第 45 行）
- **用途：** 构建页面：一个标题为 `settingsWidgets` 的 `Scaffold`，内含大号小组件和横条两个分区。
- **输入：** `context`。
- **返回：** `Widget`——一个 `Scaffold`，其页身是由两个 `MyAppsSettingsSection` 组成的 `ListView`（底部内边距 24 dp）。
- **副作用：** 构建时无；滑块经由 `AppSettingsNotifier` 持久化各自的倍数并安排一次小组件刷新。
- **算法：** 监听 `appSettingsProvider`。局部函数 `section(title, kind, scale, onChanged)` 构建一个
  `MyAppsSettingsSection`，其中有一个 `WidgetTextScaleControl`（`settingsWidgetTextSize`、`settingsWidgetTextSizeDesc`），
  以及内边距为 `16, 4, 16, 16` 的 `HomeWidgetPreview(data: _data, kind: kind, textScale: scale)`。它以
  `HomeWidgetPreviewKind.large` 搭配 `widgetTextScale` / `setWidgetTextScale` 调用一次，再以
  `HomeWidgetPreviewKind.strip` 搭配 `widgetStripTextScale` / `setWidgetStripTextScale` 调用一次。
- **用法：** [`settings_page.md`](settings_page.md#detailpage) 中的 `_SettingsPageState._detailPage(_SettingsDetail.widgets)`。
- **备注：** `_data` 是来自 `HomeWidgetPreview.load()` 的 `late final` future，因此每次访问只读取一次片库和已放置尺寸，
  由两个预览共用；拖动滑块只重绘它自己的预览，从不重新加载片库。
