-- Organization Manager Database Setup Script
-- Execute this in your Supabase SQL Editor: https://clitxbssfloylyiuhekv.supabase.co

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Organizations table
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    logo_url TEXT,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    member_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products table
CREATE TABLE public.products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('goods', 'service')),
    price DECIMAL(10,2) NOT NULL,
    image_url TEXT,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    is_available_for_sale BOOLEAN DEFAULT false,
    is_available_for_rent BOOLEAN DEFAULT false,
    rent_price_per_day DECIMAL(10,2),
    quantity_available INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Workflows table
CREATE TABLE public.workflows (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL CHECK (status IN ('draft', 'active', 'paused', 'completed')),
    tasks JSONB DEFAULT '[]',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sales table
CREATE TABLE public.sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    customer_id TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    items JSONB NOT NULL DEFAULT '[]',
    total_amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'shipped', 'delivered', 'cancelled')),
    sale_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rentals table
CREATE TABLE public.rentals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    customer_id TEXT NOT NULL,
    customer_name TEXT NOT NULL,
    customer_email TEXT NOT NULL,
    items JSONB NOT NULL DEFAULT '[]',
    total_amount DECIMAL(10,2) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('pending', 'confirmed', 'active', 'returned', 'cancelled')),
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    return_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workflows ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rentals ENABLE ROW LEVEL SECURITY;

-- Organizations policies
CREATE POLICY "Users can view organizations they own or are members of" ON public.organizations
    FOR SELECT USING (
        auth.uid() = owner_id OR
        auth.uid() = ANY(member_ids)
    );

CREATE POLICY "Users can insert organizations they own" ON public.organizations
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "Organization owners can update their organizations" ON public.organizations
    FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY "Organization owners can delete their organizations" ON public.organizations
    FOR DELETE USING (auth.uid() = owner_id);

-- Products policies
CREATE POLICY "Users can view products of their organizations" ON public.products
    FOR SELECT USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

CREATE POLICY "Organization members can insert products" ON public.products
    FOR INSERT WITH CHECK (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

CREATE POLICY "Organization members can update products" ON public.products
    FOR UPDATE USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

CREATE POLICY "Organization members can delete products" ON public.products
    FOR DELETE USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

-- Workflows policies
CREATE POLICY "Users can view workflows of their organizations" ON public.workflows
    FOR SELECT USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

CREATE POLICY "Organization members can manage workflows" ON public.workflows
    FOR ALL USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

-- Sales policies
CREATE POLICY "Users can view sales of their organizations" ON public.sales
    FOR SELECT USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

CREATE POLICY "Organization members can manage sales" ON public.sales
    FOR ALL USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

-- Rentals policies
CREATE POLICY "Users can view rentals of their organizations" ON public.rentals
    FOR SELECT USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

CREATE POLICY "Organization members can manage rentals" ON public.rentals
    FOR ALL USING (
        organization_id IN (
            SELECT id FROM public.organizations
            WHERE auth.uid() = owner_id OR auth.uid() = ANY(member_ids)
        )
    );

-- Create indexes for better performance
CREATE INDEX idx_organizations_owner_id ON public.organizations(owner_id);
CREATE INDEX idx_organizations_member_ids ON public.organizations USING GIN(member_ids);
CREATE INDEX idx_products_organization_id ON public.products(organization_id);
CREATE INDEX idx_workflows_organization_id ON public.workflows(organization_id);
CREATE INDEX idx_sales_organization_id ON public.sales(organization_id);
CREATE INDEX idx_rentals_organization_id ON public.rentals(organization_id);

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'Organization Manager database setup completed successfully!';
    RAISE NOTICE 'You can now run your Flutter app and start creating organizations.';
END $$;