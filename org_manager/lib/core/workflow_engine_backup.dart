import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workflow.dart';
import '../models/rbac.dart';
import '../services/rbac_permission_resolver.dart';
import '../services/audit_service.dart';
import '../services/event_bus.dart';
import 'base_workflow.dart';

class WorkflowEngine {
  final SupabaseClient _supabase;
  final RBACPermissionResolver _rbacResolver;
  final EventBus _eventBus;
  final AuditService _auditService;
  final Map<String, BaseWorkflow> _runningWorkflows = {};

  WorkflowEngine({
    required SupabaseClient supabase,
    required RBACPermissionResolver rbacResolver,
    required EventBus eventBus,
    required AuditService auditService,
  }) : _supabase = supabase,
       _rbacResolver = rbacResolver,
       _eventBus = eventBus,
       _auditService = auditService;

  Future<WorkflowInstance> createWorkflowInstance({
    required String workflowId,
    required String initiatorUserId,
    required String organizationId,
    Map<String, dynamic> initialContext = const {},
  }) async {
    try {
      final workflow = await getWorkflow(workflowId);
      if (workflow == null) {
        throw WorkflowException('Workflow $workflowId not found');
      }

      if (!workflow.isActive) {
        throw WorkflowException('Workflow $workflowId is not active');
      }

      final firstStep = workflow.steps.isNotEmpty 
          ? workflow.steps.first.stepName 
          : 'initial';

      final instance = WorkflowInstance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        workflowId: workflowId,
        currentState: firstStep,
        contextData: initialContext,
        initiatorUserId: initiatorUserId,
        organizationId: organizationId,
        status: WorkflowStatus.active,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final response = await _supabase
          .from('workflow_instances')
          .insert(instance.toJson())
          .select()
          .single();

      if (response.error != null) {
        throw Exception('Failed to create workflow instance: ${response.error!.message}');
      }

      final createdInstance = WorkflowInstance.fromJson(response.data);

      await _auditService.logWorkflowTransition(
        instanceId: createdInstance.id,
        fromState: null,
        toState: firstStep,
        userId: initiatorUserId,
        actorRole: 'requestor',
        context: initialContext,
      );

      _eventBus.emit(WorkflowEvents.instanceCreated, {
        'instanceId': createdInstance.id,
        'workflowId': workflowId,
        'initiatorUserId': initiatorUserId,
        'organizationId': organizationId,
      });

      return createdInstance;
    } catch (error) {
      _eventBus.emit('workflow.instance.creation.failed', {
        'workflowId': workflowId,
        'initiatorUserId': initiatorUserId,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  Future<TransitionResult> transitionWorkflow({
    required String instanceId,
    required String targetState,
    required String actorRole,
    required String userId,
    Map<String, dynamic> context = const {},
    String? reason,
  }) async {
    try {
      final instance = await getWorkflowInstance(instanceId);
      if (instance == null) {
        throw WorkflowException('Workflow instance $instanceId not found');
      }

      if (instance.status != WorkflowStatus.active) {
        throw WorkflowException('Workflow instance is not in active state');
      }

      final workflow = await getWorkflow(instance.workflowId);
      if (workflow == null) {
        throw WorkflowException('Workflow ${instance.workflowId} not found');
      }

      final targetStep = workflow.steps
          .where((step) => step.stepName == targetState)
          .firstOrNull;

      if (targetStep == null) {
        throw WorkflowException('Target state $targetState not found in workflow');
      }

      final permissionResult = await _rbacResolver.checkPermission(
        userId: userId,
        workflowStepId: targetStep.id,
        actorRole: actorRole,
        context: {
          ...instance.contextData,
          ...context,
          'workflowInstance': instance.toJson(),
        },
      );

      if (!permissionResult.hasPermission) {
        await _auditService.logPermissionDenied(
          userId: userId,
          workflowStepId: targetStep.id,
          actorRole: actorRole,
          permissionResult: permissionResult,
          context: context,
        );

        throw PermissionDeniedException(
          'User $userId lacks $actorRole permission for workflow step $targetState',
          userId: userId,
          workflowStepId: targetStep.id,
          actorRole: actorRole,
          reasons: permissionResult.reasons,
        );
      }

      await _auditService.logPermissionCheck(
        instanceId: instanceId,
        userId: userId,
        workflowStepId: targetStep.id,
        actorRole: actorRole,
        result: permissionResult,
      );

      if (targetStep.stepConditions.isNotEmpty) {
        final conditionsPassed = await _evaluateStepConditions(
          targetStep.stepConditions,
          instance.contextData,
          context,
        );

        if (!conditionsPassed) {
          throw ValidationException('Step conditions not met for transition to $targetState');
        }
      }

      final updatedContext = {
        ...instance.contextData,
        ...context,
        'performedBy': userId,
        'actorRole': actorRole,
        'permissionContext': permissionResult.matchedPermissions,
        'transitionReason': reason,
      };

      final updatedInstance = instance.copyWith(
        currentState: targetState,
        contextData: updatedContext,
        updatedAt: DateTime.now(),
      );

      final updateResponse = await _supabase
          .from('workflow_instances')
          .update(updatedInstance.toJson())
          .eq('id', instanceId)
          .select()
          .single();

      if (updateResponse.error != null) {
        throw Exception('Failed to update workflow instance: ${updateResponse.error!.message}');
      }

      await _createWorkflowHistoryEntry(
        instanceId: instanceId,
        fromState: instance.currentState,
        toState: targetState,
        userId: userId,
        actorRole: actorRole,
        contextData: context,
        reason: reason,
      );

      await _auditService.logWorkflowTransition(
        instanceId: instanceId,
        fromState: instance.currentState,
        toState: targetState,
        userId: userId,
        actorRole: actorRole,
        context: context,
      );

      if (_isCompletedState(targetStep, workflow)) {
        await _completeWorkflowInstance(instanceId);
      }

      _eventBus.emit(WorkflowEvents.transitionCompleted, {
        'instanceId': instanceId,
        'fromState': instance.currentState,
        'targetState': targetState,
        'userId': userId,
        'actorRole': actorRole,
        'permissionContext': permissionResult.matchedPermissions,
      });

      return TransitionResult(
        success: true,
        newState: targetState,
        context: updatedContext,
        timestamp: DateTime.now(),
      );

    } catch (error) {
      _eventBus.emit(WorkflowEvents.transitionFailed, {
        'instanceId': instanceId,
        'targetState': targetState,
        'userId': userId,
        'actorRole': actorRole,
        'error': error.toString(),
      });
      
      rethrow;
    }
  }

  Future<List<WorkflowAction>> getAvailableActionsForUser({
    required String instanceId,
    required String userId,
  }) async {
    final instance = await getWorkflowInstance(instanceId);
    if (instance == null) {
      throw WorkflowException('Workflow instance $instanceId not found');
    }

    final workflow = await getWorkflow(instance.workflowId);
    if (workflow == null) {
      throw WorkflowException('Workflow ${instance.workflowId} not found');
    }

    final currentStep = workflow.steps
        .where((step) => step.stepName == instance.currentState)
        .firstOrNull;

    if (currentStep == null) {
      return [];
    }

    final availableTransitions = await _getAvailableTransitions(currentStep, workflow);
    final availableActions = <WorkflowAction>[];

    for (final transition in availableTransitions) {
      for (final actorRole in transition.requiredActors) {
        final permissionResult = await _rbacResolver.checkPermission(
          userId: userId,
          workflowStepId: transition.id,
          actorRole: actorRole,
          context: {'workflowData': instance.contextData},
        );

        if (permissionResult.hasPermission) {
          availableActions.add(WorkflowAction(
            action: 'transition_to_${transition.stepName}',
            targetState: transition.stepName,
            actorRole: actorRole,
            stepName: transition.stepName,
            permissionContext: permissionResult.matchedPermissions,
          ));
        }
      }
    }

    return availableActions;
  }

  Future<List<String>> getEligibleUsersForStep({
    required String workflowStepId,
    required List<String> requiredActors,
  }) async {
    return await _rbacResolver.getEligibleUsersForStep(
      workflowStepId,
      requiredActors,
    );
  }

  Future<WorkflowInstance?> getWorkflowInstance(String instanceId) async {
    final response = await _supabase
        .from('workflow_instances')
        .select()
        .eq('id', instanceId)
        .maybeSingle();

    if (response.error != null || response.data == null) {
      return null;
    }

    return WorkflowInstance.fromJson(response.data);
  }

  Future<Workflow?> getWorkflow(String workflowId) async {
    final response = await _supabase
        .from('workflows')
        .select('''
          *,
          workflow_steps(*)
        ''')
        .eq('id', workflowId)
        .eq('is_active', true)
        .maybeSingle();

    if (response.error != null || response.data == null) {
      return null;
    }

    final workflowData = Map<String, dynamic>.from(response.data);
    final stepsData = workflowData.remove('workflow_steps') as List<dynamic>? ?? [];
    
    final steps = stepsData
        .map((stepData) => WorkflowStep.fromJson(stepData))
        .toList();

    return Workflow.fromJson({
      ...workflowData,
      'steps': steps.map((step) => step.toJson()).toList(),
    });
  }

  Future<List<WorkflowInstance>> getWorkflowInstances({
    String? organizationId,
    String? userId,
    WorkflowStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _supabase
        .from('workflow_instances')
        .select()
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    if (organizationId != null) {
      query = query.eq('organization_id', organizationId);
    }

    if (userId != null) {
      query = query.eq('initiator_user_id', userId);
    }

    if (status != null) {
      query = query.eq('status', status.toString().split('.').last);
    }

    final response = await query;

    if (response.error != null) {
      throw Exception('Failed to fetch workflow instances: ${response.error!.message}');
    }

    return (response.data as List<dynamic>)
        .map((json) => WorkflowInstance.fromJson(json))
        .toList();
  }

  Future<void> pauseWorkflowInstance(String instanceId, String userId) async {
    await _updateWorkflowInstanceStatus(
      instanceId, 
      WorkflowStatus.paused, 
      userId,
    );
  }

  Future<void> resumeWorkflowInstance(String instanceId, String userId) async {
    await _updateWorkflowInstanceStatus(
      instanceId, 
      WorkflowStatus.active, 
      userId,
    );
  }

  Future<void> cancelWorkflowInstance(String instanceId, String userId) async {
    await _updateWorkflowInstanceStatus(
      instanceId, 
      WorkflowStatus.cancelled, 
      userId,
    );
  }

  Future<List<WorkflowHistoryEntry>> getWorkflowHistory(String instanceId) async {
    final response = await _supabase
        .from('workflow_history')
        .select()
        .eq('instance_id', instanceId)
        .order('performed_at', ascending: false);

    if (response.error != null) {
      throw Exception('Failed to fetch workflow history: ${response.error!.message}');
    }

    return (response.data as List<dynamic>)
        .map((json) => WorkflowHistoryEntry(
          id: json['id'],
          fromState: json['from_state'],
          toState: json['to_state'],
          contextData: Map<String, dynamic>.from(json['context_data'] ?? {}),
          performedAt: DateTime.parse(json['performed_at']),
          performedBy: json['performed_by'],
          actorRole: json['actor_role'],
          reason: json['reason'],
        ))
        .toList();
  }

  Future<bool> _evaluateStepConditions(
    Map<String, dynamic> conditions,
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    for (final entry in conditions.entries) {
      final conditionKey = entry.key;
      final conditionValue = entry.value;

      switch (conditionKey) {
        case 'required_fields':
          final requiredFields = List<String>.from(conditionValue);
          for (final field in requiredFields) {
            if (!transitionContext.containsKey(field) || 
                transitionContext[field] == null) {
              return false;
            }
          }
          break;

        case 'min_amount':
          final minAmount = conditionValue as num;
          final amount = transitionContext['amount'] as num? ?? 0;
          if (amount < minAmount) return false;
          break;

        case 'max_amount':
          final maxAmount = conditionValue as num;
          final amount = transitionContext['amount'] as num? ?? 0;
          if (amount > maxAmount) return false;
          break;

        case 'approval_count':
          final requiredCount = conditionValue as int;
          final approvals = currentContext['approvals'] as List? ?? [];
          if (approvals.length < requiredCount) return false;
          break;

        case 'time_limit':
          final timeLimitHours = conditionValue as int;
          final createdAt = DateTime.parse(currentContext['created_at'] as String);
          final now = DateTime.now();
          final hoursDiff = now.difference(createdAt).inHours;
          if (hoursDiff > timeLimitHours) return false;
          break;

        case 'custom_validation':
          final validationName = conditionValue as String;
          final isValid = await _executeCustomStepValidation(
            validationName,
            currentContext,
            transitionContext,
          );
          if (!isValid) return false;
          break;
      }
    }

    return true;
  }

  Future<bool> _executeCustomStepValidation(
    String validationName,
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    switch (validationName) {
      case 'budget_validation':
        return await _validateBudget(currentContext, transitionContext);
      
      case 'security_clearance':
        return await _validateSecurityClearance(currentContext, transitionContext);
      
      case 'compliance_check':
        return await _validateCompliance(currentContext, transitionContext);
      
      default:
        return true;
    }
  }

  Future<bool> _validateBudget(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final amount = transitionContext['amount'] as num? ?? 0;
    final department = transitionContext['department'] as String?;
    
    if (department == null) return false;

    final response = await _supabase
        .from('department_budgets')
        .select('available_budget')
        .eq('department_code', department)
        .eq('year', DateTime.now().year)
        .maybeSingle();

    if (response.error != null || response.data == null) {
      return false;
    }

    final availableBudget = response.data['available_budget'] as num;
    return amount <= availableBudget;
  }

  Future<bool> _validateSecurityClearance(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final classification = transitionContext['security_classification'] as String? ?? 'public';
    final performedBy = transitionContext['performedBy'] as String?;
    
    if (performedBy == null) return false;

    final userPositions = await _rbacResolver.getUserActivePositions(performedBy);
    final maxJobLevel = userPositions
        .map((pos) => pos.jobLevel ?? 0)
        .fold(0, (max, level) => level > max ? level : max);

    switch (classification) {
      case 'public':
        return true;
      case 'internal':
        return maxJobLevel >= 3;
      case 'confidential':
        return maxJobLevel >= 5;
      case 'secret':
        return maxJobLevel >= 8;
      case 'top_secret':
        return maxJobLevel >= 10;
      default:
        return false;
    }
  }

  Future<bool> _validateCompliance(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final requiredApprovals = currentContext['required_approvals'] as List? ?? [];
    final actualApprovals = currentContext['approvals'] as List? ?? [];

    for (final requiredApproval in requiredApprovals) {
      final approvalType = requiredApproval['type'] as String;
      final hasApproval = actualApprovals.any((approval) => 
          approval['type'] == approvalType && approval['status'] == 'approved');
      
      if (!hasApproval) return false;
    }

    return true;
  }

  Future<List<WorkflowStep>> _getAvailableTransitions(
    WorkflowStep currentStep,
    Workflow workflow,
  ) async {
    final nextStepOrder = currentStep.stepOrder + 1;
    
    if (currentStep.isParallel) {
      return workflow.steps
          .where((step) => step.stepOrder == nextStepOrder)
          .toList();
    } else {
      final nextStep = workflow.steps
          .where((step) => step.stepOrder == nextStepOrder)
          .firstOrNull;
      
      return nextStep != null ? [nextStep] : [];
    }
  }

  bool _isCompletedState(WorkflowStep step, Workflow workflow) {
    final maxOrder = workflow.steps
        .map((s) => s.stepOrder)
        .fold(0, (max, order) => order > max ? order : max);
    
    return step.stepOrder == maxOrder;
  }

  Future<void> _completeWorkflowInstance(String instanceId) async {
    await _updateWorkflowInstanceStatus(
      instanceId,
      WorkflowStatus.completed,
      null,
    );

    _eventBus.emit(WorkflowEvents.instanceCompleted, {
      'instanceId': instanceId,
      'completedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _updateWorkflowInstanceStatus(
    String instanceId,
    WorkflowStatus status,
    String? userId,
  ) async {
    final response = await _supabase
        .from('workflow_instances')
        .update({
          'status': status.toString().split('.').last,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', instanceId);

    if (response.error != null) {
      throw Exception('Failed to update workflow instance status: ${response.error!.message}');
    }

    if (userId != null) {
      await _auditService.logWorkflowTransition(
        instanceId: instanceId,
        fromState: null,
        toState: status.toString().split('.').last,
        userId: userId,
        actorRole: 'system',
        context: {'status_change': true},
      );
    }
  }

  Future<void> _createWorkflowHistoryEntry({
    required String instanceId,
    required String fromState,
    required String toState,
    required String userId,
    required String actorRole,
    required Map<String, dynamic> contextData,
    String? reason,
  }) async {
    final historyEntry = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'instance_id': instanceId,
      'from_state': fromState,
      'to_state': toState,
      'action': 'transition',
      'context_data': contextData,
      'performed_by': userId,
      'actor_role': actorRole,
      'performed_at': DateTime.now().toIso8601String(),
      'reason': reason,
    };

    final response = await _supabase
        .from('workflow_history')
        .insert(historyEntry);

    if (response.error != null) {
      print('Warning: Failed to create workflow history entry: ${response.error!.message}');
    }
  }
}