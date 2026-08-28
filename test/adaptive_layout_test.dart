import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/shared/utils/adaptive_layout.dart';
import 'package:my_anime/shared/utils/detail_layout.dart';

// Every viewport below is a real device's logical-pixel size, with the device
// named in a comment, so a regression names the device it would break.
void main() {
  group('split decision', () {
    test('a Z Fold 8 answers differently in each orientation', () {
      // 4:3 landscape inner panel: 2448 x 1848 px.
      expect(canSplitLayout(933, 704), isTrue); // unfolded, landscape
      expect(canSplitLayout(704, 933), isFalse); // unfolded, portrait
    });

    test('near-square foldables split both ways', () {
      expect(canSplitLayout(750, 832), isTrue); // Z Fold 7 portrait
      expect(canSplitLayout(832, 750), isTrue); // Z Fold 7 landscape
      expect(canSplitLayout(859, 954), isTrue); // Z Fold 8 Ultra portrait
      expect(canSplitLayout(954, 859), isTrue); // Z Fold 8 Ultra landscape
      expect(canSplitLayout(791, 820), isTrue); // Pixel 10 Pro Fold portrait
      expect(canSplitLayout(820, 791), isTrue); // Pixel 10 Pro Fold landscape
    });

    test('older folds still split', () {
      expect(canSplitLayout(659, 791), isTrue); // Z Fold 5
      expect(canSplitLayout(675, 786), isTrue); // Z Fold 6
    });

    test('folded cover screens never split', () {
      expect(canSplitLayout(360, 840), isFalse); // Z Fold 7 / 8 Ultra cover
      expect(canSplitLayout(416, 657), isFalse); // Z Fold 8 cover
      expect(canSplitLayout(411, 923), isFalse); // Pixel 10 Pro Fold cover
    });

    test('short landscape is rejected on height, not width', () {
      expect(canSplitLayout(657, 416), isFalse); // Z Fold 8 cover, landscape
      expect(canSplitLayout(915, 412), isFalse); // ordinary phone, landscape
    });

    test('tablets follow the same rule as the Fold 8', () {
      expect(canSplitLayout(768, 1024), isFalse); // 4:3 tablet portrait
      expect(canSplitLayout(1024, 768), isTrue); // 4:3 tablet landscape
      expect(canSplitLayout(800, 1280), isFalse); // 16:10 tablet portrait
      expect(canSplitLayout(1280, 800), isTrue); // 16:10 tablet landscape
    });

    test('each threshold is exclusive at its boundary', () {
      expect(canSplitLayout(599, 700), isFalse);
      expect(canSplitLayout(600, 700), isTrue);
      expect(canSplitLayout(700, 479), isFalse);
      expect(canSplitLayout(700, 480), isTrue);
      expect(canSplitLayout(810, 1000), isFalse); // aspect 0.81
      expect(canSplitLayout(830, 1000), isTrue); // aspect 0.83
    });

    test('zero or negative height never splits', () {
      expect(canSplitLayout(1200, 0), isFalse);
      expect(canSplitLayout(1200, -100), isFalse);
    });

    test('the detail page delegates to the same rule', () {
      const viewports = <List<double>>[
        [933, 704],
        [704, 933],
        [750, 832],
        [411, 914],
        [915, 412],
        [1024, 768],
        [1600, 900],
      ];
      for (final v in viewports) {
        expect(
          useDetailTwoPane(v[0], v[1]),
          canSplitLayout(v[0], v[1]),
          reason: 'detail page disagreed at ${v[0]}x${v[1]}',
        );
      }
    });
  });

  group('column capacity', () {
    test('an unfolded foldable carries two columns', () {
      expect(listColumnCapacity(659), 2); // Z Fold 5
      expect(listColumnCapacity(704), 2); // Z Fold 8 portrait
      expect(listColumnCapacity(750), 2); // Z Fold 7
      expect(listColumnCapacity(933), 2); // Z Fold 8 landscape
      expect(listColumnCapacity(954), 2); // Z Fold 8 Ultra landscape
    });

    test('tablets and desktops carry more', () {
      expect(listColumnCapacity(1024), 3); // tablet landscape
      expect(listColumnCapacity(1280), 3);
      expect(listColumnCapacity(1600), 4);
    });

    test('never below one nor above the cap', () {
      expect(listColumnCapacity(0), 1);
      expect(listColumnCapacity(-50), 1);
      expect(listColumnCapacity(320), 1);
      expect(listColumnCapacity(4000), listMaxColumns);
    });

    test('a second column needs room for the gap as well', () {
      expect(listColumnCapacity(639), 1);
      expect(listColumnCapacity(652), 2); // 320 + 12 + 320
    });
  });

  group('effective column count', () {
    int columnsAt(double w, double h, int preference) => listColumnCount(
      screenWidth: w,
      screenHeight: h,
      contentWidth: w,
      preference: preference,
    );

    test('auto fills whatever the width allows', () {
      expect(columnsAt(933, 704, listColumnsAuto), 2); // Fold 8 landscape
      expect(columnsAt(1024, 768, listColumnsAuto), 3); // tablet landscape
    });

    test('a viewport that cannot split stays single column', () {
      expect(columnsAt(704, 933, listColumnsAuto), 1); // Fold 8 portrait
      expect(columnsAt(768, 1024, listColumnsAuto), 1); // tablet portrait
      expect(columnsAt(915, 412, listColumnsAuto), 1); // phone landscape
      expect(columnsAt(411, 914, listColumnsAuto), 1); // phone portrait
    });

    test('a pinned preference is honoured within capacity', () {
      expect(columnsAt(1024, 768, 1), 1);
      expect(columnsAt(1024, 768, 2), 2);
      expect(columnsAt(1024, 768, 3), 3);
    });

    test('a pinned preference is clamped, not lost, when it will not fit', () {
      // Set on a desktop, then carried onto a folded phone and back.
      expect(columnsAt(1600, 900, 4), 4);
      expect(columnsAt(933, 704, 4), 2);
      expect(columnsAt(411, 914, 4), 1);
    });

    test('the list gate reads the screen while capacity reads the list', () {
      // A narrow list inside a wide window splits, but only one column fits.
      expect(
        listColumnCount(
          screenWidth: 1024,
          screenHeight: 768,
          contentWidth: 400,
          preference: listColumnsAuto,
        ),
        1,
      );
    });
  });

  group('row count', () {
    test('divides items into rows, ragged last row included', () {
      expect(listRowCount(0, 2), 0);
      expect(listRowCount(1, 2), 1);
      expect(listRowCount(4, 2), 2);
      expect(listRowCount(5, 2), 3);
      expect(listRowCount(7, 3), 3);
    });

    test('a single column is one row per item', () {
      expect(listRowCount(6, 1), 6);
      expect(listRowCount(6, 0), 6);
    });
  });
}
