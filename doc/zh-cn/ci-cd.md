# CI/CD 与构建命令

## 工作流

`.github/workflows/build.yml` 在 `v*` 标签推送和 `workflow_dispatch` 时运行。

每个检出步骤都传 `submodules: recursive`。没有它，`flutter pub get` 会因缺失的 `packages/myapps_data` 路径依赖而失败。相对子模块 URL 在 CI 中解析到公共 GitHub 副本，因此默认的 `GITHUB_TOKEN` 就足够了。

## 任务

- Android full 风味的 APK 和 store 风味的 AAB。
- 在 `windows-latest` 上构建 Windows x64 full 安装包。
- 在 `windows-11-arm` 上构建 Windows ARM64 full 安装包；它目前使用缓存的 Flutter master，因为编写工作流时 stable 的 ARM64 引擎支持尚不可用。
- 不带签名的 iOS full 侧载 IPA。
- 通过 `create-dmg` 构建 macOS full DMG。
- 标签推送时上传 GitHub Release 工件。

## 工作流注意事项

- 让工作流 Flutter 版本与 Dart SDK 约束保持一致。
- GitHub `secrets` 不能直接在步骤的 `if` 表达式中使用；要通过任务级 `env` 路由。
- Windows ARM64 输出由 `iscc /DARM64 installer.iss` 控制。
- ARM64 Flutter master 缓存按周更新，让 Windows Defender 信誉可以累积到复用的 DLL 哈希上。一旦 stable Flutter 提供合适的 ARM64 支持，就把这个任务切回 stable 通道配置。
- 依赖链不再包含 `<experimental/coroutine>` 后，移除 `CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` 兼容宏。
- Action 版本：`actions/checkout@v7`、`actions/setup-java@v5`、`actions/upload-artifact@v7`、`actions/download-artifact@v8`、`actions/cache@v6`、`softprops/action-gh-release@v3`（从 GitHub 废弃的基于 Node 20 的 majors 升级）。在下次标签发布前用一次 `workflow_dispatch` 运行验证工作流变更。
- 已知的剩余警告：Android 任务仍会为 `flutter_timezone`、`package_info_plus`、`share_plus`、`shared_preferences_android`、`wakelock_plus` 和 `file_picker` 打印 Flutter 的"应用 KGP 的插件"警告。应用侧已迁移（AGP 9.1.1，无应用级 `kotlin-android`）；剩余警告只在插件侧，且截至 2026-07，即使这些插件的最新版本仍应用 KGP。彻底消除需要在每个插件都提供 Built-in Kotlin 支持后翻转为 `android.builtInKotlin=true`；尝试时要用真实的 APK/AAB 构建验证。

## 命令

```powershell
flutter pub get
flutter analyze
flutter test
flutter test test/anime_json_test.dart
flutter gen-l10n
flutter build apk --release --dart-define=FLAVOR=full
flutter build appbundle --release --dart-define=FLAVOR=store
flutter build windows --release --dart-define=FLAVOR=full
iscc installer.iss
iscc /DARM64 installer.iss
```

使用最窄的相关命令集做校验。模型或同步变更时，包含 `flutter test test/anime_json_test.dart`。

`flutter analyze` 目前报告既有的 info 级条目（在 `tool/`、一个视图和一个测试中），外加 pub advisory 的 decode 警告。把这些既有噪声与本次变更引入的回归区分开——与编辑前的计数比较，而不是期望为零。

## 全新克隆

共享引擎包是 git 子模块，因此普通 `git clone` 会留下空的 `packages/myapps_data`，`flutter pub get` 失败：

```bash
git clone --recurse-submodules <app-url>
# or, after a plain clone:
git submodule update --init
```

## `tool/` 脚本

`tool/` 目录包含临时脚本，如图标生成和搜索源校验。`tool/generate_ios_icons.dart` 从 `assets/icon/app_icon.png` 派生出带内边距的 iOS 默认、深色和着色图标来源，并把预览 PNG 写到 `/tmp` 下；更改 iOS 图标来源后，用 `flutter_launcher_icons` 重新生成 `ios/Runner/Assets.xcassets/AppIcon.appiconset/`。

生产行为优先用聚焦测试，除非用户要求，否则把工具脚本留在发布关键路径之外。
