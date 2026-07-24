# lib/features/settings/views/license_page.dart

`LicensePage` is a tiny, fully static settings sub-page reached from Settings -> About -> License
(see `functions/features/settings/views/settings_page.md`). It has no state and no service
dependencies: the entire page is a `StatelessWidget` that renders a single hard-coded
`SelectableText` block holding the project's GPLv3 license notice (stored as the private
`_licenseText` static const `String` field). There is no Tier A logic in this file — it exists
purely to display static text, distinct from the generated third-party license page reachable via
`showLicensePage` elsewhere in `settings_page.dart`.

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `LicensePage({super.key})` | constructor (`LicensePage`) | B | Create a license page instance. |
| `build` | method (widget build) | B | Render the static GPLv3 license text in a scrollable, selectable view. |

## Documentation

No Tier A declarations in this file — both members are Tier B (a trivial constructor and a
`build` method that only lays out a `Scaffold`/`SelectableText` around the static
`_licenseText` field). See the Declarations table above for the full member list.
