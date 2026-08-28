import 'package:flutter_test/flutter_test.dart';
import 'package:my_anime/shared/utils/detail_layout.dart';

/// Purpose: Run anime detail page layout unit tests.
/// Inputs: None.
/// Returns: None.
/// Side effects: None.
/// Notes: Viewport sizes are the real logical-pixel dimensions of the devices
/// named in each case, so a regression names the device it would break.
void main() {
  group('two-pane decision', () {
    test('a Galaxy Z Fold 8 splits unfolded in landscape but not portrait', () {
      // The 4:3 inner panel is the reason this is an aspect rule and not a
      // width breakpoint: one device, one width, two different answers.
      expect(useDetailTwoPane(933, 704), isTrue);
      expect(useDetailTwoPane(704, 933), isFalse);
    });

    test('near-square foldables split in both orientations', () {
      // Z Fold 7.
      expect(useDetailTwoPane(750, 832), isTrue);
      expect(useDetailTwoPane(832, 750), isTrue);
      // Z Fold 8 Ultra.
      expect(useDetailTwoPane(859, 954), isTrue);
      expect(useDetailTwoPane(954, 859), isTrue);
      // Pixel 10 Pro Fold.
      expect(useDetailTwoPane(791, 820), isTrue);
      expect(useDetailTwoPane(820, 791), isTrue);
    });

    test('older Folds still split unfolded at the densest display size', () {
      expect(useDetailTwoPane(659, 791), isTrue); // Z Fold 5
      expect(useDetailTwoPane(675, 786), isTrue); // Z Fold 6
    });

    test('folded cover screens never split', () {
      expect(useDetailTwoPane(360, 840), isFalse); // Z Fold 7 / 8 Ultra cover
      expect(useDetailTwoPane(416, 657), isFalse); // Z Fold 8 cover
      expect(useDetailTwoPane(411, 923), isFalse); // Pixel 10 Pro Fold cover
    });

    test('short landscape viewports are rejected on height, not width', () {
      // Both clear the 600 width floor and the aspect test; only the height
      // floor keeps them single-column.
      expect(useDetailTwoPane(657, 416), isFalse); // Z Fold 8 cover, landscape
      expect(useDetailTwoPane(915, 412), isFalse); // ordinary phone, landscape
    });

    test('tablets follow the same shape rule as the Fold 8', () {
      expect(useDetailTwoPane(768, 1024), isFalse); // 4:3 portrait
      expect(useDetailTwoPane(1024, 768), isTrue); // 4:3 landscape
      expect(useDetailTwoPane(800, 1280), isFalse); // 16:10 portrait
      expect(useDetailTwoPane(1280, 800), isTrue); // 16:10 landscape
    });

    test('each threshold is exclusive on its own boundary', () {
      expect(useDetailTwoPane(599, 700), isFalse);
      expect(useDetailTwoPane(600, 700), isTrue);
      expect(useDetailTwoPane(700, 479), isFalse);
      expect(useDetailTwoPane(700, 480), isTrue);
      expect(useDetailTwoPane(810, 1000), isFalse); // aspect 0.81
      expect(useDetailTwoPane(830, 1000), isTrue); // aspect 0.83
    });

    test('a zero or negative height never splits', () {
      expect(useDetailTwoPane(1200, 0), isFalse);
      expect(useDetailTwoPane(1200, -100), isFalse);
    });
  });

  group('left pane width', () {
    test('scales with the viewport and clamps at both ends', () {
      expect(detailLeftPaneWidth(600), 260); // clamped low
      expect(detailLeftPaneWidth(672), 260); // clamped low
      expect(detailLeftPaneWidth(954), closeTo(343.4, 0.1));
      expect(detailLeftPaneWidth(1600), 420); // clamped high
    });

    test('always leaves the right pane the larger share', () {
      for (final width in [600.0, 704.0, 933.0, 1024.0, 1600.0]) {
        expect(detailLeftPaneWidth(width), lessThan(width / 2));
      }
    });
  });

  group('cover size', () {
    test('keeps the cover aspect ratio', () {
      final cover = detailCoverSize(300, 800);
      expect(
        cover.width / cover.height,
        closeTo(detailCoverAspectRatio, 0.001),
      );
    });

    test('grows with the height left after the header budget', () {
      final short = detailCoverSize(400, 600);
      final tall = detailCoverSize(400, 700);
      expect(tall.height, greaterThan(short.height));
    });

    test('clamps so it neither disappears nor sprawls', () {
      expect(detailCoverSize(400, 100).height, 140);
      expect(detailCoverSize(800, 4000).height, 420);
    });

    test('never takes more than half its pane', () {
      // A Z Fold 8 in landscape: 704 tall, so the flat header budget alone
      // would hand the cover 420 and push the chips off the bottom.
      final cover = detailCoverSize(335, 704);
      expect(cover.height, lessThanOrEqualTo(704 / 2));
      for (final height in [500.0, 704.0, 768.0, 1000.0]) {
        expect(
          detailCoverSize(400, height).height,
          lessThanOrEqualTo(height / 2),
        );
      }
    });

    test('re-derives from width on a narrow, tall pane', () {
      // The Z Fold 8 3:4 case: plenty of height, little width. Without the
      // width check this would return a tall, thin cover that overflows.
      const paneWidth = 260.0;
      final cover = detailCoverSize(paneWidth, 1200);
      expect(cover.width, lessThanOrEqualTo(paneWidth - 32));
      expect(
        cover.width / cover.height,
        closeTo(detailCoverAspectRatio, 0.001),
      );
    });
  });

  group('edit page cover size', () {
    // What the left pane holds under the cover: 16 below it, two 56 dp fields
    // with 12 between them, and 16 of bottom padding.
    double columnHeight(double coverHeight) =>
        coverHeight + 16 + 56 + 12 + 56 + 16;

    test('clamps on a tall pane rather than becoming a poster', () {
      final cover = editCoverSize(420, 900); // desktop
      expect(cover.height, 320);
      expect(cover.width / cover.height, closeTo(editCoverAspectRatio, 0.001));
    });

    test('floors on a short pane so it stays a usable tap target', () {
      final cover = editCoverSize(336, 300);
      expect(cover.height, 140);
    });

    test('re-derives from width on a narrow pane', () {
      const paneWidth = 220.0;
      final cover = editCoverSize(paneWidth, 900);
      expect(cover.width, lessThanOrEqualTo(paneWidth - 32));
      expect(cover.width / cover.height, closeTo(editCoverAspectRatio, 0.001));
    });

    test('the left pane fits without scrolling at every splittable height', () {
      // The load-bearing property: the pane is declared non-scrolling, so the
      // column it holds must fit by construction. 480 is the minimum height
      // canSplitLayout admits; 56 comes off it for the app bar.
      for (
        var screenHeight = 480.0;
        screenHeight <= 1200.0;
        screenHeight += 1
      ) {
        final paneHeight = screenHeight - 56;
        final cover = editCoverSize(336, paneHeight);
        expect(
          columnHeight(cover.height),
          lessThanOrEqualTo(paneHeight),
          reason: 'left pane overflows at screen height $screenHeight',
        );
      }
    });
  });
}
