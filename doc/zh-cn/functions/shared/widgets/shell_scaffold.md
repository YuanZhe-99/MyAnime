# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` 是由 `router.dart` 的 `ShellRoute` 渲染的常驻外壳控件——它把当前标签页（`child`）包进一个
`Scaffold`，其导航要么是底部的 `NavigationBar`，要么是侧边的 `NavigationRail`，服务于主标签页：首页、管理、
统计与设置，开启假名标签时在统计与设置之间多出假名。它是一个 `ConsumerWidget`，以便监听这项偏好。该控件所处的
路由表见 [../../../architecture.md](../../../architecture.md#app-shell) 与
[../../app/router.md](../../app/router.md)，而在两者之间做选择的规则见
[../../../adaptive-layout.md](../../../adaptive-layout.md)。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| `ShellScaffold.new` | 构造函数（`ShellScaffold`） | B | 创建一个 `ShellScaffold` 实例。 |
| [`ShellScaffold._currentIndex`](#shellscaffold_currentindex) | 方法（`ShellScaffold`） | A | 判定当前路由对应哪一个导航目的地被选中。 |
| [`ShellScaffold._destinations`](#shellscaffold_destinations) | 方法（`ShellScaffold`） | A | 把外壳当前可见的目的地连同路径与图标一次性描述清楚。 |
| [`ShellScaffold.build`](#shellscaffold_build) | 方法（`ShellScaffold`，控件构建） | A | 围绕 `child` 构建带侧边导航栏或底栏的 `Scaffold`。 |
| `_ShellDestination.new` | 构造函数（`_ShellDestination`） | B | 创建一个 `_ShellDestination` 实例。 |

## 文档

### `int _currentIndex(BuildContext context, List<_ShellDestination> destinations)` <a id="shellscaffold_currentindex"></a>
- **种类：** `ShellScaffold` 的方法
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（约第 27 行）
- **用途：** 把当前 `go_router` 位置映射到匹配的目的地下标。
- **输入：** `context`——用于读取 `GoRouterState.of(context).uri.path`；`destinations`——出自
  [`_destinations`](#shellscaffold_destinations) 的可见目的地。
- **返回：** `int`——`destinations`（因而也是当前所显示的那个导航控件）中路径是当前位置前缀的那一项的下标；
  都不匹配时为 `0`（首页）。
- **副作用：** 无。
- **算法：**
  1. 从 `GoRouterState.of(context).uri.path` 读取当前路径。
  2. 按顺序遍历 `destinations`，返回第一个使当前路径以 `destinations[i].path` 开头的下标 `i`。
  3. 若都不匹配，返回 `0`。
- **用法：**
  ```dart
  final index = _currentIndex(context, destinations);
  ```
  （出自同一文件的 `ShellScaffold.build`，供给两个导航控件中正在构建的那一个）
- **备注：** 使用 `startsWith` 而非精确相等，因此在外壳内渲染的嵌套/非标签路由（若日后在某个标签路径下新增）
  仍会高亮对应的标签。由于 `router.dart` 目前把动画详情/编辑、元数据更新审阅与查重作为 `ShellRoute` 之外的
  顶层路由推入，这套匹配今天只需要区分各标签的前缀。下标每次构建都从位置推导，从不记忆，因此隐藏假名标签不会
  留下过时的下标——设置从下标 4 移到下标 3，仍按其路径被找到。

### `List<_ShellDestination> _destinations(AppLocalizations l10n, {required bool kanaTabEnabled})` <a id="shellscaffold_destinations"></a>
- **种类：** `ShellScaffold` 的方法
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（约第 48 行）
- **用途：** 把外壳当前可见的目的地连同路径与图标一次性描述清楚。
- **输入：** `l10n`——用于各个 `nav*` 标签；`kanaTabEnabled`——`AppSettings.kanaTabEnabled`。
- **返回：** `List<_ShellDestination>`——`/home`、`/manage`、`/stats`，`kanaTabEnabled` 时再加 `/kana`，然后是
  `/settings`。
- **副作用：** 无。
- **算法：** 返回由四条或五条记录组成的列表，每条包含一个路由路径、一个轮廓图标、一个选中态实心图标与一个本地化
  标签。
- **用法：**
  ```dart
  for (final d in destinations)
    NavigationRailDestination(
      icon: Icon(d.icon),
      selectedIcon: Icon(d.selectedIcon),
      label: Text(d.label),
    ),
  ```
  （出自同一文件的 `ShellScaffold.build`）
- **备注：** 随侧边导航栏于 1.5.4 加入；自 1.6.0 起每条记录还携带自己的路由路径，取代了并行的 `_routes` 列表。
  底栏与侧边导航栏都从这一份列表读取，因此一个目的地不可能只出现在其中之一，不可能在两者中顺序不同，也不可能在
  假名被滤掉后指向错误的路由——那会悄悄弄坏 `_currentIndex` 与 `select`，因为两者都按位置索引。私有的
  `_ShellDestination` 记录本身没有任何逻辑，不作为独立行编入索引。

### `Widget build(BuildContext context, WidgetRef ref)` <a id="shellscaffold_build"></a>
- **种类：** `ShellScaffold` 的方法（控件构建）
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（约第 93 行）
- **用途：** 围绕 `child` 构建带侧边导航栏或底栏的 `Scaffold`。
- **输入：** `context`、`ref`。
- **返回：** 外壳的控件树。
- **副作用：** 点击目的地时经由 `context.go(destinations[i].path)` 导航。
- **算法：**
  1. 监听 `appSettingsProvider.select((s) => s.kanaTabEnabled)`，然后构建目的地列表与选中下标。
  2. 当 `useNavigationRail(MediaQuery.sizeOf(context).width)` 为假时，返回原本那个带底部 `NavigationBar` 的
     `Scaffold`。
  3. 否则返回一个 `Scaffold`，其 body 是由侧边导航栏、`VerticalDivider(width: 1)` 与
     `Expanded(child: child)` 组成的 `Row`。
- **用法：**
  ```dart
  ShellRoute(
    builder: (context, state, child) => ShellScaffold(child: child),
    ...
  ```
  （出自 `lib/app/router.dart` 中的 `appRouter`）
- **备注：** 显示哪一种导航是 `useNavigationRail` **只看宽度**的判定，刻意不是全应用的拆分规则——见
  [../utils/adaptive_layout.md](../utils/adaptive_layout.md#usenavigationrail)。这里没有任何状态，因此折叠
  设备会在下一帧把两者互换，不发生路由变化，也没有需要保存与恢复的东西。在设置中开启或关闭假名标签，外壳会在
  下一帧以五个或四个目的地重建。

  侧边导航栏设置 `groupAlignment: 0` 以将其目的地居中，而非采用默认的顶部对齐：顶部对齐是为了让导航栏坐落在
  一个前导菜单按钮或 FAB 之下，而这里两者都没有，于是目的地挤在一条 704 dp 高的导航栏顶端会让它整个下半部分
  空着。

  它还被包进了标准的 `LayoutBuilder` → `SingleChildScrollView` → `ConstrainedBox(minHeight:)` →
  `IntrinsicHeight` 组合。五个（最多也就这么多）带标签的目的地约合 370 逻辑像素，这在今天任何宽到足以获得侧边
  导航栏的窗口里都放得下——但侧边导航栏可能出现在 compact 高度下（手机横持只有 412），因此允许它滚动而不是溢出。
