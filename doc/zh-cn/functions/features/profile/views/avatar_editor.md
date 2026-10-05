# lib/features/profile/views/avatar_editor.dart

P3：下文公共声明位于 `myapps_profile`；应用文件为重新导出或适配，
保留公开导入路径和构造器形式。
见 [../../../../shared-ui.md](../../../../shared-ui.md)。

全屏头像编辑器（1.7.2）：用户在一个圆形内为图片取景，可按四分之一圈旋转，然后保存。`showAvatarEditor` 打开它并返回取景后的正方形 JPEG，个人资料对话框再通过 `ProfileNotifier.setAvatarJpeg` 存储。取景的正方形就是最终存储的内容，因此头像始终与所见一致。见 [`../services/avatar_image.md`](../services/avatar_image.md)、[`profile_header.md`](profile_header.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| [`showAvatarEditor`](#showavatareditor) | 顶层函数 | A | 让用户为头像取景并返回结果。 |
| `AvatarEditorPage` | 构造函数（`AvatarEditorPage`） | B | 为一张源图片创建头像编辑器。 |
| `AvatarEditorPage.createState` | 方法（控件生命周期） | B | 创建编辑器状态。 |
| `_AvatarEditorPageState.initState` | 方法（控件生命周期） | B | 开始准备图片。 |
| `_AvatarEditorPageState.dispose` | 方法（控件生命周期） | B | 释放变换控制器。 |
| [`_AvatarEditorPageState._prepare`](#_prepare) | 方法（`_AvatarEditorPageState`） | A | 按当前旋转角度解码、摆正并调整源图尺寸。 |
| [`_AvatarEditorPageState._rotate`](#_rotate) | 方法（`_AvatarEditorPageState`） | A | 顺时针旋转四分之一圈。 |
| [`_AvatarEditorPageState._reset`](#_reset) | 方法（`_AvatarEditorPageState`） | A | 回到初始取景。 |
| [`_AvatarEditorPageState._save`](#_save) | 方法（`_AvatarEditorPageState`） | A | 裁出圆形所示的内容并返回。 |
| [`_AvatarEditorPageState.build`](#_build) | 方法（控件构建） | A | 构建编辑器：应用栏、取景视口、提示。 |
| `_CircleMaskPainter` | 构造函数（`_CircleMaskPainter`） | B | 创建遮罩绘制器。 |
| `_CircleMaskPainter.paint` | 方法（`CustomPainter`） | B | 绘制带圆形镂空的遮罩与轮廓。 |
| `_CircleMaskPainter.shouldRepaint` | 方法（`CustomPainter`） | B | 仅在颜色变化时重绘。 |

## showAvatarEditor

- **输入：** `context`；`source`——所选图片，或当前头像的字节。
- **返回：** `Future<Uint8List?>`——`ProfileStore.avatarSize` 像素的正方形 JPEG；用户退出时为 null。
- **副作用：** 推入一个全屏 `MaterialPageRoute`（`fullscreenDialog: true`），内容是 `AvatarEditorPage`。
- **备注：** 对错误输入不抛出任何异常：无法解码的图片会在编辑器中显示错误状态。

## _prepare

- **副作用：** 设置 `_busy`，在另一个 isolate 中运行 `prepareAvatarSourceInBackground(source, quarterTurns: _turns)`，然后保存 `AvatarSource`、清除忙碌与失败标志，并设置 `_viewport = 0`，使下一次构建重新居中图片；失败时设置 `_failed`。
- **备注：** 由 `initState` 调用，并在每次旋转之后调用。页面已不再挂载时忽略结果。

## _rotate

- **副作用：** 把 `_turns` 加 1（按 4 取模）并调用 `_prepare`，由它重新准备图片并重置取景。
- **备注：** 旋转被固化进准备好的 PNG，而不是作为显示变换应用，因此所显示的像素与所裁的像素始终一致。

## _reset

- **副作用：** 把变换设为 `Matrix4.translationValues(-(base.width - viewport) / 2, -(base.height - viewport) / 2, 0)`：缩放 1 倍并居中，图片铺满圆形。
- **备注：** 每当视口尺寸或图片尺寸变化时，也会从一次帧后回调中调用。变换的重置发生在帧之后，而从不在构建期间，因为控制器会通知其监听者。

## _save

- **副作用：** 设置 `_busy`，把视口经变换矩阵映射回图片像素（`scale = getMaxScaleOnAxis()`；`x = -tx / scale * toPixels`；`y = -ty / scale * toPixels`；`side = viewport / scale * toPixels`，其中 `toPixels = image.width / base.width`），以 `size: ProfileStore.avatarSize` 运行 `cropAvatarJpegInBackground`，并带着 JPEG 弹出该路由。失败时设置 `_failed` 并清除 `_busy`。
- **备注：** 图片尚未就绪或视口尚未测量时什么都不做。

## _build

- **算法：** 一个 `Scaffold`，其 `AppBar`（标题 `profileAdjustAvatar`）有三个操作：**旋转**（`rotate_90_degrees_cw_outlined`，提示 `profileAvatarRotate`）、**重置**（`restart_alt`，提示 `profileAvatarReset`）和**保存** `FilledButton`；忙碌期间、图片就绪前以及（保存）失败后都会禁用。body 是一个 `SafeArea`：`_failed` 时显示 `profileAvatarError` 文本，图片就绪前显示 `CircularProgressIndicator`，否则是一个 `Column`，内含一个正方形视口与提示文字（`profileAvatarEditorHint`）。视口边长是 `min(width, height - 96) - 32`，限制在 160 到 480 之间；图片被布局为**铺满**视口（`cover = side / min(image.width, image.height)`），位于 `ClipRect` → `InteractiveViewer`（`constrained: false`、`minScale: 1`、`maxScale: 8`、`boundaryMargin: EdgeInsets.zero`）→ `Image.memory` 之中。其上是一个 `IgnorePointer` 的 `CustomPaint`，绘制 `_CircleMaskPainter`：内切圆之外是 `scrim` 颜色（55% 透明度），外加一圈 2 px 的 `primary` 描边；`_busy` 时视口上叠加一个忙碌指示器。
- **备注：** 拖动移动，捏合或滚轮缩放（1 倍到 8 倍）。`minScale: 1` 与零边界边距保证无论用户如何拖动或缩放，图片都始终铺满圆形。`build` 记录视口边长与基础图片尺寸，供 `_save` 使用。
