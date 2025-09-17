import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/responsive_breakpoints.dart';
import 'adaptive_navigation.dart';
import 'responsive_layout.dart';

/// Main layout wrapper that provides adaptive navigation and responsive structure
class MainLayout extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final bool showAppBar;
  final bool showNavigation;

  const MainLayout({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showAppBar = true,
    this.showNavigation = true,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).fullPath ?? '/';

    if (!showNavigation) {
      // For auth screens and other standalone pages
      return Scaffold(
        appBar: showAppBar
            ? AdaptiveAppBar(
                title: title ?? 'Organization Manager',
                actions: actions,
              )
            : null,
        body: ResponsiveContainer(child: child),
        floatingActionButton: floatingActionButton,
      );
    }

    // Main app layout with adaptive navigation
    return AdaptiveNavigation(
      currentRoute: currentRoute,
      body: Column(
        children: [
          if (showAppBar)
            AdaptiveAppBar(
              title: title ?? 'Organization Manager',
              actions: actions,
            ),
          Expanded(
            child: ResponsiveContainer(
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Responsive page wrapper with consistent spacing and max-width
class ResponsivePage extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;
  final bool showBackButton;
  final EdgeInsetsGeometry? padding;

  const ResponsivePage({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
    this.showBackButton = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final responsivePadding = padding ?? ResponsiveHelper.getContentPadding(context);

    return MainLayout(
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
      child: SingleChildScrollView(
        padding: responsivePadding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveHelper.getMaxContentWidth(context),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Responsive dialog that adapts to screen size
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);
    final dialogWidth = isDesktop ? 600.0 : MediaQuery.of(context).size.width * 0.9;

    return Dialog(
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxWidth: ResponsiveBreakpoints.maxContentWidth,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Expanded(
                      child: ResponsiveText(
                        title!,
                        baseFontSize: 20,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: contentPadding ??
                  EdgeInsets.all(
                    ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 20, desktop: 24),
                  ),
                child: child,
              ),
            ),
            if (actions != null && actions!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!
                      .map((action) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: action,
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    List<Widget>? actions,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return showDialog<T>(
      context: context,
      builder: (context) => ResponsiveDialog(
        title: title,
        actions: actions,
        contentPadding: contentPadding,
        child: child,
      ),
    );
  }
}

/// Responsive bottom sheet that adapts to screen size
class ResponsiveBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool isScrollControlled;

  const ResponsiveBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.isScrollControlled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isDesktop) {
      // Show as dialog on desktop
      return ResponsiveDialog(
        title: title,
        child: child,
      );
    }

    // Show as bottom sheet on mobile/tablet
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: ResponsiveHelper.getContentPadding(context),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    bool isScrollControlled = true,
  }) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    if (isDesktop) {
      return ResponsiveDialog.show<T>(
        context: context,
        title: title,
        child: child,
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      builder: (context) => ResponsiveBottomSheet(
        title: title,
        isScrollControlled: isScrollControlled,
        child: child,
      ),
    );
  }
}