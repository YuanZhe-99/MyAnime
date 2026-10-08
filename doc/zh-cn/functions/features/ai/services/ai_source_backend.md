# lib/features/ai/services/ai_source_backend.dart

## AI 来源与 WebDAV 隐私

MyApps-AI v0.6.0 显式拆分运行时、平台、模型、本地 UI 和 llama.cpp 包。设置使用统一分区骨架。全局来源选择保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。Qwen3.5 0.8B/2B Q4_K_M 与 Gemma 4 E2B Q4_0 默认在 CPU 上运行；仅当在来源分区中开启且设备经验证时才使用 GPU，GPU 失败会记录在本设备。可在强制警告后从 Hugging Face 仓库添加自定义 GGUF 模型，也可重命名模型。设备本地键 `aiComputePreference`、`aiGpuFailures`、`aiCustomModels` 与 `aiModelAliases` 不同步，也不进入备份。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。

在线来源使用共享在线 UI/后端及 MyApps-UI 输入组件。来源记录和明文 API 密钥仅保存在本设备；密钥使用 SecretStore，不进入同步/备份/ZIP。必须明确选择并确认对应接收主机的隐私提醒。提示词包含分类/推荐输入，不自动回退到在线来源。

## 声明

| 声明 | 用途 |
|---|---|
| `createOnlineSources({StorageAdapter? storage})` | 基于 MyAnime 的配置与现有密钥文件创建共享的 `OnlineSourceManager` |
| `createAiSourceRouter({StorageAdapter? storage, CapabilityGenAiBackend? system, OnlineSourceManager? online})` | 基于 MyAnime 存储、系统 AI 通道、`ai_models/` 与在线来源创建共享的 `AiSourceRouter` |

自 1.9.0 起，应用自有的 `AiSourceBackend` 类已移除：路由、模型管理、自定义 Hugging Face 模型、GPU
选项、名称与技术详情均来自 `myapps_ai_sources` 包的 `AiSourceRouter`（MyApps-AI v0.6.0）。本文件同时重新导出
`OnlineSourceManager` 与 `AiSourceRouter`。在线记录、密钥与确认沿用 1.8.11 的键与文件
（`aiOnlineProviders`、`aiOnlineAcknowledgements`、`anime_ai_secrets.json`），因此已有来源会保留。
路由器保存设备本地键 `aiSourceSelection`、`aiComputePreference`、`aiGpuFailures`、`aiCustomModels` 与
`aiModelAliases`。
