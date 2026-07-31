# lib/app/app.dart

定义根组件 `MyAnimeApp`，它把 `MaterialApp.router` 与应用主题、语言区域、本地化委托、`go_router` 配置和 `DevicePreview` 集成包在一起。它还定义了一个小的 `ScrollBehavior` 覆盖，使桌面鼠标滚轮/触控板滚动在处处可用。这与整体应用外壳的契合（`main.dart` → `app.dart` → `router.dart`/`theme.dart`）见 [../../architecture.md](../../architecture.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_DesktopScrollBehavior.dragDevices` | getter（`_DesktopScrollBehavior`） | B | 为滚动启用触控、鼠标和触控板拖动输入。 |
| `MyAnimeApp.new` | 构造函数（`MyAnimeApp`） | B | 创建一个 `MyAnimeApp` 实例。 |
| `MyAnimeApp.build` | 方法（`MyAnimeApp`，组件构建） | B | 构建带主题/语言区域/路由器接线的根 `MaterialApp.router`。 |

<本文件中的每个声明都是 Tier B：`_DesktopScrollBehavior` 是一行 `ScrollBehavior` 覆盖，没有分支；`MyAnimeApp` 的构造函数是平凡的转发 `const` 构造函数；`build()` 是纯组件组合（读取 `appSettingsProvider` 并把其值转发进 `MaterialApp.router` 参数），没有自己的逻辑——见 `build()` 方法和简单转发构造函数的定级规则。>

## 文档

无。按定级规则，本文件所有声明都是 Tier B（仅索引行，无完整条目）——`build()` 方法和简单转发构造函数不做完整文档小节。
