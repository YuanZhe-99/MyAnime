# 桌面小组件

两个「接下来」小组件把首页的两个问题放到主屏上——*今天播出了什么*，以及*还有什么待看*——无需打开应用。
它们只存在于 Android 和 iOS；桌面构建没有小组件界面。

| 尺寸 | Android | iOS |
|---|---|---|
| 2×2 | `UpNextWidgetProvider`（主屏，2 × 2 格，可调整大小） | `systemSmall` 主屏小组件 |
| 2×1 横条 | `UpNextStripWidgetProvider`（主屏，2 × 1 格，可调整大小） | `accessoryRectangular` 锁屏 / 待机显示（StandBy）小组件（iOS 16+） |

iOS 没有 2×1 的主屏尺寸，因此紧凑横条对应矩形锁屏小组件，两者形状和信息密度相同。

## 显示什么

计数完全沿用首页的定义（见
[`home-management-statistics.md`](home-management-statistics.md)）：一集的状态为未看、且播出时间
（日本时间，空播出时间 = 23:59 JST）已过时，即为**待看**。

**2×2**

- 顶部：应用标志和名称，以及一个显示**今日更新数**的胶囊——播出日期为今天的每一集，无论是否已看。
- 一个大号的**待看集数**，并附上对应的番剧部数。
- 最多两行**观看队列**：每部动画取其最早的已播出未看剧集，按播出时间从早到晚排列——与首页*未看*列表的行相同。
  Android 只在小组件高度至少 150 dp 时显示第二行。
- 没有待看内容时，计数变为*已全部看完*，该行显示下一集即将播出的剧集及其时间（今天：`HH:mm`；
  之后：星期 + `HH:mm`）。

**2×1 横条**

- 一个显示待看计数的色调方块（为零时显示对勾）。
- 队列中的第一个标题，以及其集数和今日更新数；全部看完时，显示下一集即将播出的剧集或*今日无更新*。

点击任一小组件都会打开应用。

「今天」使用首页日历的时间基准：默认日本时间；选择**设置 › 首页日历时间 › 本地时间**时使用设备的本地日期。
显示的播出时间使用同一时区。

## 设计

两个平台各自采用当前的系统风格，而不是共用一套绘制：

- **Android** —— 采用 Material 3 形状的 RemoteViews 布局：启动器自身的小组件圆角半径
  （`system_app_widget_background_radius`），以及 Android 12+ 上取自壁纸的 **Material You** 颜色
  （`system_accent1/2`、`system_neutral1/2`）；Android 8–11 回退为应用种子色 `#673AB7` 的 Material 3 色调。
  浅色和深色配色跟随系统主题。小组件选择器中的预览直接使用布局本身（`previewLayout`），
  `targetCellWidth/Height` 给出 Android 12+ 的默认格数。
- **iOS** —— SwiftUI WidgetKit 视图：圆体设计的计数、SF Symbol 标志、叠在系统背景上的柔和品牌渐变、
  iOS 17+ 上的 `containerBackground`，以及 `widgetAccentable` 部件，使着色主屏和锁屏都能正确渲染。

## 数据流

小组件从不读取资料库。应用计算一份小快照交给原生端，由原生端保存并重绘：

1. `HomeWidgetService.refresh()`（`lib/shared/services/home_widget_service.dart`）加载
   `anime_data.json`、日历时间基准和界面语言，并构建快照。
2. 它通过 `com.yuanzhe.my_anime/home_widget` method channel（`update`）发送 JSON。
3. Android（`MainActivity` → `WidgetStore.push`）把它写入私有的 `MyAnimeWidget` shared
   preferences，并重绘每个已放置的实例。iOS（`AppDelegate`）把它写入
   `group.com.yuanzhe.myAnime` App Group 的 `UserDefaults`，并调用
   `WidgetCenter.reloadAllTimelines()`。

`HomeWidgetService.notifyDataChanged()` 在以下事件中最后一次发生后 2 秒安排一次刷新：

- 任何资料库保存（`AnimeStorage._writeData`），
- 同步下载或备份恢复（`AutoSyncService` 的本地数据变更回调），
- 应用恢复到前台，
- 界面语言或日历时间基准变更。

### 应用关闭时保持正确

快照携带即将播出的剧集，而不只是总数，因此原生端可以在 8 天前瞻窗口内随时重新计数：

```text
toWatch = airedUnwatched + count(entries where !w and generatedAt < at <= now)
queue   = per anime, the earliest entry with !w and at <= now, by air time
today   = entries whose air date (in the snapshot's zone) is today
nextUp  = the earliest entry with !w and at > now
```

- **Android** 每次重绘都重新计算；系统至少每 30 分钟重绘一次（`updatePeriodMillis`）。
- **iOS** 构建一条时间线，在未来 24 小时内的每个播出时间以及下一个午夜各放一个条目，
  并在最后一个条目之后（至少一小时后）请求新的时间线。

### 快照格式（第 1 版）

```json
{
  "v": 1,
  "generatedAt": 1769605200000,
  "timeZone": "Asia/Tokyo",
  "airedUnwatched": 2,
  "queueSize": 1,
  "episodes": [
    { "id": "…", "t": "Title", "e": 3, "at": 1768568400000, "w": false }
  ],
  "labels": {
    "appName": "MyAnime", "toWatch": "…", "today": "…", "caughtUp": "…",
    "noUpdates": "…", "next": "…", "episode": "EP {n}", "series": "{n} series"
  }
}
```

- `generatedAt`、`at` —— 纪元毫秒数（UTC 时刻）。
- `timeZone` —— JST 日历为 `Asia/Tokyo`，设备时区为空。
- `airedUnwatched` —— `generatedAt` 时刻的待看计数。
- `episodes` —— 每部动画最早的已播出未看剧集（队列条目），加上从今天开始到 8 天后的每一集；
  最多 80 个条目，队列条目在前。已看或已跳过的剧集 `w` 为 true。
- `labels` —— 小组件文案，按应用语言从 ARB 文件解析；`{n}` 由原生端替换。只有小组件选择器中的名称和描述
  放在原生资源里（Android 上为 `res/values*/widget_strings.xml`，iOS 上为 Swift 文件中的 `galleryText`）。

该格式只属于应用及其自身的小组件：仅存于设备本地，绝不同步、绝不备份、绝不分享。修改它意味着要同时提升 `v`
并更新两个原生读取端。

## 平台设置

- **Android** —— `AndroidManifest.xml` 中的两个 `<receiver>` 条目；Kotlin 代码位于
  `android/app/src/main/kotlin/com/yuanzhe/my_anime/widget/`。不需要额外的 Gradle 依赖。
- **iOS** —— `UpNextWidget` 应用扩展目标（`ios/UpNextWidget/`，部署目标 iOS 14）嵌入在 Runner 中。
  Runner 和扩展都带有 `group.com.yuanzhe.myAnime` App Group entitlement，签名构建前必须在两个 App ID 上
  都启用它。Runner（iOS 13）弱链接 WidgetKit。见
  [`../platform-notes.md`](../platform-notes.md#ios)。

## 隐私

小组件会显示动画标题，这些标题因此会出现在主屏上——对于 iOS 矩形小组件，还会出现在锁屏上。
在用户添加小组件之前不会显示任何内容，移除小组件即停止显示；快照本身从不离开设备。
