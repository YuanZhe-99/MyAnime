# 共享小组件

## 归属

MyApps-Widget v0.1.0 以相对同级 URL `../MyApps-Widget.git` 嵌入在 `packages/myapps_widget`（1.9.5）。应用依赖
`packages/myapps_widget/packages/myapps_widget`（桥接层，以及 Android 和 iOS 插件）和
`packages/myapps_widget/packages/myapps_widget_ui`（预览外壳、字号控件）；两者都会引入 `myapps_widget_core`。全新检出时，
先运行 `git submodule update --init --recursive` 再运行 `flutter pub get`。该子模块不参与应用的 `flutter analyze`，它有自己的 CI。

共享包负责外层封装格式及其容错读取端（Dart、Kotlin、Swift）、存储键、method channel
`com.yuanzhe.myapps_widget/bridge`、防抖调度器以及重绘调用。外层封装的说明见共享包自身的 `doc/en-us/envelope.md`。

MyAnime 保留：

- 门面 `HomeWidgetService`，公开成员不变：`isSupported`、`init`、`notifyDataChanged`、`refresh`、`labelsFor`、
  `buildSnapshot`、`jstToUtc`、`clampTextScale` 以及各常量。新增 `kind`（`myanime.upNext`）和 `appGroupId`。
- payload（`timeZone`、`airedUnwatched`、`queueSize`、`episodes`、`labels`）及其版本 `pv`
  （`HomeWidgetService.formatVersion`）。
- 原生渲染：`UpNextWidgetProvider` 和 `UpNextStripWidgetProvider`（继承共享的 `EnvelopeWidgetProvider`）、
  `UpNextState`、XML 布局和颜色，以及 `UpNextWidget` 扩展（`UpNextWidget.swift`）。
- 文案、`widgetTextScale` 设置项和设置页预览 `HomeWidgetPreview`。

许可页面列出了 MyApps-Widget 及其 GPL v3 源码。

## 行为

1.9.5 中用户能看到的内容没有变化：内容相同，2 秒防抖、刷新时机和字号范围都相同。改变的是传输方式：

| 1.9.5 之前 | 1.9.5 起 |
|---|---|
| `MainActivity` 和 `AppDelegate` 中的 `com.yuanzhe.my_anime/home_widget` 通道 | 由插件注册的 `com.yuanzhe.myapps_widget/bridge` |
| Android `WidgetStore` 自己重绘两个 Provider | `EnvelopeStore.requestUpdate` 按类名向两个 Provider 广播 |
| iOS `reloadAllTimelines()` | `reloadTimelines(ofKind: "MyAnimeUpNextWidget")` |
| 存于 `myanime_widget_snapshot` 的扁平快照 | 存于 `envelope.myanime.upNext`（Android）和 `myapps_widget.envelope.myanime.upNext`（iOS）的外层封装 |

在没有外层封装时，两个原生读取端都会回退读取旧的扁平快照，因此更新前放置的小组件在应用运行一次之前仍保留内容。
由更新的外层封装格式写入（`tooNew`）或无法解析的数据会绘制为空状态。

## 验证

修改门面后运行 `flutter analyze` 和 `test/home_widget_service_test.dart`；该测试还会检查 `buildSnapshot`
生成的外层封装能被共享读取端接受。共享包自身的测试在 Dart、Kotlin 和 Swift 中覆盖约定夹具。应用的 CI 构建是
Kotlin 与 Swift 接入代码的首次编译；放置小组件、以及检查从 1.9.4 更新后的回退读取，仍需要真机。
