import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:org_manager/models/workflow.dart';
import 'package:org_manager/models/rbac.dart';
import 'package:org_manager/services/rbac_permission_resolver.dart';
import 'package:org_manager/services/cache_service.dart';
import 'package:org_manager/services/event_bus.dart';
import 'package:org_manager/services/audit_service.dart';
import 'package:org_manager/core/workflow_engine.dart';
import 'package:org_manager/workflows/hire_workflow.dart';

// Mock classes
@GenerateMocks([
  SupabaseClient,
  PostgrestQueryBuilder,
  PostgrestFilterBuilder,
  PostgrestResponse,
])
import 'workflow_system_test.mocks.dart';

void main() {
  group('Workflow System Tests', () {
    late MockSupabaseClient mockSupabase;
    late CacheService cacheService;
    late EventBus eventBus;
    late AuditService auditService;
    late RBACPermissionResolver rbacResolver;
    late WorkflowEngine workflowEngine;

    setUp(() {
      mockSupabase = MockSupabaseClient();
      cacheService = MemoryCacheService();
      eventBus = EventBus();
      auditService = AuditService(supabase: mockSupabase, eventBus: eventBus);
      rbacResolver = RBACPermissionResolver(
        supabase: mockSupabase,
        cache: cacheService,
      );
      workflowEngine = WorkflowEngine(
        supabase: mockSupabase,
        rbacResolver: rbacResolver,
        eventBus: eventBus,
        auditService: auditService,
      );
    });

    tearDown(() {
      eventBus.dispose();
    });

    group('RBAC Permission Tests', () {
      test('should grant permission for valid user with correct role', () async {
        // Mock user positions
        final mockResponse = MockPostgrestResponse();
        when(mockResponse.data).thenReturn([
          {
            'assignment_id': 'assign-1',
            'assignment_type': 'primary',
            'position_id': 'pos-1',
            'position_title': 'HR Manager',
            'designation_id': 'des-1',
            'designation_name': 'Manager',
            'designation_code': 'MGR',
            'group_type': 'department',
            'group_id': 'dept-1',
            'job_level': 7,
            'department_name': 'Human Resources',
            'department_code': 'HR',
            'team_name': null,
            'team_code': null,
            'parent_department_name': null,
            'seat_number': 'A101',
            'building_name': 'Main Building',
            'branch_name': 'Headquarters',
            'organization_name': 'Test Company',
          }
        ]);
        when(mockResponse.error).thenReturn(null);

        final mockRpc = MockPostgrestFilterBuilder();
        when(mockRpc.then(any)).thenAnswer((_) async => mockResponse);
        when(mockSupabase.rpc('get_user_active_positions', parameters: anyNamed('parameters')))
            .thenReturn(mockRpc);

        // Mock workflow step permissions
        final mockPermissionsQuery = MockPostgrestFilterBuilder();
        final mockPermissionsResponse = MockPostgrestResponse();
        when(mockPermissionsResponse.data).thenReturn([
          {
            'id': 'perm-1',
            'workflow_step_id': 'step-1',
            'actor_id': 'actor-1',
            'group_type': 'department',
            'group_id': 'dept-1',
            'designation_id': 'des-1',
            'permission_type': 'required',
            'conditions': {},
            'is_active': true,
            'created_at': '2023-01-01T00:00:00Z',
          }
        ]);
        when(mockPermissionsResponse.error).thenReturn(null);

        when(mockPermissionsQuery.eq(any, any)).thenReturn(mockPermissionsQuery);
        when(mockPermissionsQuery.then(any)).thenAnswer((_) async => mockPermissionsResponse);

        final mockFrom = MockPostgrestQueryBuilder();
        when(mockFrom.select(any)).thenReturn(mockPermissionsQuery);
        when(mockSupabase.from('workflow_permissions')).thenReturn(mockFrom);

        // Test permission check
        final result = await rbacResolver.checkPermission(
          userId: 'user-1',
          workflowStepId: 'step-1',
          actorRole: 'approver',
          context: {},
        );

        expect(result.hasPermission, isTrue);
        expect(result.matchedPermissions, isNotEmpty);
        expect(result.reasons, isEmpty);
      });

      test('should deny permission for user without correct role', () async {
        // Mock empty user positions
        final mockResponse = MockPostgrestResponse();
        when(mockResponse.data).thenReturn([]);
        when(mockResponse.error).thenReturn(null);

        final mockRpc = MockPostgrestFilterBuilder();
        when(mockRpc.then(any)).thenAnswer((_) async => mockResponse);
        when(mockSupabase.rpc('get_user_active_positions', parameters: anyNamed('parameters')))
            .thenReturn(mockRpc);

        // Test permission check
        final result = await rbacResolver.checkPermission(
          userId: 'user-1',
          workflowStepId: 'step-1',
          actorRole: 'approver',
          context: {},
        );

        expect(result.hasPermission, isFalse);
        expect(result.matchedPermissions, isEmpty);
        expect(result.reasons, contains('User has no active organizational positions'));
      });

      test('should enforce amount-based permissions', () async {
        // Mock user with limited approval authority
        final mockResponse = MockPostgrestResponse();
        when(mockResponse.data).thenReturn([
          {
            'assignment_id': 'assign-1',
            'assignment_type': 'primary',
            'position_id': 'pos-1',
            'position_title': 'Team Lead',
            'designation_id': 'des-1',
            'designation_name': 'Team Lead',
            'designation_code': 'TL',
            'group_type': 'team',
            'group_id': 'team-1',
            'job_level': 5,
            'department_name': 'Engineering',
            'department_code': 'ENG',
            'team_name': 'Backend Team',
            'team_code': 'BE',
            'parent_department_name': 'Engineering',
            'seat_number': 'B201',
            'building_name': 'Tech Building',
            'branch_name': 'Headquarters',
            'organization_name': 'Test Company',
          }
        ]);
        when(mockResponse.error).thenReturn(null);

        final mockRpc = MockPostgrestFilterBuilder();
        when(mockRpc.then(any)).thenAnswer((_) async => mockResponse);
        when(mockSupabase.rpc('get_user_active_positions', parameters: anyNamed('parameters')))
            .thenReturn(mockRpc);

        // Mock workflow step permissions with amount condition
        final mockPermissionsQuery = MockPostgrestFilterBuilder();
        final mockPermissionsResponse = MockPostgrestResponse();
        when(mockPermissionsResponse.data).thenReturn([
          {
            'id': 'perm-1',
            'workflow_step_id': 'step-1',
            'actor_id': 'actor-1',
            'group_type': 'team',
            'group_id': 'team-1',
            'designation_id': null,
            'permission_type': 'required',
            'conditions': {'workflow_amount_limit': 5000},
            'is_active': true,
            'created_at': '2023-01-01T00:00:00Z',
          }
        ]);
        when(mockPermissionsResponse.error).thenReturn(null);

        when(mockPermissionsQuery.eq(any, any)).thenReturn(mockPermissionsQuery);
        when(mockPermissionsQuery.then(any)).thenAnswer((_) async => mockPermissionsResponse);

        final mockFrom = MockPostgrestQueryBuilder();
        when(mockFrom.select(any)).thenReturn(mockPermissionsQuery);
        when(mockSupabase.from('workflow_permissions')).thenReturn(mockFrom);

        // Test with amount within limit
        final resultWithinLimit = await rbacResolver.checkPermission(
          userId: 'user-1',
          workflowStepId: 'step-1',
          actorRole: 'approver',
          context: {'amount': 3000},
        );

        expect(resultWithinLimit.hasPermission, isTrue);

        // Test with amount exceeding limit
        final resultExceedingLimit = await rbacResolver.checkPermission(
          userId: 'user-1',
          workflowStepId: 'step-1',
          actorRole: 'approver',
          context: {'amount': 10000},
        );

        expect(resultExceedingLimit.hasPermission, isFalse);
      });
    });

    group('Workflow Engine Tests', () {
      test('should create workflow instance successfully', () async {
        // Mock workflow query
        final mockWorkflowQuery = MockPostgrestFilterBuilder();
        final mockWorkflowResponse = MockPostgrestResponse();
        when(mockWorkflowResponse.data).thenReturn({
          'id': 'workflow-1',
          'name': 'Test Workflow',
          'description': 'Test Description',
          'version': 1,
          'is_active': true,
          'created_by': 'user-1',
          'workflow_definition': {},
          'rbac_enabled': true,
          'created_at': '2023-01-01T00:00:00Z',
        });
        when(mockWorkflowResponse.error).thenReturn(null);

        when(mockWorkflowQuery.eq(any, any)).thenReturn(mockWorkflowQuery);
        when(mockWorkflowQuery.single()).thenAnswer((_) async => mockWorkflowResponse);

        final mockFrom = MockPostgrestQueryBuilder();
        when(mockFrom.select(any)).thenReturn(mockWorkflowQuery);
        when(mockSupabase.from('workflows')).thenReturn(mockFrom);

        // Mock workflow steps query
        final mockStepsQuery = MockPostgrestFilterBuilder();
        final mockStepsResponse = MockPostgrestResponse();
        when(mockStepsResponse.data).thenReturn([
          {
            'id': 'step-1',
            'workflow_id': 'workflow-1',
            'step_name': 'initial',
            'step_order': 1,
            'step_type': 'task',
            'required_actors': ['requestor'],
            'optional_actors': [],
            'step_conditions': {},
            'timeout_hours': null,
            'is_parallel': false,
            'is_active': true,
            'created_at': '2023-01-01T00:00:00Z',
          }
        ]);
        when(mockStepsResponse.error).thenReturn(null);

        when(mockStepsQuery.eq(any, any)).thenReturn(mockStepsQuery);
        when(mockStepsQuery.order(any, ascending: anyNamed('ascending'))).thenReturn(mockStepsQuery);
        when(mockStepsQuery.limit(any)).thenReturn(mockStepsQuery);
        when(mockStepsQuery.then(any)).thenAnswer((_) async => mockStepsResponse);

        when(mockSupabase.from('workflow_steps')).thenReturn(mockFrom);

        // Mock instance creation
        final mockInstanceQuery = MockPostgrestFilterBuilder();
        final mockInstanceResponse = MockPostgrestResponse();
        when(mockInstanceResponse.data).thenReturn({
          'id': 'instance-1',
          'workflow_id': 'workflow-1',
          'current_state': 'initial',
          'context_data': {},
          'initiator_user_id': 'user-1',
          'organization_id': 'org-1',
          'status': 'active',
          'created_at': '2023-01-01T00:00:00Z',
          'updated_at': '2023-01-01T00:00:00Z',
        });
        when(mockInstanceResponse.error).thenReturn(null);

        when(mockInstanceQuery.insert(any)).thenReturn(mockInstanceQuery);
        when(mockInstanceQuery.select()).thenReturn(mockInstanceQuery);
        when(mockInstanceQuery.single()).thenAnswer((_) async => mockInstanceResponse);

        when(mockSupabase.from('workflow_instances')).thenReturn(mockInstanceQuery);

        // Mock audit log creation
        final mockAuditQuery = MockPostgrestFilterBuilder();
        final mockAuditResponse = MockPostgrestResponse();
        when(mockAuditResponse.error).thenReturn(null);

        when(mockAuditQuery.insert(any)).thenAnswer((_) async => mockAuditResponse);
        when(mockSupabase.from('audit_logs')).thenReturn(mockAuditQuery);

        // Test instance creation
        final instance = await workflowEngine.createWorkflowInstance(
          workflowId: 'workflow-1',
          initiatorUserId: 'user-1',
          organizationId: 'org-1',
          initialContext: {'test': 'data'},
        );

        expect(instance.id, equals('instance-1'));
        expect(instance.workflowId, equals('workflow-1'));
        expect(instance.currentState, equals('initial'));
        expect(instance.status, equals(WorkflowStatus.active));
      });
    });

    group('Hire Workflow Tests', () {
      test('should validate requisition data correctly', () async {
        final hireWorkflow = HireWorkflow(
          id: 'hire-1',
          eventBus: eventBus,
          rbacResolver: rbacResolver,
          auditService: auditService,
        );

        // Test valid requisition data
        final validContext = {
          'position': 'Software Engineer',
          'department': 'Engineering',
          'job_description': 'Develop software applications',
          'required_skills': ['Flutter', 'Dart'],
          'experience_level': 'Mid-level',
          'salary_range': {'min': 50000, 'max': 80000},
        };

        expect(
          await hireWorkflow.states['requisition_created']!.validations.first(
            {},
            validContext,
          ),
          isTrue,
        );

        // Test invalid requisition data (missing required fields)
        final invalidContext = {
          'position': 'Software Engineer',
          'department': 'Engineering',
          // Missing other required fields
        };

        expect(
          await hireWorkflow.states['requisition_created']!.validations.first(
            {},
            invalidContext,
          ),
          isFalse,
        );

        // Test invalid salary range
        final invalidSalaryContext = {
          'position': 'Software Engineer',
          'department': 'Engineering',
          'job_description': 'Develop software applications',
          'required_skills': ['Flutter', 'Dart'],
          'experience_level': 'Mid-level',
          'salary_range': {'min': 80000, 'max': 50000}, // Invalid range
        };

        expect(
          await hireWorkflow.states['requisition_created']!.validations.first(
            {},
            invalidSalaryContext,
          ),
          isFalse,
        );
      });

      test('should handle state transitions correctly', () async {
        final hireWorkflow = HireWorkflow(
          id: 'hire-1',
          eventBus: eventBus,
          rbacResolver: rbacResolver,
          auditService: auditService,
        );

        // Test initial state setup
        expect(hireWorkflow.states.containsKey('requisition_created'), isTrue);
        expect(hireWorkflow.states.containsKey('requisition_reviewed'), isTrue);
        expect(hireWorkflow.states.containsKey('requisition_approved'), isTrue);

        // Test state transitions
        final requisitionCreatedState = hireWorkflow.states['requisition_created']!;
        expect(requisitionCreatedState.transitions, contains('requisition_reviewed'));

        final requisitionReviewedState = hireWorkflow.states['requisition_reviewed']!;
        expect(requisitionReviewedState.transitions, contains('requisition_approved'));
        expect(requisitionReviewedState.transitions, contains('requisition_rejected'));
      });
    });

    group('Event Bus Tests', () {
      test('should emit and receive events correctly', () async {
        bool eventReceived = false;
        Map<String, dynamic>? eventData;

        eventBus.on('test.event', (data) {
          eventReceived = true;
          eventData = data;
        });

        final testData = {'message': 'Hello, World!'};
        eventBus.emit('test.event', testData);

        // Allow event to propagate
        await Future.delayed(Duration.zero);

        expect(eventReceived, isTrue);
        expect(eventData, equals(testData));
      });

      test('should handle multiple listeners for same event', () async {
        int listener1Called = 0;
        int listener2Called = 0;

        eventBus.on('multi.event', (data) => listener1Called++);
        eventBus.on('multi.event', (data) => listener2Called++);

        eventBus.emit('multi.event', {});

        // Allow events to propagate
        await Future.delayed(Duration.zero);

        expect(listener1Called, equals(1));
        expect(listener2Called, equals(1));
      });

      test('should remove listeners correctly', () async {
        int callCount = 0;
        
        void listener(data) => callCount++;

        eventBus.on('remove.event', listener);
        eventBus.emit('remove.event', {});

        await Future.delayed(Duration.zero);
        expect(callCount, equals(1));

        eventBus.off('remove.event', listener);
        eventBus.emit('remove.event', {});

        await Future.delayed(Duration.zero);
        expect(callCount, equals(1)); // Should not have increased
      });
    });

    group('Cache Service Tests', () {
      test('should cache and retrieve permission results', () async {
        final cacheService = MemoryCacheService();
        
        final permissionResult = PermissionCheckResult(
          hasPermission: true,
          matchedPermissions: [],
          reasons: [],
          userPositions: [],
        );

        const cacheKey = 'user-1:step-1:approver';
        
        // Cache the result
        await cacheService.setPermission(cacheKey, permissionResult);
        
        // Retrieve the result
        final cachedResult = await cacheService.getPermission(cacheKey);
        
        expect(cachedResult, isNotNull);
        expect(cachedResult!.hasPermission, equals(permissionResult.hasPermission));
      });

      test('should invalidate user permissions correctly', () async {
        final cacheService = MemoryCacheService();
        
        final permissionResult = PermissionCheckResult(
          hasPermission: true,
          matchedPermissions: [],
          reasons: [],
          userPositions: [],
        );

        const cacheKey1 = 'user-1:step-1:approver';
        const cacheKey2 = 'user-1:step-2:reviewer';
        const cacheKey3 = 'user-2:step-1:approver';
        
        // Cache multiple results
        await cacheService.setPermission(cacheKey1, permissionResult);
        await cacheService.setPermission(cacheKey2, permissionResult);
        await cacheService.setPermission(cacheKey3, permissionResult);
        
        // Invalidate user-1's permissions
        await cacheService.invalidateUserPermissions('user-1');
        
        // Check results
        expect(await cacheService.getPermission(cacheKey1), isNull);
        expect(await cacheService.getPermission(cacheKey2), isNull);
        expect(await cacheService.getPermission(cacheKey3), isNotNull);
      });
    });
  });
}