# lib/features/ai/widgets/ai_source_controls.dart

## AI 来源与 WebDAV 隐私

MyApps-AI v0.6.0 显式拆分运行时、平台、模型、本地 UI 和 llama.cpp 包。设置使用统一分区骨架。全局来源选择保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。Qwen3.5 0.8B/2B Q4_K_M 与 Gemma 4 E2B Q4_0 默认在 CPU 上运行；仅当在来源分区中开启且设备经验证时才使用 GPU，GPU 失败会记录在本设备。可在强制警告后从 Hugging Face 仓库添加自定义 GGUF 模型，也可重命名模型。设备本地键 `aiComputePreference`、`aiGpuFailures`、`aiCustomModels` 与 `aiModelAliases` 不同步，也不进入备份。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。

在线来源使用共享在线 UI/后端及 MyApps-UI 输入组件。来源记录和明文 API 密钥仅保存在本设备；密钥使用 SecretStore，不进入同步/备份/ZIP。必须明确选择并确认对应接收主机的隐私提醒。提示词包含分类/推荐输入，不自动回退到在线来源。

## 声明

| 声明 | 用途 |
|---|---|
| `AiSourceControls.new` | 绑定路由器，以及来源变更时暂停 AI 服务的回调 |
| `AiSourceControls.build` | 渲染共享的 `MyAppsAiSourceSection`（选择器、本地模型入口、在线入口、GPU 开关），在线模型显示服务商图标 |
| `openAiLocalModels` | 打开本地模型页：带重命名菜单的模型列表，以及“添加自定义模型”入口（`MyAppsAddCustomModelPage`，Hugging Face GGUF，强制警告） |
| `_modelLabels` | 构建本地模型列表标签；名称来自路由器（友好名称或别名） |
| `_ModelMenu.new` / `_ModelMenu.build` | 单个模型的菜单：重命名；自定义模型还可从列表移除 |
| `_AliasDialog.new` / `_AliasDialog.build` | 重命名对话框；通过路由器保存别名 |

自 1.9.0 起，硬编码的 `modelDisplayName` 已移除；模型显示为 `Qwen: Qwen3.5 0.8B (Q4_K_M)` 的形式。
