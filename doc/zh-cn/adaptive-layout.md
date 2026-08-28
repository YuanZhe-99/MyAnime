# 自适应布局

这是全应用范围内关于**布局何时可以拆分**的规则——拆成动画详情页与设置页的两栏，或拆成三个数据浏览模块与
假名页的多列——以及一旦可以拆分后**分几列**。另有一条更窄的规则决定**导航放在哪里**。两者都位于
[`lib/shared/utils/adaptive_layout.dart`](functions/shared/utils/adaptive_layout.md)，该模块刻意只导入
`dart:core`，因此每一个判定都可以在没有控件树的情况下直接进行单元测试。

在本文件存在之前，该规则只活在详情页自己的辅助函数里，读起来像是一条详情页专属的规则。它不是：同样的三个阈值
现在同时门控多列列表、假名页与设置页分栏，因此同一台设备在应用各处都给出同样的答案。

## 何时拆分

以下**三条全部**成立时才拆分：

| 常量 | 取值 | 含义 |
|---|---|---|
| `splitMinWidth` | `600.0` | Material 的 *medium* 宽度类；Android 的 `sw600dp`。 |
| `splitMinHeight` | `480.0` | compact 与 medium 高度类的边界。 |
| `splitMinAspect` | `0.82` | 宽度除以高度。 |

```dart
bool canSplitLayout(double width, double height) {
  if (width < splitMinWidth) return false;
  if (height < splitMinHeight) return false;
  if (height <= 0) return false;
  return width / height >= splitMinAspect;
}
```

每一个条件都有其存在的理由，且任何一条单独都不够。

### 宽高比测试是承重的那一项

**它正是这条规则不是一个单纯宽度断点的原因，而 Galaxy Z Fold 8 是它必须存在的原因。** Fold 8 展开后是 4:3 的
**横向**面板（2448 × 1848 px），因此竖持时它是 3:4——**相对其高度比它所替代的近方形 Fold 7 更窄**，尽管它更
新——而 Fold 8 Ultra 却走向了相反的方向。同一代产品展开后现在横跨约 672 到 954 逻辑像素，于是一台设备需要在
同一个宽度下给出两个不同的答案。

像素数是权威依据；逻辑像素取决于密度桶以及三星那个用户可调的**显示尺寸**设置，因此这里给出一个合理区间。

| 设备 | 内屏面板，px | 竖持宽:高 | 竖持宽度，dp | 竖持 | 横持 |
|---|---|---|---|---|---|
| Galaxy Z Fold 5 | 1812 × 2176 | 0.83 | 659–690 | 拆分 | 拆分 |
| Galaxy Z Fold 6 | 1856 × 2160 | 0.86 | 675–707 | 拆分 | 拆分 |
| Galaxy Z Fold 7 | 1968 × 2184 | 0.90 | 716–750 | 拆分 | 拆分 |
| **Galaxy Z Fold 8** | **2448 × 1848（4:3 横向）** | **0.755** | **672–704** | **单栏** | **拆分** |
| Galaxy Z Fold 8 Ultra | 2256 × 2504 | 0.90 | 820–859 | 拆分 | 拆分 |
| Pixel 9 / 10 Pro Fold | 2076 × 2152 | 0.96 | 755–791 | 拆分 | 拆分 |

`0.82` 位于 Fold 8 竖持的 `0.755` 与 Fold 7 / Fold 8 Ultra 竖持的 `0.90` 之间那道空隙的中部附近，两侧各留出
约 9% 的余量。`720` 这样的阈值会直接把 Fold 8、Fold 5 与 Fold 6 一并挡在门外；`840` 则只会剩下 Ultra。

### 宽度下限

即便在密度区间较密的一端，每一块展开面板也都至少超出 600 dp 达 59 dp，而每一块折叠状态的外屏都远在其下：
Z Fold 7 / 8 Ultra 约 360 dp，Z Fold 8 约 356–416 dp，Pixel 10 Pro Fold 约 411 dp。

### 高度下限

单靠宽高比测试会放行*又宽又矮*的视口。没有这条下限，一台折叠状态、旋转到横向的 Z Fold 8 外屏
（约 657 × 416 dp）以及一台普通手机横持（约 915 × 412 dp）都会被拆成两个逼仄的栏。Google 独立地给出了同样的
建议：对于手机或展开的翻盖机横持，窗口宽度通常是 medium 而高度是 compact，两栏布局在那里并不实用。

### 值得知道的一个后果

这条规则针对的是**形状而非设备类别**，因此 4:3 平板竖持（768 × 1024 → 0.75）与 16:10 平板竖持（0.625）同样
保持单栏，与 Fold 8 竖持完全一样。两者横持时都会拆分。

## 分几列

一旦允许拆分，列数取决于内容实际获得的宽度以及每列的最小宽度：

```dart
int columnCapacity(
  double contentWidth, {
  required double minItemWidth,
  double gap = listTileGap,
  int maxColumns = listMaxColumns,
}) => ((contentWidth + gap) / (minItemWidth + gap))
        .floor()
        .clamp(1, maxColumns);
```

这是 Google 为 feed 布局推荐的自适应最小宽度做法——在空间允许的范围内塞下尽可能多的、不低于某个最小宽度的
列——而非为每个断点写死一个列数。每个调用方带来自己内容所需要的那个最小值：

| 调用方 | 最小宽度 | 上限 | 该数字的由来 |
|---|---|---|---|
| 动画列表（`listColumnCapacity`） | `320` | 4 | 列表条目在其 40 × 56 封面、两行文字和最多两个尾部图标按钮把标题挤到无处容身之前所需要的宽度。 |
| 假名表 | `330` | 2 | 五列表格要为行标签花掉 44，因此 330 每格约留 57——与同一张表在手机单列下所得持平。 |
| 假名规则卡 | `320` | 2 | 段落式卡片；第三列会让行宽低于舒适的阅读尺度。 |

`listColumnCount` 把门控与容量合起来：`canSplitLayout` 为假时返回 1，否则在用户偏好为 `listColumnsAuto` 时
返回容量，再否则返回被钳制到容量的偏好值。钳制而非拒绝，正是让在桌面端设定的偏好能在被带到折叠状态的手机上
存活下来、并在展开时回来的原因。

内容宽度是 `shellContentWidth(screenWidth)` 再减去页面自身的内边距——参见
[下面一节](#门控量屏幕容量量内容)。

| 视口 | 是否拆分 | 列表内容宽 | 动画列表列数 | 假名表列数 |
|---|---|---|---|---|
| Z Fold 8 横向 933 × 704 | 是 | 852 | 2 | 2 |
| Z Fold 8 竖向 704 × 933 | 否 | — | 1 | 1 |
| Z Fold 8 Ultra 954 × 859 / 859 × 954 | 是 | 873 / 778 | 2 / 2 | 2 / 2 |
| Pixel 10 Pro Fold 791 × 820 | 是 | 710 | 2 | 2 |
| Z Fold 7 832 × 750 / 750 × 832 | 是 | 751 / 669 | 2 / 2 | 2 / 1 |
| Z Fold 6 675 × 786 · Z Fold 5 659 × 791 | 是 | 594 / 578 | 1 / 1 | 1 / 1 |
| 平板 1024 × 768 | 是 | 943 | 2 | 2 |
| 平板 768 × 1024 | 否 | — | 1 | 1 |
| 手机横持 915 × 412 | 否 | — | 1 | 1 |
| 桌面 1600 × 900 | 是 | 1519 | 4 | 2 |

**平板横持现在得到两列动画列表，而 1.5.3 给的是三列。** 导航栏从它的 1024 中取走了 81，而剩下的 943 若分三
列则每列 306 宽——低于 320 这个最小值。变的是空间，不是规则。

条目按**从左到右、然后从上到下**排布。至于那为什么是一个基于行的构建器而非 `GridView`，见
[`functions/shared/widgets/adaptive_tile_grid.md`](functions/shared/widgets/adaptive_tile_grid.md)。

## 导航放在哪里

这是**第二条规则，并且刻意更窄**：

```dart
bool useNavigationRail(double screenWidth) => screenWidth >= navRailMinWidth; // 600.0
```

在其之上，外壳沿侧边渲染一个 `NavigationRail`；在其之下则是它一直以来的底部 `NavigationBar`。两者都由
[`shell_scaffold.dart`](functions/shared/widgets/shell_scaffold.md) 中同一份目的地列表构建，因此不可能彼此
走样。侧边导航栏将其目的地**居中**（`groupAlignment: 0`）而非采用默认的顶部对齐：顶部对齐是为了让导航栏坐落
在一个前导菜单按钮或 FAB 之下，而这里两者都没有，于是五个目的地挤在一条 704 dp 高的导航栏顶端会让它整个下半
部分空着。

**这里只看宽度是刻意的，绝不可改为走 `canSplitLayout`。** 侧边导航栏不是一次拆分。它拿宽度——在这个测试通过时
总是充裕的那一维——去换高度，而高度并不充裕。它帮助最大的那个情形，恰恰是拆分规则刻意拒绝的那个：一台普通
手机横持于 915 × 412，底栏在此花掉 19% 的高度用于导航，而 915 逻辑像素的宽度闲置着。Z Fold 8 横向时窗口也
只有 704 高，同样的交换成立。

有两个后果会贯穿应用其余部分：

- `shellContentWidth(screenWidth)` 在侧边导航栏显示时减去 `navRailWidth`（81 = 80 dp 的导航栏加其 1 dp 的
  分隔线）。每一处容量都由此测量，绝不使用未经处理的屏幕宽度。
- `shellListBottomInset(screenWidth)` 在没有底栏时，把滚动页面为底栏预留的 80 dp 降到 16——否则这份预留恰好
  会在垂直空间最紧缺的时刻变成一片死区。

刻意没有做：在 1240 dp 以上使用 `NavigationDrawer`。侧边导航栏在这里直到 extra-large 都是正确的，而第三种导航
形态不值得它的代价。

## 门控量屏幕，容量量内容

`canSplitLayout` 与 `useNavigationRail` 读取 `MediaQuery.sizeOf(context)`——整块屏幕。而容量与栏宽读取内容
实际获得的宽度。这份不对称是刻意的，出于两个彼此独立的理由：

- 拿 `Scaffold` 的 body 来量拆分判定，会从高度中减去应用栏并抬高比值，把 Z Fold 8 竖持读成 `0.80` 而不是
  `0.755`，在阈值之下几乎不留余量。
- 门控问的是窗口的*形状*，而侧边导航栏并不改变形状。容量问的是还剩多少空间，而侧边导航栏对此影响甚大。

## 折叠与展开

`android/app/src/main/AndroidManifest.xml` 在其 activity 的 `configChanges` 中声明了
`screenLayout|screenSize|smallestScreenSize|density`，因此折叠或展开会调整窗口尺寸而**不重启 activity**。于是
一切读取 `MediaQuery.sizeOf` 的代码都会在下一帧重新求值，这正是"设备展开时自动切换"所需要的全部——不需要生命
周期处理，也没有状态需要保存与恢复。

## 这些规则用在哪里

| 调用点 | 拆分规则 | 备注 |
|---|---|---|
| `anime_detail_page.dart` | 是 | 经由 `useDetailTwoPane`，一个转发到 `canSplitLayout` 的单行委托。 |
| `home_page.dart`、`management_page.dart`、`statistics_page.dart` | 是 | 经由 `listColumnCount`。 |
| `settings_page.dart` | 是 | 两栏：左边一级列表，右边它所通向的二级页面。 |
| `kana_page.dart` | 是 | 先由 `canSplitLayout` 门控，再看两张 330 dp 的表是否放得下。 |
| `shell_scaffold.dart` | 否——`useNavigationRail` | 只看宽度；见上文。 |

**1.5.3 在此记录的那条 `kana_page.dart` 例外已经解除。** 它曾为规则卡的双列 `Wrap` 带着自己内联的
`constraints.maxWidth >= 720`，当时被刻意放过，因为改动它会改变没有人问起过的平板竖持行为。而 1.5.4 把它接入
`columnCapacity` 之后，结果是**保住**了那个行为而非改变它：侧边导航栏使平板竖持只剩 655 dp 的规则宽度，那个
`720` 字面量会在此落空，而共用的算式则通过。`lib/` 中不再有第二条布局规则。

## 与 Google 规范的分歧

Google 的自适应布局规范称窗口尺寸类"明确地不由设备屏幕的尺寸决定"，且"不打算用于 *isTablet* 那类逻辑"，并
指引应用依据可用宽度而非宽高比来做判断。本应用在一点上**刻意分歧**：宽高比测试。这不是疏漏。单靠宽度无法让
Fold 8 在其两个方向上给出两个不同的答案，而那个行为——横持拆分、竖持保持原本的单栏——正是这条规则存在所要
满足的需求。

其余一切都严格遵循 Google：宽度与高度下限就是它的断点，列容量就是它的 feed 规范，而 medium 宽度及以上使用
侧边导航栏更是它的原话。

## 测试

- `test/adaptive_layout_test.dart`——门控、导航栏规则、内容宽度、容量、偏好钳制、设置栏宽以及行数运算，全部
  钉在上表中每一台设备的真实逻辑像素几何上，并在注释中写明设备名，这样一次回归会说出它会弄坏的那台设备。它
  还断言 `useDetailTwoPane` 与 `canSplitLayout` 仍然一致，使这条委托无法悄然走样。
- `test/detail_layout_test.dart`——详情页的栏宽与封面尺寸。
- `test/list_columns_ui_test.dart`、`test/detail_layout_ui_test.dart`、`test/kana_layout_ui_test.dart`、
  `test/settings_two_pane_ui_test.dart` 与 `test/shell_nav_ui_test.dart`——在同样的几何下，通过真实页面驱动
  出来的渲染结果。

`flutter_test` 把其默认字体的每一个字形都渲染成一个完整的 em 方块，这会把一个标签的宽度抬高到其真实宽度的约
两倍半。这正是 `settings_two_pane_ui_test.dart` 以简体中文运行的原因：英文选项标签会在测试环境——且仅在测试
环境——撑破它们所在的行，而较短的中文标签让测试量到的是真实布局，而不是围着一个假的布局去过滤错误。
