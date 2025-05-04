/*
  # Add Subscription Trial Tracking

  1. New Columns
    - `subscription_start_date` - When the subscription started (for trial tracking)
    - `subscription_end_date` - When the subscription is scheduled to end
    
  2. Security
    - Maintain existing RLS policies
*/

-- Add subscription tracking columns to users table
ALTER TABLE public.users 
  ADD COLUMN IF NOT EXISTS subscription_start_date timestamptz,
  ADD COLUMN IF NOT EXISTS subscription_end_date timestamptz;

-- Update existing Pro Plan users to have a subscription start date
UPDATE public.users
SET subscription_start_date = created_at
WHERE plan = 'Pro Plan' AND subscription_start_date IS NULL;

-- Create function to check trial status
CREATE OR REPLACE FUNCTION check_subscription_trial_status(
  p_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_plan text;
  v_subscription_start_date timestamptz;
  v_trial_days integer := 60;
  v_trial_end_date timestamptz;
  v_days_remaining integer;
BEGIN
  -- Get user's plan and subscription start date
  SELECT 
    plan,
    subscription_start_date
  INTO 
    v_plan,
    v_subscription_start_date
  FROM users
  WHERE id = p_user_id;
  
  -- If not on Pro Plan or no subscription start date, return not on trial
  IF v_plan != 'Pro Plan' OR v_subscription_start_date IS NULL THEN
    RETURN jsonb_build_object(
      'is_on_trial', false,
      'plan', v_plan
    );
  END IF;
  
  -- Calculate trial end date
  v_trial_end_date := v_subscription_start_date + (v_trial_days || ' days')::interval;
  
  -- Calculate days remaining
  v_days_remaining := CEIL(EXTRACT(EPOCH FROM (v_trial_end_date - now())) / 86400);
  
  -- Return trial status
  RETURN jsonb_build_object(
    'is_on_trial', v_days_remaining > 0,
    'days_remaining', v_days_remaining,
    'trial_end_date', v_trial_end_date,
    'plan', v_plan
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION check_subscription_trial_status(uuid) TO public;

-- Create function to handle trial expiration
CREATE OR REPLACE FUNCTION handle_expired_trials()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired_count integer := 0;
  v_user record;
BEGIN
  -- Find users whose trial has expired
  FOR v_user IN (
    SELECT 
      u.id,
      u.subscription_start_date
    FROM users u
    WHERE 
      u.plan = 'Pro Plan' AND
      u.subscription_start_date IS NOT NULL AND
      u.subscription_start_date + interval '60 days' < now() AND
      NOT EXISTS (
        SELECT 1 FROM subscriptions s
        WHERE s.user_id = u.id AND s.status = 'active'
      )
  ) LOOP
    -- Update user to Free Plan
    UPDATE users
    SET plan = 'Free Plan'
    WHERE id = v_user.id;
    
    v_expired_count := v_expired_count + 1;
    
    -- Log the trial expiration
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      0,
      jsonb_build_object(
        'operation', 'handle_expired_trials',
        'user_id', v_user.id,
        'subscription_start_date', v_user.subscription_start_date,
        'trial_end_date', v_user.subscription_start_date + interval '60 days',
        'timestamp', now()
      )
    );
  END LOOP;
  
  RETURN v_expired_count;
END;
$$;

-- Create a cron job to check for expired trials daily
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Use proper syntax for cron.schedule
    BEGIN
      PERFORM cron.schedule(
        'handle-expired-trials',
        '0 0 * * *',  -- Run at midnight every day
        'SELECT handle_expired_trials()'
      );
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create cron job: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'pg_cron extension not available. Please set up an external cron job to call handle_expired_trials() daily.';
  END IF;
END
$$;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'add_subscription_trial_tracking',
    'description', 'Added subscription trial tracking with 60-day trial period',
    'timestamp', now()
  )
);