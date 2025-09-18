import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rbac.dart';
import 'event_bus.dart';

class AuditService {
  final SupabaseClient _supabase;
  final EventBus _eventBus;

  AuditService({
    required SupabaseClient supabase,
    required EventBus eventBus,
  }) : _supabase = supabase, _eventBus = eventBus;

  Future<void> logPermissionCheck({
    required String instanceId,
    required String userId,
    required String workflowStepId,
    required String actorRole,
    required PermissionCheckResult result,
    Map<String, dynamic> context = const {},
  }) async {
    final auditEntry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: 'permission_check',
      userId: userId,
      resourceType: 'workflow_step',
      resourceId: workflowStepId,
      action: actorRole,
      result: result.hasPermission ? 'granted' : 'denied',
      details: _encryptSensitiveData({
        'matched_permissions': result.matchedPermissions,
        'reasons': result.reasons,
        'user_positions': result.userPositions.map((p) => p.toJson()).toList(),
        'context': context,
      }),
      workflowInstanceId: instanceId,
      timestamp: DateTime.now(),
    );

    await _createAuditLog(auditEntry);
    
    _eventBus.emit('audit.permission_check', auditEntry.toJson());
  }

  Future<void> logPermissionDenied({
    required String userId,
    required String workflowStepId,
    required String actorRole,
    required PermissionCheckResult permissionResult,
    Map<String, dynamic> context = const {},
  }) async {
    final auditEntry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: 'permission_denied',
      userId: userId,
      resourceType: 'workflow_step',
      resourceId: workflowStepId,
      action: actorRole,
      result: 'denied',
      details: _encryptSensitiveData({
        'reasons': permissionResult.reasons,
        'user_positions': permissionResult.userPositions.map((p) => p.toJson()).toList(),
        'context': context,
      }),
      timestamp: DateTime.now(),
    );

    await _createAuditLog(auditEntry);
    
    _eventBus.emit('audit.permission_denied', auditEntry.toJson());
  }

  Future<void> logWorkflowTransition({
    required String instanceId,
    required String? fromState,
    required String toState,
    required String userId,
    required String actorRole,
    Map<String, dynamic> context = const {},
  }) async {
    final auditEntry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: 'workflow_transition',
      userId: userId,
      resourceType: 'workflow_instance',
      resourceId: instanceId,
      action: 'transition_${fromState ?? 'initial'}_to_$toState',
      result: 'success',
      details: _encryptSensitiveData({
        'from_state': fromState,
        'to_state': toState,
        'actor_role': actorRole,
        'context': context,
      }),
      workflowInstanceId: instanceId,
      timestamp: DateTime.now(),
    );

    await _createAuditLog(auditEntry);
    
    _eventBus.emit('audit.workflow_transition', auditEntry.toJson());
  }

  Future<void> logSecurityIncident({
    required String type,
    required String userId,
    required String resource,
    required String attemptedAction,
    Map<String, dynamic> additionalData = const {},
  }) async {
    final auditEntry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: 'security_incident',
      userId: userId,
      resourceType: 'security',
      resourceId: resource,
      action: attemptedAction,
      result: 'blocked',
      details: _encryptSensitiveData({
        'incident_type': type,
        'additional_data': additionalData,
      }),
      timestamp: DateTime.now(),
    );

    await _createAuditLog(auditEntry);
    
    _eventBus.emit('audit.security_incident', auditEntry.toJson());
  }

  Future<void> logUserPositionChange({
    required String userId,
    required String positionId,
    required String changeType,
    required String performedBy,
    Map<String, dynamic> context = const {},
  }) async {
    final auditEntry = AuditLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      eventType: 'position_change',
      userId: userId,
      resourceType: 'user_position',
      resourceId: positionId,
      action: changeType,
      result: 'success',
      details: _encryptSensitiveData({
        'performed_by': performedBy,
        'context': context,
      }),
      timestamp: DateTime.now(),
    );

    await _createAuditLog(auditEntry);
    
    _eventBus.emit('audit.position_change', auditEntry.toJson());
  }

  Future<List<AuditLogEntry>> getAuditLogs({
    String? userId,
    String? eventType,
    String? workflowInstanceId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
    int offset = 0,
  }) async {
    var query = _supabase
        .from('audit_logs')
        .select()
        .order('timestamp', ascending: false)
        .range(offset, offset + limit - 1);

    if (userId != null) {
      query = query.eq('user_id', userId);
    }

    if (eventType != null) {
      query = query.eq('event_type', eventType);
    }

    if (workflowInstanceId != null) {
      query = query.eq('workflow_instance_id', workflowInstanceId);
    }

    if (startDate != null) {
      query = query.gte('timestamp', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte('timestamp', endDate.toIso8601String());
    }

    final response = await query;

    if (response.error != null) {
      throw Exception('Failed to fetch audit logs: ${response.error!.message}');
    }

    return (response.data as List<dynamic>)
        .map((json) => AuditLogEntry.fromJson(json))
        .toList();
  }

  Future<Map<String, dynamic>> generateComplianceReport({
    required DateTime startDate,
    required DateTime endDate,
    String? organizationId,
    String? userId,
    String? eventType,
  }) async {
    final query = '''
      SELECT 
        event_type,
        result,
        COUNT(*) as event_count,
        COUNT(DISTINCT user_id) as unique_users,
        DATE_TRUNC('day', timestamp) as event_date
      FROM audit_logs
      WHERE timestamp BETWEEN \$1 AND \$2
    ''';

    final params = [startDate.toIso8601String(), endDate.toIso8601String()];
    var paramIndex = 2;

    var finalQuery = query;

    if (userId != null) {
      finalQuery += ' AND user_id = \$${++paramIndex}';
      params.add(userId);
    }

    if (eventType != null) {
      finalQuery += ' AND event_type = \$${++paramIndex}';
      params.add(eventType);
    }

    if (organizationId != null) {
      finalQuery += '''
        AND EXISTS (
          SELECT 1 FROM workflow_instances wi 
          WHERE wi.id = audit_logs.workflow_instance_id 
          AND wi.organization_id = \$${++paramIndex}
        )
      ''';
      params.add(organizationId);
    }

    finalQuery += '''
      GROUP BY event_type, result, event_date 
      ORDER BY event_date DESC, event_type
    ''';

    final response = await _supabase.rpc('execute_query', {
      'query_text': finalQuery,
      'params': params,
    });

    if (response.error != null) {
      throw Exception('Failed to generate compliance report: ${response.error!.message}');
    }

    final reportData = response.data as List<dynamic>;

    return {
      'report_period': {
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      },
      'filters': {
        'organization_id': organizationId,
        'user_id': userId,
        'event_type': eventType,
      },
      'summary': _generateReportSummary(reportData),
      'detailed_data': reportData,
      'generated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<List<Map<String, dynamic>>> getSecurityAlerts({
    DateTime? since,
    int limit = 50,
  }) async {
    final sinceDate = since ?? DateTime.now().subtract(const Duration(hours: 24));

    final response = await _supabase
        .from('audit_logs')
        .select()
        .eq('event_type', 'security_incident')
        .gte('timestamp', sinceDate.toIso8601String())
        .order('timestamp', ascending: false)
        .limit(limit);

    if (response.error != null) {
      throw Exception('Failed to fetch security alerts: ${response.error!.message}');
    }

    return (response.data as List<dynamic>)
        .map((json) => Map<String, dynamic>.from(json))
        .toList();
  }

  Future<void> _createAuditLog(AuditLogEntry entry) async {
    final response = await _supabase
        .from('audit_logs')
        .insert(entry.toJson());

    if (response.error != null) {
      throw Exception('Failed to create audit log: ${response.error!.message}');
    }
  }

  String _encryptSensitiveData(Map<String, dynamic> data) {
    return data.toString();
  }

  Map<String, dynamic> _generateReportSummary(List<dynamic> reportData) {
    final summary = <String, dynamic>{
      'total_events': 0,
      'unique_users': 0,
      'events_by_type': <String, int>{},
      'success_rate': 0.0,
      'security_incidents': 0,
    };

    final uniqueUsers = <String>{};
    var totalEvents = 0;
    var successfulEvents = 0;

    for (final row in reportData) {
      final eventType = row['event_type'] as String;
      final result = row['result'] as String;
      final eventCount = row['event_count'] as int;
      final userCount = row['unique_users'] as int;

      totalEvents += eventCount;
      if (result == 'success' || result == 'granted') {
        successfulEvents += eventCount;
      }

      summary['events_by_type'][eventType] = 
          (summary['events_by_type'][eventType] ?? 0) + eventCount;

      if (eventType == 'security_incident') {
        summary['security_incidents'] += eventCount;
      }

      uniqueUsers.add(userCount.toString());
    }

    summary['total_events'] = totalEvents;
    summary['unique_users'] = uniqueUsers.length;
    summary['success_rate'] = totalEvents > 0 ? successfulEvents / totalEvents : 0.0;

    return summary;
  }
}