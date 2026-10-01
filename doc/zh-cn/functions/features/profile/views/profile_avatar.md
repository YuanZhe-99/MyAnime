# lib/features/profile/views/profile_avatar.dart

绘制在圆形中的用户头像（1.7.0），显示在首页应用栏、设置页顶部和个人资料编辑对话框中。`ProfileAvatar` 监听个人资料 provider；`ProfileAvatarView` 是其背后的无状态渲染，以个人资料为参数，使测试和预览无需 provider。见 [`../providers/profile_provider.md`](../providers/profile_provider.md)、[`profile_header.md`](profile_header.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ProfileAvatar` | 构造函数（`ProfileAvatar`） | B | 创建个人资料头像；`radius` 默认为 18。 |
| [`ProfileAvatar.build`](#profileavatarbuild) | 方法（`ProfileAvatar`，组件构建） | A | 为当前个人资料构建圆形头像。 |
| `ProfileAvatarView` | 构造函数（`ProfileAvatarView`） | B | 为给定个人资料和半径创建头像视图。 |
| [`ProfileAvatarView._placeholder`](#placeholder) | 方法（`ProfileAvatarView`） | A | 构建没有图片时显示的圆形。 |
| [`ProfileAvatarView.build`](#profileavatarviewbuild) | 方法（`ProfileAvatarView`，组件构建） | A | 构建图片圆形，或占位图。 |

## ProfileAvatar.build

- **备注：** 一个 `ConsumerWidget`：读取 `profileProvider` 并返回 `ProfileAvatarView(profile: profile, radius: radius)`。

## _placeholder

- **返回：** 一个 `CircleAvatar`，背景为 `primaryContainer`、前景为 `onPrimaryContainer`，显示名称首字母（大写），没有名称时显示人像图标。

## ProfileAvatarView.build

- **算法：** 没有头像路径时返回占位图。否则由 `FutureBuilder<File>`（以头像路径为 key）通过 `ImageService.resolve` 解析文件；文件尚未解析时显示占位图，之后显示一个 `ClipOval`，其中是 `Image.file`（边长 `radius * 2` 的正方形、`BoxFit.cover`、`gaplessPlayback`，`errorBuilder` 回退到占位图）。
- **备注：** 头像文件尚未从同步到达时显示的也是占位图；它以同样方式回退，之后某次重建找到该文件时图片就会出现。
