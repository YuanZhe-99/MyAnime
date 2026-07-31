# lib/features/settings/views/license_page.dart

`LicensePage` 是从设置 -> 关于 -> 许可证到达的一个极小的、完全静态的设置子页（见 `functions/features/settings/views/settings_page.md`）。它没有状态、没有服务依赖：整个页面是一个渲染单个硬编码 `SelectableText` 块（保存项目 GPLv3 许可证声明，存储为私有 `_licenseText` 静态 const `String` 字段）的 `StatelessWidget`。本文件没有 Tier A 逻辑——它纯粹为显示静态文本而存在，与 `settings_page.dart` 别处经 `showLicensePage` 到达的生成第三方许可证页不同。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `LicensePage({super.key})` | 构造函数（`LicensePage`） | B | 创建许可证页实例。 |
| `build` | 方法（组件构建） | B | 在可滚动、可选择视图中渲染静态 GPLv3 许可证文本。 |

## 文档

本文件没有 Tier A 声明——两个成员都是 Tier B（平凡构造函数和一个只在静态 `_licenseText` 字段周围布局 `Scaffold`/`SelectableText` 的 `build` 方法）。完整成员列表见上方声明表。
