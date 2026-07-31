# lib/main.dart

应用入口点。它在把控制权通过 `runApp` 交给 Flutter 组件树之前，接好每个纯桌面后台服务（开机自启、本地 API 服务器、系统托盘、备份、自动同步、提醒和文件打开处理器）。更广的服务生命周期图见 [../architecture.md](../architecture.md)（如果存在），桌面功能概览（本地 API 服务器、托盘、提醒）见仓库根目录的 `AGENTS.md`。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`main`](#main) | 顶层函数 | A | 初始化启动服务并启动应用入口点。 |

## 文档

### `void main(List<String> args) async` <a id="main"></a>
- **种类：** 顶层函数（入口点）
- **来源：** `lib/main.dart`（约第 23 行）
- **用途：** 初始化纯桌面后台服务、核心应用服务和待处理文件打开状态，然后启动 Flutter 组件树。
- **输入：** `args` — 进程命令行参数；扫描其中的 `.myanimeitem` 路径（通过文件关联/双击的桌面冷启动）。
- **返回：** 无（isolate 通过 `runApp` 继续运行）。
- **副作用：** 调用 `WidgetsFlutterBinding.ensureInitialized()`；仅在 Windows/macOS/Linux 上设置 `launch_at_startup`、启动 `LocalApiServer` 并初始化 `TrayService`；初始化 `ReminderService` 本地通知；触发 `BackupService.runAutoBackupIfNeeded()`（即发即忘）；启动 `AutoSyncService.instance` 生命周期观察者；启动 `ReminderService.startPeriodicCheck()`；初始化 `FileOpenService`；并调用 `runApp` 挂载包在 `DevicePreview` 中的组件树。
- **算法：**
  1. 在任何插件调用前确保 Flutter bindings 已初始化。
  2. 如果在桌面平台运行（`!kIsWeb && (Windows || macOS || Linux)`），读取 `PackageInfo.fromPlatform()`，并用应用名和 `Platform.resolvedExecutable` 向 `launch_at_startup` 注册应用。
  3. 在同一个桌面平台检查上，启动 `LocalApiServer`（如果功能在设置中禁用，内部无操作）。
  4. 在同一个桌面平台检查上，初始化 `TrayService.instance`。
  5. 无条件初始化 `ReminderService`（本地通知插件设置）——这个调用在所有平台上都 await。
  6. 不 await 地触发 `BackupService.runAutoBackupIfNeeded()`（在后台运行每日一次自动备份检查）。
  7. 启动 `AutoSyncService.instance`，使它开始观察应用生命周期事件以触发同步。
  8. 启动 `ReminderService.startPeriodicCheck()`（桌面 60 秒进程内提醒检查）。
  9. 初始化 `FileOpenService`（注册移动端文件关联 `MethodChannel`）。
  10. 扫描 `args` 找第一个以 `.myanimeitem` 结尾的条目；找到则用 `FileOpenService.setPendingFile()` 暂存，用于桌面冷启动文件关联。
  11. 调用 `runApp`，把 `ProviderScope(child: MyAnimeApp())` 包在 `DevicePreview` 中（仅 `kDebugMode` 启用）。
  12. 如果第 10 步找到了待处理文件，通过 `WidgetsBinding.instance.addPostFrameCallback` 安排 `FileOpenService.processPendingFile()` 在第一帧之后运行，使文件在组件树（因此导航）存在后打开。
- **用法：** 这是 Dart 程序入口点；Flutter 工具链直接调用它（如通过 `flutter run` 或构建出的可执行文件）。其他应用代码不调用它。
- **备注：** 三个桌面平台门各自写成带相同条件的独立 `if` 块，而不是一个共享块——功能等价，只是重复。`.myanimeitem` 待处理文件舞蹈（第 10–12 步）存在是因为 `FileOpenService.processPendingFile` 需要有效的导航上下文，而它只在第一帧渲染后才可用。
