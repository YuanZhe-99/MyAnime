# lib/shared/widgets/shell_scaffold.dart

`ShellScaffold` 是 `router.dart` 的 `ShellRoute` 渲染的常驻外壳组件——它把当前标签（`child`）包在带五个主标签（主页、管理、统计、假名、设置）底部 `NavigationBar` 的 `Scaffold` 中。此组件所在的路由表见 [../../../architecture.md](../../../architecture.md#app-shell) 和 [../../app/router.md](../../app/router.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ShellScaffold.new` | 构造函数（`ShellScaffold`） | B | 创建 `ShellScaffold` 实例。 |
| [`ShellScaffold._currentIndex`](#shellscaffold_currentindex) | 方法（`ShellScaffold`） | A | 为当前路由确定选中哪个底部导航标签。 |
| `ShellScaffold.build` | 方法（`ShellScaffold`，组件构建） | B | 在 `child` 周围构建带底部 `NavigationBar` 的 `Scaffold`。 |

## 文档

### `int _currentIndex(BuildContext context)` <a id="shellscaffold_currentindex"></a>
- **种类：** `ShellScaffold` 的方法
- **来源：** `lib/shared/widgets/shell_scaffold.dart`（约第 23 行）
- **用途：** 把当前 `go_router` 位置映射到匹配的底部导航目的地索引。
- **输入：** `context` — 用于读取 `GoRouterState.of(context).uri.path`。
- **返回：** `int` — `_routes`（因此 `NavigationBar.destinations`）中路径前缀匹配当前位置的索引；无匹配时为 `0`（主页）。
- **副作用：** 无。
- **算法：**
  1. 从 `GoRouterState.of(context).uri.path` 读取当前路径。
  2. 按顺序遍历 `_routes`（`['/home', '/manage', '/stats', '/kana', '/settings']`）；返回当前路径以 `_routes[i]` 开头的第一个索引 `i`。
  3. 没有路由匹配时返回 `0`。
- **用法：**
  ```dart
  bottomNavigationBar: NavigationBar(
    selectedIndex: _currentIndex(context),
    ...
  ```
  （来自 `ShellScaffold.build`，同一文件）
- **备注：** 用 `startsWith` 而不是精确相等，因此在外壳内渲染的嵌套/非标签路由（如果被加在标签路径下）仍会高亮对应标签。由于 `router.dart` 目前把动画详情/编辑和重复检查作为 `ShellRoute` 之外的顶层路由压栈，此匹配今天实际只需要区分五个列出的前缀。
