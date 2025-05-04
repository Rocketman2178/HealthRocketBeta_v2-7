/*
  # Create Plans Table

  1. New Table
    - `plans` - Stores subscription plan information
      - `id` (text, primary key)
      - `name` (text)
      - `description` (text)
      - `price_id` (text)
      - `price` (numeric)
      - `interval` (text)
      - `features` (jsonb)
      - `is_active` (boolean)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)
    
  2. Security
    - Enable RLS on the table
    - Add policy for users to view active plans
*/

-- Create plans table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.plans (
  id text PRIMARY KEY,
  name text NOT NULL,
  description text,
  price_id text NOT NULL,
  price numeric(10,2) NOT NULL,
  interval text NOT NULL,
  features jsonb DEFAULT '[]'::jsonb,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;

-- Drop existing policy if it exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'plans' AND policyname = 'plans_select_policy'
  ) THEN
    DROP POLICY "plans_select_policy" ON public.plans;
  END IF;
END
$$;

-- Create policy for users to view active plans
CREATE POLICY "plans_select_policy"
  ON public.plans
  FOR SELECT
  TO public
  USING (is_active = true);

-- Insert default plans
INSERT INTO public.plans (id, name, description, price_id, price, interval, features, is_active)
VALUES
  ('free_plan', 'Free Plan', 'Basic access to Health Rocket', 'price_1Qt7haHPnFqUVCZdl33y9bET', 0, 'month', 
   jsonb_build_array(
     'Access to all basic features',
     'Daily boosts and challenges',
     'Health tracking',
     'Community access',
     'Prize Pool Rewards not included'
   ), true),
  ('pro_plan', 'Pro Plan', 'Full access to all features', 'price_1Qt7jVHPnFqUVCZdutw3mSWN', 59.95, 'month', 
   jsonb_build_array(
     'All Free Plan features',
     'Premium challenges and quests',
     'Prize pool eligibility',
     'Advanced health analytics',
     '60-day free trial'
   ), true),
  ('family_plan', 'Pro + Family', 'Share with up to 5 family members', 'price_1Qt7lXHPnFqUVCZdlpS1vrfs', 89.95, 'month', 
   jsonb_build_array(
     'All Pro Plan features',
     'Up to 5 family members',
     'Family challenges and competitions',
     'Family leaderboard',
     'Shared progress tracking'
   ), true),
  ('team_plan', 'Pro + Team', 'For teams and organizations', 'price_1Qt7mVHPnFqUVCZdqvWROuTD', 149.95, 'month', 
   jsonb_build_array(
     'All Pro Plan features',
     'Up to 20 team members',
     'Team challenges and competitions',
     'Team analytics dashboard',
     'Admin controls and reporting'
   ), true)
ON CONFLICT (id) DO UPDATE
SET 
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  price_id = EXCLUDED.price_id,
  price = EXCLUDED.price,
  interval = EXCLUDED.interval,
  features = EXCLUDED.features,
  is_active = EXCLUDED.is_active,
  updated_at = now();

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'create_plans_table',
    'description', 'Created plans table and inserted default plans',
    'timestamp', now()
  )
);