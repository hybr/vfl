import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface WorkflowTransitionRequest {
  instanceId: string;
  targetState: string;
  actorRole: string;
  context?: Record<string, any>;
  reason?: string;
}

interface CreateWorkflowInstanceRequest {
  workflowId: string;
  organizationId: string;
  initialContext?: Record<string, any>;
}

interface PermissionCheckRequest {
  workflowStepId: string;
  actorRole: string;
  context?: Record<string, any>;
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: { headers: { Authorization: req.headers.get('Authorization')! } },
      }
    )

    // Get user from the request
    const {
      data: { user },
    } = await supabaseClient.auth.getUser()

    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { 
          status: 401, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    const url = new URL(req.url);
    const path = url.pathname.split('/').pop();

    switch (req.method) {
      case 'GET':
        return await handleGet(supabaseClient, user, url, path);
      case 'POST':
        return await handlePost(supabaseClient, user, req, path);
      case 'PUT':
        return await handlePut(supabaseClient, user, req, path);
      default:
        return new Response(
          JSON.stringify({ error: 'Method not allowed' }),
          { 
            status: 405, 
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        )
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})

async function handleGet(supabaseClient: any, user: any, url: URL, path: string | undefined) {
  switch (path) {
    case 'instances':
      return await getWorkflowInstances(supabaseClient, user, url);
    case 'available-actions':
      return await getAvailableActions(supabaseClient, user, url);
    case 'history':
      return await getWorkflowHistory(supabaseClient, user, url);
    case 'eligible-users':
      return await getEligibleUsers(supabaseClient, user, url);
    case 'workflows':
      return await getWorkflows(supabaseClient, user, url);
    default:
      if (path?.startsWith('instance-')) {
        const instanceId = path.replace('instance-', '');
        return await getWorkflowInstance(supabaseClient, user, instanceId);
      }
      return new Response(
        JSON.stringify({ error: 'Endpoint not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
  }
}

async function handlePost(supabaseClient: any, user: any, req: Request, path: string | undefined) {
  const body = await req.json();

  switch (path) {
    case 'create-instance':
      return await createWorkflowInstance(supabaseClient, user, body);
    case 'transition':
      return await transitionWorkflow(supabaseClient, user, body);
    case 'check-permission':
      return await checkPermission(supabaseClient, user, body);
    case 'pause-instance':
      return await pauseWorkflowInstance(supabaseClient, user, body);
    case 'resume-instance':
      return await resumeWorkflowInstance(supabaseClient, user, body);
    case 'cancel-instance':
      return await cancelWorkflowInstance(supabaseClient, user, body);
    default:
      return new Response(
        JSON.stringify({ error: 'Endpoint not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
  }
}

async function handlePut(supabaseClient: any, user: any, req: Request, path: string | undefined) {
  // Handle PUT requests for updates
  return new Response(
    JSON.stringify({ error: 'PUT method not implemented yet' }),
    { 
      status: 501, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function createWorkflowInstance(supabaseClient: any, user: any, body: CreateWorkflowInstanceRequest) {
  try {
    // Validate workflow exists and is active
    const { data: workflow, error: workflowError } = await supabaseClient
      .from('workflows')
      .select('*')
      .eq('id', body.workflowId)
      .eq('is_active', true)
      .single();

    if (workflowError || !workflow) {
      return new Response(
        JSON.stringify({ error: 'Workflow not found or inactive' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Get first step
    const { data: steps } = await supabaseClient
      .from('workflow_steps')
      .select('*')
      .eq('workflow_id', body.workflowId)
      .eq('is_active', true)
      .order('step_order', { ascending: true })
      .limit(1);

    const firstStep = steps?.[0]?.step_name || 'initial';

    // Create workflow instance
    const instance = {
      workflow_id: body.workflowId,
      current_state: firstStep,
      context_data: body.initialContext || {},
      initiator_user_id: user.id,
      organization_id: body.organizationId,
      status: 'active',
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    const { data: createdInstance, error } = await supabaseClient
      .from('workflow_instances')
      .insert(instance)
      .select()
      .single();

    if (error) {
      throw error;
    }

    // Create audit log
    await supabaseClient
      .from('audit_logs')
      .insert({
        event_type: 'workflow_instance_created',
        user_id: user.id,
        resource_type: 'workflow_instance',
        resource_id: createdInstance.id,
        action: 'create',
        result: 'success',
        details: JSON.stringify({
          workflow_id: body.workflowId,
          organization_id: body.organizationId,
          initial_context: body.initialContext,
        }),
        workflow_instance_id: createdInstance.id,
        timestamp: new Date().toISOString(),
      });

    return new Response(
      JSON.stringify({
        success: true,
        data: createdInstance,
      }),
      { 
        status: 201, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Failed to create workflow instance: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
}

async function transitionWorkflow(supabaseClient: any, user: any, body: WorkflowTransitionRequest) {
  try {
    // Get workflow instance
    const { data: instance, error: instanceError } = await supabaseClient
      .from('workflow_instances')
      .select('*')
      .eq('id', body.instanceId)
      .single();

    if (instanceError || !instance) {
      return new Response(
        JSON.stringify({ error: 'Workflow instance not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    if (instance.status !== 'active') {
      return new Response(
        JSON.stringify({ error: 'Workflow instance is not in active state' }),
        { 
          status: 400, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Get target workflow step
    const { data: targetStep, error: stepError } = await supabaseClient
      .from('workflow_steps')
      .select('*')
      .eq('workflow_id', instance.workflow_id)
      .eq('step_name', body.targetState)
      .eq('is_active', true)
      .single();

    if (stepError || !targetStep) {
      return new Response(
        JSON.stringify({ error: 'Target workflow step not found' }),
        { 
          status: 404, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Check permissions using the RBAC function
    const permissionResult = await checkUserPermissions(
      supabaseClient,
      user.id,
      targetStep.id,
      body.actorRole,
      { ...instance.context_data, ...body.context }
    );

    if (!permissionResult.hasPermission) {
      // Log permission denied
      await supabaseClient
        .from('audit_logs')
        .insert({
          event_type: 'permission_denied',
          user_id: user.id,
          resource_type: 'workflow_step',
          resource_id: targetStep.id,
          action: body.actorRole,
          result: 'denied',
          details: JSON.stringify({
            reasons: permissionResult.reasons,
            context: body.context,
          }),
          workflow_instance_id: body.instanceId,
          timestamp: new Date().toISOString(),
        });

      return new Response(
        JSON.stringify({ 
          error: 'Permission denied',
          reasons: permissionResult.reasons,
        }),
        { 
          status: 403, 
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Update workflow instance
    const updatedContext = {
      ...instance.context_data,
      ...body.context,
      performed_by: user.id,
      actor_role: body.actorRole,
      permission_context: permissionResult.matchedPermissions,
      transition_reason: body.reason,
    };

    const { data: updatedInstance, error: updateError } = await supabaseClient
      .from('workflow_instances')
      .update({
        current_state: body.targetState,
        context_data: updatedContext,
        updated_at: new Date().toISOString(),
      })
      .eq('id', body.instanceId)
      .select()
      .single();

    if (updateError) {
      throw updateError;
    }

    // Create workflow history entry
    await supabaseClient
      .from('workflow_history')
      .insert({
        instance_id: body.instanceId,
        from_state: instance.current_state,
        to_state: body.targetState,
        action: 'transition',
        context_data: body.context || {},
        performed_by: user.id,
        actor_role: body.actorRole,
        performed_at: new Date().toISOString(),
        reason: body.reason,
      });

    // Create audit log
    await supabaseClient
      .from('audit_logs')
      .insert({
        event_type: 'workflow_transition',
        user_id: user.id,
        resource_type: 'workflow_instance',
        resource_id: body.instanceId,
        action: `transition_${instance.current_state}_to_${body.targetState}`,
        result: 'success',
        details: JSON.stringify({
          from_state: instance.current_state,
          to_state: body.targetState,
          actor_role: body.actorRole,
          context: body.context,
        }),
        workflow_instance_id: body.instanceId,
        timestamp: new Date().toISOString(),
      });

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          instanceId: body.instanceId,
          newState: body.targetState,
          context: updatedContext,
          timestamp: new Date().toISOString(),
        },
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Failed to transition workflow: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
}

async function checkPermission(supabaseClient: any, user: any, body: PermissionCheckRequest) {
  try {
    const permissionResult = await checkUserPermissions(
      supabaseClient,
      user.id,
      body.workflowStepId,
      body.actorRole,
      body.context || {}
    );

    return new Response(
      JSON.stringify({
        success: true,
        data: permissionResult,
      }),
      { 
        status: 200, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: `Failed to check permission: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
}

async function checkUserPermissions(
  supabaseClient: any,
  userId: string,
  workflowStepId: string,
  actorRole: string,
  context: Record<string, any>
) {
  // Get user's active positions
  const { data: userPositions } = await supabaseClient.rpc('get_user_active_positions', {
    input_user_id: userId
  });

  if (!userPositions || userPositions.length === 0) {
    return {
      hasPermission: false,
      reasons: ['User has no active organizational positions'],
      matchedPermissions: [],
      userPositions: [],
    };
  }

  // Get workflow step permissions
  const { data: stepPermissions } = await supabaseClient
    .from('workflow_permissions')
    .select(`
      *,
      workflow_actors!inner(name)
    `)
    .eq('workflow_step_id', workflowStepId)
    .eq('workflow_actors.name', actorRole)
    .eq('is_active', true);

  if (!stepPermissions || stepPermissions.length === 0) {
    return {
      hasPermission: false,
      reasons: ['No permissions configured for this workflow step'],
      matchedPermissions: [],
      userPositions,
    };
  }

  // Evaluate permissions
  const matchedPermissions = [];
  let hasValidPermission = false;

  for (const permission of stepPermissions) {
    for (const userPosition of userPositions) {
      const isMatch = await evaluatePermissionMatch(
        supabaseClient,
        userPosition,
        permission,
        context
      );

      if (isMatch.matches) {
        if (permission.permission_type === 'forbidden') {
          return {
            hasPermission: false,
            reasons: ['User has forbidden permission for this action'],
            matchedPermissions: [],
            userPositions,
          };
        }

        if (permission.permission_type === 'required' || permission.permission_type === 'optional') {
          hasValidPermission = true;
          matchedPermissions.push({
            permission: permission,
            userPosition: userPosition,
            matchType: isMatch.matchType,
            conditions: isMatch.conditionResults,
          });
        }
      }
    }
  }

  return {
    hasPermission: hasValidPermission,
    reasons: hasValidPermission ? [] : ['User does not match any required permissions for this workflow step'],
    matchedPermissions,
    userPositions,
  };
}

async function evaluatePermissionMatch(
  supabaseClient: any,
  userPosition: any,
  permission: any,
  context: Record<string, any>
) {
  let groupMatches = false;
  let designationMatches = true;
  const conditionResults = {};

  // Check group matching
  if (permission.group_type === 'department') {
    if (userPosition.group_type === 'department') {
      groupMatches = userPosition.group_id === permission.group_id;
    } else if (userPosition.group_type === 'team') {
      // Check if team belongs to the department
      const { data: team } = await supabaseClient
        .from('organization_teams')
        .select('department_id')
        .eq('id', userPosition.group_id)
        .single();
      
      if (team) {
        groupMatches = team.department_id === permission.group_id;
      }
    }
  } else if (permission.group_type === 'team') {
    groupMatches = userPosition.group_type === 'team' && 
                  userPosition.group_id === permission.group_id;
  }

  // Check designation matching
  if (permission.designation_id) {
    designationMatches = userPosition.designation_id === permission.designation_id;
  }

  // Evaluate conditions
  if (permission.conditions && Object.keys(permission.conditions).length > 0) {
    const conditionsPassed = await evaluateConditions(
      permission.conditions,
      context,
      userPosition
    );
    Object.assign(conditionResults, conditionsPassed);
    designationMatches = designationMatches && 
                        Object.values(conditionsPassed).every(result => result === true);
  }

  const matches = groupMatches && designationMatches;
  let matchType = 'none';

  if (matches) {
    matchType = permission.designation_id ? 'exact' : 'group';
  }

  return {
    matches,
    matchType,
    conditionResults,
  };
}

async function evaluateConditions(
  conditions: Record<string, any>,
  context: Record<string, any>,
  userPosition: any
) {
  const results = {};

  for (const [conditionKey, conditionValue] of Object.entries(conditions)) {
    switch (conditionKey) {
      case 'min_job_level':
        results[conditionKey] = (userPosition.job_level || 0) >= conditionValue;
        break;
      case 'max_job_level':
        results[conditionKey] = (userPosition.job_level || 0) <= conditionValue;
        break;
      case 'workflow_amount_limit':
        const workflowAmount = context.amount || 0;
        results[conditionKey] = workflowAmount <= conditionValue;
        break;
      case 'time_constraint':
        results[conditionKey] = await evaluateTimeConstraints(conditionValue);
        break;
      default:
        results[conditionKey] = true;
    }
  }

  return results;
}

async function evaluateTimeConstraints(constraints: Record<string, any>) {
  const now = new Date();
  
  if (constraints.business_hours_only) {
    const hour = now.getHours();
    const isWeekday = now.getDay() >= 1 && now.getDay() <= 5;
    return isWeekday && hour >= 9 && hour <= 17;
  }

  if (constraints.deadline) {
    const deadline = new Date(constraints.deadline);
    return now < deadline;
  }

  return true;
}

async function getWorkflowInstances(supabaseClient: any, user: any, url: URL) {
  const organizationId = url.searchParams.get('organizationId');
  const status = url.searchParams.get('status');
  const limit = parseInt(url.searchParams.get('limit') || '50');
  const offset = parseInt(url.searchParams.get('offset') || '0');

  let query = supabaseClient
    .from('workflow_instances')
    .select('*')
    .order('created_at', { ascending: false })
    .range(offset, offset + limit - 1);

  if (organizationId) {
    query = query.eq('organization_id', organizationId);
  }

  if (status) {
    query = query.eq('status', status);
  }

  const { data, error } = await query;

  if (error) {
    return new Response(
      JSON.stringify({ error: `Failed to fetch workflow instances: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: data,
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function getAvailableActions(supabaseClient: any, user: any, url: URL) {
  const instanceId = url.searchParams.get('instanceId');

  if (!instanceId) {
    return new Response(
      JSON.stringify({ error: 'instanceId parameter is required' }),
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  // Implementation would call the workflow engine's getAvailableActionsForUser method
  // For now, return a placeholder response
  return new Response(
    JSON.stringify({
      success: true,
      data: [],
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function getWorkflowHistory(supabaseClient: any, user: any, url: URL) {
  const instanceId = url.searchParams.get('instanceId');

  if (!instanceId) {
    return new Response(
      JSON.stringify({ error: 'instanceId parameter is required' }),
      { 
        status: 400, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  const { data, error } = await supabaseClient
    .from('workflow_history')
    .select('*')
    .eq('instance_id', instanceId)
    .order('performed_at', { ascending: false });

  if (error) {
    return new Response(
      JSON.stringify({ error: `Failed to fetch workflow history: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: data,
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function getEligibleUsers(supabaseClient: any, user: any, url: URL) {
  // Implementation placeholder
  return new Response(
    JSON.stringify({
      success: true,
      data: [],
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function getWorkflows(supabaseClient: any, user: any, url: URL) {
  const { data, error } = await supabaseClient
    .from('workflows')
    .select(`
      *,
      workflow_steps(*)
    `)
    .eq('is_active', true)
    .order('name');

  if (error) {
    return new Response(
      JSON.stringify({ error: `Failed to fetch workflows: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: data,
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function getWorkflowInstance(supabaseClient: any, user: any, instanceId: string) {
  const { data, error } = await supabaseClient
    .from('workflow_instances')
    .select('*')
    .eq('id', instanceId)
    .single();

  if (error) {
    return new Response(
      JSON.stringify({ error: `Failed to fetch workflow instance: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  return new Response(
    JSON.stringify({
      success: true,
      data: data,
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}

async function pauseWorkflowInstance(supabaseClient: any, user: any, body: { instanceId: string }) {
  return await updateWorkflowInstanceStatus(supabaseClient, user, body.instanceId, 'paused');
}

async function resumeWorkflowInstance(supabaseClient: any, user: any, body: { instanceId: string }) {
  return await updateWorkflowInstanceStatus(supabaseClient, user, body.instanceId, 'active');
}

async function cancelWorkflowInstance(supabaseClient: any, user: any, body: { instanceId: string }) {
  return await updateWorkflowInstanceStatus(supabaseClient, user, body.instanceId, 'cancelled');
}

async function updateWorkflowInstanceStatus(supabaseClient: any, user: any, instanceId: string, status: string) {
  const { data, error } = await supabaseClient
    .from('workflow_instances')
    .update({
      status: status,
      updated_at: new Date().toISOString(),
    })
    .eq('id', instanceId)
    .select()
    .single();

  if (error) {
    return new Response(
      JSON.stringify({ error: `Failed to update workflow instance: ${error.message}` }),
      { 
        status: 500, 
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }

  // Create audit log
  await supabaseClient
    .from('audit_logs')
    .insert({
      event_type: 'workflow_status_change',
      user_id: user.id,
      resource_type: 'workflow_instance',
      resource_id: instanceId,
      action: `status_change_to_${status}`,
      result: 'success',
      workflow_instance_id: instanceId,
      timestamp: new Date().toISOString(),
    });

  return new Response(
    JSON.stringify({
      success: true,
      data: data,
    }),
    { 
      status: 200, 
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    }
  )
}