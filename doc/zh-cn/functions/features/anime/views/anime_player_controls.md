# lib/features/anime/views/anime_player_controls.dart

应用自己的播放控件（1.6.5），在所有平台上绘制于原生视频之上，取代 media_kit 自带的控件。该组件不导入
media_kit：它驱动一个 `AnimeNativePlayer` 和一个可选的 `AnimeFullscreenHost`，因此测试可以用替身运行它。见
[`../../../../features/watch-url-lookup.md`](../../../../features/watch-url-lookup.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `boostedPlaybackRate` | 函数 | B | 按住长按期间的速度：加快一档，至多 3.0。 |
| [`dragSeekTarget`](#dragseektarget) | 函数 | A | 把一次水平滑动映射为目标位置。 |
| `formatPlaybackRate` | 函数 | B | 把速度格式化为 `1.0x` 之类的形式。 |
| `AnimePlayerControls` | 构造函数 | B | 创建覆盖层。 |
| `createState` | 方法 | B | 创建覆盖层状态。 |
| `initState` | 方法 | B | 读取播放器状态并跟随其流。 |
| `dispose` | 方法 | B | 取消计时器和订阅；从不触碰播放器。 |
| `_update` | 方法 | B | 在仍挂载时应用状态变更。 |
| `_show` | 方法 | B | 显示控件，可选择安排自动隐藏。 |
| `_restartHideTimer` | 方法 | B | 播放时 3 秒后隐藏，拖动或拖动进度条时除外。 |
| `_seekTo` | 方法 | B | 跳转到限制在时长范围内的位置。 |
| `_seekBy` | 方法 | B | 从当前位置跳转。 |
| `_togglePlay` | 方法 | B | 切换播放/暂停。 |
| `_selectRate` | 方法 | B | 从菜单选择速度并报告给页面。 |
| `_startBoost` | 方法 | B | 开始长按加速。 |
| `_endBoost` | 方法 | B | 恢复长按前的速度。 |
| `_onKey` | 方法 | B | 桌面快捷键：Space、← / →、F、Esc。 |
| [`build`](#build) | 方法 | A | 绘制手势层、控件和临时标签。 |
| `_buildGestureLayer` | 方法 | B | 用于单击、双击、长按和滑动的全尺寸层。 |
| `_buildTopBar` | 方法 | B | 仅全屏时显示的标题行，带退出按钮。 |
| `_buildCenterRow` | 方法 | B | 后退 5 秒、播放/暂停、前进 5 秒。 |
| `_buildBottomBar` | 方法 | B | 时间、进度条、播放速度菜单和全屏按钮。 |
| `_buildDragLabel` | 方法 | B | 滑动预览，如 `12:34 / 23:40 (+15s)`。 |
| `_Badge` | 构造函数 | B | 创建深色圆角标签。 |
| `_Badge.build` | 方法 | B | 绘制该标签。 |

`animePlaybackRates`（0.25、0.5、1.0、1.5、2.0、3.0）、`animeMaxPlaybackRate`（3.0）、
`animeSeekStep`（5 秒）、`animeDragSeekSpan`（90 秒）和 `animeControlsHideDelay`（3 秒）没有
`/// Purpose:` 注释。

## dragSeekTarget

- **算法：** 滑过整个宽度对应媒体长度与 90 秒中较短者，因此在 24 分钟的一集上，手机上的滑动仍保持精细；
  结果限制在 `[0, duration]` 内。时长未知或宽度为零时返回起始位置。

## build

- **备注：** 手势层是 `Stack` 最底层的子组件，位于按钮和进度条之下，因此滑块自身的拖动从不与滑动跳转争抢。
  中间一行为 `MainAxisSize.min`，因此点击其两侧会到达手势层。单击切换显示（延迟一个双击判定窗口），双击播放或暂停，
  长按期间设置 `boostedPlaybackRate` 直到松手并显示一个标签，水平滑动预览目标并在松手时跳转一次。
  时长未知时进度条和 ±5 秒按钮处于禁用状态。在桌面上鼠标悬停会显示控件。
