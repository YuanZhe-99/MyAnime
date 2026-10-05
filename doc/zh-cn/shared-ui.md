# 共享界面基础

MyApps-UI `v0.1.0` 作为子模块放在 `packages/myapps_ui`，相对地址为
`../MyApps-UI.git`。克隆后递归初始化子模块。

`lib/app/theme.dart` 调用 `myapps_ui`，保留原接口和紫色
`0xFF673AB7` 品牌色。公共枚举保持存储名称和默认值。
仅 Android 启用动态配色的策略仍由应用根组件控制。

`lib/shared/utils/adaptive_layout.dart` 重新导出 `myapps_adaptive` 的
公共阈值和 `canSplitLayout`、`useNavigationRail`、`columnCapacity`、`listRowCount`。
动画条目、排行榜控件、统计分栏和剧集布局尺寸仍由应用负责。
原有内容宽度预测行为不变。
导航组件和资料抽取属于后续阶段；数据格式不变。

## 升级

先将共享库发布到两个远程，固定到标签提交，再验证并提交
应用指针。库文档维护公共行为和声明；
应用文档维护品牌配置、业务尺寸和接入说明。
