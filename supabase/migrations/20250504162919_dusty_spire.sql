/*
  # Update All Users to Pro Plan Trial

  1. Changes
    - Set all users to Pro Plan
    - Set subscription_start_date to May 1, 2025
    - Ensure trial period is properly tracked
    
  2. Security
    - Maintain existing RLS policies
*/

-- Update all users to Pro Plan with subscription start date of May 1, 2025
UPDATE public.users
SET 
  plan = 'Pro Plan',
  subscription_start_date = '2025-05-01 00:00:00.000Z'::timestamptz
WHERE 
  plan != 'Pro Plan' OR subscription_start_date IS NULL;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_all_users_to_pro_plan_trial',
    'description', 'Updated all users to Pro Plan with subscription start date of May 1, 2025',
    'timestamp', now(),
    'affected_users', (SELECT COUNT(*) FROM public.users)
  )
);