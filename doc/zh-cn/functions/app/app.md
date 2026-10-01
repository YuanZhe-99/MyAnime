# lib/app/app.dart

定义根组件 `MyAnimeApp`，它把 `MaterialApp.router`（置于 `DynamicColorBuilder` 内）与应用主题、语言区域、本地化委托、`go_router` 配置和 `DevicePreview` 集成包在一起。它还定义了一个小的 `ScrollBehavior` 覆盖，使桌面鼠标滚轮/触控板滚动在处处可用。这与整体应用外壳的契合（`main.dart` → `app.dart` → `router.dart`/`theme.dart`）见 [../../architecture.md](../../architecture.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_DesktopScrollBehavior.dragDevices` | getter（`_DesktopScrollBehavior`） | B | 为滚动启用触控、鼠标和触控板拖动输入。 |
| `MyAnimeApp.new` | 构造函数（`MyAnimeApp`） | B | 创建一个 `MyAnimeApp` 实例。 |
| `MyAnimeApp.build` | 方法（`MyAnimeApp`，组件构建） | B | 构建带主题/语言区域/路由器接线的根 `DynamicColorBuilder` + `MaterialApp.router`。 |

<本文件中的每个声明都是 Tier B：`_DesktopScrollBehavior` 是一行 `ScrollBehavior` 覆盖，没有分支；`MyAnimeApp` 的构造函数是平凡的转发 `const` 构造函数；`build()` 是纯组件组合（读取 `appSettingsProvider` 并把其值转发进 `MaterialApp.router` 参数），没有自己的逻辑——见 `build()` 方法和简单转发构造函数的定级规则。>

## 文档

无。按定级规则，本文件所有声明都是 Tier B（仅索引行，无完整条目）——`build()` 方法和简单转发构造函数不做完整文档小节。

## 动态取色（自 1.7.0 起）

`MyAnimeApp.build` 把 `MaterialApp.router` 包在 `DynamicColorBuilder`（`dynamic_color` 包）中。构建器给出的由壁纸派生的（Material You）配色方案，**仅**在 `!kIsWeb && defaultTargetPlatform == TargetPlatform.android` 时才传给 `AppTheme.light(...)` / `AppTheme.dark(...)`。设置这个门槛是因为在 Windows 和 macOS 上该插件返回的是系统强调色，会取代应用自己的深紫色种子；因此这些平台（以及 iOS，和插件不返回配色方案的 Android 11 及更早版本）使用 `ColorScheme.fromSeed(AppTheme.seedColor)`。`MaterialApp.router` 的其他所有参数（滚动行为、语言区域、委托、`DevicePreview.appBuilder`、路由器）不变。见 [theme.md](theme.md) 和 [../../platform-notes.md](../../platform-notes.md)。
