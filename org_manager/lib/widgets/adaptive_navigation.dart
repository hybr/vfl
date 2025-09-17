import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../utils/responsive_breakpoints.dart';
import '../utils/app_router.dart';
import 'responsive_layout.dart';

class NavigationItem {
  final String label;
  final IconData icon;
  final String route;
  final List<NavigationItem>? children;

  NavigationItem({
    required this.label,
    required this.icon,
    required this.route,
    this.children,
  });
}

class AdaptiveNavigation extends StatelessWidget {
  final Widget body;
  final String currentRoute;

  const AdaptiveNavigation({
    super.key,
    required this.body,
    required this.currentRoute,
  });

  static final List<NavigationItem> _navigationItems = [
    NavigationItem(
      label: 'Dashboard',
      icon: Icons.dashboard,
      route: AppRouter.home,
    ),
    NavigationItem(
      label: 'Organizations',
      icon: Icons.business,
      route: AppRouter.organizations,
    ),
    NavigationItem(
      label: 'Workflows',
      icon: MdiIcons.sitemap,
      route: AppRouter.workflows,
    ),
    NavigationItem(
      label: 'Products',
      icon: Icons.inventory,
      route: AppRouter.products,
    ),
    NavigationItem(
      label: 'Sales',
      icon: Icons.point_of_sale,
      route: AppRouter.sales,
    ),
    NavigationItem(
      label: 'Rentals',
      icon: MdiIcons.calendarClock,
      route: AppRouter.rentals,
    ),
    NavigationItem(
      label: 'Profile',
      icon: Icons.person,
      route: AppRouter.profile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (ResponsiveHelper.shouldUseSideNav(context)) {
      return _DesktopLayout(
        body: body,
        currentRoute: currentRoute,
        navigationItems: _navigationItems,
      );
    } else {
      return _MobileLayout(
        body: body,
        currentRoute: currentRoute,
        navigationItems: _navigationItems,
      );
    }
  }
}

class _DesktopLayout extends StatelessWidget {
  final Widget body;
  final String currentRoute;
  final List<NavigationItem> navigationItems;

  const _DesktopLayout({
    required this.body,
    required this.currentRoute,
    required this.navigationItems,
  });

  @override
  Widget build(BuildContext context) {
    final isUltraWide = MediaQuery.of(context).size.width >= ResponsiveBreakpoints.ultraWide;
    final sideNavWidth = isUltraWide ? 280.0 : 240.0;

    return Scaffold(
      body: Row(
        children: [
          Container(
            width: sideNavWidth,
            color: Theme.of(context).colorScheme.surface,
            child: _SideNavigationRail(
              currentRoute: currentRoute,
              navigationItems: navigationItems,
              extended: true,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _MobileLayout extends StatelessWidget {
  final Widget body;
  final String currentRoute;
  final List<NavigationItem> navigationItems;

  const _MobileLayout({
    required this.body,
    required this.currentRoute,
    required this.navigationItems,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = ResponsiveHelper.isTablet(context);

    if (isTablet) {
      return Scaffold(
        body: Row(
          children: [
            _SideNavigationRail(
              currentRoute: currentRoute,
              navigationItems: navigationItems,
              extended: false,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    } else {
      return Scaffold(
        body: body,
        bottomNavigationBar: _BottomNavigationBar(
          currentRoute: currentRoute,
          navigationItems: navigationItems,
        ),
      );
    }
  }
}

class _SideNavigationRail extends StatelessWidget {
  final String currentRoute;
  final List<NavigationItem> navigationItems;
  final bool extended;

  const _SideNavigationRail({
    required this.currentRoute,
    required this.navigationItems,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      extended: extended,
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (index) {
        if (index < navigationItems.length) {
          context.go(navigationItems[index].route);
        }
      },
      destinations: navigationItems
          .map((item) => NavigationRailDestination(
                icon: Icon(item.icon),
                label: Text(item.label),
              ))
          .toList(),
      leading: extended
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.business_center,
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Org Manager',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.business_center,
                size: 24,
                color: Theme.of(context).primaryColor,
              ),
            ),
    );
  }

  int _getSelectedIndex() {
    for (int i = 0; i < navigationItems.length; i++) {
      if (currentRoute.startsWith(navigationItems[i].route)) {
        return i;
      }
    }
    return 0;
  }
}

class _BottomNavigationBar extends StatelessWidget {
  final String currentRoute;
  final List<NavigationItem> navigationItems;

  const _BottomNavigationBar({
    required this.currentRoute,
    required this.navigationItems,
  });

  @override
  Widget build(BuildContext context) {
    // Show only main navigation items for mobile
    final mainItems = navigationItems.take(5).toList();

    return NavigationBar(
      selectedIndex: _getSelectedIndex(mainItems),
      onDestinationSelected: (index) {
        if (index < mainItems.length) {
          context.go(mainItems[index].route);
        }
      },
      destinations: mainItems
          .map((item) => NavigationDestination(
                icon: Icon(item.icon),
                label: item.label,
              ))
          .toList(),
    );
  }

  int _getSelectedIndex(List<NavigationItem> items) {
    for (int i = 0; i < items.length; i++) {
      if (currentRoute.startsWith(items[i].route)) {
        return i;
      }
    }
    return 0;
  }
}

/// Adaptive app bar with responsive features
class AdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showMenuButton;

  const AdaptiveAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showMenuButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveHelper.isDesktop(context);

    return AppBar(
      title: ResponsiveText(
        title,
        baseFontSize: 20,
        tabletFontSize: 22,
        desktopFontSize: 24,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      leading: leading ?? (showMenuButton && !isDesktop ? null : const SizedBox.shrink()),
      automaticallyImplyLeading: showMenuButton && !isDesktop,
      actions: [
        if (actions != null) ...actions!,
        if (isDesktop) ...[
          const SizedBox(width: 16),
        ],
      ],
      elevation: isDesktop ? 1 : 0,
      scrolledUnderElevation: isDesktop ? 2 : 1,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Responsive drawer for mobile/tablet
class AdaptiveDrawer extends StatelessWidget {
  final List<NavigationItem> navigationItems;
  final String currentRoute;

  const AdaptiveDrawer({
    super.key,
    required this.navigationItems,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.business_center,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Organization Manager',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage your business',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
                      ),
                ),
              ],
            ),
          ),
          ...navigationItems.map((item) => ListTile(
                leading: Icon(item.icon),
                title: Text(item.label),
                selected: currentRoute.startsWith(item.route),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.route);
                },
              )),
        ],
      ),
    );
  }
}