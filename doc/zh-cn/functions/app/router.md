# lib/app/router.dart

定义 `appRouter`，应用唯一的 `go_router` `GoRouter` 实例：一个包住五个底部导航标签（主页、管理、统计、假名、设置）的 `ShellRoute`，外加动画详情/编辑和重复检查页的独立路由。完整路由表和 `ShellScaffold`（`lib/shared/widgets/shell_scaffold.dart`）如何在 `child` 周围渲染底部导航栏见 [../../architecture.md](../../architecture.md#app-shell)。

## 声明

本文件包含一个顶层声明，`final appRouter = GoRouter(...)`（第 13 行）。它是配置值（从路由列表构建的 `GoRouter` 实例），不是函数、方法、构造函数、getter 或 setter，因此落在 `AGENTS.md` 描述的仓库函数解释层约定之外——与此一致，源码中它没有 `/// Purpose:` 注释（`grep -c 'Purpose:' lib/app/router.dart` 报告 0）。因此本文件的声明表中没有可列的行。

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|

（无行——按函数解释层约定没有声明符合；见上文。）

## 文档

无——本文件没有 Tier A 声明。仅供参考，路由表本身为：

| 路径 | 页面 | 备注 |
|---|---|---|
| `/home` | `HomePage` | 外壳标签 |
| `/manage` | `ManagementPage` | 外壳标签 |
| `/stats` | `StatisticsPage` | 外壳标签 |
| `/kana` | `KanaPage` | 外壳标签 |
| `/settings` | `SettingsPage` | 外壳标签 |
| `/anime/detail/:id` | `AnimeDetailPage` | 压栈在外壳之上；`id` 必填 |
| `/anime/edit` | `AnimeEditPage` | 创建流程（无 `animeId`） |
| `/anime/edit/:id` | `AnimeEditPage` | 编辑流程（`animeId` 来自路径） |
| `/duplicate-check` | `DuplicateCheckPage` | 压栈在外壳之上 |

外壳路由包在 `ShellRoute` 中，其 `builder` 渲染 `ShellScaffold(child: child)`（见 [`../shared/widgets/shell_scaffold.md`](../shared/widgets/shell_scaffold.md)），后者提供常驻底部 `NavigationBar`。
