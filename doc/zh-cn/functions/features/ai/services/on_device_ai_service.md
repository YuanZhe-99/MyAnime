# lib/features/ai/services/on_device_ai_service.dart

## 声明

| 声明 | 用途 |
|---|---|
| `OnDeviceAiService` | 共享执行上的应用单例和常量 |
| `OnDeviceAiService()` | 注入后端与时钟，默认应用通道 |
| `setInstanceForTest` | 为测试替换应用单例 |
| `onDeviceAiServiceProvider` | 应用单例的 Riverpod provider |

重新导出 AiPriority 和 GenAiDownload。继承执行包含开关门控、生命周期、优先队列、
超时取消、晚到结果失效和配额节奏。见 [shared-ai](../../../../shared-ai.md)。
