# lib/app/flavor.dart

定义 `AppFlavor`，一个暴露编译期构建风味（`full` vs `store`）的纯静态类，从 `FLAVOR` Dart define（`--dart-define=FLAVOR=store`）读取。风味门控表以及哪些功能必须对商店构建保持隐藏见 [../../architecture.md](../../architecture.md#build-flavors)。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `AppFlavor._` | 构造函数（`AppFlavor`） | B | 阻止直接实例化，只暴露静态成员。 |

`AppFlavor.isStore` 和 `AppFlavor.isFull` 是带普通（非 `Purpose:`）文档注释的 `static const` 字段，不属于函数解释层约定，因此这里不作为单独行索引；它们的一行定义见源码。

## 文档

无。唯一的声明，私有构造函数 `AppFlavor._()`，是 Tier B——一个只阻止实例化的平凡私有构造函数，没有逻辑可记录。
