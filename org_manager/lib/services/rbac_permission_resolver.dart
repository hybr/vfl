import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/rbac.dart';
import '../models/workflow.dart';
import 'cache_service.dart';

class RBACPermissionResolver {
  final SupabaseClient _supabase;
  final CacheService _cache;

  RBACPermissionResolver({
    required SupabaseClient supabase,
    required CacheService cache,
  }) : _supabase = supabase, _cache = cache;

  Future<PermissionCheckResult> checkPermission({
    required String userId,
    required String workflowStepId,
    required String actorRole,
    Map<String, dynamic> context = const {},
  }) async {
    final cacheKey = '$userId:$workflowStepId:$actorRole';
    
    final cached = await _cache.getPermission(cacheKey);
    if (cached != null) return cached;

    try {
      final userPositions = await getUserActivePositions(userId);
      
      final stepPermissions = await getWorkflowStepPermissions(
        workflowStepId, 
        actorRole
      );
      
      final permissionResult = await evaluatePermissions(
        userPositions, 
        stepPermissions, 
        context
      );

      await _cache.setPermission(cacheKey, permissionResult);

      return permissionResult;
    } catch (error) {
      throw PermissionError('Permission check failed: ${error.toString()}');
    }
  }

  Future<List<UserPositionContext>> getUserActivePositions(String userId) async {
    const query = '''
      SELECT 
        upa.id as assignment_id,
        upa.assignment_type,
        op.id as position_id,
        op.position_title,
        ogd.id as designation_id,
        ogd.designation_name,
        ogd.designation_code,
        ogd.group_type,
        ogd.group_id,
        ogd.job_level,
        
        -- Department info (if group_type = 'department')
        od.name as department_name,
        od.code as department_code,
        
        -- Team info (if group_type = 'team')
        ot.name as team_name,
        ot.code as team_code,
        parent_dept.name as parent_department_name,
        
        -- Physical location
        ows.seat_number,
        ob.name as building_name,
        obr.name as branch_name,
        org.name as organization_name
        
      FROM user_position_assignments upa
      JOIN organization_positions op ON upa.position_id = op.id
      JOIN organization_group_designations ogd ON op.group_designation_id = ogd.id
      JOIN organization_worker_seats ows ON op.worker_seat_id = ows.id
      JOIN organization_buildings ob ON ows.building_id = ob.id
      JOIN organization_branches obr ON ob.branch_id = obr.id
      JOIN organizations org ON obr.organization_id = org.id
      
      -- Join department or team based on group_type
      LEFT JOIN organization_departments od ON ogd.group_type = 'department' AND ogd.group_id = od.id
      LEFT JOIN organization_teams ot ON ogd.group_type = 'team' AND ogd.group_id = ot.id
      LEFT JOIN organization_departments parent_dept ON ot.department_id = parent_dept.id
      
      WHERE upa.user_id = \$1
        AND upa.is_active = true
        AND (upa.end_date IS NULL OR upa.end_date >= CURRENT_DATE)
        AND upa.start_date <= CURRENT_DATE
        AND op.is_active = true
        AND ogd.is_active = true
    ''';
    
    final response = await _supabase.rpc('execute_query', {
      'query_text': query,
      'params': [userId]
    });

    if (response.error != null) {
      throw Exception('Failed to fetch user positions: ${response.error!.message}');
    }

    return (response.data as List<dynamic>)
        .map((row) => UserPositionContext.fromJson(row))
        .toList();
  }

  Future<List<WorkflowPermission>> getWorkflowStepPermissions(
    String workflowStepId,
    String actorRole,
  ) async {
    final response = await _supabase
        .from('workflow_permissions')
        .select('''
          *,
          workflow_actors!inner(name)
        ''')
        .eq('workflow_step_id', workflowStepId)
        .eq('workflow_actors.name', actorRole)
        .eq('is_active', true);

    if (response.error != null) {
      throw Exception('Failed to fetch workflow permissions: ${response.error!.message}');
    }

    return (response.data as List<dynamic>)
        .map((json) => WorkflowPermission.fromJson(json))
        .toList();
  }

  Future<PermissionCheckResult> evaluatePermissions(
    List<UserPositionContext> userPositions,
    List<WorkflowPermission> stepPermissions,
    Map<String, dynamic> context,
  ) async {
    final matchedPermissions = <Map<String, dynamic>>[];
    final reasons = <String>[];

    if (userPositions.isEmpty) {
      reasons.add('User has no active organizational positions');
      return PermissionCheckResult(
        hasPermission: false,
        matchedPermissions: matchedPermissions,
        reasons: reasons,
        userPositions: userPositions,
      );
    }

    if (stepPermissions.isEmpty) {
      reasons.add('No permissions configured for this workflow step');
      return PermissionCheckResult(
        hasPermission: false,
        matchedPermissions: matchedPermissions,
        reasons: reasons,
        userPositions: userPositions,
      );
    }

    bool hasValidPermission = false;

    for (final permission in stepPermissions) {
      for (final userPosition in userPositions) {
        final isMatch = await evaluatePermissionMatch(
          userPosition, 
          permission, 
          context
        );

        if (isMatch.matches) {
          if (permission.permissionType == PermissionType.forbidden) {
            reasons.add('User has forbidden permission for this action');
            return PermissionCheckResult(
              hasPermission: false,
              matchedPermissions: matchedPermissions,
              reasons: reasons,
              userPositions: userPositions,
            );
          }

          if (permission.permissionType == PermissionType.required ||
              permission.permissionType == PermissionType.optional) {
            hasValidPermission = true;
            matchedPermissions.add({
              'permission': permission.toJson(),
              'userPosition': userPosition.toJson(),
              'matchType': isMatch.matchType,
              'conditions': isMatch.conditionResults,
            });
          }
        }
      }
    }

    if (!hasValidPermission) {
      reasons.add('User does not match any required permissions for this workflow step');
    }

    return PermissionCheckResult(
      hasPermission: hasValidPermission,
      matchedPermissions: matchedPermissions,
      reasons: reasons,
      userPositions: userPositions,
      contextualChecks: await evaluateContextualConditions(context),
    );
  }

  Future<PermissionMatchResult> evaluatePermissionMatch(
    UserPositionContext userPosition,
    WorkflowPermission permission,
    Map<String, dynamic> context,
  ) async {
    bool groupMatches = false;
    bool designationMatches = true;
    final conditionResults = <String, dynamic>{};

    if (permission.groupType == 'department') {
      if (userPosition.groupType == GroupType.department) {
        groupMatches = userPosition.groupId == permission.groupId;
      } else if (userPosition.groupType == GroupType.team) {
        final teamDepartmentResponse = await _supabase
            .from('organization_teams')
            .select('department_id')
            .eq('id', userPosition.groupId)
            .single();
        
        if (teamDepartmentResponse.error == null) {
          groupMatches = teamDepartmentResponse.data['department_id'] == permission.groupId;
        }
      }
    } else if (permission.groupType == 'team') {
      groupMatches = userPosition.groupType == GroupType.team && 
                   userPosition.groupId == permission.groupId;
    }

    if (permission.designationId != null) {
      designationMatches = userPosition.designationId == permission.designationId;
    }

    if (permission.conditions.isNotEmpty) {
      final conditionCheck = await evaluateConditions(
        permission.conditions, 
        context, 
        userPosition
      );
      conditionResults.addAll(conditionCheck);
      
      designationMatches = designationMatches && 
                          conditionCheck.values.every((result) => result == true);
    }

    final matches = groupMatches && designationMatches;
    String matchType = 'none';

    if (matches) {
      if (permission.designationId != null) {
        matchType = 'exact';
      } else {
        matchType = 'group';
      }
    }

    return PermissionMatchResult(
      matches: matches,
      matchType: matchType,
      conditionResults: conditionResults,
    );
  }

  Future<Map<String, dynamic>> evaluateConditions(
    Map<String, dynamic> conditions,
    Map<String, dynamic> context,
    UserPositionContext userPosition,
  ) async {
    final results = <String, dynamic>{};

    for (final entry in conditions.entries) {
      final conditionKey = entry.key;
      final conditionValue = entry.value;

      switch (conditionKey) {
        case 'min_job_level':
          final minLevel = conditionValue as int;
          results[conditionKey] = (userPosition.jobLevel ?? 0) >= minLevel;
          break;

        case 'max_job_level':
          final maxLevel = conditionValue as int;
          results[conditionKey] = (userPosition.jobLevel ?? 0) <= maxLevel;
          break;

        case 'assignment_type':
          final requiredTypes = List<String>.from(conditionValue);
          results[conditionKey] = requiredTypes.contains(
            userPosition.assignmentType.toString().split('.').last
          );
          break;

        case 'workflow_amount_limit':
          final limit = conditionValue as num;
          final workflowAmount = context['amount'] as num? ?? 0;
          results[conditionKey] = workflowAmount <= limit;
          break;

        case 'department_budget_approval':
          final contextDepartment = context['department'] as String?;
          results[conditionKey] = contextDepartment == userPosition.departmentCode;
          break;

        case 'time_constraint':
          final timeConstraints = Map<String, dynamic>.from(conditionValue);
          results[conditionKey] = await evaluateTimeConstraints(timeConstraints);
          break;

        case 'custom_validation':
          final validationName = conditionValue as String;
          results[conditionKey] = await executeCustomValidation(
            validationName, 
            context, 
            userPosition
          );
          break;

        default:
          results[conditionKey] = true;
      }
    }

    return results;
  }

  Future<bool> evaluateTimeConstraints(Map<String, dynamic> constraints) async {
    final now = DateTime.now();
    
    if (constraints.containsKey('business_hours_only')) {
      final businessHoursOnly = constraints['business_hours_only'] as bool;
      if (businessHoursOnly) {
        final hour = now.hour;
        final isWeekday = now.weekday <= 5;
        return isWeekday && hour >= 9 && hour <= 17;
      }
    }

    if (constraints.containsKey('deadline')) {
      final deadline = DateTime.parse(constraints['deadline'] as String);
      return now.isBefore(deadline);
    }

    return true;
  }

  Future<bool> executeCustomValidation(
    String validationName,
    Map<String, dynamic> context,
    UserPositionContext userPosition,
  ) async {
    switch (validationName) {
      case 'expense_approval_hierarchy':
        return await validateExpenseApprovalHierarchy(context, userPosition);
      
      case 'document_classification_clearance':
        return await validateDocumentClearance(context, userPosition);
      
      case 'project_team_membership':
        return await validateProjectTeamMembership(context, userPosition);
      
      default:
        return true;
    }
  }

  Future<bool> validateExpenseApprovalHierarchy(
    Map<String, dynamic> context,
    UserPositionContext userPosition,
  ) async {
    final amount = context['amount'] as num? ?? 0;
    final jobLevel = userPosition.jobLevel ?? 0;

    if (amount <= 1000 && jobLevel >= 3) return true;
    if (amount <= 5000 && jobLevel >= 5) return true;
    if (amount <= 25000 && jobLevel >= 7) return true;
    if (amount <= 100000 && jobLevel >= 9) return true;
    if (jobLevel >= 10) return true;

    return false;
  }

  Future<bool> validateDocumentClearance(
    Map<String, dynamic> context,
    UserPositionContext userPosition,
  ) async {
    final classification = context['document_classification'] as String? ?? 'public';
    final jobLevel = userPosition.jobLevel ?? 0;

    switch (classification) {
      case 'public':
        return true;
      case 'internal':
        return jobLevel >= 3;
      case 'confidential':
        return jobLevel >= 5;
      case 'secret':
        return jobLevel >= 8;
      case 'top_secret':
        return jobLevel >= 10;
      default:
        return false;
    }
  }

  Future<bool> validateProjectTeamMembership(
    Map<String, dynamic> context,
    UserPositionContext userPosition,
  ) async {
    final projectId = context['project_id'] as String?;
    if (projectId == null) return false;

    final response = await _supabase
        .from('project_team_members')
        .select('user_id')
        .eq('project_id', projectId)
        .eq('user_id', userPosition.assignmentId)
        .eq('is_active', true);

    return response.data?.isNotEmpty ?? false;
  }

  Future<Map<String, dynamic>?> evaluateContextualConditions(
    Map<String, dynamic> context,
  ) async {
    final results = <String, dynamic>{};

    if (context.containsKey('workflow_priority')) {
      results['priority_check'] = await evaluatePriorityRequirements(context);
    }

    if (context.containsKey('escalation_path')) {
      results['escalation_check'] = await evaluateEscalationPath(context);
    }

    return results.isEmpty ? null : results;
  }

  Future<bool> evaluatePriorityRequirements(Map<String, dynamic> context) async {
    final priority = context['workflow_priority'] as String? ?? 'normal';
    final now = DateTime.now();
    final hour = now.hour;

    switch (priority) {
      case 'emergency':
        return true;
      case 'high':
        return hour >= 8 && hour <= 18;
      case 'normal':
        return hour >= 9 && hour <= 17 && now.weekday <= 5;
      default:
        return true;
    }
  }

  Future<bool> evaluateEscalationPath(Map<String, dynamic> context) async {
    final escalationLevel = context['escalation_level'] as int? ?? 0;
    final maxEscalations = context['max_escalations'] as int? ?? 3;
    
    return escalationLevel <= maxEscalations;
  }

  Future<List<String>> getEligibleUsersForStep(
    String workflowStepId,
    List<String> requiredActors,
  ) async {
    final eligibleUsers = <String>[];

    for (final actorRole in requiredActors) {
      final stepPermissions = await getWorkflowStepPermissions(
        workflowStepId,
        actorRole,
      );

      for (final permission in stepPermissions) {
        final userQuery = await _supabase
            .from('user_position_assignments')
            .select('''
              user_id,
              organization_positions!inner(
                group_designation_id,
                organization_group_designations!inner(
                  group_type,
                  group_id,
                  id
                )
              )
            ''')
            .eq('is_active', true)
            .eq('organization_positions.organization_group_designations.group_type', permission.groupType)
            .eq('organization_positions.organization_group_designations.group_id', permission.groupId);

        if (permission.designationId != null) {
          userQuery.eq('organization_positions.organization_group_designations.id', permission.designationId);
        }

        final response = await userQuery;

        if (response.error == null) {
          final userIds = (response.data as List<dynamic>)
              .map((row) => row['user_id'] as String)
              .toList();
          
          eligibleUsers.addAll(userIds);
        }
      }
    }

    return eligibleUsers.toSet().toList();
  }

  Future<void> invalidateUserPermissions(String userId) async {
    await _cache.invalidateUserPermissions(userId);
  }

  Future<void> invalidateWorkflowPermissions(String workflowId) async {
    await _cache.invalidatePattern('*:$workflowId:*');
  }
}

class PermissionMatchResult {
  final bool matches;
  final String matchType;
  final Map<String, dynamic> conditionResults;

  PermissionMatchResult({
    required this.matches,
    required this.matchType,
    required this.conditionResults,
  });
}

class PermissionError implements Exception {
  final String message;
  PermissionError(this.message);
  
  @override
  String toString() => 'PermissionError: $message';
}