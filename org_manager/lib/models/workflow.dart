enum WorkflowStatus { draft, active, paused, completed, cancelled }

enum TaskStatus { pending, inProgress, completed, cancelled }

enum PermissionType { required, optional, forbidden }

enum AssignmentType { primary, secondary, temporary }

class WorkflowActor {
  final String id;
  final String name;
  final String description;
  final Map<String, dynamic> capabilities;
  final bool isActive;

  WorkflowActor({
    required this.id,
    required this.name,
    required this.description,
    required this.capabilities,
    this.isActive = true,
  });

  factory WorkflowActor.fromJson(Map<String, dynamic> json) {
    return WorkflowActor(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      capabilities: Map<String, dynamic>.from(json['capabilities'] ?? {}),
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'capabilities': capabilities,
      'is_active': isActive,
    };
  }
}

class WorkflowPermission {
  final String id;
  final String workflowStepId;
  final String actorId;
  final String groupType;
  final String groupId;
  final String? designationId;
  final PermissionType permissionType;
  final Map<String, dynamic> conditions;
  final bool isActive;
  final DateTime createdAt;

  WorkflowPermission({
    required this.id,
    required this.workflowStepId,
    required this.actorId,
    required this.groupType,
    required this.groupId,
    this.designationId,
    required this.permissionType,
    required this.conditions,
    this.isActive = true,
    required this.createdAt,
  });

  factory WorkflowPermission.fromJson(Map<String, dynamic> json) {
    return WorkflowPermission(
      id: json['id'],
      workflowStepId: json['workflow_step_id'],
      actorId: json['actor_id'],
      groupType: json['group_type'],
      groupId: json['group_id'],
      designationId: json['designation_id'],
      permissionType: PermissionType.values.firstWhere(
        (e) => e.toString().split('.').last == json['permission_type']
      ),
      conditions: Map<String, dynamic>.from(json['conditions'] ?? {}),
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflow_step_id': workflowStepId,
      'actor_id': actorId,
      'group_type': groupType,
      'group_id': groupId,
      'designation_id': designationId,
      'permission_type': permissionType.toString().split('.').last,
      'conditions': conditions,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class WorkflowStep {
  final String id;
  final String workflowId;
  final String stepName;
  final int stepOrder;
  final String stepType;
  final List<String> requiredActors;
  final List<String> optionalActors;
  final Map<String, dynamic> stepConditions;
  final int? timeoutHours;
  final bool isParallel;
  final bool isActive;
  final DateTime createdAt;

  WorkflowStep({
    required this.id,
    required this.workflowId,
    required this.stepName,
    required this.stepOrder,
    required this.stepType,
    required this.requiredActors,
    required this.optionalActors,
    required this.stepConditions,
    this.timeoutHours,
    this.isParallel = false,
    this.isActive = true,
    required this.createdAt,
  });

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    return WorkflowStep(
      id: json['id'],
      workflowId: json['workflow_id'],
      stepName: json['step_name'],
      stepOrder: json['step_order'],
      stepType: json['step_type'],
      requiredActors: List<String>.from(json['required_actors'] ?? []),
      optionalActors: List<String>.from(json['optional_actors'] ?? []),
      stepConditions: Map<String, dynamic>.from(json['step_conditions'] ?? {}),
      timeoutHours: json['timeout_hours'],
      isParallel: json['is_parallel'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflow_id': workflowId,
      'step_name': stepName,
      'step_order': stepOrder,
      'step_type': stepType,
      'required_actors': requiredActors,
      'optional_actors': optionalActors,
      'step_conditions': stepConditions,
      'timeout_hours': timeoutHours,
      'is_parallel': isParallel,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class WorkflowTask {
  final String id;
  final String name;
  final String description;
  final String assignedTo;
  final String? workflowInstanceId;
  final String? actorRole;
  final Map<String, dynamic> permissionContext;
  final TaskStatus status;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkflowTask({
    required this.id,
    required this.name,
    required this.description,
    required this.assignedTo,
    required this.status,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.workflowInstanceId,
    this.actorRole,
    this.permissionContext = const {},
  });

  factory WorkflowTask.fromJson(Map<String, dynamic> json) {
    return WorkflowTask(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      assignedTo: json['assignedTo'],
      status: TaskStatus.values.firstWhere((e) => e.toString() == 'TaskStatus.${json['status']}'),
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      workflowInstanceId: json['workflowInstanceId'],
      actorRole: json['actorRole'],
      permissionContext: Map<String, dynamic>.from(json['permissionContext'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'assignedTo': assignedTo,
      'status': status.toString().split('.').last,
      'dueDate': dueDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'workflowInstanceId': workflowInstanceId,
      'actorRole': actorRole,
      'permissionContext': permissionContext,
    };
  }

  WorkflowTask copyWith({
    String? id,
    String? name,
    String? description,
    String? assignedTo,
    TaskStatus? status,
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? workflowInstanceId,
    String? actorRole,
    Map<String, dynamic>? permissionContext,
  }) {
    return WorkflowTask(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      workflowInstanceId: workflowInstanceId ?? this.workflowInstanceId,
      actorRole: actorRole ?? this.actorRole,
      permissionContext: permissionContext ?? this.permissionContext,
    );
  }
}

class WorkflowInstance {
  final String id;
  final String workflowId;
  final String currentState;
  final Map<String, dynamic> contextData;
  final String initiatorUserId;
  final String organizationId;
  final WorkflowStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkflowInstance({
    required this.id,
    required this.workflowId,
    required this.currentState,
    required this.contextData,
    required this.initiatorUserId,
    required this.organizationId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkflowInstance.fromJson(Map<String, dynamic> json) {
    return WorkflowInstance(
      id: json['id'],
      workflowId: json['workflow_id'],
      currentState: json['current_state'],
      contextData: Map<String, dynamic>.from(json['context_data'] ?? {}),
      initiatorUserId: json['initiator_user_id'],
      organizationId: json['organization_id'],
      status: WorkflowStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status']
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'workflow_id': workflowId,
      'current_state': currentState,
      'context_data': contextData,
      'initiator_user_id': initiatorUserId,
      'organization_id': organizationId,
      'status': status.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WorkflowInstance copyWith({
    String? id,
    String? workflowId,
    String? currentState,
    Map<String, dynamic>? contextData,
    String? initiatorUserId,
    String? organizationId,
    WorkflowStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkflowInstance(
      id: id ?? this.id,
      workflowId: workflowId ?? this.workflowId,
      currentState: currentState ?? this.currentState,
      contextData: contextData ?? this.contextData,
      initiatorUserId: initiatorUserId ?? this.initiatorUserId,
      organizationId: organizationId ?? this.organizationId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Workflow {
  final String id;
  final String name;
  final String description;
  final int version;
  final bool isActive;
  final String? createdBy;
  final Map<String, dynamic> workflowDefinition;
  final bool rbacEnabled;
  final List<WorkflowStep> steps;
  final DateTime createdAt;

  Workflow({
    required this.id,
    required this.name,
    required this.description,
    this.version = 1,
    this.isActive = true,
    this.createdBy,
    required this.workflowDefinition,
    this.rbacEnabled = true,
    required this.steps,
    required this.createdAt,
  });

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      version: json['version'] ?? 1,
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      workflowDefinition: Map<String, dynamic>.from(json['workflow_definition'] ?? {}),
      rbacEnabled: json['rbac_enabled'] ?? true,
      steps: (json['steps'] as List<dynamic>?)?.map((stepJson) => WorkflowStep.fromJson(stepJson)).toList() ?? [],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'version': version,
      'is_active': isActive,
      'created_by': createdBy,
      'workflow_definition': workflowDefinition,
      'rbac_enabled': rbacEnabled,
      'steps': steps.map((step) => step.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Workflow copyWith({
    String? id,
    String? name,
    String? description,
    int? version,
    bool? isActive,
    String? createdBy,
    Map<String, dynamic>? workflowDefinition,
    bool? rbacEnabled,
    List<WorkflowStep>? steps,
    DateTime? createdAt,
  }) {
    return Workflow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      createdBy: createdBy ?? this.createdBy,
      workflowDefinition: workflowDefinition ?? this.workflowDefinition,
      rbacEnabled: rbacEnabled ?? this.rbacEnabled,
      steps: steps ?? this.steps,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}