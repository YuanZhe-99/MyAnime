# lib/features/anime/services/manage_grouping.dart

管理页的按系列查看（1.6.2）：管理页会记住的两个视图状态枚举、它们的解析函数，以及
把片库变成行的纯函数。见
[`../views/management_page.md`](../views/management_page.md) 和
[`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md#management-management_pagedart)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `parseManageViewMode` | 顶层函数 | B | 解析 `manageViewMode`；除 `series` 以外的值都是按季度查看。 |
| `parseManageSeriesSort` | 顶层函数 | B | 解析 `manageSeriesSort`；未知值视为 `latest`。 |
| `ManageSeriesGroup.new` | 构造函数（`ManageSeriesGroup`） | B | 创建一行：键、标签、成员，以及可选的系列。 |
| `ManageSeriesGroup.isGroup` | getter（`ManageSeriesGroup`） | B | 该行是否可展开（两个或更多成员）。 |
| [`groupForSeriesView`](#groupforseriesview) | 顶层函数 | A | 为系列视图把片库分组。 |

这些枚举没有 `/// Purpose:` 注释：

| 枚举 | 取值 | 存储为 |
|---|---|---|
| `ManageViewMode` | `quarter`（默认）、`series` | `manageViewMode`，只在为 `series` 时写入 |
| `ManageSeriesSort` | `latest`（默认）、`title`、`modified` | `manageSeriesSort`，只在不为 `latest` 时写入 |

## 文档

### `List<ManageSeriesGroup> groupForSeriesView(List<Anime> all, {required bool Function(Anime) keep, required ManageSeriesSort sort})` <a id="groupforseriesview"></a>
- **种类：** 顶层函数
- **来源：** `lib/features/anime/services/manage_grouping.dart`（约第 92 行）
- **用途：** 把片库变成系列视图的行。
- **输入：** `all` — 整个片库；`keep` — 页面的存档与分类筛选；`sort`。
- **返回：** `List<ManageSeriesGroup>` — 每条保留的记录恰好出现一次。
- **副作用：** 无。
- **算法：**
  1. `SeriesIndex.build(all)` — 基于**整个**片库，因此筛选永远不会改变哪些记录
     属于同一系列。
  2. 对每条尚未放置的保留记录：有两个或更多成员的系列贡献其中被保留的成员，按系列顺序排列。
     两个或更多 → 一个分组，键为系列键，标签为第一个成员标题经 `stripSeasonMarkers` 处理后的结果
     （若处理后为空则用标题本身）。只有一个 → 单独一行，键为 `id:<id>`，标签为其标题。不属于任何
     系列的记录、独立记录以及只有一个成员的手动关联的系列也都是单独的行。
  3. 排序：`latest` — 成员中最新的 `firstAirDate` 靠前，没有日期的行排在最后；
     `title` — 按标签，不区分大小写；`modified` — 成员中最新的 `modifiedAt` 靠前。
     相同时按标签，再按第一个成员的 id 排序。
- **用法：** `_ManagementPageState._seriesGroups`。
- **备注：** 对同一片库结果确定。测试见 `test/manage_grouping_test.dart`。
