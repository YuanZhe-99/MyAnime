# lib/app/theme.dart

本文件现在调用 MyApps-UI `v0.1.0`。公共枚举通过重新导出提供；
原品牌色和 `scheme`、`build`、`light`、`dark` 接口保持不变。
下文的内部主题函数只在共享包中实现。
见 [../../shared-ui.md](../../shared-ui.md)。

定义 `AppUiStyle`（两种界面风格）、`NavPlacement`（外壳把导航放在哪里，1.7.2）与 `AppTheme`——一个纯静态类，用单个种子色构建应用的 `ThemeData`。自 1.7.0 起，视觉体系是纯 Flutter Material 3（`ThemeData` + `ColorScheme.fromSeed`）；`flex_color_scheme` 已移除。自 1.7.1 起，主题在相同配色之上提供两种风格：原版 **Material 3**，以及 **Expressive**（默认）——在其之上叠加的、主题层面的 Material 3 Expressive 近似。平台动态取色（Material You）**不**在此处读取——由调用方决定是否传入动态配色方案。被 [`../app/app.md`](app.md) 中的 `MyAnimeApp.build()` 作为 `theme:`/`darkTheme:` 消费；`ShareService` 也由 `AppTheme.seedColor` 派生分享图配色。视觉体系在应用外壳中的位置见 [../../architecture.md](../../architecture.md#app-shell)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AppUiStyle`](#appuistyle) | 枚举 | A | 用户可选的两种界面风格：`material3` 与 `expressive`（1.7.1）。 |
| [`NavPlacement`](#navplacement) | 枚举 | A | 外壳把导航放在哪里，两种风格通用：`bottom`、`sideOnWide` 或 `side`（1.7.2）。 |
| `AppTheme._` | 构造函数（`AppTheme`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`AppTheme.seedColor`](#apptheme-seedcolor) | 静态常量（`AppTheme`） | A | 应用的品牌色，也是视觉体系中唯一的每应用旋钮。 |
| [`AppTheme.scheme`](#apptheme-scheme) | 静态方法（`AppTheme`） | A | 解析某一亮度的 `ColorScheme`：给定动态配色方案则用之，否则用种子色方案。 |
| [`AppTheme.build`](#apptheme-build) | 静态方法（`AppTheme`） | A | 为某一亮度与界面风格构建 `ThemeData`。 |
| [`AppTheme.light`](#apptheme-light) | 静态方法（`AppTheme`） | A | 返回应用使用的浅色 Material 主题。 |
| [`AppTheme.dark`](#apptheme-dark) | 静态方法（`AppTheme`） | A | 返回应用使用的深色 Material 主题。 |

## 文档

### `enum AppUiStyle` <a id="appuistyle"></a>
- **种类：** 顶层枚举
- **来源：** `lib/app/theme.dart`（约第 10 行）
- **用途：** 为用户在设置 › 通用 › 界面风格中可选的两种界面风格命名：`material3` 与 `expressive`。
- **输入：** 无。
- **返回：** 枚举值 `AppUiStyle.material3` 与 `AppUiStyle.expressive`。
- **副作用：** 无。
- **备注：** 1.7.1 新增；带有文档注释但没有 `Purpose:` 行，因此不计入 [INDEX.md](../INDEX.md)。`expressive` 为默认值。它**在主题层面**近似 Material 3 Expressive（Flutter 没有自带 Expressive 组件），并让底栏成为紧凑悬浮胶囊（`_ExpressiveNavBar`）。`material3` 是原版 Material 3，配经典的通栏底栏。该风格由 `AnimeStorage.setUiStyle` 持久化（字符串 `'material3'`，Expressive 则不写键），保存在 `AppSettings.uiStyle` 中，由 `MyAnimeApp.build` 传给 `AppTheme.light`/`dark`；`ShellScaffold` 读取它来选择底栏。两种风格共用相同的配色。

### `static const Color seedColor` <a id="apptheme-seedcolor"></a>
- **种类：** `AppTheme` 的静态常量
- **来源：** `lib/app/theme.dart`（约第 32 行）
- **用途：** 保存应用的品牌色 `Color(0xFF673AB7)`（深紫色），视觉体系中唯一的每应用旋钮。
- **输入：** 无。
- **返回：** `Color`。
- **副作用：** 无。
- **备注：** 只要平台没有提供动态配色方案，Material 3 色调调色板的每个角色都由它生成。系列中每个应用都有自己的种子色，便于一眼区分。`ShareService` 也由它派生（始终为浅色、从不动态的）分享图配色。`ShareService` 不受界面风格影响。

### `enum NavPlacement` <a id="navplacement"></a>
- **种类：** 顶层枚举
- **来源：** `lib/app/theme.dart`
- **用途：** 命名外壳把导航放在哪里，与界面风格无关。
- **输入：** 无。
- **返回：** 枚举值 `NavPlacement.bottom`（默认：每个窗口都用底栏）、`NavPlacement.sideOnWide`（宽窗口用侧边导航栏，窄窗口用底栏）与 `NavPlacement.side`（每个窗口都用侧边导航栏，包括手机；不推荐，因为侧边导航栏会占用内容的宽度）。
- **副作用：** 无。
- **备注：** 1.7.2 新增；带有文档注释但没有 `Purpose:` 行，因此不计入 [INDEX.md](../INDEX.md)。与 `AppUiStyle` 一同声明于此，保存在 `AppSettings.navPlacement` 中；由 `AnimeStorage.setNavPlacement` 持久化（键 `navPlacement`，`bottom` 时不存在），在设置 › 通用 › 导航栏位置中选择。由 `ShellScaffold` 读取。主题本身忽略它。

### `static ColorScheme scheme(Brightness brightness, [ColorScheme? dynamicScheme])` <a id="apptheme-scheme"></a>
- **种类：** `AppTheme` 的静态方法
- **来源：** `lib/app/theme.dart`（约第 47 行）
- **用途：** 解析某一亮度的 `ColorScheme`。
- **输入：** `brightness`；`dynamicScheme`——平台由壁纸派生的该亮度配色方案，或 `null`。
- **返回：** `ColorScheme`——给定 `dynamicScheme` 时返回它，否则返回 `ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness)`。
- **副作用：** 无。
- **算法：** `dynamicScheme ?? ColorScheme.fromSeed(...)`。
- **备注：** 哪些平台可以传入动态配色方案由**调用方**决定：`MyAnimeApp.build` 只允许 Android（见 [app.md](app.md) 和 [platform-notes.md](../../platform-notes.md)）。两种界面风格共用这些配色，因此切换风格不会改变调色板。

### `static ThemeData build(Brightness brightness, [ColorScheme? dynamicScheme, AppUiStyle style = AppUiStyle.expressive])` <a id="apptheme-build"></a>
- **种类：** `AppTheme` 的静态方法
- **来源：** `lib/app/theme.dart`（约第 63 行）
- **用途：** 为某一亮度与界面风格构建主题。
- **输入：** `brightness`；`dynamicScheme`——可选的平台配色方案；`style`——界面风格，默认为 `AppUiStyle.expressive`（1.7.1 新增）。
- **返回：** `ThemeData`。
- **副作用：** 无（纯构造）。
- **算法：** 构建 `base = ThemeData(useMaterial3: true, colorScheme: scheme(brightness, dynamicScheme), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()))`——与 1.7.0 的主题完全一致——然后在 `style == AppUiStyle.expressive` 时返回 `_expressive(base)`，否则返回 `base`。
- **备注：** Material 3 风格刻意贴近 Flutter 的 Material 3 默认值。唯一的组件覆盖是**描边文本框**——Material 3 规范允许这样做，并使所有表单保持 1.7.0 之前的外观。其余全部为原版：没有着染/混合表面，使用 Material 3 分隔线，底部 `NavigationBar` 始终显示所有标签（1.7.0 之前只显示选中项的标签）。Expressive 在完全相同的主题之上叠加 [`_expressive`](#apptheme-expressive)，因此两种风格只在形状、字重和组件细节上不同，绝不改变布局或配色。

### `static const Duration _morphDuration` <a id="apptheme-morphduration"></a>
- **种类：** `AppTheme` 的私有静态常量
- **来源：** `lib/app/theme.dart`（约第 36 行）
- **用途：** 保存 Expressive 按钮在静止与按下形状之间变形所用的时长。
- **输入：** 无。
- **返回：** `Duration`——200 毫秒。
- **副作用：** 无。
- **备注：** 1.7.1 新增；带有文档注释但没有 `Purpose:` 行，因此不计入 [INDEX.md](../INDEX.md)。被 `_morphingButtonStyle` 以及 `_expressive` 中的 `SegmentedButton` 主题用作 `animationDuration`。

### `static ButtonStyle _morphingButtonStyle()` <a id="apptheme-morphingbuttonstyle"></a>
- **种类：** `AppTheme` 的私有静态方法
- **来源：** `lib/app/theme.dart`（约第 86 行）
- **用途：** 返回按下时形状会变形的按钮样式。
- **输入：** 无。
- **返回：** `ButtonStyle`——静止时为胶囊形，按下时为圆角方形。
- **副作用：** 无。
- **算法：** 一个 `ButtonStyle`，`animationDuration: _morphDuration`，`shape` 按状态解析：处于 `WidgetState.pressed` 时为 `RoundedRectangleBorder(borderRadius: 12)`，否则为 `StadiumBorder()`。`Material` 在两种形状之间做动画。
- **备注：** 仅在本文件内使用的内部辅助函数。无需自定义控件即可近似 Expressive 的形状变形。尺寸与内边距不变，因此没有任何布局位移。

### `static TextTheme _emphasized(TextTheme text)` <a id="apptheme-emphasized"></a>
- **种类：** `AppTheme` 的私有静态方法
- **来源：** `lib/app/theme.dart`（约第 102 行）
- **用途：** 加重 display、headline 与 title 样式的字重。
- **输入：** `text`——基础主题的文字主题。
- **返回：** 字重经过强调的 `TextTheme`。
- **副作用：** 无。
- **算法：** 对九个样式做 `copyWith`：`display*` 为 `FontWeight.w500`；`headline*` 与 `title*` 为 `FontWeight.w600`。
- **备注：** 仅在本文件内使用的内部辅助函数。只靠字重近似 Expressive 的“强调”字阶；字号与行高保持原版，因此文字不会重新排版。body 与 label 样式不变。

### `static ThemeData _expressive(ThemeData base)` <a id="apptheme-expressive"></a>
- **种类：** `AppTheme` 的私有静态方法
- **来源：** `lib/app/theme.dart`（约第 127 行）
- **用途：** 在原版 Material 3 主题之上叠加 Material 3 Expressive 近似。
- **输入：** `base`——由 `build` 构建的原版 Material 3 主题。
- **返回：** `ThemeData`——`base.copyWith(...)`。
- **副作用：** 无。
- **算法：** 对以下内容做 `copyWith`，全部在主题层面：
  - **文字：** `_emphasized(base.textTheme)`。
  - **按钮：** Filled、Elevated、Outlined、Text 与 Icon 按钮主题使用 `_morphingButtonStyle()`；`SegmentedButton` 主题只增加 `animationDuration: _morphDuration`。
  - **圆角：** 悬浮操作按钮 20；卡片 20（原版 12）；对话框 32（原版 28）；底部面板上缘 32；弹出菜单与菜单 16；Chip 12。
  - **Snack bar：** 悬浮行为，圆角 16。
  - **文本框：** 描边，所有边框状态下圆角均为 12——静止、启用与禁用时为轮廓色（禁用时为 12% 透明度的 `onSurface`）；聚焦时为主色、2 px；出错时为错误色（聚焦时 2 px）。
  - **进度指示器与滑块：** `ProgressIndicatorThemeData(year2023: false)` 与 `SliderThemeData(year2023: false)`，即 2024 版设计。`year2023` 被弃用只是因为 `false` 将成为默认值，但它是唯一的启用方式，因此两行都带有 `ignore: deprecated_member_use`。
  - **页面转场：** Android、Fuchsia、Linux 与 Windows 使用 `FadeForwardsPageTransitionsBuilder`；iOS 与 macOS 使用 `CupertinoPageTransitionsBuilder`（因此引入了 `package:flutter/cupertino.dart`）。
- **备注：** 仅在本文件内使用的内部辅助函数。配色、布局与尺寸均不变。**不模仿**（Flutter 没有对应物）：弹簧动效、波浪形进度指示器、按钮组、分体按钮、FAB 菜单与悬浮工具栏。与 Expressive 搭配的悬浮导航栏不属于主题；`ShellScaffold` 在 `AppSettings.uiStyle` 为 `AppUiStyle.expressive` 时显示它（见 [shell_scaffold.md](../shared/widgets/shell_scaffold.md)）。

### `static ThemeData light([ColorScheme? dynamicScheme, AppUiStyle style = AppUiStyle.expressive])` <a id="apptheme-light"></a>
- **种类：** `AppTheme` 的静态方法（1.7.0 之前是 getter）
- **来源：** `lib/app/theme.dart`（约第 198 行）
- **用途：** 返回应用使用的浅色主题。
- **输入：** `dynamicScheme`——可选的浅色平台配色方案；`style`——可选的界面风格（1.7.1 新增，默认 Expressive）。
- **返回：** `ThemeData`——`build(Brightness.light, dynamicScheme, style)`。
- **副作用：** 无。
- **用法：**
  ```dart
  MaterialApp.router(
    theme: AppTheme.light(allowDynamic ? lightDynamic : null, settings.uiStyle),
    darkTheme: AppTheme.dark(allowDynamic ? darkDynamic : null, settings.uiStyle),
    themeMode: settings.themeMode,
    ...
  )
  ```
  （来自 `lib/app/app.dart` 的 `MyAnimeApp.build`）
- **备注：** 现在是方法，应以 `AppTheme.light()` 调用；不再是 getter。

### `static ThemeData dark([ColorScheme? dynamicScheme, AppUiStyle style = AppUiStyle.expressive])` <a id="apptheme-dark"></a>
- **种类：** `AppTheme` 的静态方法（1.7.0 之前是 getter）
- **来源：** `lib/app/theme.dart`（约第 208 行）
- **用途：** 返回应用使用的深色主题。
- **输入：** `dynamicScheme`——可选的深色平台配色方案；`style`——可选的界面风格（1.7.1 新增，默认 Expressive）。
- **返回：** `ThemeData`——`build(Brightness.dark, dynamicScheme, style)`。
- **副作用：** 无。
- **用法：** 见上面的 `AppTheme.light`；两者在 `MyAnimeApp.build` 中一起调用。
- **备注：** 浅色与深色只在传给 `scheme` 的亮度上不同。
