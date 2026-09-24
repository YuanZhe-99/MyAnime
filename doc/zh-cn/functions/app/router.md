# lib/app/router.dart

定义 `appRouter`，应用唯一的 `go_router` `GoRouter` 实例：一个包住主导航标签（主页、管理、统计、设置，以及开启假名标签时的假名）的 `ShellRoute`，外加动画详情/编辑、元数据更新审阅和重复检查页的独立路由。完整路由表和 `ShellScaffold`（`lib/shared/widgets/shell_scaffold.dart`）如何在 `child` 周围渲染导航见 [../../architecture.md](../../architecture.md#app-shell)。

## 声明

`final appRouter = GoRouter(...)` 是配置值（从路由列表构建的 `GoRouter` 实例），不是函数、方法、构造函数、getter 或 setter，因此落在 `AGENTS.md` 描述的仓库函数解释层约定之外，下表中没有它的行。本文件唯一的函数是 1.6.0 加入的 `kanaRouteRedirect`。

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`kanaRouteRedirect`](#kanarouteredirect) | 顶层函数 | A | 假名标签隐藏时让 `/kana` 无法到达。 |

## 文档

### `String? kanaRouteRedirect(BuildContext context, GoRouterState state)` <a id="kanarouteredirect"></a>
- **种类：** 顶层函数
- **来源：** `lib/app/router.dart`（约第 23 行）
- **用途：** 假名标签隐藏时让 `/kana` 无法到达。
- **输入：** `context`——必须位于应用的 `ProviderScope` 之下；`state`（未使用）。
- **返回：** `String?`——`null` 表示放行该路由，否则为 `'/home'`。
- **副作用：** 无；通过 `ProviderScope.containerOf(context, listen: false)` 读取 `appSettingsProvider`。
- **算法：** `AppSettings.kanaTabEnabled` 为真时返回 `null`，否则返回 `'/home'`。
- **用法：**
  ```dart
  GoRoute(
    path: '/kana',
    redirect: kanaRouteRedirect,
    builder: (context, state) => const KanaPage(),
  ),
  ```
  （出自同一文件的 `appRouter`；`test/shell_nav_ui_test.dart` 也在其桩路由上使用它）
- **备注：** 自 1.6.0 起假名标签默认关闭（见 [../../features/kana-reference.md](../../features/kana-reference.md)）。设置是异步加载的，因此最初几帧看到的是 `kanaTabEnabled == false`；这不会弹回任何真实访问，因为初始位置是 `/home`，而进入 `/kana` 的唯一途径就是该标签本身。

仅供参考，路由表为：

| 路径 | 页面 | 备注 |
|---|---|---|
| `/home` | `HomePage` | 外壳标签 |
| `/manage` | `ManagementPage` | 外壳标签 |
| `/stats` | `StatisticsPage` | 外壳标签 |
| `/kana` | `KanaPage` | 外壳标签，仅在假名标签开启时；否则重定向到 `/home` |
| `/settings` | `SettingsPage` | 外壳标签 |
| `/anime/detail/:id` | `AnimeDetailPage` | 压栈在外壳之上；`id` 必填 |
| `/anime/edit` | `AnimeEditPage` | 创建流程（无 `animeId`） |
| `/anime/edit/:id` | `AnimeEditPage` | 编辑流程（`animeId` 来自路径）；`extra: true` 会在加载后打开在线搜索 |
| `/metadata-updates` | `MetadataUpdatesPage` | 压栈在外壳之上；`extra` 可携带当前页的动画 id |
| `/duplicate-check` | `DuplicateCheckPage` | 压栈在外壳之上 |

外壳路由包在 `ShellRoute` 中，其 `builder` 渲染 `ShellScaffold(child: child)`（见 [`../shared/widgets/shell_scaffold.md`](../shared/widgets/shell_scaffold.md)），后者提供常驻的底栏或侧边导航栏。
