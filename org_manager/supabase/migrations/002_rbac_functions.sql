-- RBAC Helper Functions
-- Version: 2.0
-- Migration: 002_rbac_functions

-- ============================================================================
-- USER POSITION LOOKUP FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION get_user_active_positions(input_user_id UUID)
RETURNS TABLE (
    assignment_id UUID,
    assignment_type VARCHAR(50),
    position_id UUID,
    position_title VARCHAR(255),
    designation_id UUID,
    designation_name VARCHAR(255),
    designation_code VARCHAR(50),
    group_type VARCHAR(20),
    group_id UUID,
    job_level INTEGER,
    department_name VARCHAR(255),
    department_code VARCHAR(50),
    team_name VARCHAR(255),
    team_code VARCHAR(50),
    parent_department_name VARCHAR(255),
    seat_number VARCHAR(50),
    building_name VARCHAR(255),
    branch_name VARCHAR(255),
    organization_name VARCHAR(255)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
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
    
    WHERE upa.user_id = input_user_id
      AND upa.is_active = true
      AND (upa.end_date IS NULL OR upa.end_date >= CURRENT_DATE)
      AND upa.start_date <= CURRENT_DATE
      AND op.is_active = true
      AND ogd.is_active = true;
END;
$$;

-- ============================================================================
-- WORKFLOW PERMISSION CHECKING FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION check_workflow_permission(
    input_user_id UUID,
    input_workflow_step_id UUID,
    input_actor_role VARCHAR(100),
    input_context JSONB DEFAULT '{}'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    user_positions RECORD;
    step_permissions RECORD;
    permission_result JSONB;
    has_permission BOOLEAN := FALSE;
    matched_permissions JSONB := '[]'::jsonb;
    denial_reasons TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Get user positions
    SELECT COUNT(*) INTO user_positions FROM get_user_active_positions(input_user_id);
    
    IF user_positions IS NULL OR user_positions = 0 THEN
        denial_reasons := array_append(denial_reasons, 'User has no active organizational positions');
        RETURN jsonb_build_object(
            'hasPermission', FALSE,
            'reasons', array_to_json(denial_reasons),
            'matchedPermissions', matched_permissions,
            'userPositions', '[]'::jsonb
        );
    END IF;

    -- Get workflow step permissions
    SELECT COUNT(*) INTO step_permissions
    FROM workflow_permissions wp
    JOIN workflow_actors wa ON wp.actor_id = wa.id
    WHERE wp.workflow_step_id = input_workflow_step_id
      AND wa.name = input_actor_role
      AND wp.is_active = true;

    IF step_permissions IS NULL OR step_permissions = 0 THEN
        denial_reasons := array_append(denial_reasons, 'No permissions configured for this workflow step');
        RETURN jsonb_build_object(
            'hasPermission', FALSE,
            'reasons', array_to_json(denial_reasons),
            'matchedPermissions', matched_permissions,
            'userPositions', '[]'::jsonb
        );
    END IF;

    -- Check each permission against each user position
    FOR user_positions IN 
        SELECT * FROM get_user_active_positions(input_user_id)
    LOOP
        FOR step_permissions IN
            SELECT wp.*, wa.name as actor_name
            FROM workflow_permissions wp
            JOIN workflow_actors wa ON wp.actor_id = wa.id
            WHERE wp.workflow_step_id = input_workflow_step_id
              AND wa.name = input_actor_role
              AND wp.is_active = true
        LOOP
            -- Check if this permission matches the user position
            IF evaluate_permission_match(user_positions, step_permissions, input_context) THEN
                -- Check permission type
                IF step_permissions.permission_type = 'forbidden' THEN
                    RETURN jsonb_build_object(
                        'hasPermission', FALSE,
                        'reasons', array_to_json(ARRAY['User has forbidden permission for this action']),
                        'matchedPermissions', matched_permissions,
                        'userPositions', '[]'::jsonb
                    );
                END IF;

                IF step_permissions.permission_type IN ('required', 'optional') THEN
                    has_permission := TRUE;
                    matched_permissions := matched_permissions || jsonb_build_object(
                        'permission', row_to_json(step_permissions),
                        'userPosition', row_to_json(user_positions),
                        'matchType', 'exact'
                    );
                END IF;
            END IF;
        END LOOP;
    END LOOP;

    IF NOT has_permission THEN
        denial_reasons := array_append(denial_reasons, 'User does not match any required permissions for this workflow step');
    END IF;

    RETURN jsonb_build_object(
        'hasPermission', has_permission,
        'reasons', array_to_json(denial_reasons),
        'matchedPermissions', matched_permissions,
        'userPositions', (SELECT jsonb_agg(row_to_json(p)) FROM get_user_active_positions(input_user_id) p)
    );
END;
$$;

-- ============================================================================
-- PERMISSION MATCHING HELPER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION evaluate_permission_match(
    user_position RECORD,
    permission RECORD,
    context JSONB
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    group_matches BOOLEAN := FALSE;
    designation_matches BOOLEAN := TRUE;
    team_department_id UUID;
BEGIN
    -- Check group matching
    IF permission.group_type = 'department' THEN
        IF user_position.group_type = 'department' THEN
            group_matches := user_position.group_id = permission.group_id;
        ELSIF user_position.group_type = 'team' THEN
            -- Check if team belongs to the department
            SELECT department_id INTO team_department_id
            FROM organization_teams
            WHERE id = user_position.group_id;
            
            group_matches := team_department_id = permission.group_id;
        END IF;
    ELSIF permission.group_type = 'team' THEN
        group_matches := user_position.group_type = 'team' AND user_position.group_id = permission.group_id;
    END IF;

    -- Check designation matching
    IF permission.designation_id IS NOT NULL THEN
        designation_matches := user_position.designation_id = permission.designation_id;
    END IF;

    -- Evaluate conditions (simplified version)
    IF permission.conditions IS NOT NULL AND jsonb_typeof(permission.conditions) = 'object' THEN
        designation_matches := designation_matches AND evaluate_permission_conditions(
            permission.conditions,
            context,
            user_position
        );
    END IF;

    RETURN group_matches AND designation_matches;
END;
$$;

-- ============================================================================
-- CONDITION EVALUATION HELPER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION evaluate_permission_conditions(
    conditions JSONB,
    context JSONB,
    user_position RECORD
)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    condition_key TEXT;
    condition_value JSONB;
    result BOOLEAN := TRUE;
BEGIN
    -- Iterate through conditions
    FOR condition_key, condition_value IN
        SELECT * FROM jsonb_each(conditions)
    LOOP
        CASE condition_key
            WHEN 'min_job_level' THEN
                IF COALESCE(user_position.job_level, 0) < (condition_value #>> '{}')::INTEGER THEN
                    result := FALSE;
                    EXIT;
                END IF;
            
            WHEN 'max_job_level' THEN
                IF COALESCE(user_position.job_level, 0) > (condition_value #>> '{}')::INTEGER THEN
                    result := FALSE;
                    EXIT;
                END IF;
            
            WHEN 'workflow_amount_limit' THEN
                IF (context ->> 'amount')::NUMERIC > (condition_value #>> '{}')::NUMERIC THEN
                    result := FALSE;
                    EXIT;
                END IF;
            
            WHEN 'assignment_type' THEN
                IF NOT (condition_value ? user_position.assignment_type) THEN
                    result := FALSE;
                    EXIT;
                END IF;
            
            WHEN 'department_budget_approval' THEN
                IF (context ->> 'department') != user_position.department_code THEN
                    result := FALSE;
                    EXIT;
                END IF;
            
            WHEN 'time_constraint' THEN
                IF NOT evaluate_time_constraints(condition_value) THEN
                    result := FALSE;
                    EXIT;
                END IF;
            
            ELSE
                -- Unknown condition, skip
                CONTINUE;
        END CASE;
    END LOOP;

    RETURN result;
END;
$$;

-- ============================================================================
-- TIME CONSTRAINT EVALUATION FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION evaluate_time_constraints(constraints JSONB)
RETURNS BOOLEAN
LANGUAGE plpgsql
AS $$
DECLARE
    current_time TIMESTAMP := NOW();
    current_hour INTEGER := EXTRACT(HOUR FROM current_time);
    current_dow INTEGER := EXTRACT(DOW FROM current_time); -- 0=Sunday, 1=Monday, etc.
BEGIN
    -- Business hours check
    IF constraints ? 'business_hours_only' AND (constraints ->> 'business_hours_only')::BOOLEAN THEN
        -- Monday to Friday, 9 AM to 5 PM
        IF current_dow < 1 OR current_dow > 5 OR current_hour < 9 OR current_hour > 17 THEN
            RETURN FALSE;
        END IF;
    END IF;

    -- Deadline check
    IF constraints ? 'deadline' THEN
        IF current_time >= (constraints ->> 'deadline')::TIMESTAMP THEN
            RETURN FALSE;
        END IF;
    END IF;

    RETURN TRUE;
END;
$$;

-- ============================================================================
-- ORGANIZATIONAL HIERARCHY FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION get_department_hierarchy(dept_id UUID)
RETURNS TABLE (
    id UUID,
    name VARCHAR(255),
    code VARCHAR(50),
    level INTEGER,
    path TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE dept_hierarchy AS (
        -- Base case
        SELECT 
            d.id,
            d.name,
            d.code,
            0 as level,
            d.name::TEXT as path
        FROM organization_departments d
        WHERE d.id = dept_id
        
        UNION ALL
        
        -- Recursive case
        SELECT 
            d.id,
            d.name,
            d.code,
            dh.level + 1,
            dh.path || ' > ' || d.name
        FROM organization_departments d
        JOIN dept_hierarchy dh ON d.parent_department_id = dh.id
        WHERE d.is_active = true
    )
    SELECT * FROM dept_hierarchy ORDER BY level;
END;
$$;

CREATE OR REPLACE FUNCTION get_user_organizational_context(input_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSONB;
    user_data RECORD;
BEGIN
    -- Get comprehensive user organizational context
    SELECT jsonb_build_object(
        'userId', input_user_id,
        'positions', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'positionId', position_id,
                    'title', position_title,
                    'assignmentType', assignment_type,
                    'designation', jsonb_build_object(
                        'id', designation_id,
                        'name', designation_name,
                        'code', designation_code,
                        'jobLevel', job_level
                    ),
                    'group', jsonb_build_object(
                        'type', group_type,
                        'id', group_id,
                        'departmentName', department_name,
                        'departmentCode', department_code,
                        'teamName', team_name,
                        'teamCode', team_code
                    ),
                    'location', jsonb_build_object(
                        'seatNumber', seat_number,
                        'building', building_name,
                        'branch', branch_name,
                        'organization', organization_name
                    )
                )
            )
            FROM get_user_active_positions(input_user_id)
        ),
        'organizations', (
            SELECT jsonb_agg(DISTINCT organization_name)
            FROM get_user_active_positions(input_user_id)
        ),
        'departments', (
            SELECT jsonb_agg(DISTINCT department_name)
            FROM get_user_active_positions(input_user_id)
            WHERE department_name IS NOT NULL
        ),
        'teams', (
            SELECT jsonb_agg(DISTINCT team_name)
            FROM get_user_active_positions(input_user_id)
            WHERE team_name IS NOT NULL
        ),
        'maxJobLevel', (
            SELECT COALESCE(MAX(job_level), 0)
            FROM get_user_active_positions(input_user_id)
        )
    ) INTO result;

    RETURN result;
END;
$$;

-- ============================================================================
-- WORKFLOW UTILITY FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION get_workflow_eligible_users(
    input_workflow_step_id UUID,
    input_actor_role VARCHAR(100)
)
RETURNS TABLE (user_id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT upa.user_id
    FROM user_position_assignments upa
    JOIN organization_positions op ON upa.position_id = op.id
    JOIN organization_group_designations ogd ON op.group_designation_id = ogd.id
    JOIN workflow_permissions wp ON (
        wp.group_type = ogd.group_type::TEXT 
        AND wp.group_id = ogd.group_id
        AND (wp.designation_id IS NULL OR wp.designation_id = ogd.id)
    )
    JOIN workflow_actors wa ON wp.actor_id = wa.id
    WHERE wp.workflow_step_id = input_workflow_step_id
      AND wa.name = input_actor_role
      AND wp.permission_type IN ('required', 'optional')
      AND wp.is_active = true
      AND upa.is_active = true
      AND (upa.end_date IS NULL OR upa.end_date >= CURRENT_DATE)
      AND upa.start_date <= CURRENT_DATE
      AND op.is_active = true
      AND ogd.is_active = true;
END;
$$;

-- ============================================================================
-- AUDIT AND SECURITY FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION log_security_event(
    event_type VARCHAR(100),
    input_user_id UUID,
    resource_type VARCHAR(100),
    resource_id UUID,
    action VARCHAR(100),
    result VARCHAR(50),
    details JSONB DEFAULT NULL,
    workflow_instance_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    log_id UUID;
BEGIN
    INSERT INTO audit_logs (
        event_type,
        user_id,
        resource_type,
        resource_id,
        action,
        result,
        details,
        workflow_instance_id,
        timestamp
    ) VALUES (
        event_type,
        input_user_id,
        resource_type,
        resource_id,
        action,
        result,
        COALESCE(details, '{}'::jsonb)::TEXT,
        workflow_instance_id,
        NOW()
    ) RETURNING id INTO log_id;

    RETURN log_id;
END;
$$;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION execute_query(query_text TEXT, params TEXT[] DEFAULT ARRAY[]::TEXT[])
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result RECORD;
    results JSONB := '[]'::jsonb;
BEGIN
    -- This is a helper function for dynamic queries
    -- In production, this should have strict security controls
    -- and only be accessible to authorized functions
    
    FOR result IN EXECUTE query_text USING VARIADIC params
    LOOP
        results := results || row_to_json(result)::jsonb;
    END LOOP;
    
    RETURN results;
END;
$$;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_user_active_positions(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION check_workflow_permission(UUID, UUID, VARCHAR(100), JSONB) TO authenticated;
GRANT EXECUTE ON FUNCTION get_user_organizational_context(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_workflow_eligible_users(UUID, VARCHAR(100)) TO authenticated;
GRANT EXECUTE ON FUNCTION log_security_event(VARCHAR(100), UUID, VARCHAR(100), UUID, VARCHAR(100), VARCHAR(50), JSONB, UUID) TO authenticated;

-- Grant execute permissions to service role for internal functions
GRANT EXECUTE ON FUNCTION evaluate_permission_match(RECORD, RECORD, JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION evaluate_permission_conditions(JSONB, JSONB, RECORD) TO service_role;
GRANT EXECUTE ON FUNCTION evaluate_time_constraints(JSONB) TO service_role;
GRANT EXECUTE ON FUNCTION execute_query(TEXT, TEXT[]) TO service_role;

-- Create indexes for better performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_user_event_time 
ON audit_logs (user_id, event_type, timestamp DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_workflow_instance 
ON audit_logs (workflow_instance_id, timestamp DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_workflow_permissions_lookup 
ON workflow_permissions (workflow_step_id, actor_id, group_type, group_id) 
WHERE is_active = true;

-- Add helpful comments
COMMENT ON FUNCTION get_user_active_positions(UUID) IS 'Returns all active organizational positions for a user with full context';
COMMENT ON FUNCTION check_workflow_permission(UUID, UUID, VARCHAR(100), JSONB) IS 'Comprehensive RBAC permission check for workflow operations';
COMMENT ON FUNCTION get_user_organizational_context(UUID) IS 'Returns complete organizational context for a user in JSON format';
COMMENT ON FUNCTION get_workflow_eligible_users(UUID, VARCHAR(100)) IS 'Returns all users eligible to perform a specific workflow action';