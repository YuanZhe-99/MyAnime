# lib/shared/services/image_service.dart

`ImageService` 集中封面图在磁盘上的存储，位于 `<应用目录>/images/` 下。它是从设备选择图像、从 URL 下载图像、把存储的相对路径解析为绝对 `File`、以及删除不再被引用的图像的唯一地方。动画编辑/搜索流程用它附加封面图，[`share_service.md`](share_service.md) 和 [`file_open_service.md`](file_open_service.md) 用它读取封面文件做分享图像生成和 `.myanimeitem` 导出/导入。导出的封面如何以 base64 嵌入见 [`../../../features/share-and-import.md`](../../../features/share-and-import.md)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`_getImageDir`](#_getimagedir) | 方法（`ImageService`） | A | 取（需要时创建）应用的 `images/` 目录。 |
| [`pickAndSaveImage`](#pickandsaveimage) | 方法（`ImageService`） | A | 让用户选择图像文件并复制进应用存储。 |
| [`resolve`](#resolve) | 方法（`ImageService`） | A | 把相对图像路径（如 `images/xxx.png`）解析为绝对 `File`。 |
| [`saveImageFromUrl`](#saveimagefromurl) | 方法（`ImageService`） | A | 从 URL 下载图像并保存进应用存储。 |
| [`delete`](#delete) | 方法（`ImageService`） | A | 删除先前保存的图像文件。 |

## 文档

### `static Future<Directory> _getImageDir()` <a id="_getimagedir"></a>
- **种类：** `ImageService` 的静态方法
- **来源：** `lib/shared/services/image_service.dart`（约第 16 行）
- **用途：** 返回应用的 `images/` 子目录，尚不存在时先创建。
- **输入：** 无。
- **返回：** `Future<Directory>` — 应用数据目录（`AnimeStorage.getAppDir()`）下的 `images/` 目录。
- **副作用：** 可能创建磁盘上的 `images/` 目录（`recursive: true`）。
- **算法：**
  1. 经 `AnimeStorage.getAppDir()` 解析应用数据目录。
  2. 拼接 `images` 得到目标 `Directory`。
  3. 尚不存在时递归创建它。
  4. 返回目录。
- **用法：** 由 [`pickAndSaveImage`](#pickandsaveimage) 和 [`saveImageFromUrl`](#saveimagefromurl) 内部调用；不暴露给本文件之外。
- **备注：** 无。

### `static Future<String?> pickAndSaveImage()` <a id="pickandsaveimage"></a>
- **种类：** `ImageService` 的静态方法
- **来源：** `lib/shared/services/image_service.dart`（约第 30 行）
- **用途：** 打开限制为图像的平台文件选择器，并把所选文件以基于新 UUID 的名称复制进应用存储。
- **输入：** 无。
- **返回：** `Future<String?>` — 新的相对路径（如 `"images/<uuid>.png"`），用户取消选择器时为 `null`。
- **副作用：** 显示操作系统文件选择器；把所选文件复制进 `<应用目录>/images/`。
- **算法：**
  1. 调用 `FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false)`。
  2. 结果 null/空或所选路径为 null 时返回 `null`。
  3. 确保 `images/` 目录存在（经 `_getImageDir`）。
  4. 构建新文件名 `"<uuid.v4()><original extension>"`。
  5. 把所选文件复制到该目标并返回相对 `images/<name>` 路径。
- **用法：**
  ```dart
  final path = await ImageService.pickAndSaveImage();
  ```
  （来自 `lib/features/anime/views/anime_edit_page.dart`，用户点"从设备选择"时设置封面图）
- **备注：** 无。

### `static Future<File> resolve(String relativePath)` <a id="resolve"></a>
- **种类：** `ImageService` 的静态方法
- **来源：** `lib/shared/services/image_service.dart`（约第 52 行）
- **用途：** 把存储在 `Anime` 记录上的相对图像路径（如 `coverImage`）解析为应用数据目录下的绝对 `File`。
- **输入：** `relativePath` — 像 `"images/<uuid>.jpg"` 的路径，通常是 `Anime.coverImage` 值。
- **返回：** `Future<File>` — 绝对文件（本方法自身不检查存在性）。
- **副作用：** 无（纯路径拼接；调用方通常自己检查 `.existsSync()`/`.exists()`）。
- **算法：** 把 `AnimeStorage.getAppDir()` 与 `relativePath` 拼接并包进 `File`。
- **用法：**
  ```dart
  future: ImageService.resolve(anime.coverImage!),
  ```
  （来自 `lib/features/anime/views/anime_detail_page.dart`，并在动画列表、主页日历、统计和分享图像代码中渲染封面缩略图的任何地方复用）
- **备注：** 不校验文件是否存在；之后读取文件的每个调用方都先用存在性检查守卫（见 [`share_service.md`](share_service.md) 的封面加载逻辑）。

### `static Future<String?> saveImageFromUrl(String url)` <a id="saveimagefromurl"></a>
- **种类：** `ImageService` 的静态方法
- **来源：** `lib/shared/services/image_service.dart`（约第 62 行）
- **用途：** 从远程 URL 下载图像并保存进应用存储，供只提供封面图像 URL 的动画搜索结果使用。
- **输入：** `url` — 源图像 URL。
- **返回：** `Future<String?>` — 新的相对路径（如 `"images/<uuid>.jpg"`），HTTP 响应非 200 时为 `null`。
- **副作用：** 执行 HTTP GET 请求（15 秒超时）；把下载字节写入 `<应用目录>/images/`。
- **算法：**
  1. 带 `User-Agent: MyAnime/0.1` 头和 15 秒超时 `GET` 该 URL。
  2. 响应状态不是 200 时返回 `null`。
  3. 从 URL 路径派生文件扩展名；空或长于 5 个字符时回退 `.jpg`（防止 URL 的"扩展名"实际是查询片段）。
  4. 构建新文件名 `"<uuid.v4()><ext>"`，把响应字节写入它，返回相对 `images/<name>` 路径。
- **用法：**
  ```dart
  final path = await ImageService.saveImageFromUrl(result.coverImageUrl!);
  ```
  （来自 `lib/features/anime/views/anime_search_dialog.dart`，用户添加搜索结果时把其封面图像本地保存）
- **备注：** 网络或解码失败与非 200 响应不区分——两者都以 `null` 返回浮出给调用方；没有重试。

### `static Future<void> delete(String relativePath)` <a id="delete"></a>
- **种类：** `ImageService` 的静态方法
- **来源：** `lib/shared/services/image_service.dart`（约第 82 行）
- **用途：** 删除先前保存的图像文件（如果仍存在）。
- **输入：** `relativePath` — 要移除的存储相对路径。
- **返回：** `Future<void>`。
- **副作用：** 存在时删除 `<应用目录>/images/` 下的文件。
- **算法：** 经 [`resolve`](#resolve) 解析路径；文件存在则删除；否则什么都不做。
- **用法：** 目前仓库其他地方不调用（供替换或移除封面图并想回收磁盘空间的调用方使用）；镜像 `AnimeStorage` 删除动画记录时内联使用的模式。
- **备注：** 文件已消失时静默空操作——调用方无需先检查存在性。
