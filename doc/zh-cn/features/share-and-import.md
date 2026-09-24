# 分享与文件导入

`share_service.dart` 和 `file_open_service.dart` 覆盖应用的外向（分享/导出）和内向（文件打开/导入）流程。`.myanimeitem` JSON 格式本身见 [`../data-formats.md`](../data-formats.md)，导入期间复用的冲突解决逻辑见 [`duplicate-detection.md`](duplicate-detection.md)。

## `share_service.dart`

支持把动画分享为图像卡片、把当前统计排名导出/分享为图像，以及把当前统计摘要视图导出/分享为图像或数据文件。

- 分享流程先询问分享为**图像**、**数据文件**还是 **TXT** 名称列表。
- **图像卡片**包括封面图、标题、季/类型/日程、播出进度、备注、作为二维码的被选 info/watch URL、应用 logo 和 MyAnime!!!!! 水印。它们刻意**排除**本地存档记录——资料仓库代码和存档份数是用户自己的存储基础设施，不该出现在交给别人的卡片上。`share_service.dart` 中没有集中的"待绘制字段"清单；每个渲染器读取具名的 `anime.<field>` 属性，因此新字段默认就被排除，只要不把它加进 `infoLines` 块或排名/统计的 `detail` 列表就会一直如此。
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

- 导出经 `stripPersonalData`（1.6.0 之前为私有的 `_stripPersonalData`）从每条导出记录中剥离个人数据——`episodeStatuses`、`episodeWeekOffsets`、`localArchive`，以及自 1.6.0 起的 `seriesLink`。剥离存档记录的理由与观看字段不同：它泄露的不是发送者看了什么，而是发送者把东西存在哪里。手写文件中恰好带有 `localArchive` 时导入仍会带过，以便拷贝清单保持完整。
- `seriesLink` 在导入时不同：即使手写文件带有它（包括保留在 `extraJson` 中的无法解析的值）也会被**丢弃**。外来的 `seriesId` 在接收方片库中毫无意义，还会把记录钉在自动分组之外——见 [`series-linking.md`](series-linking.md)。
- `externalMeta`（公开的资料库信息）从不剥离，并自 1.6.0 起导入会带过它。更早的版本会导出它，却在导入时悄无声息地丢弃。
- 统计数据文件导出和 TXT 导出走同一套剥离，因此应用中没有任何分享界面会输出 `localArchive` 或 `seriesLink`。
- 导入总是为传入记录创建新 UUID，绝不覆盖既有动画；新记录由 `importedCopy`（[`../functions/shared/services/file_open_service.md`](../functions/shared/services/file_open_service.md#importedcopy)）构建。
- 多动画捆绑导入检测与既有本地记录的冲突（复用 [`duplicate-detection.md`](duplicate-detection.md) 的分组逻辑），并为每个冲突显示提供保留本地、使用导入或合并选项的对话框。
- 平台文件关联在 Android、iOS、macOS 和 Windows 上配置——各平台的确切注册细节见 [`../platform-notes.md`](../platform-notes.md)（尤其是 Windows 注册在 `installer.iss` 中）。
