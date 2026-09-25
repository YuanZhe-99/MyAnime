# lib/app/data_modules.dart

**本应用与共享 `myapps_data` 包之间的接缝**，也是 MyAnime 数据文件的唯一真实来源。应用以前携带的每个硬编码 `anime_data.json` 清单和备份模块映射，现在都从此处声明的注册表读取。自 1.6.2 起注册表包含两个模块：先是 `anime_data.json`，然后是 `recommendations.json`（推荐垃圾箱和相关推荐列表；见 [`../features/recommendations/services/recommendation_store.md`](../features/recommendations/services/recommendation_store.md)）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AnimeStorageAdapter`](#animestorageadapter) | 类 | A | 基于 `AnimeStorage` 实现包的 `StorageAdapter`。 |
| [`animeDataFileName`](#constants) | 常量 | A | `'anime_data.json'` — 本地和远程文件名。 |
| [`animeModuleId`](#constants) | 常量 | A | `'anime'` — 备份捆绑模块键。 |
| [`animeDefaultRemotePath`](#constants) | 常量 | A | `'/MyAnime'`。 |
| [`animeArchiveNamePrefix`](#constants) | 常量 | A | `'myanime_export_'`。 |
| [`validateAnimeJson(json)`](#validateanimejson) | 函数 | A | 除非负载能解析为动画数据，否则抛出。 |
| [`encodeAnimeData(data)`](#encodeanimedata) | 函数 | A | 按中枢的写入方式美化打印合并数据。 |
| [`animeReferencedImages(json)`](#animereferencedimages) | 函数 | A | 记录引用的封面图基名。 |
| [`mergeAnimeModule({...})`](#mergeanimemodule) | 函数 | A | 把 `mergeAnimeData` 适配到引擎的合并契约。 |
| [`buildAnimeModule()`](#buildanimemodule) | 函数 | A | 构建动画的 `DataModule`。 |
| [`validateRecommendationsJson(json)`](#validaterecommendationsjson) | 函数 | A | 除非负载是 JSON 对象，否则抛出（1.6.2）。 |
| [`mergeRecommendationsModule({...})`](#mergerecommendationsmodule) | 函数 | A | 把无冲突的推荐合并适配到引擎（1.6.2）。 |
| [`buildRecommendationsModule()`](#buildrecommendationsmodule) | 函数 | A | 构建推荐的 `DataModule`（1.6.2）。 |
| [`animeModuleRegistry`](#animemoduleregistry) | 字段 | A | 应用的 `ModuleRegistry`。 |

## 文档

### `class AnimeStorageAdapter` <a id="animestorageadapter"></a>
- **用途：** 在包完全不了解 `AnimeStorage` 的情况下，给共享引擎提供存储根和 `storage_config.json` 访问。
- **构造函数：** `const AnimeStorageAdapter({Future<Directory> Function()? appDir})`。
- **方法：** `getAppDir()`、`readConfig()`、`writeConfig(config)` — 全部委托给中枢。
- **备注：** 可选的 `appDir` 解析器存在，使 `BackupService` 能继续尊重它的 `@visibleForTesting appDirProvider`。它每次调用都被查询，因此测试间切换 provider 仍然有效。`AnimeStorage.getAppDir()` 每次调用都重新读取其配置，因此自定义存储路径变更会被每个引擎立即拾取。

### 常量 <a id="constants"></a>
- **备注：** 文件名和模块 id 是持久化的兼容契约——旧构建和新构建必须能对同一个 WebDAV 服务器和同样的备份捆绑互通。绝不更改。1.6.2 新增了 `recommendationsFileName`（`'recommendations.json'`）和 `recommendationsModuleId`（`'recommendations'`），遵循同样的规则；它们在常量小节中列出，而不作为单独的行。

### `validateAnimeJson(json)` <a id="validateanimejson"></a>
- **抛出：** `jsonDecode` 或 `AnimeData.fromJson` 抛出的任何东西。
- **备注：** 刻意保持与抽取前备份和导入路径所做的相同裸调用，使调用方浮出的异常类型和消息不变。

### `encodeAnimeData(data)` <a id="encodeanimedata"></a>
- **返回：** 用 `JsonEncoder.withIndent('  ')` 的 JSON。
- **备注：** 必须与 `AnimeStorage` 的本地保存格式匹配。若不匹配，一个本来未变化的文件会在下一次同步时错过原始相等快速路径，永远重新上传。

### `animeReferencedImages(json)` <a id="animereferencedimages"></a>
- **返回：** 封面图基名；格式错误的输入返回空集。
- **备注：** 引擎对本地和远程结果取并集，复现此前的规则：同步任一侧引用的图像，绝不碰孤儿。

### `mergeAnimeModule({localJson, remoteJson, baseJson, autoResolve})` <a id="mergeanimemodule"></a>
- **返回：** `ModuleMergeOutcome` — 无冲突时完整，否则待定并带解决构建器。
- **备注：** 包装未变的 `mergeAnimeData`。类型化的 `AnimeMergeResult` 作为不透明 `state` 携带，使 `WebDAVService` 仍能把真正的 `PendingSync` 交给冲突对话框。

### `buildAnimeModule()` <a id="buildanimemodule"></a>
- **备注：** 没有 `postMergeTransform`（MyAnime 没有迁移）也没有 `preUploadTransform`——未知字段保留内建在模型中，因此合并输出已经自我保留。

### `validateRecommendationsJson(json)` <a id="validaterecommendationsjson"></a>
- **抛出：** 负载不是 JSON 对象时抛出 `FormatException`，或 `jsonDecode` 抛出的任何东西。
- **备注：** 对象内部的模型是宽容的，因此只有完全不属于我们的文件才会被拒绝——由备份恢复以及同步引擎在写入前拒绝。

### `mergeRecommendationsModule({localJson, remoteJson, baseJson})` <a id="mergerecommendationsmodule"></a>
- **返回：** 总是来自 `mergeRecommendationJson`（[`../features/recommendations/services/recommendation_merge.md`](../features/recommendations/services/recommendation_merge.md)）的完整 `ModuleMergeOutcome`。
- **备注：** 设计上无冲突，因此该模块永远不会进入冲突对话框，`WebDAVService` 仍只从动画模块读取冲突；其门面不变。

### `buildRecommendationsModule()` <a id="buildrecommendationsmodule"></a>
- **备注：** 没有图像，也没有变换。引擎的 `autoResolve` 参数被接受并忽略：没有需要解决的东西。

### `animeModuleRegistry` <a id="animemoduleregistry"></a>
- **备注：** 只构建一次。注册表顺序对同步顺序、进度报告和备份键顺序在行为上意义重大。`anime_data.json` 保持在第一位，因此它的进度序号和冲突先于其他一切；`recommendations.json` 紧随其后。

## 契约文档的位置

`packages/myapps_data/doc/en-us/functions/src/modules/data_module.md` 和 `packages/myapps_data/doc/en-us/functions/src/storage/storage_adapter.md`。
