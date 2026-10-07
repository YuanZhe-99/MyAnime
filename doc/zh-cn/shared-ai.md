# 共享 AI

## 所有权

MyApps-AI v0.4.1 通过相对同级 URL `../MyApps-AI.git` 嵌入 `packages/myapps_ai`。
全新检出先执行 `git submodule update --init --recursive`，再执行 `flutter pub get`。
依赖路径为 `packages/myapps_ai/packages/myapps_ai`。

`genai_backend.dart` 保留既有通道名称并导出共享类型。
`on_device_ai_service.dart` 负责单例和 Riverpod provider，共享代码负责执行。
`output_validation.dart` 导出共享清理工具。原生通道、业务提示词、事实、解析器和
缓存格式留在应用，原生通道由共享 myapps_ai_platform 插件注册。
授权页列出 myapps_ai、myapps_ai_platform 及 GPL v3 源码。

## 行为

关闭时不查询后端或生成。开关和模型偏好变更使晚到结果失效。45 秒超时现在会在
推进队列前请求原生后端取消。应用 dispose 结束队列中的任务。保留交互优先、
后台节奏、生命周期门控和当日配额行为。取消仍受原生系统实现约束。

## 验证

适配器变更后运行 flutter analyze 和应用测试套件。共享包测试覆盖独立能力状态和
晚到结果失效。共享 CI 已通过 Android ARM64、iOS/macOS release 构建和 Apple 弱链接。
消费者 release 构建及真机推理仍是独立检查。

共享呈现使用 myapps_ai_ui，设置文案、功能门控和操作由应用负责。
分类与推荐流程由应用负责。

## AI 来源与 WebDAV 隐私

MyApps-AI v0.5.3 显式拆分运行时、平台、模型、本地 UI 和 llama.cpp 包。设置使用统一分区骨架。全局来源选择保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。Qwen3.5 0.8B/2B Q4_K_M 与 Gemma 4 E2B Q4_0 在 CPU 上运行。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。

在线来源使用共享在线 UI/后端及 MyApps-UI 输入组件。来源记录和明文 API 密钥仅保存在本设备；密钥使用 SecretStore，不进入同步/备份/ZIP。必须明确选择并确认对应接收主机的隐私提醒。提示词包含分类/推荐输入，不自动回退到在线来源。
