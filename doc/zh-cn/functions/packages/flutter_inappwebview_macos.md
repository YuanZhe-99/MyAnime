# packages/flutter_inappwebview_macos

MIT 授权的 1.2.0-beta.3 运行时源码副本，应用上游 PR #2870 的 macOS 可用性修复。
来源与替换条件见[平台说明](../../platform-notes.md)及包内 README。
未修改的第三方声明保留上游文档，不计入 `lib/` 总数。

## 修改的声明

| 声明 | 用途 |
|---|---|
| `WebAuthenticationPresentationContextProvider.presentationAnchor` | 在标记为 macOS 10.15 可用的协议遵循下返回主窗口。 |
| `WebAuthenticationSession.init` | 将提供器赋给原生会话的弱引用属性，并保持其存活。 |
| `WebAuthenticationSession.dispose` | 随会话一起释放持有的提供器。 |
