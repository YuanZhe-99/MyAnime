import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../utils/adaptive_layout.dart';

/// Purpose: Build one row of a multi-column list, filled left to right.
/// Inputs: `rowIndex` — the zero-based row; `columns` — tiles per row;
/// `itemCount` — total tiles in the list; `itemBuilder` — builds one tile by
/// its index in the flat list; `gap` — spacing between columns.
/// Returns: A `Row` of equally wide tiles.
/// Side effects: None.
/// Notes: Deliberately a `Row` of `Expanded` children rather than a `GridView`.
/// Two of the three list modules build their tiles as children of an outer
/// scroll view, where a nested scrollable would need `shrinkWrap`, and the
/// third relies on `ListView.builder` virtualization that a pre-built grid
/// would throw away. Feeding this from a builder over [listRowCount] rows keeps
/// both properties and yields left-to-right, top-to-bottom order. Short final
/// rows are padded with empty cells so the remaining tiles keep their width
/// instead of stretching across the row.
Widget adaptiveTileRow({
  required int rowIndex,
  required int columns,
  required int itemCount,
  required Widget Function(int index) itemBuilder,
  double gap = listTileGap,
}) {
  final children = <Widget>[];
  for (var column = 0; column < columns; column++) {
    if (column > 0) children.add(SizedBox(width: gap));
    final index = rowIndex * columns + column;
    children.add(
      Expanded(
        child: index < itemCount ? itemBuilder(index) : const SizedBox.shrink(),
      ),
    );
  }
  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
}

/// Purpose: Build a list's children as rows, single column or multi-column.
/// Inputs: `columns`, `itemCount`, `itemBuilder`, `gap`.
/// Returns: A list of widgets ready to spread into a `ListView` or `Column`.
/// Side effects: None.
/// Notes: At one column this returns the tiles untouched, so callers that wrap
/// their single-column tile in something else — the management page's
/// `Dismissible`, for instance — keep their existing widget tree exactly.
List<Widget> adaptiveTileRows({
  required int columns,
  required int itemCount,
  required Widget Function(int index) itemBuilder,
  double gap = listTileGap,
}) {
  if (columns <= 1) {
    return List.generate(itemCount, itemBuilder);
  }
  return List.generate(
    listRowCount(itemCount, columns),
    (rowIndex) => adaptiveTileRow(
      rowIndex: rowIndex,
      columns: columns,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      gap: gap,
    ),
  );
}

/// Purpose: Build the app-bar control that picks a list's column count.
/// Inputs: `context`; `preference` — the stored choice; `capacity` — the most
/// columns the current width can carry; `onChanged` — receives the new
/// preference.
/// Returns: A `PopupMenuButton`, or an empty widget when the window cannot
/// carry more than one column.
/// Side effects: None beyond invoking `onChanged` when the user picks.
/// Notes: Hidden rather than disabled when `capacity` is 1, so a phone and a
/// folded cover screen never show a control that could not do anything. The
/// menu always offers every count up to [listMaxColumns] so a preference can be
/// set while folded and take effect on unfolding; the check mark tracks the
/// stored preference, while what renders is that preference clamped to what
/// fits.
Widget listColumnsButton(
  BuildContext context, {
  required int preference,
  required int capacity,
  required ValueChanged<int> onChanged,
}) {
  if (capacity <= 1) return const SizedBox.shrink();
  final l10n = AppLocalizations.of(context)!;
  return PopupMenuButton<int>(
    icon: const Icon(Icons.view_column_outlined),
    tooltip: l10n.listColumns,
    initialValue: preference,
    onSelected: onChanged,
    itemBuilder: (context) => [
      PopupMenuItem(value: listColumnsAuto, child: Text(l10n.listColumnsAuto)),
      for (var n = 1; n <= listMaxColumns; n++)
        PopupMenuItem(value: n, child: Text(l10n.listColumnsCount(n))),
    ],
  );
}
