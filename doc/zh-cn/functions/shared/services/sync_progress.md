# lib/shared/services/sync_progress.dart

**再导出垫片。** `SyncPhase`、`SyncProgress` 和 `SyncProgressListenable` 原样移入共享 `myapps_data` 包（那里的 `lib/src/webdav/sync_progress.dart`）。三个应用的副本逐字节相同（SHA-256 验证），因此移动没有改变任何行为。

本文件保留只是为了既有导入继续工作：

```dart
export 'package:myapps_data/myapps_data.dart'
    show SyncPhase, SyncProgress, SyncProgressListenable;
```

## 声明

没有自己的。

## 真实文档的位置

`packages/myapps_data/doc/en-us/functions/src/webdav/sync_progress.md`。

另见 [`webdav_service.md`](webdav_service.md)，它暴露 UI 监听的 `ValueNotifier<SyncProgress>`。
