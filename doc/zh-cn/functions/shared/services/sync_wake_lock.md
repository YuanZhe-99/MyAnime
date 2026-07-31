# lib/shared/services/sync_wake_lock.dart

**再导出垫片。** `SyncWakeLock` 原样移入共享 `myapps_data` 包（那里的 `lib/src/sync/sync_wake_lock.dart`）。三个应用的副本逐字节相同（SHA-256 验证）。

```dart
export 'package:myapps_data/myapps_data.dart' show SyncWakeLock;
```

锁仍是引用计数、所有权跟踪的，并吞掉所有插件错误。它由运行前台操作的**页面**（手动同步、冲突最终化、强制上传/下载）获取和释放，不是同步引擎——后台自动同步不得使用它。

## 声明

没有自己的。

## 真实文档的位置

`packages/myapps_data/doc/en-us/functions/src/sync/sync_wake_lock.md`。
