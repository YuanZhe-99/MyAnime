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

  group('navigation rail', () {
    test('appears from the medium width class up, whatever the height', () {
      expect(useNavigationRail(599), isFalse); // just under sw600dp
      expect(useNavigationRail(600), isTrue); // exactly sw600dp
      expect(useNavigationRail(933), isTrue); // Z Fold 8, landscape
      expect(useNavigationRail(412), isFalse); // Pixel 9, portrait
    });

    test('a phone in landscape gets a rail but still may not split', () {
      // The case the two rules exist to disagree about. 915x412 is a Pixel 9
      // on its side: wide enough that navigation belongs at the edge, far too
      // short to carry two panes.
      expect(useNavigationRail(915), isTrue);
      expect(canSplitLayout(915, 412), isFalse);
    });

    test('content width is the screen less the rail, when there is one', () {
      expect(shellContentWidth(933), 933 - navRailWidth); // Z Fold 8
      expect(shellContentWidth(412), 412); // Pixel 9, no rail
      expect(shellContentWidth(600), 600 - navRailWidth); // first rail width
      expect(shellContentWidth(0), 0);
    });

    test('the bottom inset is only reserved for a bottom bar', () {
      expect(shellListBottomInset(412), 80); // Pixel 9, bottom bar
      expect(shellListBottomInset(933), 16); // Z Fold 8, rail
    });
  });

  group('generic column capacity', () {
    test('counts items of a given minimum, paying only inner gaps', () {
      // Two 330 columns need 330 + 12 + 330 = 672.
      expect(columnCapacity(671, minItemWidth: 330, maxColumns: 2), 1);
      expect(columnCapacity(672, minItemWidth: 330, maxColumns: 2), 2);
    });

    test('kana tables go two-up on exactly the devices that can hold them', () {
      int kana(double screenWidth) {
        final available = shellContentWidth(screenWidth) - 32;
        return columnCapacity(
          available > 1080 ? 1080 : available,
          minItemWidth: 330,
          maxColumns: 2,
        );
      }

      expect(kana(933), 2); // Z Fold 8, landscape
      expect(kana(954), 2); // Z Fold 8 Ultra, landscape
      expect(kana(859), 2); // Z Fold 8 Ultra, portrait
      expect(kana(791), 2); // Pixel 10 Pro Fold
      expect(kana(832), 2); // Z Fold 7, landscape
      expect(kana(750), 1); // Z Fold 7, portrait
      expect(kana(675), 1); // Z Fold 6
      expect(kana(659), 1); // Z Fold 5
      expect(kana(1024), 2); // tablet, landscape
      expect(kana(1600), 2); // desktop, capped at two
    });

    test('rule cards keep the two-up layout a tablet in portrait had', () {
      // 1.5.3 used a hardcoded `maxWidth >= 720`. The rail now takes 81 of a
      // tablet's 768, leaving 655 â which that literal would have failed.
      final tabletPortrait = shellContentWidth(768) - 32;
      expect(tabletPortrait, lessThan(720));
      expect(
        columnCapacity(tabletPortrait, minItemWidth: 320, maxColumns: 2),
        2,
      );
    });

    test('degenerate arguments fall back rather than divide by zero', () {
      expect(columnCapacity(0, minItemWidth: 320), 1);
      expect(columnCapacity(-10, minItemWidth: 320), 1);
      expect(columnCapacity(1000, minItemWidth: 0, maxColumns: 3), 3);
      expect(columnCapacity(1000, minItemWidth: 320, maxColumns: 0), 1);
    });
  });

  group('settings pane width', () {
    test('is proportional between its clamps', () {
      // Z Fold 8 in landscape, less the rail.
      expect(settingsLeftPaneWidth(852), closeTo(374.88, 0.01));
    });

    test('clamps at both ends', () {
      expect(settingsLeftPaneWidth(669), 300); // Z Fold 7, floor
      expect(settingsLeftPaneWidth(1519), 440); // desktop, ceiling
    });

    test('never squeezes the detail pane below its minimum', () {
      // Z Fold 5 unfolded, less the rail: the floor cannot be honoured and the
      // left pane gives way rather than the right becoming unusable.
      final left = settingsLeftPaneWidth(578);
      expect(left, 578 - settingsRightPaneMinWidth);
      expect(578 - left, settingsRightPaneMinWidth);
    });
  });

  group('statistics summary beside the chart', () {
    test('needs both blocks to fit, not merely a wide window', () {
      // The gate is exactly the two minimums plus the gap between them.
      expect(useStatsSideBySide(651), isFalse);
      expect(useStatsSideBySide(652), isTrue);
    });

    test('the three foldables that split but stay stacked', () {
      // All three pass canSplitLayout and still fail on width: the chart would
      // be left too little to plot in. This is why the gate has two parts.
      expect(canSplitLayout(659, 791), isTrue); // Z Fold 5
      expect(canSplitLayout(675, 786), isTrue); // Z Fold 6
      expect(canSplitLayout(750, 832), isTrue); // Z Fold 7 portrait
      expect(useStatsSideBySide(shellContentWidth(659) - 32), isFalse);
      expect(useStatsSideBySide(shellContentWidth(675) - 32), isFalse);
      expect(useStatsSideBySide(shellContentWidth(750) - 32), isFalse);
    });

    test('the devices that do get it', () {
      expect(useStatsSideBySide(shellContentWidth(933) - 32), isTrue); // Fold 8
      expect(useStatsSideBySide(shellContentWidth(791) - 32), isTrue); // Pixel
      expect(useStatsSideBySide(shellContentWidth(832) - 32), isTrue); // Fold 7
      expect(
        useStatsSideBySide(shellContentWidth(1024) - 32),
        isTrue,
      ); // tablet
    });

    test('the card pane is proportional between its clamps', () {
      expect(statsSummaryPaneWidth(820), closeTo(278.8, 0.01)); // Z Fold 8
      expect(statsSummaryPaneWidth(678), statsSummaryPaneMinWidth); // floor
      expect(statsSummaryPaneWidth(1487), 360); // desktop ceiling
    });

    test('the chart always keeps its minimum once the gate has passed', () {
      // The invariant that lets statsSummaryPaneWidth skip the right-hand cap
      // that settingsLeftPaneWidth needs: the pane grows at 0.34 of the width
      // and the chart at 0.66, so the floor is met exactly at the gate and only
      // widens above it.
      for (var width = 652.0; width <= 2000.0; width += 1) {
        final chart = width - statsSummaryPaneWidth(width) - listTileGap;
        expect(
          chart,
          greaterThanOrEqualTo(statsChartMinWidth),
          reason: 'chart starved at content width $width',
        );
      }
    });
  });

  group('ranking filter panel', () {
    int filterPairs(double width) => columnCapacity(
      width,
      minItemWidth: rankingFilterMinWidth,
      maxColumns: 2,
    );

    test('the two filter dropdowns pair from 572 up', () {
      expect(filterPairs(571), 1);
      expect(filterPairs(572), 2);
    });

    test('the three sort controls share a row from 674 up', () {
      expect(useRankingSortRow(673), isFalse);
      expect(useRankingSortRow(674), isTrue);
    });

    test('a phone in landscape gets both, although it never splits', () {
      // 915 x 412: the rail applies, the split rule does not, and the pairing
      // is a width question — so the shortest viewport of all gets the biggest
      // saving. Held in portrait the same phone keeps today's stacked panel.
      final landscape = shellContentWidth(915) - 32;
      expect(canSplitLayout(915, 412), isFalse);
      expect(filterPairs(landscape), 2);
      expect(useRankingSortRow(landscape), isTrue);

      final portrait = shellContentWidth(412) - 32;
      expect(filterPairs(portrait), 1);
      expect(useRankingSortRow(portrait), isFalse);
    });

    test('the custom-range buttons now share the filters own minimum', () {
      // 1.5.4 left an inline `maxWidth < 560` here — the same question as the
      // pairing above, asked its own way. It now asks it the same way, which
      // moves the threshold by 12 logical pixels and nothing else.
      expect(filterPairs(560), 1);
      expect(filterPairs(572), 2);
    });
  });
}
