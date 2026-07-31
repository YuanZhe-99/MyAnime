# 分享与文件导入

`share_service.dart` 和 `file_open_service.dart` 覆盖应用的外向（分享/导出）和内向（文件打开/导入）流程。`.myanimeitem` JSON 格式本身见 [`../data-formats.md`](../data-formats.md)，导入期间复用的冲突解决逻辑见 [`duplicate-detection.md`](duplicate-detection.md)。

## `share_service.dart`

支持把动画分享为图像卡片、把当前统计排名导出/分享为图像，以及把当前统计摘要视图导出/分享为图像或数据文件。

- 分享流程先询问分享为**图像**、**数据文件**还是 **TXT** 名称列表。
- **图像卡片**包括封面图、标题、季/类型/日程、播出进度、备注、作为二维码的被选 info/watch URL、应用 logo 和 MyAnime!!!!! 水印。
- **排名图像导出**包括当前排名过滤器、排序/方向、带封面缩略图和分数的排名动画行、应用 logo 和水印。排名导出只有图像——它不创建 `.myanimeitem` 数据文件。要渲染超过 50 个排名行时，会警告用户生成可能耗时，并可以设置行数限制；受限的排名导出保持当前排名顺序并取前 N 行。
- **统计摘要图像导出**顶部有一个显示已跟踪、已完成和弃看计数的水平条形图，随后是带封面缩略图、状态标签、进度和可选分数的动画行。生成前，用户可以选择包含哪些派生状态（completed、watching、dropped、not-started——默认全选），条形图反映最终渲染的行。要渲染超过 50 个摘要行时，会警告用户，并可以按首播日期最近/最早优先设置行数限制；图像生成在封面加载时显示进度对话框。
- **多页拆分：** 单页像素高度超过平台纹理尺寸上限（`share_service.dart` 中的 `_maxImageDimension = 16000`）时，统计和排名图像导出会拆分为多个 PNG 页，使高列表（如 200+ 动画）不再在右/下边缘被截断。每页重复页头（摘要条形图只出现在第 1 页）；水印只出现在最后一页。多页分享使用：
  - Android 经由 `shareFiles` `MethodChannel` 的 `ACTION_SEND_MULTIPLE`。
  - iOS 多文件 `Share.shareXFiles`。
  - 带全部保存操作的桌面可滚动多页预览。
- **统计数据文件导出**创建一个包含可见动画列表的 `.myanimeitem` 多动画捆绑（v2 格式——[`../data-formats.md`](../data-formats.md)），个人观看数据被剥离。
- **统计 TXT 导出**每行写一个动画显示名，按字典序排序，不含个人观看数据。与图像和数据文件导出在同一个统计分享对话框中可用。
- **Android** 使用名为 `com.yuanzhe.my_anime/share` 的自定义 `MethodChannel` 和 `FLAG_ACTIVITY_NEW_TASK`，因此分享目标在 MyAnime 任务栈之外打开。
- **iOS** 使用系统分享面板。
- **桌面**显示预览对话框，可以复制或保存生成的图像。

## `file_open_service.dart`

支持单个动画（v1）和多动画捆绑（v2）格式的 `.myanimeitem` 导出/导入——各版本的精确 JSON 形态见 [`../data-formats.md`](../data-formats.md)。

- 导出从每条导出记录中剥离个人观看数据（`episodeStatuses`、`episodeWeekOffsets`）。
- 导入总是为传入记录创建新 UUID，绝不覆盖既有动画。
- 多动画捆绑导入检测与既有本地记录的冲突（复用 [`duplicate-detection.md`](duplicate-detection.md) 的分组逻辑），并为每个冲突显示提供保留本地、使用导入或合并选项的对话框。
- 平台文件关联在 Android、iOS、macOS 和 Windows 上配置——各平台的确切注册细节见 [`../platform-notes.md`](../platform-notes.md)（尤其是 Windows 注册在 `installer.iss` 中）。
