# lib/features/anime/services/manage_grouping.dart

The Manage tab's series view (1.6.2): the two view-state enums the tab remembers, their parsers, and
the pure function that turns the library into rows. See
[`../views/management_page.md`](../views/management_page.md) and
[`../../../../features/home-management-statistics.md`](../../../../features/home-management-statistics.md#management-management_pagedart).

## Declarations

| Declaration | Kind | Tier | Purpose |
|---|---|---|---|
| `parseManageViewMode` | top-level function | B | Parse `manageViewMode`; anything but `series` is the quarter view. |
| `parseManageSeriesSort` | top-level function | B | Parse `manageSeriesSort`; unknown values are `latest`. |
| `ManageSeriesGroup.new` | constructor (`ManageSeriesGroup`) | B | Create one row: key, label, members, optional series. |
| `ManageSeriesGroup.isGroup` | getter (`ManageSeriesGroup`) | B | Whether the row expands (two or more members). |
| [`groupForSeriesView`](#groupforseriesview) | top-level function | A | Group the library for the series view. |

The enums carry no `/// Purpose:` comment:

| Enum | Values | Stored as |
|---|---|---|
| `ManageViewMode` | `quarter` (default), `series` | `manageViewMode`, written only for `series` |
| `ManageSeriesSort` | `latest` (default), `title`, `modified` | `manageSeriesSort`, written only when not `latest` |

## Documentation

### `List<ManageSeriesGroup> groupForSeriesView(List<Anime> all, {required bool Function(Anime) keep, required ManageSeriesSort sort})` <a id="groupforseriesview"></a>
- **Kind:** top-level function
- **Source:** `lib/features/anime/services/manage_grouping.dart` (approx. line 92)
- **Purpose:** Turn the library into series-view rows.
- **Inputs:** `all` — the whole library; `keep` — the page's archive and category filters; `sort`.
- **Returns:** `List<ManageSeriesGroup>` — every kept record exactly once.
- **Side effects:** None.
- **Algorithm:**
  1. `SeriesIndex.build(all)` — over the **whole** library, so a filter never changes which records
     belong together.
  2. For each kept record not yet placed: a series of two or more members contributes its kept
     members, in series order. Two or more → one group keyed by the series key and labelled by
     `stripSeasonMarkers` of the first member's title (the title itself if stripping leaves
     nothing). One → a single row keyed `id:<id>` and labelled by its title. Records in no series,
     standalone records and one-member curated series are single rows too.
  3. Sort: `latest` — the newest `firstAirDate` among the members first, undated rows last;
     `title` — label, case-insensitive; `modified` — the newest `modifiedAt` among the members first.
     Ties go by label, then the first member's id.
- **Usage:** `_ManagementPageState._seriesGroups`.
- **Notes:** Deterministic for the same library. Tested in `test/manage_grouping_test.dart`.
