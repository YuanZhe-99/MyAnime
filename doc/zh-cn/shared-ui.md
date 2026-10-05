# 共享界面基础

MyApps-UI `v0.1.2` 作为子模块放在 `packages/myapps_ui`，相对地址为
`../MyApps-UI.git`。克隆后递归初始化子模块。

`lib/app/theme.dart` 调用 `myapps_ui`，保留原接口和紫色
`0xFF673AB7` 品牌色。公共枚举保持存储名称和默认值。
仅 Android 启用动态配色的策略仍由应用根组件控制。

`lib/shared/utils/adaptive_layout.dart` 重新导出 `myapps_adaptive` 的
公共阈值和 `canSplitLayout`、`useNavigationRail`、`columnCapacity`、`listRowCount`。
动画条目、排行榜控件、统计分栏和剧集布局尺寸仍由应用负责。

## 升级

先将共享库发布到两个远程，固定到标签提交，再验证并提交
应用指针。库文档维护公共行为和声明；
应用文档维护品牌配置、业务尺寸和接入说明。

## P2 导航与实际空间

应用现在把导航绘制交给 `MyAppsNavigationShell`。应用导航壳保留路由、
目的地过滤、选中位置持久化和提醒回调。页面把 `context` 传入宽度和底部留白
函数，只使用一次实际内容宽度；全窗口路由不再扣除侧栏。无上下文的兼容函数
保留原计算方式。固定内容位置在缩放、风格和侧栏方向切换时保留页面状态。
MyVidComp 保留经典导航、展开侧栏和审核角标。

P3 资料抽取已完成，数据格式不变。

## P3 资料与头像

五个拥有资料功能的应用接入 `myapps_profile`，共享资料模型、合并、图片处理、
存储协调、头像显示、编辑器和标题组件。应用 ProfileStore 提供当前目录、原子写入
和同步通知，图片解析和删除通过适配注入。原导入文件成为重新导出包装。
Riverpod 状态、数据模块注册、选择器和本地化编辑对话框仍由应用负责。
JSON、模块顺序、图片命名和字段合并行为不变。
