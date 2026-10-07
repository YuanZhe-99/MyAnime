# lib/shared/services/webdav_privacy.dart

## AI 来源与 WebDAV 隐私

MyApps-AI v0.5.3 显式拆分运行时、平台、模型、本地 UI 和 llama.cpp 包。设置使用统一分区骨架。全局来源选择保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。Qwen3.5 0.8B/2B Q4_K_M 与 Gemma 4 E2B Q4_0 在 CPU 上运行。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。

在线来源使用共享在线 UI/后端及 MyApps-UI 输入组件。来源记录和明文 API 密钥仅保存在本设备；密钥使用 SecretStore，不进入同步/备份/ZIP。必须明确选择并确认对应接收主机的隐私提醒。提示词包含分类/推荐输入，不自动回退到在线来源。

## Declarations

| Declaration | Purpose |
|---|---|
| `static Future<bool> allowed() async =>` | Determine whether sync may run. Inputs: None. Returns: Consent. |
| `static Future<WebDavPrivacyStatus> status(bool configured) async =>` | Classify a configured device. Inputs: configured. Returns: Status. |
| `static Future<bool> ensure(BuildContext context, WebDAVConfig config) async {` | Obtain consent before saving or making any request. |
