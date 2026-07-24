# Home, Management, and Statistics

The three main data-browsing tabs. See [`anime-tracking.md`](anime-tracking.md) for the underlying
model/quarter logic and [`../architecture.md`](../architecture.md) for how these tabs sit in the
`go_router` shell.

## Home (`home_page.dart`)

- JST-aware calendar with an optional local-time date grid.
- Localized/Japanese calendar labels: the calendar can display either localized app-language
  month/weekday labels, or Japanese 日月火水木金土 labels.
- Configurable week start: the global week-start preference defaults to Sunday; when the Japanese
  calendar layout is active, the effective week start is locked to Sunday regardless of the global
  preference.
- The home calendar date grid defaults to Japan time, but can be switched to the device's local
  timezone. Even when switched to local time, anime airing timestamps are still calculated in
  Japan time — blank air times are treated as 23:59 JST by the anime model (see
  [`../data-formats.md`](../data-formats.md)).
- Current-format calendar button text.
- Unwatched aired episodes are surfaced directly on the calendar.

## Management (`management_page.dart`)

- Seasonal quarter browser.
- Global search.
- Dynamic year/quarter picker.
- An "Other" page for anime without `firstAirDate` (which can't be quarter-placed — see
  [`anime-tracking.md`](anime-tracking.md)).
- Creating a new anime navigates to the detail page, then returns Management to the anime's
  quarter when applicable.

## Statistics (`statistics_page.dart`)

- Quarter/year/all scopes.
- Summary counts.
- Full-range scrollable trend charts with focused quarter/year selection; quarter/year granularity
  is selectable for all-scope trends.
- Expandable lists grouped by derived status (completed/watching/dropped/not-started).
- A separate **Ranking** view for rating-based ranking, supporting:
  - all/quarter/year/custom-quarter-range filters
  - type filtering
  - overall or sub-score sorting (see `AnimeRatingField` in [`../data-formats.md`](../data-formats.md))
  - ascending/descending order
  - direct quarter/year pickers
  - cover thumbnails
  - image export/share for the current filtered ranking (see
    [`share-and-import.md`](share-and-import.md))
