# 主页、管理和统计

三个主要数据浏览标签。底层模型/季度逻辑见 [`anime-tracking.md`](anime-tracking.md)，这些标签如何在 `go_router` 外壳中落位见 [`../architecture.md`](../architecture.md)。

## 主页（`home_page.dart`）

- 感知 JST 的日历，带可选的本地时间日期网格。
- 本地化/日式日历标签：日历可以显示本地化的应用语言月/星期标签，或日式 日月火水木金土 标签。
- 可配置周起始：全局周起始偏好默认周日；日式日历布局激活时，有效周起始锁定为周日，无论全局偏好如何。
- 主页日历日期网格默认日本时间，但可以切换到设备的本地时区。即使切换到本地时间，动画播出时间戳仍按日本时间计算——空播出时间被动画模型当作 23:59 JST（见 [`../data-formats.md`](../data-formats.md)）。
- 当前格式的日历按钮文本。
- 未观看的已播出剧集直接浮出在日历上。

## 管理（`management_page.dart`）

- 季浏览器。
- 全局搜索。
- 动态年/季选择器。
- 为没有 `firstAirDate`（无法季度归属——见 [`anime-tracking.md`](anime-tracking.md)）的动画准备的"其他"页。
- 创建新动画会导航到详情页，然后酌情把管理页返回到该动画的季度。

## 统计（`statistics_page.dart`）

- 季度/年/全范围。
- 摘要计数。
- 带聚焦季度/年选择的全范围可滚动趋势图；全范围趋势的季度/年粒度可选。
- 按派生状态（completed/watching/dropped/not-started）分组的可展开列表。
- 一个用于评分排名的独立**排名**视图，支持：
  - 全部/季度/年/自定义季度范围过滤器
  - 类型过滤
  - 总分或子分排序（见 [`../data-formats.md`](../data-formats.md) 中的 `AnimeRatingField`）
  - 升序/降序
  - 直接季度/年选择器
  - 封面缩略图
  - 当前过滤排名的图像导出/分享（见 [`share-and-import.md`](share-and-import.md)）
