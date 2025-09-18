import 'dart:async';
import '../models/workflow.dart';
import '../models/rbac.dart';
import '../services/rbac_permission_resolver.dart';
import '../services/audit_service.dart';
import '../services/event_bus.dart';

abstract class BaseWorkflow {
  final String id;
  final String name;
  final Map<String, StateNode> states = {};
  final EventBus eventBus;
  final RBACPermissionResolver rbacResolver;
  final AuditService auditService;
  
  String? currentState;
  Map<String, dynamic> context = {};
  List<WorkflowHistoryEntry> history = [];

  BaseWorkflow({
    required this.id,
    required this.name,
    required this.eventBus,
    required this.rbacResolver,
    required this.auditService,
  });

  void addState(String stateName, StateNode stateNode) {
    states[stateName] = stateNode;
  }

  Future<void> setState(String stateName, Map<String, dynamic> newContext) async {
    if (!states.containsKey(stateName)) {
      throw WorkflowException('State $stateName does not exist');
    }

    final previousState = currentState;
    final stateNode = states[stateName]!;

    await stateNode.onEnter?.call(newContext);
    
    currentState = stateName;
    context = {...context, ...newContext};

    final historyEntry = WorkflowHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fromState: previousState,
      toState: stateName,
      contextData: newContext,
      performedAt: DateTime.now(),
    );
    
    history.add(historyEntry);

    eventBus.emit(WorkflowEvents.stateChanged, {
      'workflowId': id,
      'previousState': previousState,
      'currentState': stateName,
      'context': context,
    });
  }

  Future<TransitionResult> transitionWithPermissionCheck(
    String targetState,
    String actorRole,
    String userId, {
    Map<String, dynamic> transitionContext = const {},
  }) async {
    try {
      final currentStateNode = states[currentState];
      if (currentStateNode == null) {
        throw WorkflowException('Current state is not set');
      }

      final targetStateNode = states[targetState];
      if (targetStateNode == null) {
        throw WorkflowException('Target state $targetState does not exist');
      }

      if (!currentStateNode.transitions.contains(targetState)) {
        throw WorkflowException('Transition from $currentState to $targetState is not allowed');
      }

      final permissionResult = await rbacResolver.checkPermission(
        userId: userId,
        workflowStepId: targetStateNode.id,
        actorRole: actorRole,
        context: {
          ...context,
          ...transitionContext,
          'workflowId': id,
          'currentState': currentState,
          'targetState': targetState,
        },
      );

      if (!permissionResult.hasPermission) {
        await auditService.logPermissionDenied(
          userId: userId,
          workflowStepId: targetStateNode.id,
          actorRole: actorRole,
          permissionResult: permissionResult,
          context: transitionContext,
        );

        throw PermissionDeniedException(
          'User $userId lacks $actorRole permission for transition to $targetState',
          userId: userId,
          workflowStepId: targetStateNode.id,
          actorRole: actorRole,
          reasons: permissionResult.reasons,
        );
      }

      await auditService.logPermissionCheck(
        instanceId: id,
        userId: userId,
        workflowStepId: targetStateNode.id,
        actorRole: actorRole,
        result: permissionResult,
      );

      for (final validation in targetStateNode.validations) {
        final isValid = await validation(context, transitionContext);
        if (!isValid) {
          throw ValidationException('Validation failed for transition to $targetState');
        }
      }

      await currentStateNode.onExit?.call(context);
      
      final transitionResult = await executeTransition(
        targetState,
        {
          ...transitionContext,
          'performedBy': userId,
          'actorRole': actorRole,
          'permissionContext': permissionResult.matchedPermissions,
        },
      );

      eventBus.emit(WorkflowEvents.transitionCompleted, {
        'workflowId': id,
        'targetState': targetState,
        'userId': userId,
        'actorRole': actorRole,
        'permissionContext': permissionResult.matchedPermissions,
      });

      return transitionResult;
    } catch (error) {
      eventBus.emit(WorkflowEvents.transitionFailed, {
        'workflowId': id,
        'targetState': targetState,
        'userId': userId,
        'actorRole': actorRole,
        'error': error.toString(),
      });
      
      rethrow;
    }
  }

  Future<TransitionResult> executeTransition(
    String targetState,
    Map<String, dynamic> transitionContext,
  ) async {
    await setState(targetState, transitionContext);
    
    return TransitionResult(
      success: true,
      newState: targetState,
      context: context,
      timestamp: DateTime.now(),
    );
  }

  Future<List<WorkflowAction>> getAvailableActionsForUser(String userId) async {
    if (currentState == null) {
      return [];
    }

    final currentStateNode = states[currentState]!;
    final availableActions = <WorkflowAction>[];

    for (final transition in currentStateNode.transitions) {
      final targetStateNode = states[transition];
      if (targetStateNode == null) continue;

      for (final actorRole in targetStateNode.requiredActors) {
        final permissionResult = await rbacResolver.checkPermission(
          userId: userId,
          workflowStepId: targetStateNode.id,
          actorRole: actorRole,
          context: {'workflowData': context},
        );

        if (permissionResult.hasPermission) {
          availableActions.add(WorkflowAction(
            action: 'transition_to_$transition',
            targetState: transition,
            actorRole: actorRole,
            stepName: targetStateNode.name,
            permissionContext: permissionResult.matchedPermissions,
          ));
        }
      }
    }

    return availableActions;
  }

  void on(String eventName, Function callback) {
    eventBus.on(eventName, callback);
  }

  void emit(String eventName, Map<String, dynamic> data) {
    eventBus.emit(eventName, data);
  }

  String? getCurrentState() => currentState;

  void reset() {
    currentState = null;
    context.clear();
    history.clear();
  }

  Map<String, dynamic> getWorkflowDefinition() {
    return {
      'id': id,
      'name': name,
      'states': states.map((key, value) => MapEntry(key, value.toJson())),
      'currentState': currentState,
      'context': context,
    };
  }
}

class StateNode {
  final String id;
  final String name;
  final List<String> transitions;
  final List<ValidationFunction> validations;
  final List<String> requiredActors;
  final Map<String, dynamic> permissionConditions;
  final Function(Map<String, dynamic>)? onEnter;
  final Function(Map<String, dynamic>)? onExit;

  StateNode({
    required this.id,
    required this.name,
    this.transitions = const [],
    this.validations = const [],
    this.requiredActors = const [],
    this.permissionConditions = const {},
    this.onEnter,
    this.onExit,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'transitions': transitions,
      'requiredActors': requiredActors,
      'permissionConditions': permissionConditions,
    };
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

typedef ValidationFunction = Future<bool> Function(
  Map<String, dynamic> currentContext,
  Map<String, dynamic> transitionContext,
);

class WorkflowException implements Exception {
  final String message;
  WorkflowException(this.message);
  
  @override
  String toString() => 'WorkflowException: $message';
}

class PermissionDeniedException implements Exception {
  final String message;
  final String userId;
  final String workflowStepId;
  final String actorRole;
  final List<String> reasons;

  PermissionDeniedException(
    this.message, {
    required this.userId,
    required this.workflowStepId,
    required this.actorRole,
    required this.reasons,
  });

  @override
  String toString() => 'PermissionDeniedException: $message';
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  
  @override
  String toString() => 'ValidationException: $message';
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