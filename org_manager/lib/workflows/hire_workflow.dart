import '../core/base_workflow.dart';
import '../services/rbac_permission_resolver.dart';
import '../services/audit_service.dart';
import '../services/event_bus.dart';

class HireWorkflow extends BaseWorkflow {
  HireWorkflow({
    required String id,
    required EventBus eventBus,
    required RBACPermissionResolver rbacResolver,
    required AuditService auditService,
  }) : super(
          id: id,
          name: 'Employee Hiring Workflow',
          eventBus: eventBus,
          rbacResolver: rbacResolver,
          auditService: auditService,
        ) {
    _initializeStates();
  }

  void _initializeStates() {
    addState('requisition_created', StateNode(
      id: 'req_created_$id',
      name: 'Requisition Created',
      transitions: ['requisition_reviewed'],
      requiredActors: ['requestor'],
      onEnter: _onRequisitionCreated,
      validations: [_validateRequisitionData],
    ));

    addState('requisition_reviewed', StateNode(
      id: 'req_reviewed_$id',
      name: 'Requisition Reviewed',
      transitions: ['requisition_approved', 'requisition_rejected'],
      requiredActors: ['analyzer'],
      onEnter: _onRequisitionReviewed,
      validations: [_validateRequisitionReview],
    ));

    addState('requisition_approved', StateNode(
      id: 'req_approved_$id',
      name: 'Requisition Approved',
      transitions: ['job_posted'],
      requiredActors: ['approver'],
      onEnter: _onRequisitionApproved,
      validations: [_validateApprovalAuthority],
    ));

    addState('requisition_rejected', StateNode(
      id: 'req_rejected_$id',
      name: 'Requisition Rejected',
      transitions: [],
      requiredActors: ['approver'],
      onEnter: _onRequisitionRejected,
    ));

    addState('job_posted', StateNode(
      id: 'job_posted_$id',
      name: 'Job Posted',
      transitions: ['applications_received'],
      requiredActors: ['requestor'],
      onEnter: _onJobPosted,
    ));

    addState('applications_received', StateNode(
      id: 'apps_received_$id',
      name: 'Applications Received',
      transitions: ['screening_completed'],
      requiredActors: ['analyzer'],
      onEnter: _onApplicationsReceived,
      validations: [_validateMinimumApplications],
    ));

    addState('screening_completed', StateNode(
      id: 'screening_done_$id',
      name: 'Screening Completed',
      transitions: ['interviews_scheduled'],
      requiredActors: ['analyzer'],
      onEnter: _onScreeningCompleted,
      validations: [_validateScreeningResults],
    ));

    addState('interviews_scheduled', StateNode(
      id: 'interviews_scheduled_$id',
      name: 'Interviews Scheduled',
      transitions: ['interviews_completed'],
      requiredActors: ['requestor'],
      onEnter: _onInterviewsScheduled,
    ));

    addState('interviews_completed', StateNode(
      id: 'interviews_done_$id',
      name: 'Interviews Completed',
      transitions: ['candidate_selected', 'no_suitable_candidate'],
      requiredActors: ['approver'],
      onEnter: _onInterviewsCompleted,
      validations: [_validateInterviewResults],
    ));

    addState('candidate_selected', StateNode(
      id: 'candidate_selected_$id',
      name: 'Candidate Selected',
      transitions: ['offer_extended'],
      requiredActors: ['approver'],
      onEnter: _onCandidateSelected,
      validations: [_validateCandidateSelection],
    ));

    addState('no_suitable_candidate', StateNode(
      id: 'no_candidate_$id',
      name: 'No Suitable Candidate',
      transitions: ['job_posted', 'requisition_cancelled'],
      requiredActors: ['approver'],
      onEnter: _onNoSuitableCandidate,
    ));

    addState('offer_extended', StateNode(
      id: 'offer_extended_$id',
      name: 'Offer Extended',
      transitions: ['offer_accepted', 'offer_rejected'],
      requiredActors: ['requestor'],
      onEnter: _onOfferExtended,
      validations: [_validateOfferDetails],
    ));

    addState('offer_accepted', StateNode(
      id: 'offer_accepted_$id',
      name: 'Offer Accepted',
      transitions: ['onboarding_scheduled'],
      requiredActors: ['requestor'],
      onEnter: _onOfferAccepted,
    ));

    addState('offer_rejected', StateNode(
      id: 'offer_rejected_$id',
      name: 'Offer Rejected',
      transitions: ['backup_candidate_considered', 'job_posted'],
      requiredActors: ['requestor'],
      onEnter: _onOfferRejected,
    ));

    addState('backup_candidate_considered', StateNode(
      id: 'backup_considered_$id',
      name: 'Backup Candidate Considered',
      transitions: ['offer_extended', 'job_posted'],
      requiredActors: ['approver'],
      onEnter: _onBackupCandidateConsidered,
      validations: [_validateBackupCandidate],
    ));

    addState('onboarding_scheduled', StateNode(
      id: 'onboarding_scheduled_$id',
      name: 'Onboarding Scheduled',
      transitions: ['hire_completed'],
      requiredActors: ['requestor'],
      onEnter: _onOnboardingScheduled,
    ));

    addState('hire_completed', StateNode(
      id: 'hire_completed_$id',
      name: 'Hire Completed',
      transitions: [],
      requiredActors: ['requestor'],
      onEnter: _onHireCompleted,
    ));

    addState('requisition_cancelled', StateNode(
      id: 'req_cancelled_$id',
      name: 'Requisition Cancelled',
      transitions: [],
      requiredActors: ['approver'],
      onEnter: _onRequisitionCancelled,
    ));
  }

  Future<void> _onRequisitionCreated(Map<String, dynamic> context) async {
    context['created_at'] = DateTime.now().toIso8601String();
    context['status'] = 'pending_review';
    
    eventBus.emit('hire.requisition.created', {
      'workflowId': id,
      'position': context['position'],
      'department': context['department'],
      'requestedBy': context['requested_by'],
    });
  }

  Future<void> _onRequisitionReviewed(Map<String, dynamic> context) async {
    context['reviewed_at'] = DateTime.now().toIso8601String();
    context['status'] = 'pending_approval';
    
    eventBus.emit('hire.requisition.reviewed', {
      'workflowId': id,
      'reviewedBy': context['reviewed_by'],
      'reviewComments': context['review_comments'],
    });
  }

  Future<void> _onRequisitionApproved(Map<String, dynamic> context) async {
    context['approved_at'] = DateTime.now().toIso8601String();
    context['status'] = 'approved';
    
    eventBus.emit('hire.requisition.approved', {
      'workflowId': id,
      'approvedBy': context['approved_by'],
      'budget': context['budget'],
    });
  }

  Future<void> _onRequisitionRejected(Map<String, dynamic> context) async {
    context['rejected_at'] = DateTime.now().toIso8601String();
    context['status'] = 'rejected';
    context['workflow_status'] = 'completed';
    
    eventBus.emit('hire.requisition.rejected', {
      'workflowId': id,
      'rejectedBy': context['rejected_by'],
      'rejectionReason': context['rejection_reason'],
    });
  }

  Future<void> _onJobPosted(Map<String, dynamic> context) async {
    context['posted_at'] = DateTime.now().toIso8601String();
    context['status'] = 'job_active';
    context['application_deadline'] = DateTime.now()
        .add(const Duration(days: 30))
        .toIso8601String();
    
    eventBus.emit('hire.job.posted', {
      'workflowId': id,
      'jobPostingId': context['job_posting_id'],
      'deadline': context['application_deadline'],
    });
  }

  Future<void> _onApplicationsReceived(Map<String, dynamic> context) async {
    context['applications_received_at'] = DateTime.now().toIso8601String();
    context['status'] = 'screening_pending';
    
    final applicationCount = context['application_count'] as int? ?? 0;
    
    eventBus.emit('hire.applications.received', {
      'workflowId': id,
      'applicationCount': applicationCount,
    });
  }

  Future<void> _onScreeningCompleted(Map<String, dynamic> context) async {
    context['screening_completed_at'] = DateTime.now().toIso8601String();
    context['status'] = 'interview_pending';
    
    final shortlistedCount = context['shortlisted_count'] as int? ?? 0;
    
    eventBus.emit('hire.screening.completed', {
      'workflowId': id,
      'shortlistedCount': shortlistedCount,
      'shortlistedCandidates': context['shortlisted_candidates'],
    });
  }

  Future<void> _onInterviewsScheduled(Map<String, dynamic> context) async {
    context['interviews_scheduled_at'] = DateTime.now().toIso8601String();
    context['status'] = 'interviews_in_progress';
    
    eventBus.emit('hire.interviews.scheduled', {
      'workflowId': id,
      'interviewSchedule': context['interview_schedule'],
    });
  }

  Future<void> _onInterviewsCompleted(Map<String, dynamic> context) async {
    context['interviews_completed_at'] = DateTime.now().toIso8601String();
    context['status'] = 'decision_pending';
    
    eventBus.emit('hire.interviews.completed', {
      'workflowId': id,
      'interviewResults': context['interview_results'],
    });
  }

  Future<void> _onCandidateSelected(Map<String, dynamic> context) async {
    context['candidate_selected_at'] = DateTime.now().toIso8601String();
    context['status'] = 'offer_preparation';
    
    eventBus.emit('hire.candidate.selected', {
      'workflowId': id,
      'selectedCandidate': context['selected_candidate'],
      'selectionReason': context['selection_reason'],
    });
  }

  Future<void> _onNoSuitableCandidate(Map<String, dynamic> context) async {
    context['no_candidate_decision_at'] = DateTime.now().toIso8601String();
    context['status'] = 'no_suitable_candidate';
    
    eventBus.emit('hire.no_suitable_candidate', {
      'workflowId': id,
      'reason': context['no_candidate_reason'],
    });
  }

  Future<void> _onOfferExtended(Map<String, dynamic> context) async {
    context['offer_extended_at'] = DateTime.now().toIso8601String();
    context['status'] = 'offer_pending';
    context['offer_expiry'] = DateTime.now()
        .add(const Duration(days: 7))
        .toIso8601String();
    
    eventBus.emit('hire.offer.extended', {
      'workflowId': id,
      'candidateId': context['selected_candidate']['id'],
      'offerDetails': context['offer_details'],
      'expiryDate': context['offer_expiry'],
    });
  }

  Future<void> _onOfferAccepted(Map<String, dynamic> context) async {
    context['offer_accepted_at'] = DateTime.now().toIso8601String();
    context['status'] = 'onboarding_preparation';
    
    eventBus.emit('hire.offer.accepted', {
      'workflowId': id,
      'candidateId': context['selected_candidate']['id'],
      'startDate': context['start_date'],
    });
  }

  Future<void> _onOfferRejected(Map<String, dynamic> context) async {
    context['offer_rejected_at'] = DateTime.now().toIso8601String();
    context['status'] = 'offer_rejected';
    
    eventBus.emit('hire.offer.rejected', {
      'workflowId': id,
      'candidateId': context['selected_candidate']['id'],
      'rejectionReason': context['offer_rejection_reason'],
    });
  }

  Future<void> _onBackupCandidateConsidered(Map<String, dynamic> context) async {
    context['backup_considered_at'] = DateTime.now().toIso8601String();
    context['status'] = 'backup_evaluation';
    
    eventBus.emit('hire.backup_candidate.considered', {
      'workflowId': id,
      'backupCandidate': context['backup_candidate'],
    });
  }

  Future<void> _onOnboardingScheduled(Map<String, dynamic> context) async {
    context['onboarding_scheduled_at'] = DateTime.now().toIso8601String();
    context['status'] = 'onboarding_ready';
    
    eventBus.emit('hire.onboarding.scheduled', {
      'workflowId': id,
      'newEmployeeId': context['new_employee_id'],
      'onboardingSchedule': context['onboarding_schedule'],
    });
  }

  Future<void> _onHireCompleted(Map<String, dynamic> context) async {
    context['hire_completed_at'] = DateTime.now().toIso8601String();
    context['status'] = 'completed';
    context['workflow_status'] = 'completed';
    
    eventBus.emit('hire.completed', {
      'workflowId': id,
      'newEmployeeId': context['new_employee_id'],
      'position': context['position'],
      'department': context['department'],
      'completedAt': context['hire_completed_at'],
    });
  }

  Future<void> _onRequisitionCancelled(Map<String, dynamic> context) async {
    context['cancelled_at'] = DateTime.now().toIso8601String();
    context['status'] = 'cancelled';
    context['workflow_status'] = 'cancelled';
    
    eventBus.emit('hire.requisition.cancelled', {
      'workflowId': id,
      'cancelledBy': context['cancelled_by'],
      'cancellationReason': context['cancellation_reason'],
    });
  }

  Future<bool> _validateRequisitionData(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final requiredFields = [
      'position',
      'department',
      'job_description',
      'required_skills',
      'experience_level',
      'salary_range',
    ];

    for (final field in requiredFields) {
      if (!transitionContext.containsKey(field) || 
          transitionContext[field] == null ||
          transitionContext[field].toString().isEmpty) {
        return false;
      }
    }

    final salaryRange = transitionContext['salary_range'] as Map<String, dynamic>?;
    if (salaryRange == null ||
        !salaryRange.containsKey('min') ||
        !salaryRange.containsKey('max') ||
        (salaryRange['min'] as num) >= (salaryRange['max'] as num)) {
      return false;
    }

    return true;
  }

  Future<bool> _validateRequisitionReview(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    return transitionContext.containsKey('review_comments') &&
           transitionContext.containsKey('reviewed_by') &&
           transitionContext['review_comments'] != null &&
           transitionContext['review_comments'].toString().isNotEmpty;
  }

  Future<bool> _validateApprovalAuthority(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final budget = transitionContext['budget'] as num? ?? 0;
    final approverLevel = transitionContext['approver_level'] as int? ?? 0;

    if (budget <= 50000 && approverLevel >= 5) return true;
    if (budget <= 100000 && approverLevel >= 7) return true;
    if (budget <= 200000 && approverLevel >= 9) return true;
    if (approverLevel >= 10) return true;

    return false;
  }

  Future<bool> _validateMinimumApplications(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final applicationCount = transitionContext['application_count'] as int? ?? 0;
    return applicationCount >= 5;
  }

  Future<bool> _validateScreeningResults(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final shortlistedCount = transitionContext['shortlisted_count'] as int? ?? 0;
    final shortlistedCandidates = transitionContext['shortlisted_candidates'] as List? ?? [];
    
    return shortlistedCount > 0 && 
           shortlistedCandidates.isNotEmpty &&
           shortlistedCount <= 10;
  }

  Future<bool> _validateInterviewResults(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final interviewResults = transitionContext['interview_results'] as List? ?? [];
    
    if (interviewResults.isEmpty) return false;
    
    for (final result in interviewResults) {
      if (result is! Map<String, dynamic> ||
          !result.containsKey('candidate_id') ||
          !result.containsKey('score') ||
          !result.containsKey('recommendation')) {
        return false;
      }
    }
    
    return true;
  }

  Future<bool> _validateCandidateSelection(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final selectedCandidate = transitionContext['selected_candidate'] as Map<String, dynamic>?;
    
    if (selectedCandidate == null ||
        !selectedCandidate.containsKey('id') ||
        !selectedCandidate.containsKey('name')) {
      return false;
    }

    final interviewResults = currentContext['interview_results'] as List? ?? [];
    final candidateId = selectedCandidate['id'];
    
    final candidateResult = interviewResults.firstWhere(
      (result) => result['candidate_id'] == candidateId,
      orElse: () => null,
    );
    
    return candidateResult != null && 
           candidateResult['recommendation'] == 'hire' &&
           (candidateResult['score'] as num) >= 70;
  }

  Future<bool> _validateOfferDetails(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final offerDetails = transitionContext['offer_details'] as Map<String, dynamic>?;
    
    if (offerDetails == null) return false;
    
    final requiredFields = ['salary', 'start_date', 'position', 'benefits'];
    
    for (final field in requiredFields) {
      if (!offerDetails.containsKey(field) || offerDetails[field] == null) {
        return false;
      }
    }
    
    final offeredSalary = offerDetails['salary'] as num;
    final budgetRange = currentContext['salary_range'] as Map<String, dynamic>? ?? {};
    final minSalary = budgetRange['min'] as num? ?? 0;
    final maxSalary = budgetRange['max'] as num? ?? double.infinity;
    
    return offeredSalary >= minSalary && offeredSalary <= maxSalary;
  }

  Future<bool> _validateBackupCandidate(
    Map<String, dynamic> currentContext,
    Map<String, dynamic> transitionContext,
  ) async {
    final backupCandidate = transitionContext['backup_candidate'] as Map<String, dynamic>?;
    
    if (backupCandidate == null) return false;
    
    final interviewResults = currentContext['interview_results'] as List? ?? [];
    final candidateId = backupCandidate['id'];
    
    final candidateResult = interviewResults.firstWhere(
      (result) => result['candidate_id'] == candidateId,
      orElse: () => null,
    );
    
    return candidateResult != null && 
           candidateResult['recommendation'] == 'hire' &&
           (candidateResult['score'] as num) >= 60;
  }
}