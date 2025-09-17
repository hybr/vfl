import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';

/// Adaptive layout widget that builds different layouts for different screen sizes
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  final Widget? tv;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.tv,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveHelper.getDeviceType(context);

    switch (deviceType) {
      case DeviceType.tv:
        return tv ?? desktop ?? tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.mobile:
        return mobile;
    }
  }
}

/// Responsive container with max width constraints
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final bool useMaxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.useMaxWidth = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = useMaxWidth ? ResponsiveHelper.getMaxContentWidth(context) : null;
    final responsivePadding = padding ?? ResponsiveHelper.getContentPadding(context);

    return Center(
      child: Container(
        width: maxWidth,
        padding: responsivePadding,
        child: child,
      ),
    );
  }
}

/// Responsive grid with adaptive column count
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int? mobileColumns;
  final int? tabletColumns;
  final int? desktopColumns;
  final int? ultraWideColumns;
  final double spacing;
  final double runSpacing;
  final double? childAspectRatio;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns,
    this.tabletColumns,
    this.desktopColumns,
    this.ultraWideColumns,
    this.spacing = 16,
    this.runSpacing = 16,
    this.childAspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveBreakpoints.getGridColumns(
      context,
      mobile: mobileColumns ?? 1,
      tablet: tabletColumns ?? 2,
      desktop: desktopColumns ?? 3,
      ultraWide: ultraWideColumns ?? 4,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: spacing,
        mainAxisSpacing: runSpacing,
        childAspectRatio: childAspectRatio ?? 1.0,
      ),
      itemCount: children.length,
      itemBuilder: (context, index) => children[index],
    );
  }
}

/// Responsive text that scales based on screen size
class ResponsiveText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final double baseFontSize;
  final double? tabletFontSize;
  final double? desktopFontSize;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const ResponsiveText(
    this.text, {
    super.key,
    this.style,
    required this.baseFontSize,
    this.tabletFontSize,
    this.desktopFontSize,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = ResponsiveBreakpoints.getFontSize(
      context,
      mobile: baseFontSize,
      tablet: tabletFontSize,
      desktop: desktopFontSize,
    );

    return Text(
      text,
      style: (style ?? const TextStyle()).copyWith(fontSize: fontSize),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Adaptive form layout
class ResponsiveForm extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ResponsiveForm({
    super.key,
    required this.children,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveHelper.shouldUseCompactLayout(context);

    if (isCompact) {
      // Single column layout for mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children
            .map((child) => Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: child,
                ))
            .toList(),
      );
    } else {
      // Multi-column layout for larger screens
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: children
            .map((child) => SizedBox(
                  width: (MediaQuery.of(context).size.width - spacing * 3) / 2,
                  child: child,
                ))
            .toList(),
      );
    }
  }
}

/// Responsive card with adaptive sizing
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double? elevation;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = padding ?? EdgeInsets.all(
      ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 20, desktop: 24),
    );

    return Card(
      color: color,
      elevation: elevation ?? (ResponsiveHelper.isDesktop(context) ? 2 : 1),
      child: Padding(
        padding: responsivePadding,
        child: child,
      ),
    );
  }
}

/// Responsive spacing widget
class ResponsiveSpacing extends StatelessWidget {
  final double mobile;
  final double? tablet;
  final double? desktop;
  final bool horizontal;

  const ResponsiveSpacing({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = ResponsiveBreakpoints.getSpacing(
      context,
      mobile: mobile,
      tablet: tablet ?? mobile * 1.5,
      desktop: desktop ?? mobile * 2,
    );

    return SizedBox(
      width: horizontal ? spacing : null,
      height: horizontal ? null : spacing,
    );
  }
}

/// Responsive list/grid switcher
class ResponsiveListGrid extends StatelessWidget {
  final List<Widget> children;
  final bool forceList;
  final double spacing;

  const ResponsiveListGrid({
    super.key,
    required this.children,
    this.forceList = false,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final useGrid = !forceList && !ResponsiveHelper.shouldUseCompactLayout(context);

    if (useGrid) {
      return ResponsiveGrid(
        spacing: spacing,
        runSpacing: spacing,
        children: children,
      );
    } else {
      return Column(
        children: children
            .map((child) => Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: child,
                ))
            .toList(),
      );
    }
  }
}