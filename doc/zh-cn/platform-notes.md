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

## iOS

- `Info.plist` 中 `CFBundleDisplayName` 是 `MyAnime!!!!!`。
- HTTPS 网络访问不需要特殊授权。
- iOS 应用图标对默认、深色和着色模式使用专门的带内边距来源：`assets/icon/app_icon_ios.png`、`assets/icon/app_icon_ios_dark.png`、`assets/icon/app_icon_ios_tinted.png`。
- `.myanimeitem` 文件关联与 macOS 使用相同的 UTI 声明。
- App Store IPA 需要签名/预置描述文件，不由 CI 构建。

## Android

- `android/app/build.gradle.kts` 应使用 `import java.util.Properties`。
- **Kotlin 迁移状态（应用侧已迁移）：** Gradle wrapper `9.3.1`、AGP `9.1.1`，应用不再应用 `kotlin-android`。Kotlin `jvmTarget` 由顶层 `kotlin { compilerOptions { jvmTarget = JvmTarget.JVM_17 } }` 块设置——刻意**不用** `jvmToolchain`（需要真实安装 JDK 17）也**不用** `kotlinOptions`（已移除）。`android/gradle.properties` 保留 Flutter 迁移器兼容标志 `android.builtInKotlin=false` 和 `android.newDsl=false`，因为多个插件仍直接应用 Kotlin Gradle Plugin（KGP）——把 `builtInKotlin` 设为 `true` 会破坏每个应用 KGP 的插件（已验证）。在 `settings.gradle.kts` 中保留 `org.jetbrains.kotlin.android` 声明（`apply false`）；应用 KGP 的插件从那里解析它。
- **`file_picker` 精确固定为 `10.3.7`**（不是 caret 约束），因为它是既自己应用 KGP（`builtInKotlin=false` 时需要）*又*能对照 `flutter.compileSdkVersion` 编译（AGP 9 AAR 元数据检查需要）的最后一个版本。`10.3.9+` 和 `11.x` 依赖 AGP 的内置 Kotlin，在兼容模式下无法编译；`10.3.2` 及更早固定 `compileSdk 34`，无法通过元数据检查。其 Dart API 是 `FilePicker.platform.*`。
- Keystore 属性应使用 `as String?` 之类的可空转换。
- 启用了核心库脱糖。
- 本地可通过 `key.properties` 可选签名；CI 使用 GitHub Secrets。
- `FileProvider` 和 `FLAG_ACTIVITY_NEW_TASK` 支持分享/导入流程（见 [`features/share-and-import.md`](features/share-and-import.md)）。

## 桌面 API 服务器、托盘和开机自启

`local_api_server.dart` 是**纯桌面**的 Shelf 服务器。默认禁用，由设置页控制。

- 默认监听地址：`localhost`。
- 默认端口：`7788`。
- 用户可以为局域网访问设置 `0.0.0.0`。
- 非回环监听需要 API 凭据；未带凭据的不安全非 localhost 启动会被直接拒绝。
- CORS 宽松。
- 配置了凭据**时**，每个非 `OPTIONS` 请求都需要 HTTP Basic 认证，**包括回环**——否则宽松的 CORS 会让任何本地网页读到 API。未配置凭据时，允许回环请求、拒绝非回环请求。

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
- 季过滤器包括 `current`、`YYYYQn`、`unassigned` 和 `all`；`all` 可以对返回行抽样，同时保持总数准确。
- API 日期序列化把从 JST 派生的剧集日期转换为带尾部 `Z` 的 UTC 字符串。

### 托盘与启动

`tray_service.dart` 处理桌面托盘行为：显示、退出、最小化到托盘、关闭到托盘，以及 macOS/Linux/Windows 分支。`launch_at_startup`（包）处理桌面自动启动。
