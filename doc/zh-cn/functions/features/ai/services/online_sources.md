# lib/features/ai/services/online_sources.dart

## AI 来源与 WebDAV 隐私

MyApps-AI v0.5.3 显式拆分运行时、平台、模型、本地 UI 和 llama.cpp 包。设置使用统一分区骨架。全局来源选择保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。Qwen3.5 0.8B/2B Q4_K_M 与 Gemma 4 E2B Q4_0 在 CPU 上运行。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。

在线来源使用共享在线 UI/后端及 MyApps-UI 输入组件。来源记录和明文 API 密钥仅保存在本设备；密钥使用 SecretStore，不进入同步/备份/ZIP。必须明确选择并确认对应接收主机的隐私提醒。提示词包含分类/推荐输入，不自动回退到在线来源。

## Declarations

| Declaration | Purpose |
|---|---|
| `OnlineSources({StorageAdapter? storage})` | Bind device-local storage. Inputs: optional test storage. |
| `Future<void> initialize() => _loading ??= _load();` | Read local providers once. Inputs: None. Returns: Completion. |
| `Future<void> _load() async {` | Load provider records. Inputs: None. Returns: Completion. |
| `List<OnlineProvider> get providers => List.unmodifiable(_providers);` | Return configured providers. Inputs: None. Returns: List. |
| `Listenable get changes => _notifier;` | Observe changes. Inputs: None. Returns: Listenable. |
| `OnlineProviderTemplateRegistry get templates =>` | Register standard templates. Inputs: None. Returns: Registry. |
| `String newProviderId() => 'provider:${const Uuid().v4()}';` | Allocate a provider id. Inputs: None. Returns: Id. |
| `Future<bool> hasKey(String providerId) async =>` | Check stored key presence. Inputs: id. Returns: Boolean. |
| `Future<void> save(` | Save acknowledged configuration and optional key. |
| `Future<void> remove(String providerId) async {` | Remove a provider and key. Inputs: id. Returns: Completion. |
| `Future<GenAiStatusReport> testConnection(` | Test an explicit draft. Inputs: provider/key. Returns: Report. |
| `OnlinePrivacyNotice? privacyNotice(OnlineProvider provider) =>` | Describe transmitted content. Inputs: provider. Returns: Notice. |
| `Future<OnlinePrivacyAcknowledgement?> acknowledgement(` | Read host-specific consent. Inputs: id. Returns: Record. |
| `Future<void> acknowledge(` | Persist consent. Inputs: id/record. Returns: Completion. |
