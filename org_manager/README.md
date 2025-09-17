# Organization Manager

A Flutter application for managing multiple organizations with workflows, sales, and rental capabilities, powered by Supabase.

## Features

- **Multi-organization management** - Create and manage multiple organizations
- **Workflow management** - Create workflows with tasks and assignments
- **Product management** - Manage inventory for sales and rentals
- **Sales tracking** - Record and track sales transactions
- **Rental management** - Manage rental agreements and tracking
- **Authentication** - Secure user authentication with Supabase Auth

## Setup

### Prerequisites

- Flutter SDK (>=3.8.1)
- Supabase account and project

### Supabase Project Configuration

This app is configured to work with the following Supabase project:
- **Project URL**: https://clitxbssfloylyiuhekv.supabase.co
- **API Key**: Already configured in the app

### Database Setup

**Step 1:** Go to your Supabase project dashboard at https://clitxbssfloylyiuhekv.supabase.co

**Step 2:** Navigate to the SQL Editor and execute the following SQL to create the required tables and security policies:

```sql
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

-- Row Level Security (RLS) policies
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

-- Similar policies for workflows, sales, and rentals
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
```

**Step 3:** Enable Row Level Security by going to Authentication > Policies in your Supabase dashboard

**Step 4:** (Optional) Set up email templates in Authentication > Templates if you want custom email verification/password reset emails

### Environment Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### First Time Setup

1. **Create an account**: Use the registration screen to create your first user account
2. **Create an organization**: After login, create your first organization
3. **Start managing**: Begin adding products, workflows, sales, and rentals

**Note:** The Supabase configuration is already set up for the project https://clitxbssfloylyiuhekv.supabase.co

## Project Structure

```
lib/
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
├── services/        # Business logic and API calls
├── utils/           # Utilities and configuration
└── widgets/         # Reusable UI components
```

## Architecture

- **State Management**: Provider pattern for reactive state management
- **Database**: Supabase PostgreSQL with real-time subscriptions
- **Authentication**: Supabase Auth with email/password
- **Navigation**: Go Router for declarative routing
- **UI**: Material Design 3 with responsive layouts

## Features Overview

### Organizations
- Create and manage multiple organizations
- Add/remove members
- Switch between organizations

### Workflows
- Create workflows with multiple tasks
- Assign tasks to team members
- Track workflow progress and status

### Products
- Manage product inventory
- Set up products for sale or rent
- Track quantities and pricing

### Sales
- Record sales transactions
- Track customer information
- Monitor sales status and revenue

### Rentals
- Manage rental agreements
- Track rental periods and returns
- Calculate rental fees and extensions

## Getting Started

```bash
cd org_manager
flutter pub get
flutter run
```

## Troubleshooting

### Common Issues

**1. Developer Extension Error (Web)**
```
registerExtension() from dart:developer is only supported in build/run/test environments
```
**Solution**: This warning is handled automatically by the app configuration. Debug mode is disabled for web builds to prevent this issue.

**2. Supabase Connection Issues**
```
Failed to load resource: net::ERR_NAME_NOT_RESOLVED
```
**Solutions**:
- Ensure you've set up the database using the `supabase_setup.sql` file
- Clear Flutter cache: `flutter clean && flutter pub get`
- Check that your Supabase project is active at https://clitxbssfloylyiuhekv.supabase.co

**3. Authentication Errors**
- Make sure you've run the database setup script
- Enable email authentication in your Supabase project settings
- Check that Row Level Security policies are properly configured

### Reset Instructions

If you encounter persistent issues:

1. **Clear Flutter cache**:
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Reset Supabase database**:
   - Go to https://clitxbssfloylyiuhekv.supabase.co
   - Drop all tables if they exist
   - Re-run the `supabase_setup.sql` script

3. **Restart your development server**:
   ```bash
   flutter run --hot-reload
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.