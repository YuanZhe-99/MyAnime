# lib/features/ai/services/genai_backend.dart

## Declarations

| Declaration | Purpose |
|---|---|
| `MethodChannelGenAiBackend` | App channel adapter over MyApps-AI v0.1.0 |
| `MethodChannelGenAiBackend()` | Accept test channel or use com.yuanzhe.my_device/genai |
| `failureForCode` | Forward shared native error mapping for tests |

Status, failure, diagnostic and backend types are re-exported from myapps_ai.
The native registration is unchanged. See [shared-ai](../../../../shared-ai.md).


Current integration uses MyApps-AI v0.6.0, explicit platform injection, the shared source router (`createAiSourceRouter`) and the unified settings skeleton. WebDAV entry points require device-local notice acknowledgement before any network request; see [sync.md](../../../sync.md).
