# 平台说明

平台特有注意事项，外加纯桌面的本地 API 服务器、托盘行为和开机自启处理。构建风味见 [`architecture.md`](architecture.md)，API 服务器如何复用共享搜索服务见 [`features/multi-source-search.md`](features/multi-source-search.md)。

## Windows

- Inno Setup 安装包在 `installer.iss` 中定义；输出到 `build/installer/`。
- 安装包创建开始菜单快捷方式——快捷方式**不是**编程创建的。
- 应用图标：`windows/runner/resources/app_icon.ico`。
- 文件关联：`.myanimeitem` -> `MyAnimeItem` -> `my_anime.exe "%1"`，经由 `installer.iss` 中的注册表项。
- Inno 用 `#ifdef ARM64` 从一个脚本构建 x64 和 ARM64 两个安装包。

## macOS

- `macos/Runner/Configs/AppInfo.xcconfig` 中的应用名是 `MyAnime!!!!!`。
- `DebugProfile.entitlements` 和 `Release.entitlements` 都必须有 `com.apple.security.network.client` 才能联网。
- 自定义应用图标用 `flutter_launcher_icons` 生成。
- `.myanimeitem` 文件关联在 `Info.plist` 中使用 UTI `com.yuanzhe.my-anime.myanimeitem`。
- 端侧 AI（1.6.0）使用与下文 iOS 相同的插件和弱链接规则；部署目标仍为 macOS 13.0。

## iOS

- `Info.plist` 中 `CFBundleDisplayName` 是 `MyAnime!!!!!`。
- HTTPS 网络访问不需要特殊授权。
- iOS 应用图标对默认、深色和着色模式使用专门的带内边距来源：`assets/icon/app_icon_ios.png`、`assets/icon/app_icon_ios_dark.png`、`assets/icon/app_icon_ios_tinted.png`。
- `.myanimeitem` 文件关联与 macOS 使用相同的 UTI 声明。
- App Store IPA 需要签名/预置描述文件，不由 CI 构建。
- **端侧 AI（1.6.0）：** Apple 的 Foundation Models 框架由本地 Flutter 插件 `packages/myapps_ai/packages/myapps_ai_platform/`
  桥接（纳入版本控制的目录，不是子模块），以 `sharedDarwinSource: true` 声明，一份 Swift 源码同时服务 iOS 和
  macOS。它注册 `com.yuanzhe.myapps_ai/genai` 通道，不暴露任何 Dart API；Flutter 工具像集成其他插件一样集成它，
  因此没有编辑任何 `project.pbxproj`。FoundationModels 是**弱链接**的（podspec 中的 `s.weak_frameworks`；在
  Swift Package Manager 下由 `@available` 守卫让链接器弱链接它），每处使用都位于
  `#if canImport(FoundationModels)` 和 `@available(iOS 26.0, macOS 26.0, *)` 之后，因此部署目标仍为 iOS 13.0，
  应用在 iOS 18 及更早版本上仍能启动。构建该桥接需要 Xcode 26 SDK；使用更旧的 SDK 时 `canImport` 为 false，
  插件回答 `unsupported`。不需要任何 entitlement 或 `Info.plist` 键。见 [`on-device-ai.md`](on-device-ai.md)。

## Android

- `android/app/build.gradle.kts` 应使用 `import java.util.Properties`。
- **Kotlin 迁移状态（应用侧已迁移）：** Gradle wrapper `9.3.1`、AGP `9.1.1`，应用不再应用 `kotlin-android`。Kotlin `jvmTarget` 由顶层 `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` 块设置——刻意**不用** `jvmToolchain`（需要真实安装 JDK 17）也**不用** `kotlinOptions`（已移除）。`android/gradle.properties` 保留 Flutter 迁移器兼容标志 `android.builtInKotlin=false` 和 `android.newDsl=false`，因为多个插件仍直接应用 Kotlin Gradle Plugin（KGP）——把 `builtInKotlin` 设为 `true` 会破坏每个应用 KGP 的插件（已验证）。在 `settings.gradle.kts` 中保留 `org.jetbrains.kotlin.android` 声明（`apply false`）；应用 KGP 的插件从那里解析它。
- **`file_picker` 精确固定为 `10.3.7`**（不是 caret 约束），因为它是既自己应用 KGP（`builtInKotlin=false` 时需要）*又*能对照 `flutter.compileSdkVersion` 编译（AGP 9 AAR 元数据检查需要）的最后一个版本。`10.3.9+` 和 `11.x` 依赖 AGP 的内置 Kotlin，在兼容模式下无法编译；`10.3.2` 及更早固定 `compileSdk 34`，无法通过元数据检查。其 Dart API 是 `FilePicker.platform.*`。
- Keystore 属性应使用 `as String?` 之类的可空转换。
- 启用了核心库脱糖。
- **自 1.6.0 起 `minSdk` 为 26**，在 `defaultConfig` 中显式设置，而不是用 `flutter.minSdkVersion`（24），因为
  ML Kit GenAI 库要求 API 26。这放弃了 Android 7.0 和 7.1。带运行时守卫的 `tools:overrideLibrary` 方案被否决：
  它有在 API 24 和 25 上发生类校验崩溃的风险。
- **端侧 AI 依赖精确锁定版本：** `com.google.mlkit:genai-prompt:1.0.0-beta4`（没有弃用政策的 beta API）和
  `org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2`。两者都能在当前工具链（AGP 9.1.1、KGP 2.2.20、
  `builtInKotlin=false`）上构建。
- **R8 保留规则：** release 构建类型加上 `proguardFiles("proguard-rules.pro")`。`android/app/proguard-rules.pro`
  保留 `com.google.mlkit.**`、`com.google.android.gms.internal.mlkit_**` 和 `kotlinx.coroutines.**`；缺少它们时，
  release 构建会在运行时失败，看起来像是设备不受支持，而 debug 构建一切正常。
- `AndroidManifest.xml` 在 `<queries>` 中有 `<package android:name="com.google.android.aicore"/>`，使 AICore 版本
  在 API 30 及以上可见。
- `GenAiChannel`（`packages/myapps_ai/packages/myapps_ai_platform/android/src/main/kotlin/com/yuanzhe/myapps_ai/GenAiChannel.kt`）在
  `MainActivity.configureFlutterEngine` 中与分享和文件打开通道一起挂接，并在 `onDestroy` 中解除挂接，同时关闭
  AICore 客户端。见 [`on-device-ai.md`](on-device-ai.md)。
- 本地可通过 `key.properties` 可选签名；CI 使用 GitHub Secrets。
- `FileProvider` 和 `FLAG_ACTIVITY_NEW_TASK` 支持分享/导入流程（见 [`features/share-and-import.md`](features/share-and-import.md)）。

## 动态取色（1.7.0）

应用使用由单个种子色（深紫色，`AppTheme.seedColor`）生成的原版 Material 3 颜色。两种界面风格（Material 3 与默认的 Expressive，1.7.1）共用这些颜色。在 **Android 12 及更新版本**上，`dynamic_color` 插件提供由壁纸派生的（Material You）配色方案，应用在浅色和深色下都用它取代种子色。在 **Android 11 及更早版本**、**iOS**、**Windows**、**macOS** 和其他任何平台上，使用种子色方案。

桌面端被刻意排除在外。在 Windows 和 macOS 上，该插件返回的不是壁纸调色板，而是系统**强调色**，使用它会取代应用自己的种子色，导致系列中的每个应用都看起来像用户选的强调色，而失去自己的辨识度。因此 `MyAnimeApp.build` 只有在 `!kIsWeb && defaultTargetPlatform == TargetPlatform.android` 时才把插件的配色方案传给 `AppTheme`（见 [`functions/app/app.md`](functions/app/app.md) 和 [`functions/app/theme.md`](functions/app/theme.md)）。Android 动态取色尚未在真机上验证。

## 桌面 API 服务器、托盘和开机自启

`local_api_server.dart` 是**纯桌面**的 Shelf 服务器。默认禁用，由设置页控制。

- 默认监听地址：`localhost`。
- 默认端口：`7788`。
- 用户可以为局域网访问设置 `0.0.0.0`。
- 非回环监听需要 API 凭据；未带凭据的不安全非 localhost 启动会被直接拒绝。
- 浏览器请求必须来自本地来源（1.6.7）：`Origin` 头不是 `localhost` 或回环 IP 上的 `http`/`https` 时，对所有方法返回 `403` 且不带 CORS 头。没有 `Origin` 头的请求（curl、脚本）不受影响；允许的来源会被原样回显，而不是 `*`。
- 配置了凭据**时**，每个非 `OPTIONS` 请求都需要 HTTP Basic 认证，**包括回环**——因此即使是允许的本地来源上的网页，没有凭据也读不到 API。未配置凭据时，允许回环请求、拒绝非回环请求。

### 端点

| 端点 | 备注 |
| --- | --- |
| `GET /ping` | 健康检查 |
| `POST /anime/search` | 调用 `AnimeSearchService.searchAll()`——见 [`features/multi-source-search.md`](features/multi-source-search.md) |
| `POST /anime/add` | 新增动画记录 |
| `GET /anime/list` | 返回 `{total, counts, data}` |
| `GET /anime/unwatched` | 未观看的已播出剧集 |
| `GET /anime/history` | 返回 `{total, counts, data}` |
| `GET /anime/ranking` | 已评分动画，返回 `{total, filters, sort, limit, data}` |

- 动画 API 条目 JSON 包含派生的 `status`（`completed`、`watching`、`dropped` 或 `notStarted`）、进度计数、URL、封面路径、备注、修改时间戳和可选的评分摘要，同时保留旧字段以向后兼容。
- `/anime/ranking` 过滤器包括 全部/季度/年/范围、动画类型、评分字段、排序方向和结果限制。
- `/anime/ranking` 另接受 `scoreSource=personal|external`（默认 `personal`），在 `external` 下还可用可选的 `externalSource=<名称>` 锁定单一资料库，而不是对所有给该番打过分的来源取平均。两者都会在 `sort` 中回显。默认值使每个既有客户端的答案保持不变；带 `externalSource` 却不带 `scoreSource=external` 会返回 `400`。
- 季过滤器包括 `current`、`YYYYQn`、`unassigned` 和 `all`；`all` 可以对返回行抽样，同时保持总数准确。
- API 日期序列化把从 JST 派生的剧集日期转换为带尾部 `Z` 的 UTC 字符串。

### 托盘与启动

`tray_service.dart` 处理桌面托盘行为：显示、退出、最小化到托盘、关闭到托盘，以及 macOS/Linux/Windows 分支。`launch_at_startup`（包）处理桌面自动启动。

## 网络连接检测

`connectivity_plus`（1.5.0 新增）用于门禁后台资料更新器。它支持全部四个目标平台，且与仓库中已有的
`share_plus`、`package_info_plus`、`wakelock_plus` 同属 `plus` 家族，因此除 `pub get` 外不需要任何
逐平台接线。在 Android 上，它会把自带的 `ACCESS_NETWORK_STATE` 权限合并进 manifest。

**它报告的是链路类型，而不是链路是否计费。** 这个限制是真实存在的，且值得明说，因为它驱动的那个设置项
叫作「不使用蜂窝数据」：

- 设备连接手机热点时报告 `wifi`，而上行其实是蜂窝。无法检测。
- 移动端的 VPN 可能报告 `vpn`，从而掩盖底层链路。
- Android 通过 `NetworkCapabilities.NET_CAPABILITY_NOT_METERED` 提供了正确答案，但
  `connectivity_plus` 没有把它暴露出来。

因此 `noCellular` 策略是一个足够好的启发式，而不是保证。插件调用失败时按「允许」处理，而不是在一个
无法回答的平台上把功能整个封死。见
[`features/metadata-auto-update.md`](features/metadata-auto-update.md)。


## Anime1 播放器依赖（1.6.4）

macOS 实现使用已发布的 1.2.0-beta.3 源码副本，并应用上游 PR [#2870](https://github.com/pichillilorenzo/flutter_inappwebview/pull/2870) 的固定提交 `8db1d528a2dc467112ec5e1a5233172f3dd828b4`。Xcode 26.6 拒绝已发布的 1.2.0-beta.3 实现：其显示上下文协议遵循从 macOS 10.14 起可用，但必需的方法标记为 10.15。补丁将协议遵循移到标记为 10.15 可用的提供器，保持其存活至会话结束，并在销毁时释放。上游 Git 树缺少发布包中的 6 个 Swift 文件，因此在 `packages/flutter_inappwebview_macos` 中保留完整的已发布运行时源码。仅此 macOS 包使用路径覆盖；有包含修复的正式版本后应替换。应用最低 macOS 版本仍为 13.0。

media_kit 1.2.6／media_kit_video 2.0.1 提供原生播放；自 1.6.5 起应用在 media_kit 的 `Video` 之上绘制自己的控件，并保留其唤醒锁、后台暂停和全屏行为；flutter_inappwebview 6.2.0-beta.3 提供回退。Windows 构建需要 NuGet，运行需要 WebView2。上游 media_kit_libs_windows_video 1.0.11 仅包含 x64 libmpv/ANGLE。本地 MIT 授权副本保留上游 x64 校验值，在 ARM64 构建注册占位插件；media_kit_video 使用其上游无媒体库实现。ARM64 在媒体解析前直接选择网页播放器。其他原生初始化或解码失败也回退。缺少 WebView 支持时提供用户主动点击的浏览器入口。沿用 CI 的 MSVC 协程兼容宏（`build.yml` 中的 `CL: /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`）。使用 MSVC 14.51 的本地 Windows 构建需要在 `CL` 环境变量中设置同一个宏；若先前失败的构建留下了占用插件 PDB 的编译器进程，还要加上 `/FS`：`$env:CL = '/FS /D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS'`。

WebView 固定为 6.2.0-beta.3：稳定版 6.1.5 使用了本项目 AGP 9.1.1 已删除的 Android ProGuard API；[上游版本已修复 AGP 9 兼容性](https://pub.dev/packages/flutter_inappwebview/versions/6.2.0-beta.3/changelog)。在完成设备播放验收前，预发布依赖仍属于平台验收风险。
