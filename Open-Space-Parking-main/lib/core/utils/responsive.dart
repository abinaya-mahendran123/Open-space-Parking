import 'package:flutter/widgets.dart';

import 'package:open_space_parking/core/config/app_constants.dart';

extension ResponsiveX on BuildContext {
  bool get isMobile => MediaQuery.sizeOf(this).width < AppConstants.mobileBreakpoint;

  bool get isTablet {
    final width = MediaQuery.sizeOf(this).width;
    return width >= AppConstants.mobileBreakpoint &&
        width < AppConstants.tabletBreakpoint;
  }

  bool get isDesktop =>
      MediaQuery.sizeOf(this).width >= AppConstants.tabletBreakpoint;
}
