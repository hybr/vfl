import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/workflow.dart';
import '../services/supabase_service.dart';

class WorkflowProvider with ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  List<Workflow> _workflows = [];
  bool _isLoading = false;

  List<Workflow> get workflows => _workflows;
  bool get isLoading => _isLoading;

  List<Workflow> getWorkflowsByOrganization(String organizationId) {
    return _workflows.where((workflow) => workflow.organizationId == organizationId).toList();
  }

  List<Workflow> getActiveWorkflows(String organizationId) {
    return getWorkflowsByOrganization(organizationId)
        .where((workflow) => workflow.status == WorkflowStatus.active)
        .toList();
  }

  Future<void> loadWorkflows() async {
    _isLoading = true;
    notifyListeners();

    try {
      _workflows = await _supabaseService.getWorkflows();
    } catch (e) {
      print('Error loading workflows: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createWorkflow({
    required String name,
    required String description,
    required String organizationId,
    required String createdBy,
    List<WorkflowTask>? tasks,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final uuid = const Uuid();
      final now = DateTime.now();

      final workflow = Workflow(
        id: uuid.v4(),
        name: name,
        description: description,
        organizationId: organizationId,
        createdBy: createdBy,
        status: WorkflowStatus.draft,
        tasks: tasks ?? [],
        createdAt: now,
        updatedAt: now,
      );

      await _supabaseService.createWorkflow(workflow);
      _workflows.add(workflow);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWorkflow(Workflow workflow) async {
    _isLoading = true;
    notifyListeners();

    try {
      final updatedWorkflow = workflow.copyWith(updatedAt: DateTime.now());

      await _supabaseService.updateWorkflow(updatedWorkflow);

      final index = _workflows.indexWhere((w) => w.id == workflow.id);
      if (index != -1) {
        _workflows[index] = updatedWorkflow;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateWorkflowStatus(String workflowId, WorkflowStatus newStatus) async {
    try {
      final workflowIndex = _workflows.indexWhere((workflow) => workflow.id == workflowId);
      if (workflowIndex != -1) {
        final updatedWorkflow = _workflows[workflowIndex].copyWith(status: newStatus);
        return await updateWorkflow(updatedWorkflow);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addTask({
    required String workflowId,
    required String name,
    required String description,
    required String assignedTo,
    DateTime? dueDate,
  }) async {
    try {
      final workflowIndex = _workflows.indexWhere((workflow) => workflow.id == workflowId);
      if (workflowIndex != -1) {
        final uuid = const Uuid();
        final now = DateTime.now();

        final newTask = WorkflowTask(
          id: uuid.v4(),
          name: name,
          description: description,
          assignedTo: assignedTo,
          status: TaskStatus.pending,
          dueDate: dueDate,
          createdAt: now,
          updatedAt: now,
        );

        final workflow = _workflows[workflowIndex];
        final updatedTasks = [...workflow.tasks, newTask];
        final updatedWorkflow = workflow.copyWith(tasks: updatedTasks);

        return await updateWorkflow(updatedWorkflow);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateTaskStatus(String workflowId, String taskId, TaskStatus newStatus) async {
    try {
      final workflowIndex = _workflows.indexWhere((workflow) => workflow.id == workflowId);
      if (workflowIndex != -1) {
        final workflow = _workflows[workflowIndex];
        final taskIndex = workflow.tasks.indexWhere((task) => task.id == taskId);

        if (taskIndex != -1) {
          final updatedTask = workflow.tasks[taskIndex].copyWith(
            status: newStatus,
            updatedAt: DateTime.now(),
          );

          final updatedTasks = [...workflow.tasks];
          updatedTasks[taskIndex] = updatedTask;

          final updatedWorkflow = workflow.copyWith(tasks: updatedTasks);
          return await updateWorkflow(updatedWorkflow);
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteWorkflow(String workflowId) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.deleteWorkflow(workflowId);

      _workflows.removeWhere((workflow) => workflow.id == workflowId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Workflow? getWorkflowById(String workflowId) {
    try {
      return _workflows.firstWhere((workflow) => workflow.id == workflowId);
    } catch (e) {
      return null;
    }
  }

  List<WorkflowTask> getTasksAssignedToUser(String userId) {
    final List<WorkflowTask> assignedTasks = [];
    for (final workflow in _workflows) {
      for (final task in workflow.tasks) {
        if (task.assignedTo == userId) {
          assignedTasks.add(task);
        }
      }
    }
    return assignedTasks;
  }

  List<WorkflowTask> getPendingTasks(String organizationId) {
    final List<WorkflowTask> pendingTasks = [];
    final orgWorkflows = getWorkflowsByOrganization(organizationId);
    for (final workflow in orgWorkflows) {
      for (final task in workflow.tasks) {
        if (task.status == TaskStatus.pending) {
          pendingTasks.add(task);
        }
      }
    }
    return pendingTasks;
  }
}