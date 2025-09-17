# Supabase Setup Guide

## Step 1: Enable Authentication

1. Go to your Supabase dashboard: https://clitxbssfloylyiuhekv.supabase.co
2. Navigate to **Authentication** → **Settings**
3. Make sure the following are enabled:
   - **Enable email confirmations**: OFF (for development)
   - **Enable email auth**: ON
   - **Enable phone auth**: OFF (optional)

## Step 2: Configure Email Authentication

1. In **Authentication** → **Settings**:
   - Set **Site URL** to: `http://localhost:3000` (or your development URL)
   - **Redirect URLs**: Add `http://localhost:3000/**` for development

## Step 3: Set Up Database Schema

1. Go to **SQL Editor**
2. Copy and paste the content from `supabase_setup.sql`
3. Click **Run** to execute

## Step 4: Verify Setup

1. Go to **Authentication** → **Users**
2. You should see an empty users table (this is normal)
3. Go to **Database** → **Tables**
4. You should see these tables:
   - organizations
   - products
   - workflows
   - sales
   - rentals

## Step 5: Test Authentication

1. Try registering a new user in your Flutter app
2. Check **Authentication** → **Users** to see if the user was created
3. If you get a 400 error, double-check that:
   - Email authentication is enabled
   - Your project URL and API key are correct
   - The database schema has been set up

## Common Issues

### 400 Bad Request Error
- **Cause**: Authentication not properly enabled
- **Solution**: Enable email authentication in Settings

### Invalid API Key Error
- **Cause**: Wrong API key or project URL
- **Solution**: Verify the keys in `lib/utils/supabase_config.dart`

### Database Connection Error
- **Cause**: Tables not created
- **Solution**: Run the `supabase_setup.sql` script

## Project Configuration

Your project is configured with:
- **URL**: https://clitxbssfloylyiuhekv.supabase.co
- **Anon Key**: (configured in the app)

## Need Help?

If you're still having issues:
1. Check the browser console for detailed error messages
2. Verify your Supabase project is active
3. Make sure you've run all setup steps above
4. Try creating a test user directly in the Supabase dashboard