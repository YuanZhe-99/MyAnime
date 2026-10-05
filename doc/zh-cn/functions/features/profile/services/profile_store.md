# lib/features/profile/services/profile_store.dart

P3：下文公共声明位于 `myapps_profile`；应用文件为重新导出或适配，
保留公开导入路径和构造器形式。
见 [../../../../shared-ui.md](../../../../shared-ui.md)。

`ProfileStore`（1.7.0）负责 `AnimeStorage.getAppDir()` 下的 `profile.json`：用户的名称和头像。它遵循与播放进度存储相同的模式：读取-修改-写入队列、原子写入、字节未变时不写入，并在每次实际写入后调用 `AutoSyncService.notifySaved`。头像图片本身位于 `images/` 中，与封面放在一起，这就是它到达其他设备的方式。见 [`../../../app/data_modules.md`](../../../app/data_modules.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ProfileStore._` | 构造函数 | B | 禁止实例化。 |
| `resolveImage` | 静态方法 | A | 通过应用适配解析图片。 |
| [`load`](#load) | 静态方法 | A | 加载个人资料；不存在或无法读取时为空。 |
| [`update`](#update) | 静态方法 | A | 应用一个排队的更改并保存。 |
| [`setName`](#setname) | 静态方法 | A | 设置或清除名称。 |
| [`pickAvatarSource`](#pickavatarsource) | 静态方法 | A | 让用户选择一张图片以编辑成头像（1.7.2；取代 `pickAvatar`）。 |
| [`readAvatarBytes`](#readavatarbytes) | 静态方法 | A | 读取当前头像图片，以便再次调整（1.7.2）。 |
| [`setAvatarJpeg`](#setavatarjpeg) | 静态方法 | A | 把编辑后的头像存为全新文件并更新个人资料（1.7.2）。 |
| [`removeAvatar`](#removeavatar) | 静态方法 | A | 以带时间戳的移除方式移除头像。 |

`fileName`（`profile.json`，必须与 `data_modules.dart` 中的 `profileFileName` 一致）、`avatarSize`（`512`）和队列 `_tail` 没有 `/// Purpose:` 注释。

## load

- **返回：** 已存储的 `ProfileData`；文件不存在、为空白或无法读取时返回空的。

## update

- **输入：** `mutate`——从已加载的个人资料返回新个人资料。
- **副作用：** 读取，然后（仅当编码后的字节不同时）用 `atomicWriteString` 写入文件并调用 `AutoSyncService.instance.notifySaved()`。
- **备注：** 调用通过 `_tail` 排队，因此并发更新依次应用。当文件存在但无法解析时，`_apply` 抛出 `FormatException` 并保持磁盘上的字节原样不动，因为覆盖保存会在同步后在每台设备上抹掉个人资料；空白文件视为空。编码经由 `encodeProfile`，因此字节与合并输出一致。

## setName

- **输入：** `name`——会去除首尾空白；为空则清除。
- **备注：** 未变化的名称保留其旧时间戳，因此不会赢得它本不该赢的合并。

## pickAvatarSource

- **返回：** `Uint8List?`——所选文件的字节；选择器被取消（或没有可用字节）时为 null。
- **副作用：** 打开 `FilePicker`（图片，`withData`）；平台没有返回字节时回退为读取 `picked.path`。
- **备注：** 不保存任何东西。字节交给头像编辑器（[`../views/avatar_editor.md`](../views/avatar_editor.md)），其结果再由 [`setAvatarJpeg`](#setavatarjpeg) 存储。它取代了 1.7.0 的 `pickAvatar`——后者一步完成选择、居中裁剪与保存；那种居中裁剪保留为 [`avatar_image.md`](avatar_image.md) 中的 `squareAvatarJpeg`。

## readAvatarBytes

- **返回：** `Uint8List?`——头像文件的字节；没有头像、或其文件尚未到达本设备（或无法读取）时为 null。
- **副作用：** 读取 `profile.json` 与 `images/` 下的一个文件，经 `ImageService.resolve` 解析。
- **备注：** 已存储的头像本身就是 512 像素的正方形，因此再次调整只能进一步放大、旋转或重新居中。

## setAvatarJpeg

- **输入：** `jpeg`——编辑器给出的正方形 JPEG（`avatarSize` 像素）。
- **返回：** `ProfileData`——新的个人资料。
- **副作用：** 写入全新的 `images/avatar_<uuid>.jpg`，通过 `update` 以 `withAvatar(rel, now)` 更新 `profile.json`，然后删除本设备上先前的头像文件。
- **备注：** 每个头像都使用**全新的文件名**，因为图像同步从不覆盖本地或远程已存在的同名文件，复用同一个名称会让其他设备一直保留旧图。旧头像文件会留在 WebDAV 服务器和其他设备上，因为图像同步只增不删——这是已知限制。

## removeAvatar

- **副作用：** 写入带有显式、带时间戳移除（`"avatar": null`）的 `profile.json`，并删除本地头像文件。
- **备注：** 移除带有时间戳，因此会同步到其他设备。

## _deleteQuietly

- **备注：** 只会删除基名以 `avatar_` 开头的文件，因此这条路径永远不会删除封面。失败被忽略。
