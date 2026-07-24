# lib/app/flavor.dart

Defines `AppFlavor`, a static-only class exposing the compile-time build flavor (`full` vs
`store`), read from the `FLAVOR` Dart define (`--dart-define=FLAVOR=store`). See
[../../architecture.md](../../architecture.md#build-flavors) for the flavor gating table and which
features must stay hidden from store builds.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `AppFlavor._` | constructor (`AppFlavor`) | B | Prevent direct instantiation and expose only static members. |

`AppFlavor.isStore` and `AppFlavor.isFull` are `static const` fields with plain (non-`Purpose:`)
doc comments, not part of the Function Explanation Layer convention, so they are not indexed as
separate rows here; see the source for their one-line definitions.

## Documentation

None. The only declaration, the private constructor `AppFlavor._()`, is Tier B — a trivial
private constructor that only prevents instantiation, with no logic to document.
