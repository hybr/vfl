import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/organization_provider.dart';
import '../../models/organization.dart';
import '../../utils/responsive_breakpoints.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/responsive_layout.dart';

class OrganizationsScreen extends StatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  State<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends State<OrganizationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        Provider.of<OrganizationProvider>(context, listen: false)
            .loadOrganizations(authProvider.currentUser!.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Organizations',
      floatingActionButton: ResponsiveHelper.isMobile(context)
          ? FloatingActionButton(
              onPressed: () => _showCreateOrganizationDialog(context, Provider.of<AuthProvider>(context, listen: false)),
              child: const Icon(Icons.add),
            )
          : null,
      child: ResponsiveLayout(
        mobile: _MobileOrganizationsLayout(),
        tablet: _TabletOrganizationsLayout(),
        desktop: _DesktopOrganizationsLayout(),
      ),
    );
  }

  void _showCreateOrganizationDialog(BuildContext context, AuthProvider authProvider) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    ResponsiveDialog.show(
      context: context,
      title: 'Create Organization',
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (nameController.text.isNotEmpty && descriptionController.text.isNotEmpty) {
              final orgProvider = Provider.of<OrganizationProvider>(context, listen: false);
              final success = await orgProvider.createOrganization(
                nameController.text,
                descriptionController.text,
                authProvider.currentUser!.id,
              );

              if (success && context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Organization created successfully')),
                );
              }
            }
          },
          child: const Text('Create'),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Organization Name',
              border: OutlineInputBorder(),
            ),
          ),
          const ResponsiveSpacing(mobile: 16),
          TextFormField(
            controller: descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  void _showOrganizationOptions(BuildContext context, Organization organization, OrganizationProvider orgProvider) {
    ResponsiveBottomSheet.show(
      context: context,
      title: 'Organization Options',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.select_all),
            title: const Text('Select Organization'),
            onTap: () {
              orgProvider.selectOrganization(organization);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Selected ${organization.name}')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('View Details'),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/organizations/${organization.id}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Organization'),
            onTap: () async {
              Navigator.of(context).pop();
              final confirmed = await ResponsiveDialog.show<bool>(
                context: context,
                title: 'Delete Organization',
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
                child: ResponsiveText(
                  'Are you sure you want to delete ${organization.name}?',
                  baseFontSize: 16,
                ),
              );

              if (confirmed == true) {
                final success = await orgProvider.deleteOrganization(organization.id);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Organization deleted')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _MobileOrganizationsLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, OrganizationProvider>(
      builder: (context, authProvider, orgProvider, child) {
        if (orgProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orgProvider.organizations.isEmpty) {
          return _EmptyState(authProvider: authProvider);
        }

        return ListView.builder(
          padding: ResponsiveHelper.getContentPadding(context),
          itemCount: orgProvider.organizations.length,
          itemBuilder: (context, index) {
            final organization = orgProvider.organizations[index];
            return _OrganizationCard(
              organization: organization,
              orgProvider: orgProvider,
            );
          },
        );
      },
    );
  }
}

class _TabletOrganizationsLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, OrganizationProvider>(
      builder: (context, authProvider, orgProvider, child) {
        if (orgProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (orgProvider.organizations.isEmpty) {
          return _EmptyState(authProvider: authProvider);
        }

        return ResponsiveGrid(
          tabletColumns: 2,
          spacing: 16,
          runSpacing: 16,
          children: orgProvider.organizations
              .map((organization) => _OrganizationCard(
                    organization: organization,
                    orgProvider: orgProvider,
                    isGridLayout: true,
                  ))
              .toList(),
        );
      },
    );
  }
}

class _DesktopOrganizationsLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, OrganizationProvider>(
      builder: (context, authProvider, orgProvider, child) {
        if (orgProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: ResponsiveHelper.getContentPadding(context),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ResponsiveText(
                    'Organizations',
                    baseFontSize: 24,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.findAncestorStateOfType<_OrganizationsScreenState>()?._showCreateOrganizationDialog(context, authProvider),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Organization'),
                  ),
                ],
              ),
            ),
            const ResponsiveSpacing(mobile: 16),
            Expanded(
              child: orgProvider.organizations.isEmpty
                  ? _EmptyState(authProvider: authProvider)
                  : ResponsiveGrid(
                      desktopColumns: 3,
                      spacing: 24,
                      runSpacing: 24,
                      children: orgProvider.organizations
                          .map((organization) => _OrganizationCard(
                                organization: organization,
                                orgProvider: orgProvider,
                                isGridLayout: true,
                              ))
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AuthProvider authProvider;

  const _EmptyState({required this.authProvider});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ResponsiveCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.business,
              size: ResponsiveBreakpoints.getSpacing(context, mobile: 64, tablet: 80, desktop: 96),
              color: Theme.of(context).disabledColor,
            ),
            const ResponsiveSpacing(mobile: 16),
            ResponsiveText(
              'No Organizations',
              baseFontSize: 20,
              tabletFontSize: 22,
              desktopFontSize: 24,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const ResponsiveSpacing(mobile: 8),
            ResponsiveText(
              'Create your first organization to get started',
              baseFontSize: 16,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              ),
            ),
            const ResponsiveSpacing(mobile: 24),
            ElevatedButton(
              onPressed: () => context.findAncestorStateOfType<_OrganizationsScreenState>()?._showCreateOrganizationDialog(context, authProvider),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveBreakpoints.getSpacing(context, mobile: 24, tablet: 32, desktop: 40),
                  vertical: ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 18, desktop: 20),
                ),
              ),
              child: ResponsiveText(
                'Create Organization',
                baseFontSize: 16,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizationCard extends StatelessWidget {
  final Organization organization;
  final OrganizationProvider orgProvider;
  final bool isGridLayout;

  const _OrganizationCard({
    required this.organization,
    required this.orgProvider,
    this.isGridLayout = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = orgProvider.selectedOrganization?.id == organization.id;

    if (isGridLayout) {
      return ResponsiveCard(
        child: InkWell(
          onTap: () {
            orgProvider.selectOrganization(organization);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Selected ${organization.name}')),
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(
              ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 20, desktop: 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: ResponsiveBreakpoints.getSpacing(context, mobile: 20, tablet: 24, desktop: 28),
                      child: organization.logoUrl != null
                          ? ClipOval(child: Image.network(organization.logoUrl!))
                          : ResponsiveText(
                              organization.name[0].toUpperCase(),
                              baseFontSize: 16,
                              tabletFontSize: 18,
                              desktopFontSize: 20,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                    const Spacer(),
                    if (isSelected)
                      const Icon(Icons.check_circle, color: Colors.green),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => context.findAncestorStateOfType<_OrganizationsScreenState>()?._showOrganizationOptions(context, organization, orgProvider),
                    ),
                  ],
                ),
                const ResponsiveSpacing(mobile: 16),
                ResponsiveText(
                  organization.name,
                  baseFontSize: 16,
                  tabletFontSize: 18,
                  desktopFontSize: 20,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const ResponsiveSpacing(mobile: 8),
                ResponsiveText(
                  organization.description,
                  baseFontSize: 14,
                  tabletFontSize: 15,
                  desktopFontSize: 16,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ResponsiveCard(
      child: ListTile(
        contentPadding: EdgeInsets.all(
          ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 20, desktop: 24),
        ),
        leading: CircleAvatar(
          radius: ResponsiveBreakpoints.getSpacing(context, mobile: 20, tablet: 24, desktop: 28),
          child: organization.logoUrl != null
              ? ClipOval(child: Image.network(organization.logoUrl!))
              : ResponsiveText(
                  organization.name[0].toUpperCase(),
                  baseFontSize: 16,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
        title: ResponsiveText(
          organization.name,
          baseFontSize: 16,
          tabletFontSize: 18,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: ResponsiveText(
          organization.description,
          baseFontSize: 14,
          tabletFontSize: 15,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.green),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => context.findAncestorStateOfType<_OrganizationsScreenState>()?._showOrganizationOptions(context, organization, orgProvider),
            ),
          ],
        ),
        onTap: () {
          orgProvider.selectOrganization(organization);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Selected ${organization.name}')),
          );
        },
      ),
    );
  }
}