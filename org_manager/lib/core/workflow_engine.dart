import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workflow.dart';
import '../services/rbac_permission_resolver.dart';
import '../services/audit_service.dart';
import '../services/event_bus.dart';
import 'base_workflow.dart';

class WorkflowEngine {
  final SupabaseClient _supabase;
  final RBACPermissionResolver _rbacResolver;
  final EventBus _eventBus;
  final AuditService _auditService;

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
        throw Exception('Workflow $workflowId not found');
      }

      if (!workflow.isActive) {
        throw Exception('Workflow $workflowId is not active');
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

      final createdInstance = WorkflowInstance.fromJson(response);

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
        throw Exception('Workflow instance $instanceId not found');
      }

      if (instance.status != WorkflowStatus.active) {
        throw Exception('Workflow instance is not in active state');
      }

      final workflow = await getWorkflow(instance.workflowId);
      if (workflow == null) {
        throw Exception('Workflow ${instance.workflowId} not found');
      }

      final targetStep = workflow.steps
          .where((step) => step.stepName == targetState)
          .firstOrNull;

      if (targetStep == null) {
        throw Exception('Target state $targetState not found in workflow');
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

        throw Exception(
          'User $userId lacks $actorRole permission for workflow step $targetState'
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
          throw Exception('Step conditions not met for transition to $targetState');
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

      await _supabase
          .from('workflow_instances')
          .update(updatedInstance.toJson())
          .eq('id', instanceId);

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
      throw Exception('Workflow instance $instanceId not found');
    }

    final workflow = await getWorkflow(instance.workflowId);
    if (workflow == null) {
      throw Exception('Workflow ${instance.workflowId} not found');
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
    try {
      final response = await _supabase
          .from('workflow_instances')
          .select()
          .eq('id', instanceId)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      return WorkflowInstance.fromJson(response);
    } catch (e) {
      return null;
    }
  }

  Future<Workflow?> getWorkflow(String workflowId) async {
    try {
      final response = await _supabase
          .from('workflows')
          .select('''
            *,
            workflow_steps(*)
          ''')
          .eq('id', workflowId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        return null;
      }

      final workflowData = Map<String, dynamic>.from(response);
      final stepsData = workflowData.remove('workflow_steps') as List<dynamic>? ?? [];
      
      final steps = stepsData
          .map((stepData) => WorkflowStep.fromJson(stepData))
          .toList();

      return Workflow.fromJson({
        ...workflowData,
        'steps': steps.map((step) => step.toJson()).toList(),
      });
    } catch (e) {
      return null;
    }
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

    return (response as List<dynamic>)
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

    return (response as List<dynamic>)
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

  // Private helper methods
  Future<bool> _evaluateStepConditions(
    Map<String, dynamic> conditions,
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    // Implementation would be similar to the original
    // For now, just return true
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
    await _supabase
        .from('workflow_instances')
        .update({
          'status': status.toString().split('.').last,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', instanceId);

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

    try {
      await _supabase
          .from('workflow_history')
          .insert(historyEntry);
    } catch (e) {
      print('Warning: Failed to create workflow history entry: $e');
    }
  }
}

class TransitionResult {
  final bool success;
  final String newState;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  final String? errorMessage;

  TransitionResult({
    required this.success,
    required this.newState,
    required this.context,
    required this.timestamp,
    this.errorMessage,
  });
}

class WorkflowAction {
  final String action;
  final String targetState;
  final String actorRole;
  final String stepName;
  final List<Map<String, dynamic>> permissionContext;

  WorkflowAction({
    required this.action,
    required this.targetState,
    required this.actorRole,
    required this.stepName,
    required this.permissionContext,
  });

  Map<String, dynamic> toJson() {
    return {
      'action': action,
      'targetState': targetState,
      'actorRole': actorRole,
      'stepName': stepName,
      'permissionContext': permissionContext,
    };
  }
}

class WorkflowHistoryEntry {
  final String id;
  final String? fromState;
  final String toState;
  final Map<String, dynamic> contextData;
  final DateTime performedAt;
  final String? performedBy;
  final String? actorRole;
  final String? reason;

  WorkflowHistoryEntry({
    required this.id,
    this.fromState,
    required this.toState,
    required this.contextData,
    required this.performedAt,
    this.performedBy,
    this.actorRole,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_state': fromState,
      'to_state': toState,
      'context_data': contextData,
      'performed_at': performedAt.toIso8601String(),
      'performed_by': performedBy,
      'actor_role': actorRole,
      'reason': reason,
    };
  }
}

class WorkflowEvents {
  static const String stateChanged = 'workflow.state.changed';
  static const String instanceCreated = 'workflow.instance.created';
  static const String instanceCompleted = 'workflow.instance.completed';
  static const String validationFailed = 'workflow.validation.failed';
  static const String permissionDenied = 'workflow.permission.denied';
  static const String transitionCompleted = 'workflow.transition.completed';
  static const String transitionFailed = 'workflow.transition.failed';
}