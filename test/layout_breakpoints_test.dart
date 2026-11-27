import 'dart:ui';

import 'package:asciidoc_editor/ui/adaptive/layout_breakpoints.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveLayoutInfo', () {
    test('phone (412x915) uses single-pane layout with Preview button', () {
      const mq = MediaQueryData(size: Size(412, 915));
      final info = AdaptiveLayoutInfo.fromMediaQuery(mq);

      expect(info.sizeClass, DeviceSizeClass.compact);
      expect(info.isSplitLayout, isFalse);
      expect(info.showPreviewButton, isTrue);
      expect(info.verticalHingeBounds, isNull);
    });

    test('large tablet (1024x768) uses split layout with no Preview button', () {
      const mq = MediaQueryData(size: Size(1024, 768));
      final info = AdaptiveLayoutInfo.fromMediaQuery(mq);

      expect(info.sizeClass, DeviceSizeClass.expanded);
      expect(info.isSplitLayout, isTrue);
      expect(info.showPreviewButton, isFalse);
      expect(info.verticalHingeBounds, isNull);
    });

    test('Googlebook maximized (1280x800) uses split layout with no Preview button', () {
      const mq = MediaQueryData(size: Size(1280, 800));
      final info = AdaptiveLayoutInfo.fromMediaQuery(mq);

      expect(info.sizeClass, DeviceSizeClass.large);
      expect(info.isSplitLayout, isTrue);
      expect(info.showPreviewButton, isFalse);
    });

    test('unfolded foldable with vertical hinge aligns split to hinge bounds', () {
      const hingeRect = Rect.fromLTWH(340, 0, 20, 840);
      const mq = MediaQueryData(
        size: Size(700, 840),
        displayFeatures: [
          DisplayFeature(
            bounds: hingeRect,
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );
      final info = AdaptiveLayoutInfo.fromMediaQuery(mq);

      expect(info.isSplitLayout, isTrue);
      expect(info.showPreviewButton, isFalse);
      expect(info.verticalHingeBounds, hingeRect);
    });
  });
}
