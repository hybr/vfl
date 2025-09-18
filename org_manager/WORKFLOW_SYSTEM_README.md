# Comprehensive Workflow System with Enhanced RBAC

## Overview

This document provides a complete implementation guide for a sophisticated workflow management system with role-based access control (RBAC). The system is built using Flutter, Dart, and Supabase, following enterprise-grade architecture patterns.

## System Architecture

### Core Components

1. **Database Layer** - PostgreSQL with comprehensive RBAC schema
2. **Backend Services** - Supabase Edge Functions for workflow management
3. **Permission Engine** - Multi-dimensional RBAC with context-aware permissions
4. **Workflow Engine** - State machine-based workflow execution
5. **Event System** - Real-time workflow state change notifications
6. **Audit System** - Complete audit trails for compliance
7. **Frontend UI** - Flutter-based workflow dashboard

### Key Features

- ✅ **Multi-dimensional RBAC** - Permissions based on organizational structure
- ✅ **State Machine Workflows** - Predictable and auditable workflow execution
- ✅ **Context-aware Permissions** - Dynamic permissions based on workflow data
- ✅ **Comprehensive Audit Trail** - Complete security and compliance logging
- ✅ **Event-driven Architecture** - Real-time notifications and updates
- ✅ **Horizontal Scalability** - Microservices-ready architecture
- ✅ **Enterprise Security** - Row-level security and encrypted audit logs

## Database Schema

### Organizational Structure Tables

The system models complex organizational hierarchies:

- **Physical Structure**: Organization → Branch → Building → Worker Seat
- **Logical Structure**: Organization → Department → Team
- **Position Assignments**: Users are assigned to positions that combine physical seats with logical designations

### RBAC Tables

- `workflow_actors` - Standard workflow roles (requestor, approver, etc.)
- `workflow_permissions` - Multi-dimensional permission matrix
- `organization_group_designations` - Job roles within departments/teams
- `user_position_assignments` - User-to-position mappings with time validity

### Workflow Tables

- `workflows` - Workflow templates with RBAC configuration
- `workflow_instances` - Active workflow executions
- `workflow_steps` - Individual steps within workflows
- `workflow_history` - Complete audit trail of all transitions

## Implementation Files

### Database Migrations

1. **`supabase/migrations/001_initial_workflow_rbac_schema.sql`**
   - Complete database schema with indexes and triggers
   - Row-level security policies
   - Initial data seeding

2. **`supabase/migrations/002_rbac_functions.sql`**
   - PostgreSQL functions for permission resolution
   - User position lookup functions
   - Audit logging functions

### Core Dart Classes

1. **Models** (`lib/models/`)
   - `workflow.dart` - Enhanced workflow models with RBAC integration
   - `rbac.dart` - Organizational and permission models

2. **Core Engine** (`lib/core/`)
   - `base_workflow.dart` - Abstract workflow base class
   - `workflow_engine.dart` - Main workflow execution engine

3. **Services** (`lib/services/`)
   - `rbac_permission_resolver.dart` - Permission checking engine
   - `workflow_api_service.dart` - API integration layer
   - `audit_service.dart` - Comprehensive audit logging
   - `event_bus.dart` - Event system for real-time updates
   - `cache_service.dart` - Permission caching for performance

4. **Workflow Implementations** (`lib/workflows/`)
   - `hire_workflow.dart` - Complete hiring workflow example

5. **API Layer** (`supabase/functions/`)
   - `workflow-management/index.ts` - Supabase Edge Functions

6. **UI Layer** (`lib/screens/workflows/`)
   - `workflow_dashboard_screen.dart` - Complete workflow management UI

7. **State Management** (`lib/providers/`)
   - `enhanced_workflow_provider.dart` - Flutter provider for workflow state

## Getting Started

### Prerequisites

1. **Flutter SDK** (3.8.1+)
2. **Supabase Account** with PostgreSQL database
3. **Dependencies** (already configured in `pubspec.yaml`):
   - `supabase_flutter`
   - `provider` for state management
   - `uuid` for ID generation

### Setup Instructions

1. **Database Setup**
   ```bash
   # Run the migrations in your Supabase project
   supabase db reset
   supabase migration up
   ```

2. **Configure Supabase Connection**
   ```dart
   // Update your Supabase configuration
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

3. **Deploy Edge Functions**
   ```bash
   supabase functions deploy workflow-management
   ```

4. **Setup Provider**
   ```dart
   // In your main.dart
   ChangeNotifierProvider(
     create: (context) => EnhancedWorkflowProvider(
       supabase: Supabase.instance.client,
     ),
     child: MyApp(),
   )
   ```

## Usage Examples

### Creating a Workflow Instance

```dart
final provider = context.read<EnhancedWorkflowProvider>();

final instance = await provider.createWorkflowInstance(
  workflowId: 'hire-workflow-template',
  organizationId: 'your-org-id',
  initialContext: {
    'position': 'Software Engineer',
    'department': 'Engineering',
    'budget': 80000,
  },
);
```

### Transitioning a Workflow

```dart
await provider.transitionWorkflow(
  instanceId: instance.id,
  targetState: 'requisition_approved',
  actorRole: 'approver',
  context: {
    'approved_budget': 75000,
    'approval_comments': 'Approved with adjusted budget',
  },
  reason: 'Budget optimization',
);
```

### Checking Permissions

```dart
final permissionResult = await provider.checkPermission(
  workflowStepId: 'approval-step-id',
  actorRole: 'approver',
  context: {
    'amount': 50000,
    'department': 'engineering',
  },
);

if (permissionResult.hasPermission) {
  // User can perform this action
} else {
  // Show permission denied message
  print('Denied: ${permissionResult.reasons.join(', ')}');
}
```

## RBAC Configuration

### Setting Up Organizational Structure

1. **Create Organization**
   ```sql
   INSERT INTO organizations (name, code) VALUES ('Acme Corp', 'ACME');
   ```

2. **Create Departments**
   ```sql
   INSERT INTO organization_departments (organization_id, name, code) 
   VALUES ('org-id', 'Engineering', 'ENG');
   ```

3. **Create Positions**
   ```sql
   INSERT INTO organization_group_designations 
   (group_type, group_id, designation_name, designation_code, job_level)
   VALUES ('department', 'dept-id', 'Senior Engineer', 'SR_ENG', 6);
   ```

### Configuring Workflow Permissions

```sql
INSERT INTO workflow_permissions 
(workflow_step_id, actor_id, group_type, group_id, designation_id, permission_type, conditions)
VALUES 
('approval-step', 'approver-actor', 'department', 'eng-dept', 'manager-designation', 'required', 
 '{"min_job_level": 7, "workflow_amount_limit": 100000}');
```

## Security Features

### Row-Level Security (RLS)

- Organizations: Users can only see data from their organizations
- Workflows: Access controlled by organizational membership
- Audit Logs: Admin-only access with job level requirements

### Audit Logging

All actions are automatically logged with:
- User identification
- Action details
- Permission context
- Timestamp and IP address
- Encrypted sensitive data

### Permission Caching

- Multi-level caching (memory + Redis)
- Automatic cache invalidation on organizational changes
- Performance optimization for frequent permission checks

## Testing

Run the comprehensive test suite:

```bash
flutter test test/workflow_system_test.dart
```

The test suite covers:
- RBAC permission resolution
- Workflow state transitions
- Event system functionality
- Cache behavior
- Hire workflow validation

## Performance Considerations

### Database Optimization

- Comprehensive indexing strategy for fast queries
- Prepared statements for permission checks
- Partitioning for large audit log tables

### Caching Strategy

- User permissions cached for 5 minutes
- Organizational structure cached for 1 hour
- Automatic invalidation on updates

### Horizontal Scaling

- Stateless API design
- Event-driven architecture
- Microservices-ready separation

## Compliance and Security

### SOX Compliance

- Complete audit trail with encrypted sensitive data
- Segregation of duties enforcement
- Non-repudiation through cryptographic signatures

### GDPR Compliance

- User data encryption
- Right to be forgotten implementation
- Data retention policies

### Security Best Practices

- Input validation at all levels
- SQL injection prevention
- Cross-site scripting (XSS) protection
- Rate limiting on APIs

## Monitoring and Observability

### Metrics Tracked

- Workflow completion rates
- Permission denial frequency
- User activity patterns
- System performance metrics

### Alerting

- Security incident detection
- Performance degradation alerts
- Compliance violation notifications

## Extending the System

### Adding New Workflow Types

1. Create a new class extending `BaseWorkflow`
2. Define states and transitions
3. Implement validation functions
4. Configure RBAC permissions

### Custom Validation Rules

Add custom validators in the permission resolver:

```dart
Future<bool> customValidation(
  Map<String, dynamic> context,
  UserPositionContext userPosition,
) async {
  // Your custom logic here
  return true;
}
```

### Integration with External Systems

Use the event bus to integrate with external systems:

```dart
eventBus.on('workflow.completed', (data) async {
  await externalSystem.notify(data);
});
```

## Troubleshooting

### Common Issues

1. **Permission Denied Errors**
   - Check user's organizational positions
   - Verify workflow step permissions configuration
   - Review audit logs for detailed error information

2. **Performance Issues**
   - Check cache hit rates
   - Review database query performance
   - Monitor index usage

3. **State Transition Failures**
   - Verify workflow step configuration
   - Check validation functions
   - Review state machine logic

### Debug Tools

Enable debug logging:

```dart
// In development mode
final eventBus = EventBus();
eventBus.events.listen((event) {
  print('Event: ${event.name}, Data: ${event.data}');
});
```

## Deployment

### Production Checklist

- [ ] Database migrations applied
- [ ] Edge functions deployed
- [ ] Environment variables configured
- [ ] SSL certificates installed
- [ ] Monitoring configured
- [ ] Backup strategy implemented
- [ ] Security policies reviewed

### Environment Configuration

```bash
# Supabase Environment Variables
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-key

# Redis Cache (Optional)
REDIS_URL=your-redis-url

# Encryption Keys
AUDIT_ENCRYPTION_KEY=your-encryption-key
```

## Support and Contributing

For questions or contributions:

1. Review the architecture documentation
2. Check existing issues and tests
3. Follow the established coding patterns
4. Ensure comprehensive test coverage
5. Update documentation for new features

## License

This workflow system implementation follows enterprise security and compliance standards. Please ensure proper licensing for production use.