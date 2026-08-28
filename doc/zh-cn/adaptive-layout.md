# 自适应布局

这是全应用范围的规则，规定**布局何时可以拆分**——在动画详情页拆成两栏，或在三个数据浏览模块中拆成多列——
以及一旦可以拆分时**分成几列**。两者都位于
[`lib/shared/utils/adaptive_layout.dart`](functions/shared/utils/adaptive_layout.md)，该模块刻意只依赖
`dart:core`，因此每一项决策都可以脱离控件树直接进行单元测试。

在本文件存在之前，该规则只存在于详情页自己的辅助函数里，读起来像是详情页专属的规则。它不是：同样的三个阈值
现在也用于门控多列列表，因此同一台设备在应用各处给出一致的答案。

## 何时拆分

当**以下三项全部**成立时拆分：

| 常量 | 值 | 含义 |
|---|---|---|
| `splitMinWidth` | `600.0` | Material 的 *medium* 宽度等级；Android 的 `sw600dp`。 |
| `splitMinHeight` | `480.0` | compact/medium 高度等级的分界。 |
| `splitMinAspect` | `0.82` | 宽度除以高度。 |

```dart
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}
```

每一个条件都有其存在的理由，任何一个单独都不够。

### 宽高比测试是承重的那一项

**这正是它不是一个单纯宽度断点的原因，而 Galaxy Z Fold 8 是它必须存在的原因。** Fold 8 展开后是 4:3 的**横向**
面板（2448 × 1848 px），因此竖持时它是 3:4——**相对其高度比它所替代的近方形 Fold 7 更窄**，尽管它更新；而
Fold 8 Ultra 则走向了另一个方向。如今同一代产品展开后横跨大约 672 到 954 逻辑像素，并且有一台设备需要在同一
个宽度下给出两个不同的答案。

像素数是权威依据；逻辑像素取决于密度分档以及三星可由用户调整的**显示大小**设置，因此下表给出一个合理区间。

| 设备 | 内屏，px | 竖屏宽高比 | 竖屏宽度，dp | 竖屏 | 横屏 |
|---|---|---|---|---|---|
| Galaxy Z Fold 5 | 1812 × 2176 | 0.83 | 659–690 | 拆分 | 拆分 |
| Galaxy Z Fold 6 | 1856 × 2160 | 0.86 | 675–707 | 拆分 | 拆分 |
| Galaxy Z Fold 7 | 1968 × 2184 | 0.90 | 716–750 | 拆分 | 拆分 |
| **Galaxy Z Fold 8** | **2448 × 1848（4:3 横向）** | **0.755** | **672–704** | **单列** | **拆分** |
| Galaxy Z Fold 8 Ultra | 2256 × 2504 | 0.90 | 820–859 | 拆分 | 拆分 |
| Pixel 9 / 10 Pro Fold | 2076 × 2152 | 0.96 | 755–791 | 拆分 | 拆分 |

`0.82` 位于 Fold 8 竖屏的 `0.755` 与 Fold 7 / Fold 8 Ultra 竖屏的 `0.90` 之间的中段，两侧各留约 9% 余量。
`720` 这个阈值——`kana_page.dart` 用于它自己那条无关规则的取值——会直接让 Fold 8、Fold 5 和 Fold 6 全部落选；
`840` 则只会剩下 Ultra。

### 宽度下限

即便在区间中密度较高的一端，每一块展开面板也都至少高出 600 dp 达 59 dp；而每一块折叠状态的外屏都远在其下：
Z Fold 7 / 8 Ultra 约 360 dp，Z Fold 8 约 356–416 dp，Pixel 10 Pro Fold 约 411 dp。

### 高度下限

单靠宽高比测试会放行*又宽又矮*的视口。没有这个下限，折叠状态的 Z Fold 8 外屏横过来（约 657 × 416 dp）以及
普通手机横持（约 915 × 412 dp）都会被拆成两个局促的分栏。Google 独立地给出了同样的建议：手机或展开的上下折
叠机横持时，窗口宽度通常是 medium 而高度是 compact，双栏布局在那里并不实用。

### 值得知道的推论

该规则依据**形状而非设备类别**，因此 4:3 平板竖屏（768 × 1024 → 0.75）和 16:10 平板竖屏（0.625）同样保持单
列，与 Fold 8 竖屏完全一致。两者都在横屏时拆分。

## 分成几列

一旦允许拆分，列数由列表实际获得的宽度决定：

```dart
int listColumnCapacity(double contentWidth) =>
    ((contentWidth + listTileGap) / (listTileMinWidth + listTileGap))
        .floor()
        .clamp(1, listMaxColumns);
```

其中 `listTileMinWidth = 320.0`、`listTileGap = 12.0`、`listMaxColumns = 4`。这就是 Google 为 feed 布局推荐
的自适应最小宽度做法——在空间允许的范围内容纳尽可能多的、不低于某个最小宽度的列——而不是为每个断点写死一个
列数。320 dp 是列表条目在其 40 × 56 封面、两行文字和最多两个尾部图标按钮把标题挤到无处容身之前所需要的宽度。

`listColumnCount` 把两者结合起来：`canSplitLayout` 为假时返回一列；否则在用户偏好为 `listColumnsAuto` 时返回
容量；否则返回被容量钳制后的偏好值。采用钳制而非拒绝，正是让在桌面端设定的偏好能够在被带到折叠状态的手机上
存活下来，并在展开时回来的原因。

| 视口 | 是否拆分 | 容量 | 自动时的列数 |
|---|---|---|---|
| Z Fold 8 横屏 933 × 704 | 是 | 2 | 2 |
| Z Fold 8 竖屏 704 × 933 | 否 | — | 1 |
| Z Fold 7 750 × 832 / 832 × 750 | 是 | 2 | 两种方向均为 2 |
| Z Fold 8 Ultra 859 × 954 / 954 × 859 | 是 | 2 | 两种方向均为 2 |
| 平板 1024 × 768 | 是 | 3 | 3 |
| 平板 768 × 1024 | 否 | — | 1 |
| 手机横屏 915 × 412 | 否 | — | 1 |
| 桌面 1600 × 900 | 是 | 4 | 4 |

条目按**从左到右、然后从上到下**排布。至于为什么这是一个基于行的构建器而非 `GridView`，见
[`functions/shared/widgets/adaptive_tile_grid.md`](functions/shared/widgets/adaptive_tile_grid.md)。

## 门控量屏幕，容量量内容

`canSplitLayout` 读取 `MediaQuery.sizeOf(context)`——整块屏幕。`listColumnCapacity` 以及详情页的分栏尺寸计算
读取内容实际获得的宽度。这种不对称是刻意的：若以 `Scaffold` 主体来衡量拆分决策，会从高度中减去应用栏并抬高
比值，把竖持的 Z Fold 8 读成 `0.80` 而非 `0.755`，几乎不给阈值留下任何余量。

## 折叠与展开

`android/app/src/main/AndroidManifest.xml` 在 activity 的 `configChanges` 中声明了
`screenLayout|screenSize|smallestScreenSize|density`，因此折叠或展开会调整窗口大小而**不重启 activity**。所有
读取 `MediaQuery.sizeOf` 的代码都会在下一帧重新求值，而这正是"设备展开时自动切换"所需要的全部——不需要生命
周期处理，也没有需要保存和恢复的状态。

## 该规则用在哪里、不用在哪里

| 调用点 | 是否使用该规则 |
|---|---|
| `anime_detail_page.dart` | 是，通过 `useDetailTwoPane`——一个转发到 `canSplitLayout` 的单行委托。 |
| `home_page.dart`、`management_page.dart`、`statistics_page.dart` | 是，通过 `listColumnCount`。 |
| `kana_page.dart` | **否。** |

`kana_page.dart` 为它的双列卡片 `Wrap` 保留了自己内联的 `constraints.maxWidth >= 720`，它早于本模块存在，且
被刻意保持原样。让它走 `canSplitLayout` 会改变它在平板竖屏下的行为——720 × 1280 目前给出两列，而宽高比规则会
给出一列——这是一项没有人要求过的、用户可见的改动。此处记录下来，是为了让这个不一致成为一个已知例外，而不是
将来的一个发现。

## 与 Google 规范的分歧

Google 的自适应布局规范称窗口尺寸等级"明确不由设备屏幕尺寸决定"、"并非用于 *isTablet* 式的逻辑"，并要求应用
依据可用宽度而非宽高比来决策。本应用在一点上**刻意分歧**：宽高比测试。这不是疏忽。单靠宽度无法让 Fold 8 在
两种方向下给出两个不同的答案，而这一行为——横屏拆分、竖屏保持原本的单列——正是该规则存在所要满足的需求。宽度
与高度下限完全遵循 Google 的断点，列容量也完全遵循其 feed 规范。

## 测试

- `test/adaptive_layout_test.dart`——门控、容量、偏好钳制以及行数计算，全部固定在上述表格中每一台设备真实的
  逻辑像素几何上，并在注释中写明设备名，这样一次回归就能报出它会弄坏的那台设备。它还断言
  `useDetailTwoPane` 与 `canSplitLayout` 仍然一致，因此这层委托不会悄悄漂移。
- `test/detail_layout_test.dart`——详情页的分栏与封面尺寸计算。
- `test/list_columns_ui_test.dart` 与 `test/detail_layout_ui_test.dart`——渲染结果，在相同几何下驱动真实页面。
