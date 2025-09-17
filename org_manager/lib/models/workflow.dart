enum WorkflowStatus { draft, active, paused, completed }

enum TaskStatus { pending, inProgress, completed, cancelled }

class WorkflowTask {
  final String id;
  final String name;
  final String description;
  final String assignedTo;
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
    );
  }
}

class Workflow {
  final String id;
  final String name;
  final String description;
  final String organizationId;
  final String createdBy;
  final WorkflowStatus status;
  final List<WorkflowTask> tasks;
  final DateTime createdAt;
  final DateTime updatedAt;

  Workflow({
    required this.id,
    required this.name,
    required this.description,
    required this.organizationId,
    required this.createdBy,
    required this.status,
    required this.tasks,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Workflow.fromJson(Map<String, dynamic> json) {
    return Workflow(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      organizationId: json['organizationId'],
      createdBy: json['createdBy'],
      status: WorkflowStatus.values.firstWhere((e) => e.toString() == 'WorkflowStatus.${json['status']}'),
      tasks: (json['tasks'] as List<dynamic>?)?.map((taskJson) => WorkflowTask.fromJson(taskJson)).toList() ?? [],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'organizationId': organizationId,
      'createdBy': createdBy,
      'status': status.toString().split('.').last,
      'tasks': tasks.map((task) => task.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Workflow copyWith({
    String? id,
    String? name,
    String? description,
    String? organizationId,
    String? createdBy,
    WorkflowStatus? status,
    List<WorkflowTask>? tasks,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Workflow(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      organizationId: organizationId ?? this.organizationId,
      createdBy: createdBy ?? this.createdBy,
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}