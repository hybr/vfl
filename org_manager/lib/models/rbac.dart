enum GroupType { department, team }

enum AssignmentType { primary, secondary, temporary }

class OrganizationBranch {
  final String id;
  final String organizationId;
  final String name;
  final String code;
  final String? address;
  final bool isActive;
  final DateTime createdAt;

  OrganizationBranch({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    this.address,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationBranch.fromJson(Map<String, dynamic> json) {
    return OrganizationBranch(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      code: json['code'],
      address: json['address'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'code': code,
      'address': address,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrganizationBuilding {
  final String id;
  final String branchId;
  final String name;
  final String code;
  final String? address;
  final int? floors;
  final bool isActive;
  final DateTime createdAt;

  OrganizationBuilding({
    required this.id,
    required this.branchId,
    required this.name,
    required this.code,
    this.address,
    this.floors,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationBuilding.fromJson(Map<String, dynamic> json) {
    return OrganizationBuilding(
      id: json['id'],
      branchId: json['branch_id'],
      name: json['name'],
      code: json['code'],
      address: json['address'],
      floors: json['floors'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'name': name,
      'code': code,
      'address': address,
      'floors': floors,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrganizationWorkerSeat {
  final String id;
  final String buildingId;
  final String seatNumber;
  final int? floor;
  final String? section;
  final bool isOccupied;
  final bool isActive;
  final DateTime createdAt;

  OrganizationWorkerSeat({
    required this.id,
    required this.buildingId,
    required this.seatNumber,
    this.floor,
    this.section,
    this.isOccupied = false,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationWorkerSeat.fromJson(Map<String, dynamic> json) {
    return OrganizationWorkerSeat(
      id: json['id'],
      buildingId: json['building_id'],
      seatNumber: json['seat_number'],
      floor: json['floor'],
      section: json['section'],
      isOccupied: json['is_occupied'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'building_id': buildingId,
      'seat_number': seatNumber,
      'floor': floor,
      'section': section,
      'is_occupied': isOccupied,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrganizationDepartment {
  final String id;
  final String organizationId;
  final String name;
  final String code;
  final String? description;
  final String? parentDepartmentId;
  final String? headUserId;
  final bool isActive;
  final DateTime createdAt;

  OrganizationDepartment({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    this.description,
    this.parentDepartmentId,
    this.headUserId,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationDepartment.fromJson(Map<String, dynamic> json) {
    return OrganizationDepartment(
      id: json['id'],
      organizationId: json['organization_id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      parentDepartmentId: json['parent_department_id'],
      headUserId: json['head_user_id'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'name': name,
      'code': code,
      'description': description,
      'parent_department_id': parentDepartmentId,
      'head_user_id': headUserId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrganizationTeam {
  final String id;
  final String departmentId;
  final String name;
  final String code;
  final String? description;
  final String? teamLeadUserId;
  final bool isActive;
  final DateTime createdAt;

  OrganizationTeam({
    required this.id,
    required this.departmentId,
    required this.name,
    required this.code,
    this.description,
    this.teamLeadUserId,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationTeam.fromJson(Map<String, dynamic> json) {
    return OrganizationTeam(
      id: json['id'],
      departmentId: json['department_id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      teamLeadUserId: json['team_lead_user_id'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'department_id': departmentId,
      'name': name,
      'code': code,
      'description': description,
      'team_lead_user_id': teamLeadUserId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrganizationGroupDesignation {
  final String id;
  final GroupType groupType;
  final String groupId;
  final String designationName;
  final String designationCode;
  final int? jobLevel;
  final String? salaryGrade;
  final String? responsibilities;
  final String? requirements;
  final bool isActive;
  final DateTime createdAt;

  OrganizationGroupDesignation({
    required this.id,
    required this.groupType,
    required this.groupId,
    required this.designationName,
    required this.designationCode,
    this.jobLevel,
    this.salaryGrade,
    this.responsibilities,
    this.requirements,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationGroupDesignation.fromJson(Map<String, dynamic> json) {
    return OrganizationGroupDesignation(
      id: json['id'],
      groupType: GroupType.values.firstWhere(
        (e) => e.toString().split('.').last == json['group_type']
      ),
      groupId: json['group_id'],
      designationName: json['designation_name'],
      designationCode: json['designation_code'],
      jobLevel: json['job_level'],
      salaryGrade: json['salary_grade'],
      responsibilities: json['responsibilities'],
      requirements: json['requirements'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_type': groupType.toString().split('.').last,
      'group_id': groupId,
      'designation_name': designationName,
      'designation_code': designationCode,
      'job_level': jobLevel,
      'salary_grade': salaryGrade,
      'responsibilities': responsibilities,
      'requirements': requirements,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrganizationPosition {
  final String id;
  final String groupDesignationId;
  final String workerSeatId;
  final String positionTitle;
  final bool isFilled;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;

  OrganizationPosition({
    required this.id,
    required this.groupDesignationId,
    required this.workerSeatId,
    required this.positionTitle,
    this.isFilled = false,
    this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
  });

  factory OrganizationPosition.fromJson(Map<String, dynamic> json) {
    return OrganizationPosition(
      id: json['id'],
      groupDesignationId: json['group_designation_id'],
      workerSeatId: json['worker_seat_id'],
      positionTitle: json['position_title'],
      isFilled: json['is_filled'] ?? false,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_designation_id': groupDesignationId,
      'worker_seat_id': workerSeatId,
      'position_title': positionTitle,
      'is_filled': isFilled,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class UserPositionAssignment {
  final String id;
  final String userId;
  final String positionId;
  final AssignmentType assignmentType;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final String? assignedBy;

  UserPositionAssignment({
    required this.id,
    required this.userId,
    required this.positionId,
    this.assignmentType = AssignmentType.primary,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.createdAt,
    this.assignedBy,
  });

  factory UserPositionAssignment.fromJson(Map<String, dynamic> json) {
    return UserPositionAssignment(
      id: json['id'],
      userId: json['user_id'],
      positionId: json['position_id'],
      assignmentType: AssignmentType.values.firstWhere(
        (e) => e.toString().split('.').last == json['assignment_type']
      ),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      assignedBy: json['assigned_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'position_id': positionId,
      'assignment_type': assignmentType.toString().split('.').last,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'assigned_by': assignedBy,
    };
  }
}

class PermissionCheckResult {
  final bool hasPermission;
  final List<Map<String, dynamic>> matchedPermissions;
  final List<String> reasons;
  final List<UserPositionContext> userPositions;
  final Map<String, dynamic>? contextualChecks;

  PermissionCheckResult({
    required this.hasPermission,
    required this.matchedPermissions,
    required this.reasons,
    required this.userPositions,
    this.contextualChecks,
  });

  factory PermissionCheckResult.fromJson(Map<String, dynamic> json) {
    return PermissionCheckResult(
      hasPermission: json['has_permission'],
      matchedPermissions: List<Map<String, dynamic>>.from(json['matched_permissions'] ?? []),
      reasons: List<String>.from(json['reasons'] ?? []),
      userPositions: (json['user_positions'] as List<dynamic>?)
          ?.map((pos) => UserPositionContext.fromJson(pos))
          .toList() ?? [],
      contextualChecks: json['contextual_checks'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'has_permission': hasPermission,
      'matched_permissions': matchedPermissions,
      'reasons': reasons,
      'user_positions': userPositions.map((pos) => pos.toJson()).toList(),
      'contextual_checks': contextualChecks,
    };
  }
}

class UserPositionContext {
  final String assignmentId;
  final AssignmentType assignmentType;
  final String positionId;
  final String positionTitle;
  final String designationId;
  final String designationName;
  final String designationCode;
  final GroupType groupType;
  final String groupId;
  final int? jobLevel;
  final String? departmentName;
  final String? departmentCode;
  final String? teamName;
  final String? teamCode;
  final String? parentDepartmentName;
  final String seatNumber;
  final String buildingName;
  final String branchName;
  final String organizationName;

  UserPositionContext({
    required this.assignmentId,
    required this.assignmentType,
    required this.positionId,
    required this.positionTitle,
    required this.designationId,
    required this.designationName,
    required this.designationCode,
    required this.groupType,
    required this.groupId,
    this.jobLevel,
    this.departmentName,
    this.departmentCode,
    this.teamName,
    this.teamCode,
    this.parentDepartmentName,
    required this.seatNumber,
    required this.buildingName,
    required this.branchName,
    required this.organizationName,
  });

  factory UserPositionContext.fromJson(Map<String, dynamic> json) {
    return UserPositionContext(
      assignmentId: json['assignment_id'],
      assignmentType: AssignmentType.values.firstWhere(
        (e) => e.toString().split('.').last == json['assignment_type']
      ),
      positionId: json['position_id'],
      positionTitle: json['position_title'],
      designationId: json['designation_id'],
      designationName: json['designation_name'],
      designationCode: json['designation_code'],
      groupType: GroupType.values.firstWhere(
        (e) => e.toString().split('.').last == json['group_type']
      ),
      groupId: json['group_id'],
      jobLevel: json['job_level'],
      departmentName: json['department_name'],
      departmentCode: json['department_code'],
      teamName: json['team_name'],
      teamCode: json['team_code'],
      parentDepartmentName: json['parent_department_name'],
      seatNumber: json['seat_number'],
      buildingName: json['building_name'],
      branchName: json['branch_name'],
      organizationName: json['organization_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'assignment_id': assignmentId,
      'assignment_type': assignmentType.toString().split('.').last,
      'position_id': positionId,
      'position_title': positionTitle,
      'designation_id': designationId,
      'designation_name': designationName,
      'designation_code': designationCode,
      'group_type': groupType.toString().split('.').last,
      'group_id': groupId,
      'job_level': jobLevel,
      'department_name': departmentName,
      'department_code': departmentCode,
      'team_name': teamName,
      'team_code': teamCode,
      'parent_department_name': parentDepartmentName,
      'seat_number': seatNumber,
      'building_name': buildingName,
      'branch_name': branchName,
      'organization_name': organizationName,
    };
  }
}

class AuditLogEntry {
  final String id;
  final String eventType;
  final String? userId;
  final String? resourceType;
  final String? resourceId;
  final String? action;
  final String? result;
  final String? details;
  final String? workflowInstanceId;
  final String? ipAddress;
  final String? userAgent;
  final String? sessionId;
  final DateTime timestamp;

  AuditLogEntry({
    required this.id,
    required this.eventType,
    this.userId,
    this.resourceType,
    this.resourceId,
    this.action,
    this.result,
    this.details,
    this.workflowInstanceId,
    this.ipAddress,
    this.userAgent,
    this.sessionId,
    required this.timestamp,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id'],
      eventType: json['event_type'],
      userId: json['user_id'],
      resourceType: json['resource_type'],
      resourceId: json['resource_id'],
      action: json['action'],
      result: json['result'],
      details: json['details'],
      workflowInstanceId: json['workflow_instance_id'],
      ipAddress: json['ip_address'],
      userAgent: json['user_agent'],
      sessionId: json['session_id'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': eventType,
      'user_id': userId,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'action': action,
      'result': result,
      'details': details,
      'workflow_instance_id': workflowInstanceId,
      'ip_address': ipAddress,
      'user_agent': userAgent,
      'session_id': sessionId,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}