import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../providers/workflow_provider.dart';
import '../../providers/sales_provider.dart';
import '../../providers/rental_provider.dart';
import '../../utils/app_router.dart';
import '../../utils/responsive_breakpoints.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/responsive_layout.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final orgProvider = Provider.of<OrganizationProvider>(context, listen: false);
    final workflowProvider = Provider.of<WorkflowProvider>(context, listen: false);
    final salesProvider = Provider.of<SalesProvider>(context, listen: false);
    final rentalProvider = Provider.of<RentalProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      await Future.wait([
        orgProvider.loadOrganizations(authProvider.currentUser!.id),
        workflowProvider.loadWorkflows(),
        salesProvider.loadSales(),
        rentalProvider.loadRentals(),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.person),
          onPressed: () => context.push(AppRouter.profile),
        ),
      ],
      floatingActionButton: ResponsiveHelper.isMobile(context)
          ? FloatingActionButton(
              onPressed: () => _showQuickActionDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
      child: ResponsiveLayout(
        mobile: _MobileDashboardLayout(onRefresh: _loadData),
        tablet: _TabletDashboardLayout(onRefresh: _loadData),
        desktop: _DesktopDashboardLayout(onRefresh: _loadData),
      ),
    );
  }

  void _showQuickActionDialog(BuildContext context) {
    ResponsiveDialog.show(
      context: context,
      title: 'Quick Actions',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('New Organization'),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRouter.organizations);
            },
          ),
          ListTile(
            leading: Icon(MdiIcons.sitemap),
            title: const Text('New Workflow'),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRouter.workflows);
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('New Product'),
            onTap: () {
              Navigator.of(context).pop();
              context.push(AppRouter.products);
            },
          ),
        ],
      ),
    );
  }
}

class _MobileDashboardLayout extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _MobileDashboardLayout({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer5<AuthProvider, OrganizationProvider, WorkflowProvider, SalesProvider, RentalProvider>(
      builder: (context, authProvider, orgProvider, workflowProvider, salesProvider, rentalProvider, child) {
        if (authProvider.currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedOrg = orgProvider.selectedOrganization;
        final orgWorkflows = selectedOrg != null ? workflowProvider.getWorkflowsByOrganization(selectedOrg.id) : <dynamic>[];
        final orgSales = selectedOrg != null ? salesProvider.getSalesByOrganization(selectedOrg.id) : <dynamic>[];
        final orgRentals = selectedOrg != null ? rentalProvider.getRentalsByOrganization(selectedOrg.id) : <dynamic>[];

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getContentPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedOrg != null) ...[
                  _OrganizationCard(organization: selectedOrg),
                  const ResponsiveSpacing(mobile: 24),
                ],
                _SectionHeader(title: 'Quick Actions'),
                const ResponsiveSpacing(mobile: 16),
                ResponsiveGrid(
                  mobileColumns: 2,
                  spacing: 16,
                  runSpacing: 16,
                  children: HomeScreen._buildDashboardCards(context, orgProvider, orgWorkflows, orgSales, orgRentals),
                ),
                if (selectedOrg != null) ...[
                  const ResponsiveSpacing(mobile: 32),
                  _SectionHeader(title: 'Overview'),
                  const ResponsiveSpacing(mobile: 16),
                  _ActivityCard(
                    selectedOrg: selectedOrg,
                    salesProvider: salesProvider,
                    workflowProvider: workflowProvider,
                    rentalProvider: rentalProvider,
                  ),
                ],
                if (selectedOrg == null) ...[
                  const ResponsiveSpacing(mobile: 32),
                  _EmptyStateCard(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TabletDashboardLayout extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _TabletDashboardLayout({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer5<AuthProvider, OrganizationProvider, WorkflowProvider, SalesProvider, RentalProvider>(
      builder: (context, authProvider, orgProvider, workflowProvider, salesProvider, rentalProvider, child) {
        if (authProvider.currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedOrg = orgProvider.selectedOrganization;
        final orgWorkflows = selectedOrg != null ? workflowProvider.getWorkflowsByOrganization(selectedOrg.id) : <dynamic>[];
        final orgSales = selectedOrg != null ? salesProvider.getSalesByOrganization(selectedOrg.id) : <dynamic>[];
        final orgRentals = selectedOrg != null ? rentalProvider.getRentalsByOrganization(selectedOrg.id) : <dynamic>[];

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getContentPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedOrg != null) ...[
                  _OrganizationCard(organization: selectedOrg),
                  const ResponsiveSpacing(mobile: 32),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(title: 'Quick Actions'),
                          const ResponsiveSpacing(mobile: 16),
                          ResponsiveGrid(
                            tabletColumns: 3,
                            spacing: 16,
                            runSpacing: 16,
                            children: HomeScreen._buildDashboardCards(context, orgProvider, orgWorkflows, orgSales, orgRentals),
                          ),
                        ],
                      ),
                    ),
                    if (selectedOrg != null) ...[
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(title: 'Overview'),
                            const ResponsiveSpacing(mobile: 16),
                            _ActivityCard(
                              selectedOrg: selectedOrg,
                              salesProvider: salesProvider,
                              workflowProvider: workflowProvider,
                              rentalProvider: rentalProvider,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (selectedOrg == null) ...[
                  const ResponsiveSpacing(mobile: 32),
                  _EmptyStateCard(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DesktopDashboardLayout extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _DesktopDashboardLayout({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Consumer5<AuthProvider, OrganizationProvider, WorkflowProvider, SalesProvider, RentalProvider>(
      builder: (context, authProvider, orgProvider, workflowProvider, salesProvider, rentalProvider, child) {
        if (authProvider.currentUser == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final selectedOrg = orgProvider.selectedOrganization;
        final orgWorkflows = selectedOrg != null ? workflowProvider.getWorkflowsByOrganization(selectedOrg.id) : <dynamic>[];
        final orgSales = selectedOrg != null ? salesProvider.getSalesByOrganization(selectedOrg.id) : <dynamic>[];
        final orgRentals = selectedOrg != null ? rentalProvider.getRentalsByOrganization(selectedOrg.id) : <dynamic>[];

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            padding: ResponsiveHelper.getContentPadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selectedOrg != null) ...[
                  _OrganizationCard(organization: selectedOrg),
                  const ResponsiveSpacing(mobile: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(title: 'Quick Actions'),
                            const ResponsiveSpacing(mobile: 24),
                            ResponsiveGrid(
                              desktopColumns: 3,
                              spacing: 24,
                              runSpacing: 24,
                              children: HomeScreen._buildDashboardCards(context, orgProvider, orgWorkflows, orgSales, orgRentals),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(title: 'Overview'),
                            const ResponsiveSpacing(mobile: 24),
                            _ActivityCard(
                              selectedOrg: selectedOrg,
                              salesProvider: salesProvider,
                              workflowProvider: workflowProvider,
                              rentalProvider: rentalProvider,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  _SectionHeader(title: 'Quick Actions'),
                  const ResponsiveSpacing(mobile: 24),
                  ResponsiveGrid(
                    desktopColumns: 4,
                    spacing: 24,
                    runSpacing: 24,
                    children: HomeScreen._buildDashboardCards(context, orgProvider, orgWorkflows, orgSales, orgRentals),
                  ),
                  const ResponsiveSpacing(mobile: 48),
                  _EmptyStateCard(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return ResponsiveText(
      title,
      baseFontSize: 20,
      tabletFontSize: 22,
      desktopFontSize: 24,
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final dynamic organization;

  const _OrganizationCard({required this.organization});

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: ResponsiveBreakpoints.getSpacing(context, mobile: 24, tablet: 28, desktop: 32),
            child: organization.logoUrl != null
                ? ClipOval(child: Image.network(organization.logoUrl!))
                : ResponsiveText(
                    organization.name[0].toUpperCase(),
                    baseFontSize: 18,
                    tabletFontSize: 20,
                    desktopFontSize: 24,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
          const ResponsiveSpacing(mobile: 16, horizontal: true),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ResponsiveText(
                  organization.name,
                  baseFontSize: 18,
                  tabletFontSize: 20,
                  desktopFontSize: 22,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const ResponsiveSpacing(mobile: 4),
                ResponsiveText(
                  organization.description,
                  baseFontSize: 14,
                  tabletFontSize: 15,
                  desktopFontSize: 16,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/organizations/${organization.id}'),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final dynamic selectedOrg;
  final dynamic salesProvider;
  final dynamic workflowProvider;
  final dynamic rentalProvider;

  const _ActivityCard({
    required this.selectedOrg,
    required this.salesProvider,
    required this.workflowProvider,
    required this.rentalProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.trending_up, color: Colors.green),
            title: ResponsiveText(
              'Total Revenue',
              baseFontSize: 16,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: ResponsiveText(
              'Sales: \$${salesProvider.getTotalRevenue(selectedOrg.id).toStringAsFixed(2)}',
              baseFontSize: 14,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.schedule, color: Colors.blue),
            title: ResponsiveText(
              'Active Workflows',
              baseFontSize: 16,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: ResponsiveText(
              '${workflowProvider.getActiveWorkflows(selectedOrg.id).length} running',
              baseFontSize: 14,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.access_time, color: Colors.orange),
            title: ResponsiveText(
              'Active Rentals',
              baseFontSize: 16,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: ResponsiveText(
              '${rentalProvider.getActiveRentals(selectedOrg.id).length} items rented',
              baseFontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: Column(
        children: [
          Icon(
            Icons.business_center,
            size: ResponsiveBreakpoints.getSpacing(context, mobile: 64, tablet: 80, desktop: 96),
            color: Theme.of(context).disabledColor,
          ),
          const ResponsiveSpacing(mobile: 16),
          ResponsiveText(
            'No Organization Selected',
            baseFontSize: 20,
            tabletFontSize: 22,
            desktopFontSize: 24,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const ResponsiveSpacing(mobile: 8),
          ResponsiveText(
            'Create or join an organization to get started',
            baseFontSize: 16,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
          const ResponsiveSpacing(mobile: 24),
          ElevatedButton(
            onPressed: () => context.push(AppRouter.organizations),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveBreakpoints.getSpacing(context, mobile: 24, tablet: 32, desktop: 40),
                vertical: ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 18, desktop: 20),
              ),
            ),
            child: ResponsiveText(
              'Manage Organizations',
              baseFontSize: 16,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static List<Widget> _buildDashboardCards(BuildContext context, dynamic orgProvider, List orgWorkflows, List orgSales, List orgRentals) {
    return [
      DashboardCard(
        title: 'Organizations',
        subtitle: '${orgProvider.organizations.length} orgs',
        icon: Icons.business,
        color: Colors.blue,
        onTap: () => context.push(AppRouter.organizations),
      ),
      DashboardCard(
        title: 'Workflows',
        subtitle: '${orgWorkflows.length} workflows',
        icon: MdiIcons.sitemap,
        color: Colors.green,
        onTap: () => context.push(AppRouter.workflows),
      ),
      DashboardCard(
        title: 'Products',
        subtitle: 'Manage inventory',
        icon: Icons.inventory,
        color: Colors.orange,
        onTap: () => context.push(AppRouter.products),
      ),
      DashboardCard(
        title: 'Sales',
        subtitle: '${orgSales.length} sales',
        icon: Icons.point_of_sale,
        color: Colors.purple,
        onTap: () => context.push(AppRouter.sales),
      ),
      DashboardCard(
        title: 'Rentals',
        subtitle: '${orgRentals.length} rentals',
        icon: MdiIcons.calendarClock,
        color: Colors.teal,
        onTap: () => context.push(AppRouter.rentals),
      ),
    ];
  }
}
}