import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/enhanced_workflow_provider.dart';
import '../../models/workflow.dart';
import '../../models/rbac.dart';

class WorkflowDashboardScreen extends StatefulWidget {
  const WorkflowDashboardScreen({Key? key}) : super(key: key);

  @override
  State<WorkflowDashboardScreen> createState() => _WorkflowDashboardScreenState();
}

class _WorkflowDashboardScreenState extends State<WorkflowDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnhancedWorkflowProvider>().loadWorkflows();
      context.read<EnhancedWorkflowProvider>().refreshWorkflowInstances();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workflow Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Active Workflows', icon: Icon(Icons.play_arrow)),
            Tab(text: 'Templates', icon: Icon(Icons.template_outlined)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<EnhancedWorkflowProvider>().refreshWorkflows();
              context.read<EnhancedWorkflowProvider>().refreshWorkflowInstances();
            },
          ),
        ],
      ),
      body: Consumer<EnhancedWorkflowProvider>(
        builder: (context, workflowProvider, child) {
          if (workflowProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (workflowProvider.error != null) {
            return _buildErrorWidget(workflowProvider.error!);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(workflowProvider),
              _buildActiveWorkflowsTab(workflowProvider),
              _buildTemplatesTab(workflowProvider),
              _buildHistoryTab(workflowProvider),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateWorkflowDialog,
        child: const Icon(Icons.add),
        tooltip: 'Create New Workflow',
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<EnhancedWorkflowProvider>().clearError();
              context.read<EnhancedWorkflowProvider>().refreshWorkflows();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(EnhancedWorkflowProvider provider) {
    final stats = provider.getWorkflowStatistics();
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow Overview',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          _buildStatsGrid(stats),
          const SizedBox(height: 32),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildRecentActivity(provider),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(Map<String, int> stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildStatCard('Total Workflows', stats['total'] ?? 0, Icons.work, Colors.blue),
        _buildStatCard('Active', stats['active'] ?? 0, Icons.play_arrow, Colors.green),
        _buildStatCard('Completed', stats['completed'] ?? 0, Icons.check_circle, Colors.orange),
        _buildStatCard('Paused', stats['paused'] ?? 0, Icons.pause, Colors.grey),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(EnhancedWorkflowProvider provider) {
    final recentInstances = provider.workflowInstances.take(5).toList();
    
    if (recentInstances.isEmpty) {
      return const Center(
        child: Text('No recent activity'),
      );
    }

    return ListView.builder(
      itemCount: recentInstances.length,
      itemBuilder: (context, index) {
        final instance = recentInstances[index];
        return _buildWorkflowInstanceCard(instance, provider);
      },
    );
  }

  Widget _buildActiveWorkflowsTab(EnhancedWorkflowProvider provider) {
    final activeInstances = provider.activeWorkflowInstances;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Workflows (${activeInstances.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                onPressed: _showCreateWorkflowDialog,
                icon: const Icon(Icons.add),
                label: const Text('Start Workflow'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: activeInstances.isEmpty
                ? const Center(child: Text('No active workflows'))
                : ListView.builder(
                    itemCount: activeInstances.length,
                    itemBuilder: (context, index) {
                      final instance = activeInstances[index];
                      return _buildWorkflowInstanceCard(instance, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowInstanceCard(WorkflowInstance instance, EnhancedWorkflowProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('Workflow Instance ${instance.id.substring(0, 8)}...'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current State: ${instance.currentState}'),
            Text('Status: ${instance.status.toString().split('.').last}'),
            Text('Created: ${_formatDateTime(instance.createdAt)}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusChip(instance.status),
            PopupMenuButton<String>(
              onSelected: (value) => _handleInstanceAction(value, instance, provider),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Details')),
                const PopupMenuItem(value: 'history', child: Text('View History')),
                if (instance.status == WorkflowStatus.active) ...[
                  const PopupMenuItem(value: 'pause', child: Text('Pause')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
                ],
                if (instance.status == WorkflowStatus.paused)
                  const PopupMenuItem(value: 'resume', child: Text('Resume')),
              ],
            ),
          ],
        ),
        onTap: () => _showInstanceDetails(instance, provider),
      ),
    );
  }

  Widget _buildStatusChip(WorkflowStatus status) {
    Color color;
    String label;

    switch (status) {
      case WorkflowStatus.active:
        color = Colors.green;
        label = 'Active';
        break;
      case WorkflowStatus.paused:
        color = Colors.orange;
        label = 'Paused';
        break;
      case WorkflowStatus.completed:
        color = Colors.blue;
        label = 'Completed';
        break;
      case WorkflowStatus.cancelled:
        color = Colors.red;
        label = 'Cancelled';
        break;
      case WorkflowStatus.draft:
        color = Colors.grey;
        label = 'Draft';
        break;
    }

    return Chip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTemplatesTab(EnhancedWorkflowProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow Templates',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: provider.workflows.isEmpty
                ? const Center(child: Text('No workflow templates available'))
                : ListView.builder(
                    itemCount: provider.workflows.length,
                    itemBuilder: (context, index) {
                      final workflow = provider.workflows[index];
                      return _buildWorkflowTemplateCard(workflow, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkflowTemplateCard(Workflow workflow, EnhancedWorkflowProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.template_outlined, size: 32),
        title: Text(workflow.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workflow.description),
            Text('Steps: ${workflow.steps.length}'),
            Text('RBAC Enabled: ${workflow.rbacEnabled ? 'Yes' : 'No'}'),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _startWorkflowFromTemplate(workflow, provider),
          child: const Text('Start'),
        ),
      ),
    );
  }

  Widget _buildHistoryTab(EnhancedWorkflowProvider provider) {
    final completedInstances = provider.completedWorkflowInstances;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workflow History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: completedInstances.isEmpty
                ? const Center(child: Text('No completed workflows'))
                : ListView.builder(
                    itemCount: completedInstances.length,
                    itemBuilder: (context, index) {
                      final instance = completedInstances[index];
                      return _buildWorkflowInstanceCard(instance, provider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _handleInstanceAction(String action, WorkflowInstance instance, EnhancedWorkflowProvider provider) {
    switch (action) {
      case 'view':
        _showInstanceDetails(instance, provider);
        break;
      case 'history':
        _showInstanceHistory(instance, provider);
        break;
      case 'pause':
        provider.pauseWorkflowInstance(instance.id);
        break;
      case 'resume':
        provider.resumeWorkflowInstance(instance.id);
        break;
      case 'cancel':
        _confirmCancelInstance(instance, provider);
        break;
    }
  }

  void _showInstanceDetails(WorkflowInstance instance, EnhancedWorkflowProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Workflow Instance Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', instance.id),
              _buildDetailRow('Workflow ID', instance.workflowId),
              _buildDetailRow('Current State', instance.currentState),
              _buildDetailRow('Status', instance.status.toString().split('.').last),
              _buildDetailRow('Organization', instance.organizationId),
              _buildDetailRow('Created', _formatDateTime(instance.createdAt)),
              _buildDetailRow('Updated', _formatDateTime(instance.updatedAt)),
              const SizedBox(height: 16),
              Text('Context Data:', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  instance.contextData.toString(),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showInstanceHistory(instance, provider);
            },
            child: const Text('View History'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showInstanceHistory(WorkflowInstance instance, EnhancedWorkflowProvider provider) {
    provider.loadWorkflowHistory(instance.id).then((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Workflow History'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: provider.workflowHistory.isEmpty
                ? const Center(child: Text('No history available'))
                : ListView.builder(
                    itemCount: provider.workflowHistory.length,
                    itemBuilder: (context, index) {
                      final entry = provider.workflowHistory[index];
                      return Card(
                        child: ListTile(
                          title: Text('${entry.fromState ?? 'Start'} → ${entry.toState}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (entry.performedBy != null)
                                Text('By: ${entry.performedBy}'),
                              if (entry.actorRole != null)
                                Text('Role: ${entry.actorRole}'),
                              Text('At: ${_formatDateTime(entry.performedAt)}'),
                              if (entry.reason != null)
                                Text('Reason: ${entry.reason}'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    });
  }

  void _confirmCancelInstance(WorkflowInstance instance, EnhancedWorkflowProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Workflow'),
        content: const Text('Are you sure you want to cancel this workflow instance? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              provider.cancelWorkflowInstance(instance.id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCreateWorkflowDialog() {
    // This would show a dialog to create a new workflow instance
    // For now, just show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Workflow'),
        content: const Text('Workflow creation dialog would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _startWorkflowFromTemplate(Workflow workflow, EnhancedWorkflowProvider provider) {
    // This would show a dialog to configure and start a workflow from template
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Start ${workflow.name}'),
        content: const Text('Workflow configuration dialog would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // provider.createWorkflowInstance(
              //   workflowId: workflow.id,
              //   organizationId: 'demo-org',
              // );
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}