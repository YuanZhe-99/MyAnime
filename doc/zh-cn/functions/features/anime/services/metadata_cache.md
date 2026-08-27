# lib/features/anime/services/metadata_cache.dart

`MetadataCache` 拥有 `metadata_updates.json` —— 设备本地的后台资料工作记录，以及已经下载好的更新候选 ——
外加可选的 `metadata_covers/` 预取目录。

它是唯一读写这两者的文件。文档形态见 [`../models/metadata_update.md`](../models/metadata_update.md)，
功能说明见
[`../../../../features/metadata-auto-update.md`](../../../../features/metadata-auto-update.md)。

## 这个文件为什么不同步

同步与备份引擎遍历 `ModuleRegistry`，并且只会碰它所列出的文件名外加 `images/`。
`metadata_updates.json` 刻意**没有**注册进
[`../../../app/data_modules.md`](../../../app/data_modules.md)，这就是全部机制 —— 没有排除列表，也没有
特判。它仍然位于 `AnimeStorage.getAppDir()` 之下，因此 `setStoragePath` 会像迁移文件夹里其他一切一样
带上它。

## 声明

| 声明 | 种类 | 层级 | 用途 |
|---|---|---|---|
| `MetadataCache._` | 构造器 | B | 阻止实例化。 |
| `_file` | 方法 | B | 在当前存储目录中解析缓存文件路径。 |
| [`_atomicWrite`](#_atomicwrite) | 方法 | A | 通过 tmp-重命名写入。 |
| [`load`](#load) | 方法 | A | 加载缓存，任何失败都降级为空。 |
| [`save`](#save) | 方法 | A | 持久化缓存。 |
| `_coverDir` | 方法 | B | 解析预取目录，按需创建。 |
| [`prefetchCover`](#prefetchcover) | 方法 | A | 提前下载候选的封面。 |
| [`deleteCover`](#deletecover) | 方法 | A | 删除单张预取封面。 |
| [`pruneCovers`](#prunecovers) | 方法 | A | 删除无人引用的预取封面。 |

## 文档

### `static Future<void> _atomicWrite(File, String)` <a id="_atomicwrite"></a>
- **种类：** `MetadataCache` 的静态方法
- **用途：** 通过临时文件加重命名写入文件。
- **副作用：** 写入 `<path>.tmp`，然后重命名覆盖目标。
- **备注：** 与 `AnimeStorage._atomicWrite` 同构。缓存是可重建的，因此损坏并不构成数据丢失风险 —— 但一个
  被截断的文件仍然意味着要通过网络把整个资料库重新扫描一遍，为此付出一次重命名是划算的。

### `static Future<MetadataUpdateStore> load()` <a id="load"></a>
- **种类：** `MetadataCache` 的静态方法
- **返回：** `Future<MetadataUpdateStore>` —— 文件不存在、为空或不可读时返回空存储。
- **备注：** 解析失败返回空存储而不是抛出。丢失这个文件的代价是网络工作量，绝不会是用户数据，因此静默
  降级优于让启动卡在它上面。

### `static Future<void> save(MetadataUpdateStore)` <a id="save"></a>
- **种类：** `MetadataCache` 的静态方法
- **副作用：** 原子地写入缓存文件。
- **备注：** 与本应用写入的其他所有文件一样，经 `JsonEncoder.withIndent('  ')` 美化打印。刻意**不**调用
  `AutoSyncService.notifySaved()` —— 这个文件从不同步，为它安排上传只会对 30 秒保存防抖造成纯粹的骚扰。

### `static Future<String?> prefetchCover(String, String)` <a id="prefetchcover"></a>
- **种类：** `MetadataCache` 的静态方法
- **输入：** `animeId`、`url`。
- **返回：** `Future<String?>` —— 相对于 app 目录的路径，失败时为 `null`。
- **副作用：** 一次 HTTP GET（20 秒超时）与一次文件写入。
- **备注：** 仅在用户开启封面预下载时调用，而该选项**默认关闭**：封面是这份缓存里唯一的大体积数据。失败
  是静默的，因为审阅界面会回退到直接从来源 URL 加载，所以一次失败的预取不会产生任何可见代价。

### `static Future<void> deleteCover(String?)` <a id="deletecover"></a>
- **种类：** `MetadataCache` 的静态方法
- **备注：** 在建议被应用或忽略后调用，使预取目录不会无限增长。文件不存在不算错误。

### `static Future<void> pruneCovers(MetadataUpdateStore)` <a id="prunecovers"></a>
- **种类：** `MetadataCache` 的静态方法
- **副作用：** 删除 `metadata_covers/` 中所有没有条目引用的文件。
- **备注：** 与 `MetadataUpdateStore.prunedTo` 配对，使属于已删除番剧的封面也一并清除。它是机会式的 ——
  任何失败都被吞掉，留待下一次清理重试。
