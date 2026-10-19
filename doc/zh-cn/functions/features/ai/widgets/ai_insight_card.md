# lib/features/ai/widgets/ai_insight_card.dart

`AiInsightCard`（1.9.1，移植自 MyDevice!!!!!）：统计页面总览和排行视图上的 AI 卡片，由 MyApps-AI 的 `MyAppsAiInsightCard` 渲染。AI 关闭时不渲染任何内容；与 MyDevice 的卡片不同，它不要求端侧模型：使用当前选中的来源（系统 AI、本地或在线），生成标注来自 `aiGeneratedLabelFor`，因此在线结果会写出服务商名称。页面重建时和本地午夜时它会重建请求，并请求 [`AiInsightStore`](../services/insight_service.md) 把自己更新为最新。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AiInsightCard` | 声明 | B | 创建一张洞察卡片。 |
| `createState` | 声明 | B | 创建状态对象。 |
| `dispose` | 声明 | B | 停止计时器和监听器。 |
| `_onServiceChanged` | 私有声明 | B | 模型变为可用时重建。 |
| `_listenTo` | 私有声明 | B | 跟随正确的 `OnDeviceAiService` 实例。 |
| `_armBoundaryTimer` | 私有声明 | B | 在事实仅因时间而变化的下一时刻重建。 |
| `_scheduleEnsure` | 私有声明 | B | 在帧结束后请求存储更新本卡片。 |
| `_statusLabel` | 私有声明 | B | 描述阻止卡片生成的模型状态。 |
| `build` | 声明 | A | 构建卡片。 |
| `_notice` | 私有声明 | B | 构建代替卡片的一行提示。 |
| `_card` | 私有声明 | B | 构建洞察卡片本体。 |

`grep -c 'Purpose:' lib/features/ai/widgets/ai_insight_card.dart` 报告 11，每个一行。
