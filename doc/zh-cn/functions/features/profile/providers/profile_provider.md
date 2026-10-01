# lib/features/profile/providers/profile_provider.dart

当前 `ProfileData` 的 Riverpod provider（1.7.0）。它只加载一次 `profile.json`，在同步或恢复重写本地数据时重新加载，并让每次编辑都经过 `ProfileStore`，使文件始终是唯一的真实来源。见 [`../services/profile_store.md`](../services/profile_store.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`ProfileNotifier.new`](#profilenotifier-new) | 构造函数（`ProfileNotifier`） | A | 创建 notifier，订阅本地数据变更并开始加载。 |
| `ProfileNotifier.fixed` | 构造函数（`ProfileNotifier`） | B | 创建带固定个人资料且无 I/O 的 notifier；供测试使用。 |
| [`reload`](#reload) | 方法（`ProfileNotifier`） | A | 把 `profile.json` 重新读入状态。 |
| `setName` | 方法（`ProfileNotifier`） | B | 保存新名称；为空则清除。 |
| `setAvatarJpeg` | 方法（`ProfileNotifier`） | B | 保存由头像编辑器产生的头像（1.7.2；取代 `pickAvatar`）。 |
| `removeAvatar` | 方法（`ProfileNotifier`） | B | 移除头像。 |
| `dispose` | 方法（`ProfileNotifier`） | B | 取消订阅本地数据变更。 |

`profileProvider`（`StateNotifierProvider<ProfileNotifier, ProfileData>`）是没有 `/// Purpose:` 注释的普通 provider 声明。

## ProfileNotifier.new

- **副作用：** 调用 `AutoSyncService.instance.addOnLocalDataChanged(reload)` 和 `reload()`。
- **备注：** 以空的 `ProfileData()` 开始；加载到的个人资料稍后替换它。由于监听器在同步或恢复改变本地文件后触发，在另一台设备上编辑的个人资料无需重启即可出现。

## reload

- **副作用：** 读取文件并替换状态，仅当 notifier 仍处于 `mounted` 时。
- **备注：** 销毁后调用也是安全的；此时结果会被丢弃。

## 编辑

`setName`、`setAvatarJpeg` 和 `removeAvatar` 调用对应的 `ProfileStore` 方法，然后用返回的个人资料替换状态。`setAvatarJpeg(Uint8List jpeg)` 接收编辑器给出的正方形 JPEG；选择与取景在调用它之前由界面完成（1.7.2 取代了一步完成选择与保存的 `pickAvatar()` 及其选择器被取消时的 `false`）。失败以异常形式向上传播，由对话框报告。`dispose` 调用 `removeOnLocalDataChanged(reload)`。
