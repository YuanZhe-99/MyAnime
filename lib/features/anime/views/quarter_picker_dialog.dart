import 'package:flutter/material.dart';

class QuarterSelection {
  final int year;
  final int quarter;

  /// Purpose: Create a quarter selection instance.
  /// Inputs: `year`, `quarter`.
  /// Returns: A new `QuarterSelection` instance.
  /// Side effects: None.
  /// Notes: None.
  const QuarterSelection(this.year, this.quarter);

  /// Purpose: Return whether other is true.
  /// Inputs: None.
  /// Returns: `bool`.
  /// Side effects: None.
  /// Notes: None.
  bool get isOther => year == 0 && quarter == 0;

  /// Purpose: Implement the q behavior for this file.
  /// Inputs: None.
  /// Returns: `int`.
  /// Side effects: None.
  /// Notes: None.
  int get q => quarter;
}

typedef QuarterCountBuilder = int Function(int year, int quarter);

/// Purpose: Implement the show quarter picker dialog behavior for this file.
/// Inputs: `context`, `title`, `minYear`, `maxYear`, `current`, `countBuilder`, `includeOther`, `otherLabel`, `otherCount`, `isOtherSelected`.
/// Returns: `Future<QuarterSelection?>`.
/// Side effects: None.
/// Notes: None.
Future<QuarterSelection?> showQuarterPickerDialog({
  required BuildContext context,
  required String title,
  required int minYear,
  required int maxYear,
  QuarterSelection? current,
  QuarterCountBuilder? countBuilder,
  bool includeOther = false,
  String? otherLabel,
  int otherCount = 0,
  bool isOtherSelected = false,
}) async {
  const rowHeight = 44.0;
  final currentRow = current != null ? current.year - minYear : 0;
  final initialOffset = ((currentRow - 3) * rowHeight).clamp(
    0.0,
    double.infinity,
  );
  final scrollCtrl = ScrollController(initialScrollOffset: initialOffset);

  final result = await showDialog<QuarterSelection>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
        content: SizedBox(
          width: 300,
          height: includeOther ? 360 : 320,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    for (final label in ['Q1', 'Q2', 'Q3', 'Q4'])
                      Expanded(
                        child: Center(
                          child: Text(
                            label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollCtrl,
                  itemCount: maxYear - minYear + 1,
                  itemExtent: rowHeight,
                  itemBuilder: (context, index) {
                    final year = minYear + index;
                    return Row(
                      children: [
                        SizedBox(
                          width: 48,
                          child: Text(
                            '$year',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        for (int quarter = 1; quarter <= 4; quarter++)
                          Expanded(
                            child: _quarterGridCell(
                              year: year,
                              quarter: quarter,
                              current: current,
                              countBuilder: countBuilder,
                              theme: theme,
                              dialogContext: dialogContext,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (includeOther) ...[
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Material(
                    color: isOtherSelected
                        ? theme.colorScheme.primary
                        : otherCount > 0
                        ? theme.colorScheme.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => Navigator.pop(
                        dialogContext,
                        const QuarterSelection(0, 0),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Text(
                              otherLabel ?? 'Other',
                              style: TextStyle(
                                color: isOtherSelected
                                    ? theme.colorScheme.onPrimary
                                    : null,
                                fontWeight: isOtherSelected
                                    ? FontWeight.bold
                                    : null,
                              ),
                            ),
                            const Spacer(),
                            if (otherCount > 0)
                              Text(
                                '$otherCount',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOtherSelected
                                      ? theme.colorScheme.onPrimary
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
        ],
      );
    },
  );
  scrollCtrl.dispose();
  return result;
}

/// Purpose: Provide the internal quarter grid cell helper for this file.
/// Inputs: `year`, `quarter`, `current`, `countBuilder`, `theme`, `dialogContext`.
/// Returns: `Widget`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
Widget _quarterGridCell({
  required int year,
  required int quarter,
  required QuarterSelection? current,
  required QuarterCountBuilder? countBuilder,
  required ThemeData theme,
  required BuildContext dialogContext,
}) {
  final isCurrent =
      current != null && year == current.year && quarter == current.quarter;
  final count = countBuilder?.call(year, quarter) ?? 0;
  final hasData = count > 0;

  return Padding(
    padding: const EdgeInsets.all(2),
    child: Material(
      color: isCurrent
          ? theme.colorScheme.primary
          : hasData
          ? theme.colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () =>
            Navigator.pop(dialogContext, QuarterSelection(year, quarter)),
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            hasData ? '$count' : '',
            style: TextStyle(
              fontSize: 12,
              color: isCurrent
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onPrimaryContainer,
              fontWeight: isCurrent ? FontWeight.bold : null,
            ),
          ),
        ),
      ),
    ),
  );
}
