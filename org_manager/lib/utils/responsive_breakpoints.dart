import 'package:flutter/material.dart';

/// 2025 Responsive Design Standards
/// Following modern RWD principles with fluid typography and adaptive layouts
class ResponsiveBreakpoints {
  // Modern breakpoints following 2025 standards
  static const double mobile = 480;     // Phone portrait
  static const double mobileLarge = 576; // Phone landscape
  static const double tablet = 768;     // Tablet portrait
  static const double tabletLarge = 992; // Tablet landscape
  static const double desktop = 1200;   // Desktop small
  static const double desktopLarge = 1400; // Desktop large
  static const double ultraWide = 1920; // Ultra-wide displays

  // Container max widths for content
  static const double maxContentWidth = 1200;
  static const double maxWideContentWidth = 1400;

  // Responsive spacing scale
  static double getSpacing(BuildContext context, {
    double mobile = 16,
    double tablet = 24,
    double desktop = 32,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) return desktop;
    if (width >= ResponsiveBreakpoints.tablet) return tablet;
    return mobile;
  }

  // Responsive typography scale
  static double getFontSize(BuildContext context, {
    required double mobile,
    double? tablet,
    double? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) {
      return desktop ?? tablet ?? mobile * 1.25;
    }
    if (width >= ResponsiveBreakpoints.tablet) {
      return tablet ?? mobile * 1.125;
    }
    return mobile;
  }

  // Grid columns based on screen size
  static int getGridColumns(BuildContext context, {
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int ultraWide = 4,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.ultraWide) return ultraWide;
    if (width >= ResponsiveBreakpoints.desktop) return desktop;
    if (width >= ResponsiveBreakpoints.tablet) return tablet;
    return mobile;
  }
}

/// Device type detection for adaptive UI
enum DeviceType {
  mobile,
  tablet,
  desktop,
  tv,
}

class ResponsiveHelper {
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;
    final diagonal = MediaQuery.of(context).size.shortestSide;

    // TV detection (large screens with specific aspect ratios)
    if (width >= 1920 && height >= 1080) return DeviceType.tv;

    // Desktop detection
    if (width >= ResponsiveBreakpoints.desktop) return DeviceType.desktop;

    // Tablet detection (considering both orientation and diagonal)
    if (diagonal >= 600 || width >= ResponsiveBreakpoints.tablet) {
      return DeviceType.tablet;
    }

    return DeviceType.mobile;
  }

  static bool isMobile(BuildContext context) =>
      getDeviceType(context) == DeviceType.mobile;

  static bool isTablet(BuildContext context) =>
      getDeviceType(context) == DeviceType.tablet;

  static bool isDesktop(BuildContext context) =>
      getDeviceType(context) == DeviceType.desktop;

  static bool isTV(BuildContext context) =>
      getDeviceType(context) == DeviceType.tv;

  // Check if device has enough space for side navigation
  static bool shouldUseSideNav(BuildContext context) {
    return MediaQuery.of(context).size.width >= ResponsiveBreakpoints.tabletLarge;
  }

  // Check if device should use compact layouts
  static bool shouldUseCompactLayout(BuildContext context) {
    return MediaQuery.of(context).size.width < ResponsiveBreakpoints.tablet;
  }

  // Get appropriate padding for content areas
  static EdgeInsets getContentPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.desktop) {
      return const EdgeInsets.all(32);
    }
    if (width >= ResponsiveBreakpoints.tablet) {
      return const EdgeInsets.all(24);
    }
    return const EdgeInsets.all(16);
  }

  // Get maximum width for content containers
  static double getMaxContentWidth(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= ResponsiveBreakpoints.ultraWide) {
      return ResponsiveBreakpoints.maxWideContentWidth;
    }
    if (width >= ResponsiveBreakpoints.desktop) {
      return ResponsiveBreakpoints.maxContentWidth;
    }
    return width;
  }
}