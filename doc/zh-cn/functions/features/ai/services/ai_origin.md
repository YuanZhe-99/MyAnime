# lib/features/ai/services/ai_origin.dart

## 声明

| 声明 | 用途 |
|---|---|
| `onlineProviderOf` | 已保存模型标识中的在线服务商 id（`provider:…`）；端侧结果返回 null |
| `aiGeneratedLabelFor` | 结果的“生成来源”标注：本设备为 `aiGeneratedLabel`，在线为写明服务商的 `aiGeneratedOnlineLabel`，该服务商已删除时为 `aiGeneratedOnlineUnknownLabel` |

1.8.12 新增。标识是生成结果时 `modelIdentityOf` 的返回值，随 AI 分类（`AiCategoryEntry.model`）和
相关列表理由（`RelatedItem.aiReasonModel`）一起保存。没有标识的结果视为端侧生成。
