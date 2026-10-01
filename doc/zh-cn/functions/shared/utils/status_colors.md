# lib/shared/utils/status_colors.dart

`StatusColors`（1.7.0）是一个 `abstract final class`，提供两种自带含义的观看状态的静态颜色辅助：已完成（成功）和已弃番（失败）。绿色和红色保留下来以便辨认，但它们由当前 `ColorScheme` 派生，遵循 Material 3 的自定义颜色指引，因此在浅色、深色和动态取色下都与界面其余部分处于同一色调家族。统计页用它们绘制摘要卡片、趋势图例和柱形（[`../../features/anime/views/statistics_page.md`](../../features/anime/views/statistics_page.md)），`ShareService` 则在自己固定的浅色配色上对它们求值（[`../services/share_service.md`](../services/share_service.md)）。配色方案本身见 [`../../app/theme.md`](../../app/theme.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `StatusColors` | abstract final class | B | 状态颜色的命名空间；从不实例化。 |
| [`StatusColors.completed`](#completed) | 静态方法 | A | 已完成动画的颜色。 |
| [`StatusColors.dropped`](#dropped) | 静态方法 | A | 已弃番动画的颜色。 |

## completed

- **输入：** `scheme`——该颜色将绘制于其上的配色方案。
- **返回：** `Color`——`Colors.green.harmonizeWith(scheme.primary)`（`dynamic_color` 扩展）。
- **备注：** 协调只会让色相朝主色轻微偏移，因此与已弃番的红色并列时仍然读作绿色。

## dropped

- **输入：** `scheme`。
- **返回：** `Color`——`scheme.error`。
- **备注：** 配色方案的 error 角色本身就是针对其亮度调好的红色。
