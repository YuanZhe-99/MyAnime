# lib/shared/widgets/duplicate_check_page.dart

`DuplicateCheckPage` 是设置可访问的页面，扫描整个动画库找重复记录（经 `DuplicateService.detect`），并让用户通过保留一条记录、合并或丢弃其他记录来逐个解决每组。`AGENTS.md` 的"重复检测与合并"一节和 [../../../architecture.md](../../../architecture.md) 描述它如何契合设置/路由器表面；实际检测/合并算法在 `lib/shared/services/duplicate_service.dart`（不属本批）。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`DuplicateCheckPage`](#duplicatecheckpage) | 类（`StatefulWidget`） | A | 显示并解决重复动画组。 |
| `DuplicateCheckPage.new` | 构造函数（`DuplicateCheckPage`） | B | 创建 `DuplicateCheckPage` 实例。 |
| `DuplicateCheckPage.createState` | 方法（`DuplicateCheckPage`） | B | 为此组件创建可变状态对象。 |
| `_DuplicateCheckPageState.initState` | 方法（`_DuplicateCheckPageState`） | B | 触发首次数据加载以初始化状态。 |
| [`_DuplicateCheckPageState._load`](#_duplicatecheckpagestate_load) | 方法（`_DuplicateCheckPageState`） | A | 加载动画数据并运行重复检测。 |
| [`_DuplicateCheckPageState._resolveGroup`](#_duplicatecheckpagestate_resolvegroup) | 方法（`_DuplicateCheckPageState`） | A | 应用用户对一个重复组的保留/合并/删除选择。 |
| `_DuplicateCheckPageState.build` | 方法（`_DuplicateCheckPageState`，组件构建） | B | 构建页面脚手架（加载/空/列表状态）。 |
| `_DuplicateCheckPageState._buildGroupCard` | 方法（组件辅助） | B | 把一个重复组渲染为 `Card`。 |
| `_DuplicateCheckPageState._buildAnimeTile` | 方法（组件辅助） | B | 在组内渲染一个动画行，带保留/合并操作。 |
| `_DuplicateCheckPageState._buildCover` | 方法（组件辅助） | B | 为一部动画渲染封面缩略图或占位图标。 |

## 文档

### `class DuplicateCheckPage extends StatefulWidget` <a id="duplicatecheckpage"></a>
- **种类：** 类（顶层组件）
- **来源：** `lib/shared/widgets/duplicate_check_page.dart`（约第 19 行）
- **用途：** "检查重复"设置流程的入口组件：扫描整个动画库找重复项，并让用户逐组保留、合并或删除冗余记录。
- **输入：** 无（除 `key` 外无构造函数参数）。
- **返回：** 不适用（组件类）。
- **副作用：** 其状态（`_DuplicateCheckPageState`）在 mounted 后读取并修改动画存储。
- **算法：** 实际检测/解决流程见下方 `_load` 和 `_resolveGroup`；本类本身只声明组件及其状态工厂。
- **用法：**
  ```dart
  GoRoute(
    path: '/duplicate-check',
    builder: (context, state) => const DuplicateCheckPage(),
  ),
  ```
  （来自 `lib/app/router.dart`；也从 `lib/features/settings/views/settings_page.dart` 的"检查重复"条目经 `MaterialPageRoute` 直接压栈）
- **备注：** 既经 `go_router`（`/duplicate-check`）路由，也从设置页经直接 `Navigator.push(MaterialPageRoute(...))` 到达——两种不同导航机制到达同一组件。

### `Future<void> _load()` <a id="_duplicatecheckpagestate_load"></a>
- **种类：** `_DuplicateCheckPageState` 的方法
- **来源：** `lib/shared/widgets/duplicate_check_page.dart`（约第 57 行）
- **用途：** 从存储加载完整动画列表并重新计算重复组。
- **输入：** 无。
- **返回：** `Future<void>`。
- **副作用：** 读取 `AnimeStorage.load()`；调用 `setState` 更新 `_allAnime`、`_result` 和 `_loading`。
- **算法：**
  1. Await `AnimeStorage.load()` 取当前 `AnimeData`（全部记录）。
  2. 用 `mounted` 守卫（组件可能在被 await 期间被释放）。
  3. `setState`：把 `data.animes` 存进 `_allAnime`，运行 `DuplicateService.detect(_allAnime)` 并把结果存进 `_result`，设 `_loading = false`。
- **用法：**
  ```dart
  @override
  void initState() {
    super.initState();
    _load();
  }
  ```
  （来自 `_DuplicateCheckPageState.initState`，同一文件；也在 `_resolveGroup` 末尾再次调用，在一次解决后刷新列表）
- **备注：** 不从 `initState` await（即发即忘），因此页面在完成前显示加载转圈（`_loading` 初始为 `true`）。

### `Future<void> _resolveGroup(DuplicateGroup group, int keepIndex, {required bool merge})` <a id="_duplicatecheckpagestate_resolvegroup"></a>
- **种类：** `_DuplicateCheckPageState` 的方法
- **来源：** `lib/shared/widgets/duplicate_check_page.dart`（约第 74 行）
- **用途：** 应用用户对一个重复组选择的解决方式——保留一条记录并丢弃其余，可选先把被丢弃记录的字段合并进被保留记录。
- **输入：** `group` — 被解决的 `DuplicateGroup`；`keepIndex` — 要保留的记录在 `group.animes` 中的索引；`merge` — 删除前是否把其他记录的字段合并进被保留记录。
- **返回：** `Future<void>`。
- **副作用：** 可能调用 `DuplicateService.merge` 和 `AnimeStorage.addOrUpdate`；对未保留记录调用 `FileOpenService.deleteAnimeByIds`；经 `_load()` 重载页面；显示确认解决方式的 `SnackBar`。
- **算法：**
  1. 提取 `kept = group.animes[keepIndex]` 和 `others`（组内其他每条记录，经索引过滤）。
  2. `merge` 为 true 时，计算 `DuplicateService.merge(kept, others)` 并经 `AnimeStorage.addOrUpdate` 保存——这先在被保留记录的 ID 下把 `others` 的字段吸收进 `kept`，然后才删除其他记录。
  3. 经 `FileOpenService.deleteAnimeByIds(others.map((a) => a.id))` 删除 `others` 中每条记录。
  4. 调用 `_load()` 从存储刷新 `_allAnime`/`_result`。
  5. 仍 mounted 时，显示带本地化 `duplicateResolved` 消息的 `SnackBar`。
- **用法：**
  ```dart
  TextButton(
    onPressed: () => _resolveGroup(group, index, merge: false),
    child: Text(l10n.duplicateKeepFirst),
  ),
  TextButton(
    onPressed: () => _resolveGroup(group, index, merge: true),
    child: Text(l10n.duplicateMergeAll),
  ),
  ```
  （来自 `_buildAnimeTile`，同一文件）
- **备注：** `merge` 为 `false`（"保留第一个"）时，未保留记录被直接删除、不做字段吸收——它们独有的任何数据（备注、评分等）都会丢失。合并算法本身（字段回退规则、剧集状态优先级）在 `DuplicateService.merge` 上文档化（见 `lib/shared/services/duplicate_service.dart`，不属本批）。
