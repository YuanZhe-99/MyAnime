# lib/features/recommendations/services/sequel_info_service.dart

`SequelInfoService`（1.6.3）为「番剧库里还没有」的缺失续作卡片抓取一段简短简介和一张小封面缩略图，并经
[`RecommendationStore.putSequelInfo`](recommendation_store.md#putsequelinfo) 以卡片的去重键（`sequelTrashKey`）
存入可同步的 `recommendations.json`。页面请求经由
[`AnimeSearchService.fetchByUrl`](../../anime/services/anime_search_service.md)，因此只能抓取 AniList、MyAnimeList 和
bangumi.tv 的续作。**这是一项联网功能：每个调用方都以 `AppFlavor.isFull` 门禁**，与搜索服务的其他所有调用方一样。
商店版仍会显示完整版抓取的内容，因为结果会同步。见
[`../../../../features/categories-and-recommendations.md`](../../../../features/categories-and-recommendations.md#缺失续作卡片)。

缩略图是 JSON 文件中的一段 base64 JPEG，而不是 `images/` 中的文件。图片同步是增量的、从不删除，因此缩略图文件会在
每台设备上比它已移入垃圾箱的卡片存留更久；JSON 字段则会随下一次同步在各处消失。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `SequelInfoService._` | 构造器 | B | 禁止实例化；该服务只有静态成员。 |
| `resetSession` | 静态方法 | B | 忘记本次会话尝试过哪些键；用于测试。 |
| [`ensure`](#ensure) | 静态方法 | A | 为一部缺失续作抓取并保存资料，只做一次。 |
| [`_run`](#_run) | 静态方法 | A | 抓取页面和封面，生成缩略图，保存结果。 |
| `_fetchPage` | 静态方法 | B | 经 `AnimeSearchService.fetchByUrl` 读取简介和封面 URL。 |
| `_download` | 静态方法 | B | 以应用的 user agent 和 15 s 超时下载一张图片。 |
| [`makeThumbnail`](#makethumbnail) | 静态方法 | A | 在后台 isolate 中把封面缩小为一段小的 base64 JPEG。 |
| `_thumbnail` | 静态方法 | B | `makeThumbnail` 的 isolate 主体。 |
| [`normalizeSynopsis`](#normalizesynopsis) | 静态方法 | A | 清理资料库的简介，用于显示和保存。 |

常量 `thumbWidth`（112 px，卡片封面 56 dp 的两倍）、`thumbQuality`（70）、`thumbMaxBytes`（24 KB）和
`synopsisMaxLength`（600 个字符），以及测试接缝 `fetchPage` 和 `download`（`@visibleForTesting` 函数字段），都没有
`/// Purpose:` 注释，不单列成行。

## 文档

### `static Future<SequelInfo?> ensure(String key, AnimeExternalRelation sequel, {SequelInfo? existing})` <a id="ensure"></a>
- **种类：** `SequelInfoService` 的静态方法
- **来源：** `lib/features/recommendations/services/sequel_info_service.dart`（约第 76 行）
- **用途：** 为一部缺失续作抓取并保存资料，只做一次。
- **输入：** `key` — 去重键；`sequel`；`existing` — 存储中已有的内容。
- **返回：** `Future<SequelInfo?>` — 已保存的资料；什么都没抓取时为 null。
- **副作用：** 至多一次页面请求和一次图片请求；一次写入 `recommendations.json`。
- **算法：** 给出 `existing` 时返回它。续作没有 URL 或键为空时返回 null。该键已有进行中的 future 时返回它。该键在本次
  会话中已经尝试过时返回 null；否则将其标记为已尝试，并运行 [`_run`](#_run)。
- **用法：** `_RecommendationsPageState._fetchSequelInfo` 和 `_AnimeDetailPageState._load`，两者都在 `AppFlavor.isFull`
  之下。
- **备注：** 会话集合使失效或不受支持的来源不会在每次重建时被请求；它只在内存中，因此下次启动会再试。保存了结果就会清除
  标记（见 `_run`），因此只有失败的键保持标记。内容为空的结果也会被保存，因此下次启动时同样不会再次抓取。

### `static Future<SequelInfo?> _run(String key, String url)` <a id="_run"></a>
- **种类：** `SequelInfoService` 的静态方法
- **来源：** `lib/features/recommendations/services/sequel_info_service.dart`（约第 98 行）
- **用途：** 抓取页面和封面，生成缩略图，保存结果。
- **输入：** `key`、`url`。
- **返回：** `Future<SequelInfo?>`。
- **副作用：** 网络；写入存储。
- **算法：** `fetchPage(url)`；为 null 则返回 null。它报告了封面 URL 时，`download` 该封面并 `makeThumbnail`。用
  `normalizeSynopsis(summary)`、封面 URL、缩略图以及 `fetchedAt` = 当前时间（UTC）构建一个 `SequelInfo`，然后调用
  `RecommendationStore.putSequelInfo`，并返回存储中该键对应的内容。保存了内容时清除该键的「已尝试」标记，使一张资料被换一批
  删除、又被撤销恢复的卡片可以在同一会话中再次抓取。
- **用法：** `ensure`。
- **备注：** 任何异常都读作 null，不保存任何内容，因此网络错误会在下一次会话中重试。卡片在垃圾箱中时 `putSequelInfo`
  忽略这次写入，此时返回值为 null。

### `static Future<String?> makeThumbnail(Uint8List bytes)` <a id="makethumbnail"></a>
- **种类：** `SequelInfoService` 的静态方法
- **来源：** `lib/features/recommendations/services/sequel_info_service.dart`（约第 164 行）
- **用途：** 把封面缩小为一段小的 base64 JPEG。
- **输入：** `bytes` — 下载的图片，`package:image` 能解码的任意格式。
- **返回：** `Future<String?>` — base64 文本；图片无法解码或 JPEG 大于 `thumbMaxBytes` 时为 null。
- **副作用：** 经 `compute` 在后台 isolate 中运行。
- **算法：** 解码；宽于 `thumbWidth` 时，以平均插值 `copyResize` 到该宽度，保持宽高比；以 `thumbQuality` `encodeJpg`；
  超过 `thumbMaxBytes` 则拒绝；base64 编码。
- **用法：** `_run`；`test/recommendation_pins_test.dart`。
- **备注：** 典型的 2:3 海报缩成 112 × 168，大小为几 KB。`package:image` 为此在 1.6.3 中成为运行时依赖；之前它是只供
  `tool/` 使用的开发依赖。

### `static String? normalizeSynopsis(String? raw)` <a id="normalizesynopsis"></a>
- **种类：** `SequelInfoService` 的静态方法
- **来源：** `lib/features/recommendations/services/sequel_info_service.dart`（约第 199 行）
- **用途：** 清理资料库的简介，用于显示和保存。
- **输入：** `raw`。
- **返回：** `String?` — 为空时为 null。
- **副作用：** 无。
- **算法：** 去掉 MyAnimeList 的 `[Written by …]` 以及任何 `(Source: …)` 出处说明，把所有空白（包括段落分隔）折叠为单个
  空格，去掉首尾空白，并截断到 `synopsisMaxLength` 个字符，末尾加 `…`。
- **用法：** `_run`。
- **备注：** 卡片至多显示三行，因此不保留段落。简介使用资料库撰写时的语言：AniList 和 MyAnimeList 为英文，bangumi.tv
  通常为中文或日文。
