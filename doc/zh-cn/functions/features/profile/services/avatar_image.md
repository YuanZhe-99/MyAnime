# lib/features/profile/services/avatar_image.dart

头像编辑器背后的纯图像操作（1.7.2）。每个函数都是同步的、只做内存分配，因此调用方会在另一个 isolate 中运行它们以保持界面响应：两个 `...InBackground` 包装函数用 `Isolate.run` 完成这件事。`squareAvatarJpeg` 从 `profile_store.dart` 移到了这里，它在 1.7.0 与 1.7.1 中位于那里。见 [`../views/avatar_editor.md`](../views/avatar_editor.md)、[`profile_store.md`](profile_store.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| `AvatarSource` | 类 | B | 所选图片经过摆正、限制尺寸后的 PNG 副本，带有 `bytes`、`width` 与 `height`。 |
| `AvatarSource.new` | 构造函数（`AvatarSource`） | B | 创建一个头像来源。 |
| `_decode` | 顶层函数 | B | 解码任意图片，且不让解码器异常漏出。 |
| [`prepareAvatarSource`](#prepareavatarsource) | 顶层函数 | A | 为编辑器规整所选图片：摆正、限制在 2048 px 以内、PNG。 |
| [`cropAvatarJpeg`](#cropavatarjpeg) | 顶层函数 | A | 裁出用户取景的正方形并编码为头像 JPEG。 |
| [`squareAvatarJpeg`](#squareavatarjpeg) | 顶层函数 | A | 把任何可解码的图片变成居中裁剪的正方形 JPEG（从 `profile_store.dart` 移来）。 |
| [`prepareAvatarSourceInBackground`](#prepareavatarsourceinbackground) | 顶层函数 | A | 在另一个 isolate 中运行 `prepareAvatarSource`。 |
| [`cropAvatarJpegInBackground`](#cropavatarjpegbackground) | 顶层函数 | A | 在另一个 isolate 中运行 `cropAvatarJpeg`。 |

`avatarSourceMaxEdge`（`2048`，编辑器处理的最长边）是没有 `/// Purpose:` 注释的普通常量。

## _decode

- **备注：** 被截断或不属于任何格式的数据可能让格式探测抛出异常（例如 `RangeError`）而不是返回 null；这种异常与 null 结果都会变成 `FormatException('Not a supported image')`。

## prepareAvatarSource

- **输入：** `bytes`——所选文件；`quarterTurns`——额外的顺时针 90° 旋转次数（编辑器的旋转按钮），按 4 取模。
- **返回：** `AvatarSource`——已摆正（应用 EXIF）、最长边不超过 `avatarSourceMaxEdge`、编码为 PNG。
- **算法：** `_decode`、`bakeOrientation`，旋转次数不为 0 时 `copyRotate(angle: 90 * turns)`，图片更大时按长边 `copyResize` 到 2048，最后 `encodePng`。
- **备注：** 在这里把方向固化，意味着编辑器所显示的像素与 `cropAvatarJpeg` 所裁的像素是同一批，无论平台自己如何处理 EXIF。对非图片抛出 `FormatException`。512 像素的头像从不需要超过 2048 像素的源图，这也让内存与 isolate 传输保持在较小范围。

## cropAvatarJpeg

- **输入：** `source`——来自 `prepareAvatarSource` 的 PNG 字节（是 `Uint8List`，不是 `AvatarSource`）；`x`、`y`、`side`——源图像素中的正方形；`size`——输出边长（像素）。
- **返回：** `Uint8List`——JPEG 字节，`size` × `size`。
- **算法：** `_decode`；把 `side` 限制在 1 到较短边之间，再限制 `x` 与 `y`，使正方形留在图内；`copyCrop`；`copyResize(size, size, interpolation: average)`；`encodeJpg(quality: 88)`。
- **备注：** 这种限制使图像边缘处的取整永远不会失败。对非图片抛出 `FormatException`。编辑器传入 `ProfileStore.avatarSize`（512）。

## squareAvatarJpeg

- **输入：** `bytes`——源图片；`size`——输出边长（像素）。
- **返回：** `Uint8List`——JPEG 字节。
- **算法：** `_decode`、`bakeOrientation`、`copyResizeCropSquare(size: size, interpolation: average)`，然后 `encodeJpg(quality: 88)`。
- **备注：** 非交互路径（不经编辑器）：应用 EXIF 方向并取居中的正方形。纯函数，可安全地在另一个 isolate 中运行。对非图片抛出 `FormatException`。

## prepareAvatarSourceInBackground

- **输入：** `bytes`、`quarterTurns`（默认 0）。
- **返回：** `Future<AvatarSource>`。
- **副作用：** 启动一个短命的 isolate（`Isolate.run`）。
- **备注：** **刻意写成顶层函数。**在控件的 `State` 方法里创建的闭包会同时捕获该 `State`（及其控制器），而它们无法发送到另一个 isolate；这是 GUI 测试中发现的一个真实缺陷。这里的闭包只捕获参数。对非图片抛出 `FormatException`。

## cropAvatarJpegInBackground

- **输入：** 同 `cropAvatarJpeg`。
- **返回：** `Future<Uint8List>`——头像 JPEG。
- **副作用：** 启动一个短命的 isolate（`Isolate.run`）。
- **备注：** 与 `prepareAvatarSourceInBackground` 出于同样的原因写成顶层函数。
