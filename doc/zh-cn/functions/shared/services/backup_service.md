# lib/shared/services/backup_service.dart

**共享引擎上的门面。** 捆绑创建、内容寻址 blob 存储、引用计数 GC、保留和 v1/v2 恢复移入 `myapps_data` 包（`lib/src/backup/backup_engine.dart`）。本文件保留每个公共名称和签名，使 `test/backup_service_test.dart` 无需修改即可运行。

备份格式不变：`backups/backup_<yyyyMMdd_HHmmss>.json` 捆绑保存 `_backupFormat`、每个模块一个原始 JSON 字符串，以及指向 `backups/blobs/<sha256><ext>` 的 `_imageRefs`。带内联 base64 `_images` 的旧 v1 捆绑仍可恢复。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`appDirProvider`](#appdirprovider) | 静态字段 | A | 重定向所有备份 I/O 的测试接缝。 |
| [`modules`](#modules) | 静态字段 | A | 文件名到备份模块键的映射，从注册表派生。 |
| [`autoBackupEnabled`](#settings) | 静态 getter/setter | A | 每日自动备份是否运行。 |
| [`retentionDays`](#settings) | 静态 getter/setter | A | 保留备份的天数；0 永久保留。 |
| [`loadSettings()`](#settings) | 静态方法 | A | 从 `storage_config.json` 读取两个设置。 |
| [`saveSettings()`](#settings) | 静态方法 | A | 持久化两个设置。 |
| [`createBackup()`](#createbackup) | 静态方法 | A | 写入 v2 捆绑加任何新 blob。 |
| [`runAutoBackupIfNeeded()`](#runautobackupifneeded) | 静态方法 | A | 到期时执行每日一次备份。 |
| [`listBackups()`](#listbackups) | 静态方法 | A | 最新优先列出捆绑，标记损坏的。 |
| [`getBackupModules(file)`](#getbackupmodules) | 静态方法 | A | 捆绑包含的模块 id。 |
| [`restoreBackup(file, {moduleKeys})`](#restorebackup) | 静态方法 | A | 先校验后恢复捆绑。 |
| [`deleteBackup(file)`](#deletebackup) | 静态方法 | A | 删除捆绑，然后 GC 孤儿 blob。 |

从包中以不变形态再导出：`BackupInfo{file, date, sizeBytes, corrupt}` 和 `RestoreResult{ok, wroteAnything, missingImages}`。

## 文档

### `appDirProvider` <a id="appdirprovider"></a>
- **种类：** 静态字段，`@visibleForTesting`
- **用途：** 在测试中把备份 I/O 重定向到临时目录。
- **备注：** 作为撕离函数传给存储适配器，并在**每次**调用时读取，因此测试在用例之间切换 provider 仍会对已构建的引擎生效。

### `modules` <a id="modules"></a>
- **种类：** 静态字段，`Map<String, String>`
- **用途：** 把数据文件名映射到备份模块键（`anime_data.json` 到 `anime`）。
- **备注：** 现在从模块注册表派生，而不是第二个硬编码映射。

### 设置：`autoBackupEnabled`、`retentionDays`、`loadSettings()`、`saveSettings()` <a id="settings"></a>
- **用途：** 读写两个备份设置。
- **副作用：** `storage_config.json`，在不变的键 `autoBackupEnabled` 和 `backupRetentionDays` 下。无关键被保留。

### `createBackup()` <a id="createbackup"></a>
- **返回：** `Future<File?>` — 捆绑，失败为 null。
- **副作用：** 写捆绑、按 sha256 去重图像 blob，然后运行保留清理和 blob GC。

### `runAutoBackupIfNeeded()` <a id="runautobackupifneeded"></a>
- **副作用：** 可能创建备份。
- **备注：** `autoBackupEnabled` 为 false 时空操作。可重入守卫。"今天已备份"通过扫描捆绑文件名决定，因此损坏捆绑不计入，当天会重试。由 `auto_sync_service.dart` 中的周期滴答和恢复钩子驱动。

### `listBackups()` <a id="listbackups"></a>
- **返回：** `Future<List<BackupInfo>>`，最新优先。
- **备注：** 4 MiB 及以下的捆绑被解析以计算有效性和引用 blob 大小；更大的只按文件大小列出。不可解析捆绑被标记 `corrupt`，绝不隐藏。

### `getBackupModules(file)` <a id="getbackupmodules"></a>
- **返回：** `Future<List<String>>`；不可解析捆绑为空。
- **用途：** 驱动逐模块恢复复选框。

### `restoreBackup(file, {moduleKeys})` <a id="restorebackup"></a>
- **返回：** `Future<RestoreResult>`。
- **副作用：** 原子覆盖数据文件并从 blob（v2）或内联 base64（v1）恢复图像。
- **备注：** 每个所选负载在**首次写入前**通过注册表解析器校验。WebDAV 自动同步在首次写入前被禁用，只在恢复失败且未写入任何内容时重新启用，因此恢复出的旧数据无法把删除传播到其他设备。

### `deleteBackup(file)` <a id="deletebackup"></a>
- **副作用：** 移除捆绑，然后垃圾回收没有剩余捆绑引用的 blob。
- **备注：** 比 10 分钟宽限窗口更年轻的 blob 绝不回收，保护并发写入中的备份。不可解析捆绑中止整趟 GC，而不是冒险删除它可能引用的 blob。

## 引擎文档的位置

`packages/myapps_data/doc/en-us/functions/src/backup/backup_engine.md`。
