import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workflow.dart';
import '../models/rbac.dart';
import '../services/workflow_api_service.dart';
import '../services/rbac_permission_resolver.dart';
import '../services/cache_service.dart';
import '../services/event_bus.dart';
import '../services/audit_service.dart';
import '../core/workflow_engine.dart';

class EnhancedWorkflowProvider with ChangeNotifier {
  final WorkflowApiService _apiService;
  final WorkflowEngine _workflowEngine;
  final RBACPermissionResolver _rbacResolver;
  final EventBus _eventBus;
  final AuditService _auditService;

  List<Workflow> _workflows = [];
  List<WorkflowInstance> _workflowInstances = [];
  List<WorkflowTask> _tasks = [];
  List<WorkflowAction> _availableActions = [];
  List<WorkflowHistoryEntry> _workflowHistory = [];
  bool _isLoading = false;
  String? _error;

  EnhancedWorkflowProvider({
    required SupabaseClient supabase,
  }) : _apiService = WorkflowApiService(supabase: supabase),
       _eventBus = EventBus(),
       _rbacResolver = RBACPermissionResolver(
         supabase: supabase,
         cache: MemoryCacheService(),
       ),
       _auditService = AuditService(
         supabase: supabase,
         eventBus: EventBus(),
       ),
       _workflowEngine = WorkflowEngine(
         supabase: supabase,
         rbacResolver: RBACPermissionResolver(
           supabase: supabase,
           cache: MemoryCacheService(),
         ),
         eventBus: EventBus(),
         auditService: AuditService(
           supabase: supabase,
           eventBus: EventBus(),
         ),
       ) {
    _setupEventListeners();
  }

  List<Workflow> get workflows => _workflows;
  List<WorkflowInstance> get workflowInstances => _workflowInstances;
  List<WorkflowTask> get tasks => _tasks;
  List<WorkflowAction> get availableActions => _availableActions;
  List<WorkflowHistoryEntry> get workflowHistory => _workflowHistory;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setupEventListeners() {
    _eventBus.on('workflow.instance.created', (data) {
      _loadWorkflowInstances();
    });

    _eventBus.on('workflow.transition.completed', (data) {
      _loadWorkflowInstances();
      _loadAvailableActions(data['instanceId']);
    });

    _eventBus.on('workflow.permission.denied', (data) {
      _error = 'Permission denied: ${data['reasons']?.join(', ') ?? 'Access denied'}';
      notifyListeners();
    });
  }

  Future<void> loadWorkflows() async {
    _setLoading(true);
    try {
      _workflows = await _apiService.getWorkflows();
      _clearError();
    } catch (e) {
      _setError('Failed to load workflows: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadWorkflowInstances({
    String? organizationId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      _workflowInstances = await _apiService.getWorkflowInstances(
        organizationId: organizationId,
        status: status,
        limit: limit,
        offset: offset,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load workflow instances: $e');
    }
  }

  Future<WorkflowInstance> createWorkflowInstance({
    required String workflowId,
    required String organizationId,
    Map<String, dynamic> initialContext = const {},
  }) async {
    _setLoading(true);
    try {
      final instance = await _apiService.createWorkflowInstance(
        workflowId: workflowId,
        organizationId: organizationId,
        initialContext: initialContext,
      );
      
      _workflowInstances.insert(0, instance);
      _clearError();
      notifyListeners();
      
      return instance;
    } catch (e) {
      _setError('Failed to create workflow instance: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> transitionWorkflow({
    required String instanceId,
    required String targetState,
    required String actorRole,
    Map<String, dynamic> context = const {},
    String? reason,
  }) async {
    _setLoading(true);
    try {
      await _apiService.transitionWorkflow(
        instanceId: instanceId,
        targetState: targetState,
        actorRole: actorRole,
        context: context,
        reason: reason,
      );

      // Update the instance in the list
      final instanceIndex = _workflowInstances.indexWhere((i) => i.id == instanceId);
      if (instanceIndex != -1) {
        final updatedInstance = await _apiService.getWorkflowInstance(instanceId);
        if (updatedInstance != null) {
          _workflowInstances[instanceIndex] = updatedInstance;
        }
      }

      _clearError();
      notifyListeners();
    } catch (e) {
      if (e is PermissionDeniedException) {
        _setError('Permission denied: ${e.reasons.join(', ')}');
      } else {
        _setError('Failed to transition workflow: $e');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<PermissionCheckResult> checkPermission({
    required String workflowStepId,
    required String actorRole,
    Map<String, dynamic> context = const {},
  }) async {
    try {
      return await _apiService.checkPermission(
        workflowStepId: workflowStepId,
        actorRole: actorRole,
        context: context,
      );
    } catch (e) {
      _setError('Failed to check permission: $e');
      rethrow;
    }
  }

  Future<void> _loadAvailableActions(String instanceId) async {
    try {
      _availableActions = await _apiService.getAvailableActions(
        instanceId: instanceId,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load available actions: $e');
    }
  }

  Future<void> loadAvailableActionsForUser(String instanceId) async {
    _setLoading(true);
    try {
      _availableActions = await _apiService.getAvailableActions(
        instanceId: instanceId,
      );
      _clearError();
    } catch (e) {
      _setError('Failed to load available actions: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadWorkflowHistory(String instanceId) async {
    _setLoading(true);
    try {
      _workflowHistory = await _apiService.getWorkflowHistory(instanceId);
      _clearError();
    } catch (e) {
      _setError('Failed to load workflow history: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<WorkflowInstance?> getWorkflowInstance(String instanceId) async {
    try {
      return await _apiService.getWorkflowInstance(instanceId);
    } catch (e) {
      _setError('Failed to get workflow instance: $e');
      return null;
    }
  }

  Future<void> pauseWorkflowInstance(String instanceId) async {
    _setLoading(true);
    try {
      await _apiService.pauseWorkflowInstance(instanceId);
      await _updateInstanceInList(instanceId);
      _clearError();
    } catch (e) {
      _setError('Failed to pause workflow instance: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resumeWorkflowInstance(String instanceId) async {
    _setLoading(true);
    try {
      await _apiService.resumeWorkflowInstance(instanceId);
      await _updateInstanceInList(instanceId);
      _clearError();
    } catch (e) {
      _setError('Failed to resume workflow instance: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cancelWorkflowInstance(String instanceId) async {
    _setLoading(true);
    try {
      await _apiService.cancelWorkflowInstance(instanceId);
      await _updateInstanceInList(instanceId);
      _clearError();
    } catch (e) {
      _setError('Failed to cancel workflow instance: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _updateInstanceInList(String instanceId) async {
    final instanceIndex = _workflowInstances.indexWhere((i) => i.id == instanceId);
    if (instanceIndex != -1) {
      final updatedInstance = await _apiService.getWorkflowInstance(instanceId);
      if (updatedInstance != null) {
        _workflowInstances[instanceIndex] = updatedInstance;
        notifyListeners();
      }
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  Future<void> updateTaskStatus(String taskId, TaskStatus status) async {
    _setLoading(true);
    try {
      // This would typically involve updating through the workflow engine
      // For now, we'll update the local state
      final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
      if (taskIndex != -1) {
        _tasks[taskIndex] = _tasks[taskIndex].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
      _clearError();
    } catch (e) {
      _setError('Failed to update task status: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Filtered getters for different workflow states
  List<WorkflowInstance> get activeWorkflowInstances => 
      _workflowInstances.where((w) => w.status == WorkflowStatus.active).toList();

  List<WorkflowInstance> get completedWorkflowInstances => 
      _workflowInstances.where((w) => w.status == WorkflowStatus.completed).toList();

  List<WorkflowInstance> get pausedWorkflowInstances => 
      _workflowInstances.where((w) => w.status == WorkflowStatus.paused).toList();

  List<WorkflowTask> get pendingTasks => 
      _tasks.where((task) => task.status == TaskStatus.pending).toList();

  List<WorkflowTask> get inProgressTasks => 
      _tasks.where((task) => task.status == TaskStatus.inProgress).toList();

  List<WorkflowTask> get completedTasks => 
      _tasks.where((task) => task.status == TaskStatus.completed).toList();

  // Helper methods for workflow management
  bool canUserPerformAction(String actorRole) {
    return _availableActions.any((action) => action.actorRole == actorRole);
  }

  List<WorkflowAction> getActionsForRole(String actorRole) {
    return _availableActions.where((action) => action.actorRole == actorRole).toList();
  }

  WorkflowInstance? getInstanceById(String instanceId) {
    try {
      return _workflowInstances.firstWhere((instance) => instance.id == instanceId);
    } catch (e) {
      return null;
    }
  }

  Workflow? getWorkflowById(String workflowId) {
    try {
      return _workflows.firstWhere((workflow) => workflow.id == workflowId);
    } catch (e) {
      return null;
    }
  }

  // Refresh methods
  Future<void> refreshWorkflows() async {
    await loadWorkflows();
  }

  Future<void> refreshWorkflowInstances({
    String? organizationId,
    String? status,
  }) async {
    await _loadWorkflowInstances(
      organizationId: organizationId,
      status: status,
    );
  }

  Future<void> refreshInstance(String instanceId) async {
    await _updateInstanceInList(instanceId);
  }

  // Statistics and metrics
  Map<String, int> getWorkflowStatistics() {
    return {
      'total': _workflowInstances.length,
      'active': activeWorkflowInstances.length,
      'completed': completedWorkflowInstances.length,
      'paused': pausedWorkflowInstances.length,
      'cancelled': _workflowInstances.where((w) => w.status == WorkflowStatus.cancelled).length,
    };
  }

  Map<String, int> getTaskStatistics() {
    return {
      'total': _tasks.length,
      'pending': pendingTasks.length,
      'inProgress': inProgressTasks.length,
      'completed': completedTasks.length,
      'cancelled': _tasks.where((t) => t.status == TaskStatus.cancelled).length,
    };
  }

  @override
  void dispose() {
    _eventBus.dispose();
    super.dispose();
  }
}