import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workflow.dart';
import '../models/rbac.dart';

class WorkflowApiService {
  final SupabaseClient _supabase;

  WorkflowApiService({required SupabaseClient supabase}) : _supabase = supabase;

  Future<WorkflowInstance> createWorkflowInstance({
    required String workflowId,
    required String organizationId,
    Map<String, dynamic> initialContext = const {},
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management',
        body: {
          'workflowId': workflowId,
          'organizationId': organizationId,
          'initialContext': initialContext,
        },
        method: HttpMethod.post,
      );

      if (response.status != 201) {
        throw Exception('Failed to create workflow instance: ${response.data['error']}');
      }

      return WorkflowInstance.fromJson(response.data['data']);
    } catch (error) {
      throw Exception('Failed to create workflow instance: $error');
    }
  }

  Future<TransitionResult> transitionWorkflow({
    required String instanceId,
    required String targetState,
    required String actorRole,
    Map<String, dynamic> context = const {},
    String? reason,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/transition',
        body: {
          'instanceId': instanceId,
          'targetState': targetState,
          'actorRole': actorRole,
          'context': context,
          if (reason != null) 'reason': reason,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        if (response.status == 403) {
          throw PermissionDeniedException(
            'Permission denied: ${response.data['error']}',
            userId: '',
            workflowStepId: '',
            actorRole: actorRole,
            reasons: List<String>.from(response.data['reasons'] ?? []),
          );
        }
        throw Exception('Failed to transition workflow: ${response.data['error']}');
      }

      final data = response.data['data'];
      return TransitionResult(
        success: true,
        newState: data['newState'],
        context: Map<String, dynamic>.from(data['context']),
        timestamp: DateTime.parse(data['timestamp']),
      );
    } catch (error) {
      if (error is PermissionDeniedException) rethrow;
      throw Exception('Failed to transition workflow: $error');
    }
  }

  Future<PermissionCheckResult> checkPermission({
    required String workflowStepId,
    required String actorRole,
    Map<String, dynamic> context = const {},
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/check-permission',
        body: {
          'workflowStepId': workflowStepId,
          'actorRole': actorRole,
          'context': context,
        },
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        throw Exception('Failed to check permission: ${response.data['error']}');
      }

      return PermissionCheckResult.fromJson(response.data['data']);
    } catch (error) {
      throw Exception('Failed to check permission: $error');
    }
  }

  Future<List<WorkflowAction>> getAvailableActions({
    required String instanceId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/available-actions?instanceId=$instanceId',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('Failed to get available actions: ${response.data['error']}');
      }

      final actionsData = response.data['data'] as List<dynamic>;
      return actionsData
          .map((actionJson) => WorkflowAction(
                action: actionJson['action'],
                targetState: actionJson['targetState'],
                actorRole: actionJson['actorRole'],
                stepName: actionJson['stepName'],
                permissionContext: List<Map<String, dynamic>>.from(
                  actionJson['permissionContext'] ?? []
                ),
              ))
          .toList();
    } catch (error) {
      throw Exception('Failed to get available actions: $error');
    }
  }

  Future<WorkflowInstance?> getWorkflowInstance(String instanceId) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/instance-$instanceId',
        method: HttpMethod.get,
      );

      if (response.status == 404) {
        return null;
      }

      if (response.status != 200) {
        throw Exception('Failed to get workflow instance: ${response.data['error']}');
      }

      return WorkflowInstance.fromJson(response.data['data']);
    } catch (error) {
      throw Exception('Failed to get workflow instance: $error');
    }
  }

  Future<List<WorkflowInstance>> getWorkflowInstances({
    String? organizationId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, String>{
        'limit': limit.toString(),
        'offset': offset.toString(),
      };

      if (organizationId != null) {
        queryParams['organizationId'] = organizationId;
      }

      if (status != null) {
        queryParams['status'] = status;
      }

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _supabase.functions.invoke(
        'workflow-management/instances?$queryString',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('Failed to get workflow instances: ${response.data['error']}');
      }

      final instancesData = response.data['data'] as List<dynamic>;
      return instancesData
          .map((instanceJson) => WorkflowInstance.fromJson(instanceJson))
          .toList();
    } catch (error) {
      throw Exception('Failed to get workflow instances: $error');
    }
  }

  Future<List<Workflow>> getWorkflows() async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/workflows',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('Failed to get workflows: ${response.data['error']}');
      }

      final workflowsData = response.data['data'] as List<dynamic>;
      return workflowsData
          .map((workflowJson) => Workflow.fromJson(workflowJson))
          .toList();
    } catch (error) {
      throw Exception('Failed to get workflows: $error');
    }
  }

  Future<List<WorkflowHistoryEntry>> getWorkflowHistory(String instanceId) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/history?instanceId=$instanceId',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('Failed to get workflow history: ${response.data['error']}');
      }

      final historyData = response.data['data'] as List<dynamic>;
      return historyData
          .map((historyJson) => WorkflowHistoryEntry(
                id: historyJson['id'],
                fromState: historyJson['from_state'],
                toState: historyJson['to_state'],
                contextData: Map<String, dynamic>.from(historyJson['context_data'] ?? {}),
                performedAt: DateTime.parse(historyJson['performed_at']),
                performedBy: historyJson['performed_by'],
                actorRole: historyJson['actor_role'],
                reason: historyJson['reason'],
              ))
          .toList();
    } catch (error) {
      throw Exception('Failed to get workflow history: $error');
    }
  }

  Future<void> pauseWorkflowInstance(String instanceId) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/pause-instance',
        body: {'instanceId': instanceId},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        throw Exception('Failed to pause workflow instance: ${response.data['error']}');
      }
    } catch (error) {
      throw Exception('Failed to pause workflow instance: $error');
    }
  }

  Future<void> resumeWorkflowInstance(String instanceId) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/resume-instance',
        body: {'instanceId': instanceId},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        throw Exception('Failed to resume workflow instance: ${response.data['error']}');
      }
    } catch (error) {
      throw Exception('Failed to resume workflow instance: $error');
    }
  }

  Future<void> cancelWorkflowInstance(String instanceId) async {
    try {
      final response = await _supabase.functions.invoke(
        'workflow-management/cancel-instance',
        body: {'instanceId': instanceId},
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        throw Exception('Failed to cancel workflow instance: ${response.data['error']}');
      }
    } catch (error) {
      throw Exception('Failed to cancel workflow instance: $error');
    }
  }

  Future<List<String>> getEligibleUsers({
    required String workflowStepId,
    required List<String> requiredActors,
  }) async {
    try {
      final queryParams = <String, String>{
        'workflowStepId': workflowStepId,
        'requiredActors': requiredActors.join(','),
      };

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _supabase.functions.invoke(
        'workflow-management/eligible-users?$queryString',
        method: HttpMethod.get,
      );

      if (response.status != 200) {
        throw Exception('Failed to get eligible users: ${response.data['error']}');
      }

      return List<String>.from(response.data['data'] ?? []);
    } catch (error) {
      throw Exception('Failed to get eligible users: $error');
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