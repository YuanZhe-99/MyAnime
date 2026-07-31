# 多源搜索

`anime_search_service.dart` 搜索或抓取多个来源，**仅在 full 构建**中可用——见下方风味门控小节和 [`../architecture.md`](../architecture.md) 的 `full`/`store` 风味划分。

## 来源

- `bangumi.tv` — 旧搜索 API。
- MyAnimeList — 经由 Jikan v4。
- AniList — GraphQL API。
- `acgsecrets.hk` — 季页面 JSON-LD。
- `filmarks.com` — HTML 抓取。
- `anime1.me` — 专门用于观看 URL 查找（不是通用元数据搜索）。

## 功能

- 结果去重。
- 中文来源的简体/繁体变体。
- 模糊匹配。
- 封面图提取。
- 把搜索结果来源 URL 保存进 `infoUrl`（见 [`../data-formats.md`](../data-formats.md)）。

来源变更时，保持公共数据源行为反映在 `PRIVACY_POLICY.md` 中。

## 风味门控

`AnimeSearchService` 本身**不**强制风味门控——它是共享工具。每个商店可达的调用方都必须显式门控访问：

- `anime_edit_page.dart` 把它的搜索操作门控在 `AppFlavor.isFull` 之后，因此在线动画搜索对面向商店的 UI 保持隐藏（`store` 风味：Google Play / App Store 构建）。
- 桌面本地 API 服务器（`local_api_server.dart`，见 [`../platform-notes.md`](../platform-notes.md)）可以直接调用 `AnimeSearchService.searchAll()`，因为它是纯桌面功能，且桌面构建以 `full` 风味发布，不是商店/移动端表面。
