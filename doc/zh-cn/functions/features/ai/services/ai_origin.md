# lib/features/ai/services/ai_origin.dart

## 声明

| 声明 | 用途 |
|---|---|
| `onlineSourceOf` | 已保存模型标识中的在线来源 id（`online:model:…`，1.8.11 起的旧值为 `provider:…`）；端侧结果返回 null |
| `aiGeneratedLabelFor` | 结果的“生成来源”标注：本设备为 `aiGeneratedLabel`，在线为写明来源的 `aiGeneratedOnlineLabel`（通过路由器查找，新旧 id 均可），该来源已删除时为 `aiGeneratedOnlineUnknownLabel` |

1.8.12 新增（1.9.0 中 `onlineProviderOf` 改名为 `onlineSourceOf`）。标识是生成结果时 `modelIdentityOf` 的返回值，
随 AI 分类（`AiCategoryEntry.model`）和相关列表理由（`RelatedItem.aiReasonModel`）一起保存。没有标识的结果视为端侧生成。
