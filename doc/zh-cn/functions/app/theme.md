# lib/app/theme.dart

定义 `AppTheme`，一个暴露用 `flex_color_scheme` 的 `FlexThemeData` 构建的应用浅色和深色 `ThemeData` 的纯静态类。被 [`../app/app.md`](app.md) 中的 `MyAnimeApp.build()` 作为 `theme:`/`darkTheme:` 消费。视觉体系在应用外壳中的位置见 [../../architecture.md](../../architecture.md#app-shell)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AppTheme._` | 构造函数（`AppTheme`） | B | 阻止直接实例化，只暴露静态成员。 |
| [`AppTheme.light`](#apptheme-light) | getter（`AppTheme`） | A | 返回应用使用的浅色 Material 主题。 |
| [`AppTheme.dark`](#apptheme-dark) | getter（`AppTheme`） | A | 返回应用使用的深色 Material 主题。 |

## 文档

### `static ThemeData get light` <a id="apptheme-light"></a>
- **种类：** `AppTheme` 的静态 getter
- **来源：** `lib/app/theme.dart`（约第 17 行）
- **用途：** 为整个应用构建并返回浅色模式 `ThemeData`。
- **输入：** 无。
- **返回：** `ThemeData`，由 `FlexThemeData.light(...)` 构建。
- **副作用：** 无（纯构造；`flex_color_scheme` 在这里不做任何 I/O）。
- **算法：**
  1. 以 `scheme: FlexScheme.deepPurple`（应用的颜色方案种子）调用 `FlexThemeData.light`。
  2. 设置 `surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold` 和 `blendLevel: 7`，控制主色着染表面相对于脚手架背景的程度。
  3. 传入 `FlexSubThemesData`，带 `blendOnLevel: 10`、`useMaterial3Typography: true`、`useM2StyleDividerInM3: true`、`inputDecoratorBorderType: FlexInputBorderType.outline` 和 `navigationBarLabelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected`（只显示被选中的底部导航标签，匹配 `router.dart` 中的五个标签外壳）。
  4. 设置 `useMaterial3: true` 并返回结果 `ThemeData`。
- **用法：**
  ```dart
  MaterialApp.router(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: settings.themeMode,
    ...
  )
  ```
  （来自 `lib/app/app.dart` 的 `MyAnimeApp.build`）
- **备注：** 混合/层级常量（`blendLevel: 7`、`blendOnLevel: 10`）低于深色主题的（`13`/`20`），这是刻意的 `flex_color_scheme` 惯例——深色表面通常需要更强的着染才能在深色背景上正确阅读。

### `static ThemeData get dark` <a id="apptheme-dark"></a>
- **种类：** `AppTheme` 的静态 getter
- **来源：** `lib/app/theme.dart`（约第 37 行）
- **用途：** 为整个应用构建并返回深色模式 `ThemeData`。
- **输入：** 无。
- **返回：** `ThemeData`，由 `FlexThemeData.dark(...)` 构建。
- **副作用：** 无。
- **算法：** 与 `AppTheme.light` 形态相同（同样的 `FlexScheme.deepPurple` 方案、`FlexSurfaceMode.levelSurfacesLowScaffold` 和 `FlexSubThemesData` 选项），只是 `blendLevel: 13` 和 `blendOnLevel: 20`——都高于浅色主题的 `7`/`10`，给深色表面一个可见的主色着染。
- **用法：** 见上面的 `AppTheme.light`；两个 getter 在 `MyAnimeApp.build` 中一起读取。
- **备注：** 更改共享选项（排版、分隔线风格、输入边框、导航标签行为）时保持 `light` 和 `dark` 同步——只有表面/混合层级是两者间刻意的不同。
