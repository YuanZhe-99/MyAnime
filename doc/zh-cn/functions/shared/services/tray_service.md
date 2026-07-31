# lib/shared/services/tray_service.dart

`TrayService` 是纯桌面单例，为 Windows、macOS 和 Linux 接线系统托盘图标/菜单（经 `tray_manager`）和窗口显示/隐藏/关闭行为（经 `window_manager`）。它通过 `AnimeStorage` 的配置文件读取并持久化 `minimizeToTray`/`closeToTray` 偏好，还通过一个小型原生 `MethodChannel` 切换 macOS Dock 图标。它与 `local_api_server.dart` 和 `launch_at_startup` 的并存方式见 [`../../../platform-notes.md`](../../../platform-notes.md) 的"桌面 API 服务器、托盘和开机自启"一节。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`TrayService._`](#trayservice-_) | 构造函数（`TrayService`） | B | 支撑 `TrayService.instance` 单例的私有构造函数。 |
| `minimizeToTray` | getter（`TrayService`） | B | 当前最小化到托盘偏好。 |
| `closeToTray` | getter（`TrayService`） | B | 当前关闭到托盘偏好。 |
| [`init`](#init) | 方法（`TrayService`） | A | 在支持的桌面平台上初始化托盘图标/菜单和窗口监听器。 |
| [`_setupTray`](#_setuptray) | 方法（`TrayService`） | A | 设置托盘图标/工具提示并构建初始上下文菜单。 |
| `_rebuildMenu` | 方法（`TrayService`） | B | 用当前语言区域的标签重建托盘上下文菜单。 |
| [`setMinimizeToTray`](#setminimizetotray) | 方法（`TrayService`） | A | 持久化并应用最小化到托盘偏好。 |
| [`setCloseToTray`](#setclosetotray) | 方法（`TrayService`） | A | 持久化并应用关闭到托盘偏好。 |
| [`updateLocale`](#updatelocale) | 方法（`TrayService`） | A | 更新托盘菜单标签使用的语言区域，已初始化时重建菜单。 |
| `onTrayIconMouseDown` | 方法（`TrayService`） | B | 左键点击托盘图标时显示窗口。 |
| `onTrayIconRightMouseDown` | 方法（`TrayService`） | B | 右键点击时弹出托盘上下文菜单。 |
| [`onTrayMenuItemClick`](#ontraymenuitemclick) | 方法（`TrayService`） | A | 处理显示/退出托盘菜单选择。 |
| [`onWindowClose`](#onwindowclose) | 方法（`TrayService`） | A | 按下操作系统关闭按钮时隐藏到托盘或销毁窗口。 |
| [`onWindowMinimize`](#onwindowminimize) | 方法（`TrayService`） | A | 启用时窗口被最小化则隐藏到托盘。 |
| `_showWindow` | 方法（`TrayService`） | B | 显示、聚焦并从 Dock 取消隐藏主窗口。 |
| `_setDockIconVisible` | 方法（`TrayService`） | B | 经原生通道调用切换 macOS Dock 图标可见性。 |

## 文档

### `TrayService._()` <a id="trayservice-_"></a>
- **种类：** `TrayService` 的私有命名构造函数
- **来源：** `lib/shared/services/tray_service.dart`（约第 17 行）
- **用途：** 支撑模块级单例 `TrayService.instance` 并阻止外部代码构造另一个实例。
- **输入：** 无。
- **返回：** 新的 `TrayService` 实例（只为 `instance` 构造一次）。
- **副作用：** 无。
- **算法：** 空体；`static final TrayService instance = TrayService._();` 是唯一调用点。
- **用法：** 不直接调用——用 `TrayService.instance`。
- **备注：** 无。

### `Future<void> init()` <a id="init"></a>
- **种类：** `TrayService` 的方法
- **来源：** `lib/shared/services/tray_service.dart`（约第 46 行）
- **用途：** 一次性设置：加载持久化的托盘偏好、挂接窗口关闭预防、构建托盘图标和菜单，并注册监听器。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `AnimeStorage.readConfig()`；初始化 `window_manager`；把 `this` 注册为 `WindowListener` 和 `TrayListener`；设置托盘图标/工具提示/菜单。
- **算法：**
  1. 已初始化，或平台不是 Windows/macOS/Linux 时立即返回。
  2. 从持久化配置读取 `minimizeToTray`/`closeToTray`（默认 `false`）。
  3. 初始化 `windowManager`，把 `this` 注册为监听器，调用 `setPreventClose(_closeToTray)` 使原生关闭按钮可被拦截。
  4. 经 [`_setupTray`](#_setuptray) 构建托盘图标/菜单并把 `this` 注册为 `TrayListener`。
  5. 标记已初始化。
- **用法：**
  ```dart
  await TrayService.instance.init();
  ```
  （来自 `lib/main.dart`，桌面平台启动期间）
- **备注：** 经 `_initialized` 守卫幂等——多次调用安全。

### `Future<void> _setupTray()` <a id="_setuptray"></a>
- **种类：** `TrayService` 的私有方法
- **来源：** `lib/shared/services/tray_service.dart`（约第 69 行）
- **用途：** 设置托盘图标（平台特定资源）和工具提示，然后构建初始上下文菜单。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 调用 `trayManager.setIcon`/`setToolTip`；经 [`_rebuildMenu`](#_rebuildmenu) 间接设置上下文菜单。
- **算法：** Windows 上选 `assets/icon/app_icon.ico`，否则 `assets/icon/app_icon.png`，设为托盘图标，把工具提示设为 `"MyAnime!!!!!"`，然后重建菜单。
- **用法：** 只从 [`init`](#init) 调用。
- **备注：** 无。

### `Future<void> setMinimizeToTray(bool value)` <a id="setminimizetotray"></a>
- **种类：** `TrayService` 的方法
- **来源：** `lib/shared/services/tray_service.dart`（约第 100 行）
- **用途：** 更新内存中的最小化到托盘标志并持久化到配置。
- **输入：** `value` — 新偏好。
- **返回：** `Future<void>`。
- **副作用：** 经 `AnimeStorage.writeConfig` 把 `minimizeToTray` 写入持久化配置文件。
- **算法：** 设 `_minimizeToTray = value`，读取当前配置，设 `minimizeToTray` 键，写回。
- **用法：**
  ```dart
  TrayService.instance.setMinimizeToTray(v);
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，"最小化到托盘"设置开关）
- **备注：** 此刻本身不改变窗口行为——它只影响 [`onWindowMinimize`](#onwindowminimize) 对下一次最小化事件的处理。

### `Future<void> setCloseToTray(bool value)` <a id="setclosetotray"></a>
- **种类：** `TrayService` 的方法
- **来源：** `lib/shared/services/tray_service.dart`（约第 112 行）
- **用途：** 更新内存中的关闭到托盘标志、持久化它，并立即重新武装/解除原生关闭预防钩子。
- **输入：** `value` — 新偏好。
- **返回：** `Future<void>`。
- **副作用：** 把 `closeToTray` 写入持久化配置；调用 `windowManager.setPreventClose(value)`。
- **算法：** 设 `_closeToTray = value`，持久化到配置，然后调用 `windowManager.setPreventClose(value)`，使操作系统关闭按钮立即被拦截（或不拦截），不像 `setMinimizeToTray` 只在下一个事件生效。
- **用法：**
  ```dart
  TrayService.instance.setCloseToTray(v);
  ```
  （来自 `lib/features/settings/views/settings_page.dart`，"关闭到托盘"设置开关）
- **备注：** 与 [`setMinimizeToTray`](#setminimizetotray) 不同，这对窗口管理器的关闭拦截有立即副作用，不只影响未来的最小化事件。

### `Future<void> updateLocale(Locale locale)` <a id="updatelocale"></a>
- **种类：** `TrayService` 的方法
- **来源：** `lib/shared/services/tray_service.dart`（约第 125 行）
- **用途：** 更新托盘菜单项标签本地化使用的语言区域，托盘已初始化时重建菜单。
- **输入：** `locale` — 新应用语言区域。
- **返回：** `Future<void>`。
- **副作用：** 可能重建托盘上下文菜单（`trayManager.setContextMenu`）。
- **算法：** 存储 `locale`；`_initialized` 时调用 [`_rebuildMenu`](#_rebuildmenu)，使"显示"/"退出"标签立即反映新语言。
- **用法：** 应用语言区域变化时调用（应用级语言区域 provider 监听器），使用户在设置中更改语言后托盘菜单绝不显示过期语言标签。
- **备注：** `init()` 运行过一次之前菜单重建是空操作（`_initialized` 守卫）——语言区域仍被记住，供 `init()` 运行时使用。

### `void onTrayMenuItemClick(MenuItem menuItem)` <a id="ontraymenuitemclick"></a>
- **种类：** `TrayService` 的覆盖方法（`TrayListener`）
- **来源：** `lib/shared/services/tray_service.dart`（约第 157 行）
- **用途：** 处理用户从托盘上下文菜单选择"显示"或"退出"。
- **输入：** `menuItem` — 被点击的菜单项（`key` 区分 `'show'` vs `'quit'`）。
- **返回：** 无。
- **副作用：** 显示/聚焦窗口，或禁用关闭预防并关闭窗口。
- **算法：** 按 `menuItem.key` 切换：`'show'` 调用 [`_showWindow`](#_showwindow)；`'quit'` 调用 `windowManager.setPreventClose(false)` 然后 `windowManager.close()`，使从托盘退出总是真正退出，即使启用了关闭到托盘。
- **用法：** 用户点击菜单条目时由 `tray_manager` 调用；应用代码不直接调用。
- **备注：** `'quit'` 分支刻意先禁用预防关闭——否则关闭请求只会重新隐藏窗口而不是退出。

### `void onWindowClose()` <a id="onwindowclose"></a>
- **种类：** `TrayService` 的覆盖方法（`WindowListener`）
- **来源：** `lib/shared/services/tray_service.dart`（约第 178 行）
- **用途：** 决定操作系统关闭按钮是把窗口隐藏到托盘还是真正销毁。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 隐藏窗口并使 macOS Dock 图标变暗，或销毁窗口/进程。
- **算法：** `_closeToTray` 时调用 `windowManager.hide()` 然后 [`_setDockIconVisible(false)`](#_setdockiconvisible)；否则调用 `windowManager.destroy()`。
- **用法：** 按下原生关闭按钮时由 `window_manager` 调用（只因 `init()` 调用了 `setPreventClose` 才可达）；不直接调用。
- **备注：** 只在 `windowManager.setPreventClose(true)` 激活时触发，即本会话中某时刻启用了 `closeToTray`。

### `void onWindowMinimize()` <a id="onwindowminimize"></a>
- **种类：** `TrayService` 的覆盖方法（`WindowListener`）
- **来源：** `lib/shared/services/tray_service.dart`（约第 193 行）
- **用途：** 最小化到托盘偏好启用时，窗口被最小化则隐藏到托盘。
- **输入：** 无。
- **返回：** 无。
- **副作用：** 可能隐藏窗口并使 macOS Dock 图标变暗。
- **算法：** `_minimizeToTray` 时调用 `windowManager.hide()` 然后 `_setDockIconVisible(false)`；否则什么都不做（正常操作系统最小化继续）。
- **用法：** 最小化事件时由 `window_manager` 调用；不直接调用。
- **备注：** 无。
