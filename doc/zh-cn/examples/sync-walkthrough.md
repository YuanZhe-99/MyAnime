# 实例演练：WebDAV 同步

本页把 [`../sync.md`](../sync.md) 的 10 步流程和 [`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md) 的合并引擎，用两条动画记录的具体场景走查：一条干净自动解决，一条产生需要用户输入的真正冲突。JSON 精简到对演练重要的字段。

两台设备：**设备 A**（手机）和**设备 B**（桌面），都已经同步过一次，因此两者在 `.sync_base/anime_data.json` 共享同一个基线快照。

## 场景 1：单侧编辑 -> 自动解决

### 基线快照（两台设备，上次成功同步后）

```json
{
  "animes": [
    {
      "id": "a1b2c3",
      "title": "Sample Anime",
      "startEpisode": 1,
      "endEpisode": 12,
      "episodeStatuses": { "1": "watched", "2": "watched" },
      "modifiedAt": "2026-07-20T09:00:00.000Z"
    }
  ]
}
```

### 设备 A 把第 3 集标记为已看

设备 A 的本地 `anime_data.json` 现在为：

```json
{
  "id": "a1b2c3",
  "episodeStatuses": { "1": "watched", "2": "watched", "3": "watched" },
  "modifiedAt": "2026-07-22T03:15:00.000Z"
}
```

设备 B 没有动过这条记录——它的本地 `anime_data.json` 中这个 ID 仍与基线逐字节相同。

### 设备 A 运行同步

1. **获取 `.lock`**，在 WebDAV 服务器上用设备 A 的客户端 id、新上传令牌、UTC 时间戳、60 秒 TTL。没有其他锁活动，因此立即成功。
2. **下载远程 `anime_data.json`。** 设备 B 自上次同步以来没有上传任何内容，因此远程副本仍与基线快照完全一致（`modifiedAt` = `2026-07-20T09:00:00.000Z`）——HTTP 200，不是 404，所以是正常的"远程存在"情形。
3. **从磁盘加载本地和基线**副本。
4. **通过 `mergeAnimeData()` 按 `modifiedAt` 逐动画合并**（[`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md)）：对 ID `a1b2c3`，`localChanged = true`（`2026-07-22` > `2026-07-20`），`remoteChanged = false`（远程仍等于基线）。
5. **只有一侧变化时自动解决：** 只有本地变化，因此合并记录是设备 A 的副本（第 3 集已看）——不产生冲突、不显示对话框，无论 `autoResolve` 是 true 还是 false，因为这个 `mergeRecords<T>` 分支根本不会到达冲突/LWW 分支。
6. 没有冲突可检测——这里没有发生两侧都变化。
7. **重新读取本地**——本场景中网络往返期间本地没有变化。
8. **没有记录冲突**，因此设备 A 在仍有效的 `.lock` 之下强制上传完整合并 JSON（这里与它自己的本地副本相同）。
9. （跳过——没有冲突）
10. **保存新的基线快照**（现在与上传的 JSON 一致，`modifiedAt = 2026-07-22T03:15:00.000Z`），然后清除上传锁。

设备 B 下一次同步时，它的本地副本（仍在旧基线）会以相反方向同样自动解决——它自己的记录自基线以来没变，因此新下载的远程副本胜出，设备 B 的本地文件更新为显示第 3 集已看。

## 场景 2：两侧不同编辑 -> 冲突

再次从上面的相同基线快照开始（设想设备在场景 1 之后已经重新同步到公共基线）。

### 设备 A 修改标题

```json
{
  "id": "a1b2c3",
  "title": "Sample Anime: Season 2",
  "episodeStatuses": { "1": "watched", "2": "watched", "3": "watched" },
  "modifiedAt": "2026-07-22T05:00:00.000Z"
}
```

### 设备 B 同时离线，把第 4 集标记为已看

```json
{
  "id": "a1b2c3",
  "title": "Sample Anime",
  "episodeStatuses": { "1": "watched", "2": "watched", "3": "watched", "4": "watched" },
  "modifiedAt": "2026-07-22T05:30:00.000Z"
}
```

设备 B 先同步并成功上传（与场景 1 的流程相同——设备 A 还没上传，所以从设备 B 的视角是干净自动解决）。远程现在持有设备 B 的版本。

### 设备 A 随后同步

1. **获取 `.lock`。**
2. **下载远程 `anime_data.json`** — 现在是设备 B 的版本（第 4 集已看、标题未变、`modifiedAt = 2026-07-22T05:30:00.000Z`）。
3. **加载本地和基线。**
4. **合并：** 对 ID `a1b2c3`，`localChanged = true`（设备 A 的标题编辑，`05:00` > 基线）且 `remoteChanged = true`（设备 B 的剧集编辑，`05:30` > 基线）。
5. 第 5 步无法自动解决——两侧都变化。
6. **检测冲突：** 既然两侧都变化*且* `serialize(local) != serialize(remote)`（标题不同、剧集状态不同——这是真正的内容不同冲突，不是会抑制它的相同内容情形），而设备 A 的同步以 `autoResolve: false` 运行（手动同步和自动同步都是——见 [`../sync.md`](../sync.md)），这就变成一个 `RecordConflict<Anime>`，`localRecord` = 设备 A 的副本、`remoteRecord` = 设备 B 的副本。
7. **重新读取本地**，捕获网络往返期间的任何并发编辑——本场景没有。
8. *（跳过——有冲突）*
9. **冲突返回给用户。** 设备 A 的 WebDAV 页面显示比较两个版本的冲突对话框。假设用户选择"手动合并"，保留设备 B 的标题但……实际上这里用户决定保留**本地标题**（"Sample Anime: Season 2"），同时接受**远程剧集进度**（第 4 集已看）——UI 通过允许用户从任一侧构造胜出的 `Anime` 记录（或直接编辑）来支持这种解决方式。无论选择哪一侧的其他字段，被选记录的 `extraJson` 都通过 `withPreservedUnknownJson` 从 `localRecord`/`remoteRecord` 两边保留（见 [`../algorithms/three-way-merge.md`](../algorithms/three-way-merge.md) `mergeAnimeData` 的第 3 步）。
   - 如果用户改为关闭对话框（如系统返回），**什么都不上传**，冲突保持待定并可见于同步状态，也没有任何记录被静默解决为本地版本——下一次同步尝试会重新检测同一冲突。
10. **`finalizePendingSync` 重新获取 `.lock`**（全新获取，因为步骤 1 的锁在用户看对话框期间可能已经过期）并强制上传完整的已解决 JSON——整个 `anime_data.json`，不只是这一条记录。如果重新获取锁或上传失败，`finalizePendingSync` 返回 `false`，基线快照保持不动，下一次同步从同一起点重新合并，而不是静默丢弃解决方案。

一旦上传成功，基线快照更新为已解决记录的 `modifiedAt`，锁被清除。设备 B 的下一次同步会把已解决的标题看作纯远程变更（它自己的副本自公共基线以来未变）并自动解决采纳它——设备 B 上不再有第二次冲突提示。
