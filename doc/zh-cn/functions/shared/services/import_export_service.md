# lib/shared/services/import_export_service.dart

**部分门面。** ZIP 半边（`exportZIP` / `importZIP`）委托给 `myapps_data` 包（`lib/src/data/zip_transfer.dart`）。Markdown 导出深度领域特定，留在这里。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`exportZIP(destDir)`](#exportzip) | 静态方法 | A | 写入 `myanime_export_<stamp>.zip`。 |
| [`importZIP(filePath)`](#importzip) | 静态方法 | A | 从导出恢复数据和图像。 |
| [`exportMarkdown(destDir)`](#exportmarkdown) | 静态方法 | A | 写入所有动画的 Markdown 记录。 |

Markdown 导出的私有标签辅助（`_typeLabel`、`_dayLabel`、`_deriveStatus` 等）不变，保留在本文件。

## 文档

### `exportZIP(destDir)` <a id="exportzip"></a>
- **返回：** `Future<String?>` — 写入的路径，失败为 null。
- **副作用：** 写入 `myanime_export_<yyyyMMdd_HHmmss>.zip`。
- **备注：** 打包注册表的数据文件加平铺 `images/<basename>` 条目。配置、`.sync_base/` 和 `backups/` 绝不包含。

### `importZIP(filePath)` <a id="importzip"></a>
- **返回：** `Future<bool>` — 成功为 true。
- **副作用：** 覆盖允许列表中的数据文件和图像。
- **备注：** 只解压允许列表中的条目（注册表的数据文件和 `images/` 下的平铺文件），且每个条目必须解析到应用目录内，因此构造的 ZIP 无法覆盖 `webdav_config.json`。

  **抽取带来的行为变更：** 每个条目在写入任何条目之前被分类，因此含路径穿越条目的归档现在被整体拒绝——调用返回 false、什么都不写——而不是跳过坏条目并导入其余部分。未知条目仍被跳过，因此来自更新构建的归档仍能导入。负载以原始字节写入，不做 UTF-8 或模型校验，与之前相同。

### `exportMarkdown(destDir)` <a id="exportmarkdown"></a>
- **返回：** `Future<String?>` — 写入的路径，失败为 null。
- **副作用：** 写入 `myanime_export_<yyyyMMdd_HHmmss>.md`。
- **备注：** 按首播日期排序、null 排最后，然后按显示标题。从注册表读取数据文件名。为 LLM 个性化上下文设计。

## 引擎文档的位置

`packages/myapps_data/doc/en-us/functions/src/data/zip_transfer.md`。
