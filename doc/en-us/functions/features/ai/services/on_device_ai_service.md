# lib/features/ai/services/on_device_ai_service.dart

## Declarations

| Declaration | Purpose |
|---|---|
| `OnDeviceAiService` | App singleton and constants over shared execution |
| `OnDeviceAiService()` | Inject backend/clock; default to app channel |
| `setInstanceForTest` | Replace app singleton for tests |
| `onDeviceAiServiceProvider` | Riverpod provider over app singleton |

AiPriority and GenAiDownload are re-exported. Inherited execution includes enabled
gate, lifecycle, priority queue, timeout cancellation, late-result invalidation and
quota pacing. See [shared-ai](../../../../shared-ai.md).
