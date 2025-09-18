-- Comprehensive Workflow System with Enhanced RBAC
-- Version: 2.0
-- Migration: 001_initial_workflow_rbac_schema

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- ORGANIZATIONAL STRUCTURE TABLES
-- ============================================================================

-- Core organizations table
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Organization branches (physical locations)
CREATE TABLE organization_branches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, code)
);

-- Organization buildings within branches
CREATE TABLE organization_buildings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    branch_id UUID NOT NULL REFERENCES organization_branches(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    address TEXT,
    floors INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(branch_id, code)
);

-- Worker seats within buildings
CREATE TABLE organization_worker_seats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    building_id UUID NOT NULL REFERENCES organization_buildings(id) ON DELETE CASCADE,
    seat_number VARCHAR(50) NOT NULL,
    floor INTEGER,
    section VARCHAR(100),
    is_occupied BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(building_id, seat_number)
);

-- Organization departments (logical grouping)
CREATE TABLE organization_departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    parent_department_id UUID REFERENCES organization_departments(id),
    head_user_id UUID, -- Will reference users table when created
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(organization_id, code)
);

-- Organization teams within departments
CREATE TABLE organization_teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    department_id UUID NOT NULL REFERENCES organization_departments(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    team_lead_user_id UUID, -- Will reference users table when created
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(department_id, code)
);

-- Group designations (roles within departments/teams)
CREATE TABLE organization_group_designations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_type VARCHAR(20) NOT NULL CHECK (group_type IN ('department', 'team')),
    group_id UUID NOT NULL, -- References either department or team
    designation_name VARCHAR(255) NOT NULL,
    designation_code VARCHAR(50) NOT NULL,
    job_level INTEGER,
    salary_grade VARCHAR(20),
    responsibilities TEXT,
    requirements TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(group_type, group_id, designation_code)
);

-- Organization positions (combination of designation and seat)
CREATE TABLE organization_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_designation_id UUID NOT NULL REFERENCES organization_group_designations(id) ON DELETE CASCADE,
    worker_seat_id UUID NOT NULL REFERENCES organization_worker_seats(id) ON DELETE CASCADE,
    position_title VARCHAR(255) NOT NULL,
    is_filled BOOLEAN DEFAULT false,
    start_date DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(worker_seat_id) -- One position per seat
);

-- ============================================================================
-- USER AND AUTHENTICATION TABLES
-- ============================================================================

-- Extended users table (assuming auth.users exists in Supabase)
CREATE TABLE users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    profile_image_url TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User position assignments
CREATE TABLE user_position_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    position_id UUID NOT NULL REFERENCES organization_positions(id) ON DELETE CASCADE,
    assignment_type VARCHAR(50) DEFAULT 'primary' CHECK (assignment_type IN ('primary', 'secondary', 'temporary')),
    start_date DATE NOT NULL DEFAULT CURRENT_DATE,
    end_date DATE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    assigned_by UUID REFERENCES users(id),
    CONSTRAINT valid_date_range CHECK (end_date IS NULL OR end_date >= start_date)
);

-- ============================================================================
-- WORKFLOW CORE TABLES
-- ============================================================================

-- Workflow definitions
CREATE TABLE workflows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES users(id),
    workflow_definition JSONB NOT NULL,
    rbac_enabled BOOLEAN DEFAULT true
);

-- Workflow instances
CREATE TABLE workflow_instances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_id UUID REFERENCES workflows(id) ON DELETE CASCADE,
    current_state VARCHAR(100) NOT NULL,
    context_data JSONB,
    initiator_user_id UUID REFERENCES users(id),
    organization_id UUID REFERENCES organizations(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'paused', 'completed', 'cancelled'))
);

-- Workflow steps/states
CREATE TABLE workflow_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_id UUID NOT NULL REFERENCES workflows(id) ON DELETE CASCADE,
    step_name VARCHAR(255) NOT NULL,
    step_order INTEGER NOT NULL,
    step_type VARCHAR(100) CHECK (step_type IN ('approval', 'task', 'decision', 'parallel')),
    required_actors JSONB, -- Array of required actor names
    optional_actors JSONB, -- Array of optional actor names
    step_conditions JSONB, -- Conditions for step execution
    timeout_hours INTEGER,
    is_parallel BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Workflow history/audit trail
CREATE TABLE workflow_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    instance_id UUID REFERENCES workflow_instances(id) ON DELETE CASCADE,
    from_state VARCHAR(100),
    to_state VARCHAR(100) NOT NULL,
    action VARCHAR(100),
    context_data JSONB,
    performed_by UUID REFERENCES users(id),
    actor_role VARCHAR(100),
    permission_context JSONB,
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    reason TEXT
);

-- ============================================================================
-- RBAC SYSTEM TABLES
-- ============================================================================

-- Workflow actors (roles that can perform actions)
CREATE TABLE workflow_actors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    capabilities JSONB, -- What this actor can do
    is_active BOOLEAN DEFAULT true
);

-- Workflow permissions (who can do what in which context)
CREATE TABLE workflow_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_step_id UUID NOT NULL REFERENCES workflow_steps(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES workflow_actors(id) ON DELETE CASCADE,
    group_type VARCHAR(20) NOT NULL CHECK (group_type IN ('department', 'team')),
    group_id UUID NOT NULL, -- References department or team
    designation_id UUID REFERENCES organization_group_designations(id),
    permission_type VARCHAR(50) NOT NULL CHECK (permission_type IN ('required', 'optional', 'forbidden')),
    conditions JSONB, -- Additional conditions
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(workflow_step_id, actor_id, group_type, group_id, designation_id)
);

-- ============================================================================
-- AUDIT AND SECURITY TABLES
-- ============================================================================

-- Comprehensive audit logs
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(100) NOT NULL,
    user_id UUID REFERENCES users(id),
    resource_type VARCHAR(100),
    resource_id UUID,
    action VARCHAR(100),
    result VARCHAR(50),
    details TEXT, -- Encrypted sensitive data
    workflow_instance_id UUID REFERENCES workflow_instances(id),
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Workflow performance indexes
CREATE INDEX idx_workflow_instances_current_state ON workflow_instances(current_state);
CREATE INDEX idx_workflow_instances_organization ON workflow_instances(organization_id, status);
CREATE INDEX idx_workflow_history_instance_id ON workflow_history(instance_id);
CREATE INDEX idx_workflow_history_performed_at ON workflow_history(performed_at);

-- RBAC performance indexes
CREATE INDEX idx_user_position_assignments_active 
ON user_position_assignments (user_id, is_active, start_date, end_date);

CREATE INDEX idx_workflow_permissions_step_actor 
ON workflow_permissions (workflow_step_id, actor_id, is_active);

CREATE INDEX idx_workflow_permissions_group 
ON workflow_permissions (group_type, group_id, is_active);

-- Composite indexes for common queries
CREATE INDEX idx_workflow_instances_status_created ON workflow_instances(status, created_at);
CREATE INDEX idx_user_active_positions_composite 
ON user_position_assignments (user_id, is_active, assignment_type) 
WHERE is_active = true AND (end_date IS NULL OR end_date >= CURRENT_DATE);

CREATE INDEX idx_workflow_permission_lookup 
ON workflow_permissions (workflow_step_id, actor_id, group_type, group_id, designation_id) 
WHERE is_active = true;

-- Organizational structure indexes
CREATE INDEX idx_org_departments_organization ON organization_departments(organization_id, is_active);
CREATE INDEX idx_org_teams_department ON organization_teams(department_id, is_active);
CREATE INDEX idx_org_designations_group ON organization_group_designations(group_type, group_id, is_active);

-- Audit log indexes
CREATE INDEX idx_audit_logs_timestamp ON audit_logs(timestamp);
CREATE INDEX idx_audit_logs_user_event ON audit_logs(user_id, event_type, timestamp);
CREATE INDEX idx_audit_logs_workflow_instance ON audit_logs(workflow_instance_id, timestamp);

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC TIMESTAMPS
-- ============================================================================

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to relevant tables
CREATE TRIGGER update_organizations_updated_at BEFORE UPDATE ON organizations 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_workflow_instances_updated_at BEFORE UPDATE ON workflow_instances 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- Enable RLS on sensitive tables
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE workflow_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Users can only see their own data
CREATE POLICY "Users can view own data" ON users
    FOR SELECT USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (auth.uid() = id);

-- Organization access based on membership
CREATE POLICY "Organization members can view" ON organizations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_position_assignments upa
            JOIN organization_positions op ON upa.position_id = op.id
            JOIN organization_group_designations ogd ON op.group_designation_id = ogd.id
            JOIN organization_departments od ON (ogd.group_type = 'department' AND ogd.group_id = od.id)
            WHERE upa.user_id = auth.uid() 
            AND od.organization_id = organizations.id
            AND upa.is_active = true
        ) OR EXISTS (
            SELECT 1 FROM user_position_assignments upa
            JOIN organization_positions op ON upa.position_id = op.id
            JOIN organization_group_designations ogd ON op.group_designation_id = ogd.id
            JOIN organization_teams ot ON (ogd.group_type = 'team' AND ogd.group_id = ot.id)
            JOIN organization_departments od ON ot.department_id = od.id
            WHERE upa.user_id = auth.uid() 
            AND od.organization_id = organizations.id
            AND upa.is_active = true
        )
    );

-- Workflow instance access based on organization membership
CREATE POLICY "Workflow access by organization" ON workflow_instances
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_position_assignments upa
            JOIN organization_positions op ON upa.position_id = op.id
            JOIN organization_group_designations ogd ON op.group_designation_id = ogd.id
            WHERE upa.user_id = auth.uid() 
            AND upa.is_active = true
            AND (
                (ogd.group_type = 'department' AND EXISTS (
                    SELECT 1 FROM organization_departments od 
                    WHERE od.id = ogd.group_id AND od.organization_id = workflow_instances.organization_id
                )) OR
                (ogd.group_type = 'team' AND EXISTS (
                    SELECT 1 FROM organization_teams ot
                    JOIN organization_departments od ON ot.department_id = od.id
                    WHERE ot.id = ogd.group_id AND od.organization_id = workflow_instances.organization_id
                ))
            )
        )
    );

-- Audit log access (admins only)
CREATE POLICY "Audit log admin access" ON audit_logs
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM user_position_assignments upa
            JOIN organization_positions op ON upa.position_id = op.id
            JOIN organization_group_designations ogd ON op.group_designation_id = ogd.id
            WHERE upa.user_id = auth.uid() 
            AND upa.is_active = true
            AND ogd.job_level >= 9 -- Admin level
        )
    );

-- ============================================================================
-- INITIAL DATA SEEDING
-- ============================================================================

-- Insert default workflow actors
INSERT INTO workflow_actors (name, description, capabilities) VALUES
('requestor', 'Initiates workflow requests', '["create_request", "view_own_requests"]'),
('analyzer', 'Analyzes and reviews requests', '["review_request", "analyze_data", "add_comments"]'),
('approver', 'Approves or rejects requests', '["approve", "reject", "request_changes"]'),
('designer', 'Creates designs and specifications', '["create_design", "modify_design", "approve_design"]'),
('developer', 'Implements solutions', '["implement", "code_review", "deploy"]'),
('tester', 'Tests and validates solutions', '["test", "validate", "report_bugs"]'),
('implementor', 'Deploys and implements', '["deploy", "configure", "monitor"]'),
('supporter', 'Provides support and maintenance', '["support", "maintain", "troubleshoot"]');

-- Create function to validate organizational hierarchy
CREATE OR REPLACE FUNCTION validate_org_hierarchy()
RETURNS TRIGGER AS $$
BEGIN
    -- Prevent circular references in department hierarchy
    IF NEW.parent_department_id IS NOT NULL THEN
        IF NEW.id = NEW.parent_department_id THEN
            RAISE EXCEPTION 'Department cannot be its own parent';
        END IF;
        
        -- Check for circular reference (simplified check)
        IF EXISTS (
            SELECT 1 FROM organization_departments 
            WHERE id = NEW.parent_department_id 
            AND parent_department_id = NEW.id
        ) THEN
            RAISE EXCEPTION 'Circular department hierarchy detected';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_department_hierarchy 
    BEFORE INSERT OR UPDATE ON organization_departments
    FOR EACH ROW EXECUTE FUNCTION validate_org_hierarchy();

-- Add comments for documentation
COMMENT ON TABLE organizations IS 'Core organizations in the system';
COMMENT ON TABLE workflow_instances IS 'Active workflow instances with state tracking';
COMMENT ON TABLE workflow_permissions IS 'RBAC permissions for workflow steps';
COMMENT ON TABLE audit_logs IS 'Comprehensive audit trail for security and compliance';

-- Add constraint to ensure group_id references valid department or team
ALTER TABLE organization_group_designations 
ADD CONSTRAINT check_valid_group_reference 
CHECK (
    (group_type = 'department' AND EXISTS (SELECT 1 FROM organization_departments WHERE id = group_id)) OR
    (group_type = 'team' AND EXISTS (SELECT 1 FROM organization_teams WHERE id = group_id))
);