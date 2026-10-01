# lib/app/theme.dart

定义 `AppTheme`，一个纯静态类，用单个种子色构建应用的原版 Material 3 `ThemeData`。自 1.7.0 起，视觉体系是纯 Flutter Material 3（`ThemeData` + `ColorScheme.fromSeed`）；`flex_color_scheme` 已移除。平台动态取色（Material You）**不**在此处读取——由调用方决定是否传入动态配色方案。被 [`../app/app.md`](app.md) 中的 `MyAnimeApp.build()` 作为 `theme:`/`darkTheme:` 消费；`ShareService` 也由 `AppTheme.seedColor` 派生分享图配色。视觉体系在应用外壳中的位置见 [../../architecture.md](../../architecture.md#app-shell)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AppTheme._` | 构造函数（`AppTheme`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`AppTheme.seedColor`](#apptheme-seedcolor) | 静态常量（`AppTheme`） | A | 应用的品牌色，也是视觉体系中唯一的每应用旋钮。 |
| [`AppTheme.scheme`](#apptheme-scheme) | 静态方法（`AppTheme`） | A | 解析某一亮度的 `ColorScheme`：给定动态配色方案则用之，否则用种子色方案。 |
| [`AppTheme.build`](#apptheme-build) | 静态方法（`AppTheme`） | A | 为某一亮度构建原版 Material 3 `ThemeData`。 |
| [`AppTheme.light`](#apptheme-light) | 静态方法（`AppTheme`） | A | 返回应用使用的浅色 Material 主题。 |
| [`AppTheme.dark`](#apptheme-dark) | 静态方法（`AppTheme`） | A | 返回应用使用的深色 Material 主题。 |

## 文档

### `static const Color seedColor` <a id="apptheme-seedcolor"></a>
- **种类：** `AppTheme` 的静态常量
- **来源：** `lib/app/theme.dart`（约第 16 行）
- **用途：** 保存应用的品牌色 `Color(0xFF673AB7)`（深紫色），视觉体系中唯一的每应用旋钮。
- **输入：** 无。
- **返回：** `Color`。
- **副作用：** 无。
- **备注：** 只要平台没有提供动态配色方案，Material 3 色调调色板的每个角色都由它生成。系列中每个应用都有自己的种子色，便于一眼区分。`ShareService` 也由它派生（始终为浅色、从不动态的）分享图配色。

### `static ColorScheme scheme(Brightness brightness, [ColorScheme? dynamicScheme])` <a id="apptheme-scheme"></a>
- **种类：** `AppTheme` 的静态方法
- **来源：** `lib/app/theme.dart`（约第 26 行）
- **用途：** 解析某一亮度的 `ColorScheme`。
- **输入：** `brightness`；`dynamicScheme`——平台由壁纸派生的该亮度配色方案，或 `null`。
- **返回：** `ColorScheme`——给定 `dynamicScheme` 时返回它，否则返回 `ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness)`。
- **副作用：** 无。
- **算法：** `dynamicScheme ?? ColorScheme.fromSeed(...)`。
- **备注：** 哪些平台可以传入动态配色方案由**调用方**决定：`MyAnimeApp.build` 只允许 Android（见 [app.md](app.md) 和 [platform-notes.md](../../platform-notes.md)）。

### `static ThemeData build(Brightness brightness, [ColorScheme? dynamicScheme])` <a id="apptheme-build"></a>
- **种类：** `AppTheme` 的静态方法
- **来源：** `lib/app/theme.dart`（约第 40 行）
- **用途：** 为某一亮度构建原版 Material 3 主题。
- **输入：** `brightness`；`dynamicScheme`——可选的平台配色方案。
- **返回：** `ThemeData`。
- **副作用：** 无（纯构造）。
- **算法：** 返回 `ThemeData(useMaterial3: true, colorScheme: scheme(brightness, dynamicScheme), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()))`。
- **备注：** 刻意贴近 Flutter 的 Material 3 默认值。唯一的组件覆盖是**描边文本框**——Material 3 规范允许这样做，并使所有表单保持 1.7.0 之前的外观。其余全部为原版：没有着染/混合表面，使用 Material 3 分隔线，底部 `NavigationBar` 始终显示所有标签（1.7.0 之前只显示选中项的标签）。

### `static ThemeData light([ColorScheme? dynamicScheme])` <a id="apptheme-light"></a>
- **种类：** `AppTheme` 的静态方法（1.7.0 之前是 getter）
- **来源：** `lib/app/theme.dart`（约第 54 行）
- **用途：** 返回应用使用的浅色主题。
- **输入：** `dynamicScheme`——可选的浅色平台配色方案。
- **返回：** `ThemeData`——`build(Brightness.light, dynamicScheme)`。
- **副作用：** 无。
- **用法：**
  ```dart
  MaterialApp.router(
    theme: AppTheme.light(allowDynamic ? lightDynamic : null),
    darkTheme: AppTheme.dark(allowDynamic ? darkDynamic : null),
    themeMode: settings.themeMode,
    ...
  )
  ```
  （来自 `lib/app/app.dart` 的 `MyAnimeApp.build`）
- **备注：** 现在是方法，应以 `AppTheme.light()` 调用；不再是 getter。

### `static ThemeData dark([ColorScheme? dynamicScheme])` <a id="apptheme-dark"></a>
- **种类：** `AppTheme` 的静态方法（1.7.0 之前是 getter）
- **来源：** `lib/app/theme.dart`（约第 62 行）
- **用途：** 返回应用使用的深色主题。
- **输入：** `dynamicScheme`——可选的深色平台配色方案。
- **返回：** `ThemeData`——`build(Brightness.dark, dynamicScheme)`。
- **副作用：** 无。
- **用法：** 见上面的 `AppTheme.light`；两者在 `MyAnimeApp.build` 中一起调用。
- **备注：** 浅色与深色只在传给 `scheme` 的亮度上不同。
