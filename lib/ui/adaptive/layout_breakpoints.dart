import 'dart:ui';

import 'package:flutter/widgets.dart';

enum DeviceSizeClass {
  compact,
  medium,
  expanded,
  large,
}

@immutable
class AdaptiveLayoutInfo {
  const AdaptiveLayoutInfo({
    required this.sizeClass,
    required this.isSplitLayout,
    required this.showPreviewButton,
    this.verticalHingeBounds,
  });

  final DeviceSizeClass sizeClass;
  final bool isSplitLayout;
  final bool showPreviewButton;
  final Rect? verticalHingeBounds;

  static const double mediumBreakpoint = 600;
  static const double expandedBreakpoint = 840;
  static const double largeBreakpoint = 1200;
  static const double minHingePaneWidth = 280;

  static AdaptiveLayoutInfo fromMediaQuery(MediaQueryData mediaQuery) {
    final size = mediaQuery.size;
    final width = size.width;

    final DeviceSizeClass sizeClass;
    if (width >= largeBreakpoint) {
      sizeClass = DeviceSizeClass.large;
    } else if (width >= expandedBreakpoint) {
      sizeClass = DeviceSizeClass.expanded;
    } else if (width >= mediumBreakpoint) {
      sizeClass = DeviceSizeClass.medium;
    } else {
      sizeClass = DeviceSizeClass.compact;
    }

    Rect? verticalHinge;
    for (final feature in mediaQuery.displayFeatures) {
      final isFoldOrHinge = feature.type == DisplayFeatureType.hinge ||
          feature.type == DisplayFeatureType.fold;
      if (!isFoldOrHinge) continue;

      final bounds = feature.bounds;
      final isVertical = bounds.height > bounds.width;
      final leftWidth = bounds.left;
      final rightWidth = width - bounds.right;
      if (isVertical &&
          leftWidth >= minHingePaneWidth &&
          rightWidth >= minHingePaneWidth) {
        verticalHinge = bounds;
        break;
      }
    }

    final isSplitLayout = width >= expandedBreakpoint || verticalHinge != null;

    return AdaptiveLayoutInfo(
      sizeClass: sizeClass,
      isSplitLayout: isSplitLayout,
      showPreviewButton: !isSplitLayout,
      verticalHingeBounds: verticalHinge,
    );
  }
}
