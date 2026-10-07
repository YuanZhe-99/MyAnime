# lib/features/ai/services/genai_backend.dart

## 声明

| 声明 | 用途 |
|---|---|
| `MethodChannelGenAiBackend` | MyApps-AI v0.1.0 的应用通道适配器 |
| `MethodChannelGenAiBackend()` | 接受测试通道或使用 com.yuanzhe.my_device/genai |
| `failureForCode` | 为测试转发共享原生错误映射 |

状态、失败、诊断和后端类型从 myapps_ai 重新导出。原生注册不变。
见 [shared-ai](../../../../shared-ai.md)。


当前接入 MyApps-AI v0.5.3，显式注入平台后端，使用应用所属来源路由与统一设置骨架。WebDAV 入口在任何网络请求前要求设备本地提醒确认；具体见同步概念文档。
