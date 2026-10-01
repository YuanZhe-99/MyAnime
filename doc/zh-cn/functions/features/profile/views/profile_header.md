# lib/features/profile/views/profile_header.dart

设置页顶部的头像加名称行（1.7.0），以及它打开的用于编辑二者的对话框。`SettingsPage` 把 `const ProfileHeader()` 放在列表的第一个子项，因此它在单窗格和双窗格布局中都会出现（[`../../settings/views/settings_page.md`](../../settings/views/settings_page.md)）。见 [`profile_avatar.md`](profile_avatar.md)、[`../providers/profile_provider.md`](../providers/profile_provider.md) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `ProfileHeader` | 构造函数（`ProfileHeader`） | B | 创建个人资料头部。 |
| [`ProfileHeader.build`](#profileheaderbuild) | 方法（`ProfileHeader`，组件构建） | A | 构建可点击的头像加名称行。 |
| [`showProfileEditDialog`](#showprofileeditdialog) | 顶层函数 | A | 打开编辑名称和头像的对话框。 |
| `_ProfileDialog` | 构造函数（`_ProfileDialog`） | B | 创建编辑对话框。 |
| `_ProfileDialog.createState` | 方法（组件生命周期） | B | 创建对话框状态。 |
| `_ProfileDialogState.initState` | 方法（组件生命周期） | B | 用当前个人资料预填名称输入框。 |
| `_ProfileDialogState.dispose` | 方法（组件生命周期） | B | 释放文本控制器。 |
| [`_ProfileDialogState._run`](#_run) | 方法（`_ProfileDialogState`） | A | 以忙碌状态和错误报告运行一个头像操作。 |
| [`_ProfileDialogState._save`](#_save) | 方法（`_ProfileDialogState`） | A | 保存名称并关闭。 |
| `_ProfileDialogState.build` | 方法（组件构建） | B | 构建对话框。 |

## ProfileHeader.build

- **返回：** 一个 `ListTile`：leading 是 `ProfileAvatar(radius: 28)`，标题是名称（没有名称时是 `profileNamePlaceholder`“设置你的名称”，使用柔和的 `onSurfaceVariant` 颜色），副标题是 `profileEditHint`，trailing 是编辑图标。点击调用 `showProfileEditDialog(context)`。
- **备注：** 只监听名称（`profileProvider.select((p) => p.name)`）。

## showProfileEditDialog

- **副作用：** 显示对话框；头像更改立即保存，名称在点击**保存**时保存。
- **备注：** 必须在 `ProviderScope` 之下调用。

## 对话框布局

一个标题为 `profileTitle` 的 `AlertDialog`，包含大号 `ProfileAvatar(radius: 48)`；一个“选择头像”`FilledButton.tonalIcon`（`profileChangeAvatar`），以及仅在已设置头像时出现的“移除”按钮（`profileRemoveAvatar`）；还有名称 `TextField`（`profileName`，`maxLength: 40`，提交即保存）。操作按钮是**取消**和**保存**。`_busy` 期间一切禁用。

## _run

- **副作用：** 设置 `_busy`，等待该操作，出现任何错误时显示带 `profileAvatarError`（“无法使用此图片”）的 `SnackBar`。用于选择和移除头像。

## _save

- **副作用：** 设置 `_busy`，调用 `ProfileNotifier.setName(text)`（由存储去除首尾空白；为空则清除名称；名称未变则不写入），然后关闭对话框。
