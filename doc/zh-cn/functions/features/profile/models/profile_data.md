# lib/features/profile/models/profile_data.dart

P3：下文公共声明位于 `myapps_profile`；应用文件为重新导出或适配，
保留公开导入路径和构造器形式。
见 [../../../../shared-ui.md](../../../../shared-ui.md)。

`profile.json`（1.7.0）的内容：用户的名称和头像，同步到每台设备。每个字段都带自己的 UTC 时间戳，因此两台设备分别编辑不同字段时各自的更改都会保留，同一字段则以较新的编辑为准。未知键保存在 `extraJson` 中，因此旧构建不会删除新构建的数据。该文件是自己独立的同步模块——见 [`../../../app/data_modules.md`](../../../app/data_modules.md)、[`../../../../data-formats.md`](../../../../data-formats.md#profilejson) 和 [`../../../../features/profile.md`](../../../../features/profile.md)。

```json
{
  "version": 1,
  "displayName": "Yuan",
  "displayNameUpdatedAt": "2026-10-01T14:06:42.530801Z",
  "avatar": "images/avatar_2953ac52-337e-4271-a8e1-bcd97ee416ba.jpg",
  "avatarUpdatedAt": "2026-10-01T14:08:59.163627Z"
}
```

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `_unknown` | 函数 | B | 收集本构建不认识的 JSON 键。 |
| `_parseTime` | 函数 | B | 把可选时间戳解析为 UTC；缺失或格式错误时为 null。 |
| `ProfileData` | 构造函数 | B | 创建个人资料；时间戳规范化为 UTC。 |
| [`ProfileData.fromJson`](#profiledatafromjson) | 工厂 | A | 宽容地读取文件；拒绝非对象。 |
| [`ProfileData.toJson`](#profiledatatojson) | 方法 | A | 序列化；字段只有在有时间戳后才会写出。 |
| `ProfileData.name` | getter | B | 去除首尾空白的名称，没有时为 null。 |
| `ProfileData.withName` | 方法 | B | 带新名称和编辑时间的副本。 |
| `ProfileData.withAvatar` | 方法 | B | 带新（或已移除）头像和编辑时间的副本。 |

`ProfileData.currentVersion`（`1`）和六个字段（`version`、`displayName`、`displayNameUpdatedAt`、`avatar`、`avatarUpdatedAt`、`extraJson`）有各自的文档注释，但没有 `/// Purpose:` 块。`avatar` 是相对于应用目录的路径，形如 `images/avatar_<uuid>.jpg`。

## ProfileData.fromJson

- **备注：** 输入不是 JSON 对象时抛出 `FormatException`，同步模块的 `validate` 依赖这一点。对象内部是宽容的：类型错误的字段读作未设置，空的 `avatar` 字符串读作 null，非整数的 `version` 读作 `currentVersion`。时间戳用 `DateTime.tryParse(...).toUtc()` 解析。

## ProfileData.toJson

- **返回：** 先是 `extraJson`，然后是 `version`，仅当名称时间戳已设置时才有 `displayName` + `displayNameUpdatedAt`，仅当头像时间戳已设置时才有 `avatar` + `avatarUpdatedAt`。
- **备注：** 已移除的头像写成带时间戳的显式 `"avatar": null`，使移除操作得以同步，而不被当作“从未设置”。没有时间戳的字段整个省略，这就是“从未设置”的表示方式。
