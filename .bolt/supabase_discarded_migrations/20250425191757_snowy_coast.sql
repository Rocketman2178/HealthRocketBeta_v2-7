/*
  # Fix Burn Streak Functionality

  1. Changes
    - Create a function to update burn streak when a boost is completed
    - Create a function to check and reset burn streaks daily
    - Add trigger to update burn streak on boost completion
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Drop existing functions if they exist to avoid conflicts
DROP FUNCTION IF EXISTS update_burn_streak() CASCADE;
DROP FUNCTION IF EXISTS check_and_reset_burn_streaks() CASCADE;

-- Create function to update burn streak when a boost is completed
CREATE OR REPLACE FUNCTION update_burn_streak()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := current_date;
  v_yesterday date := current_date - interval '1 day';
  v_user_id uuid := NEW.user_id;
  v_current_streak integer;
  v_has_completed_today boolean;
  v_has_completed_yesterday boolean;
BEGIN
  -- Get current burn streak
  SELECT burn_streak INTO v_current_streak
  FROM users
  WHERE id = v_user_id;
  
  -- Check if user already completed a boost today
  SELECT EXISTS (
    SELECT 1
    FROM completed_boosts
    WHERE user_id = v_user_id
      AND completed_date = v_today
      AND id != NEW.id
  ) INTO v_has_completed_today;
  
  -- If this is the first boost of the day, check if user completed a boost yesterday
  IF NOT v_has_completed_today THEN
    SELECT EXISTS (
      SELECT 1
      FROM completed_boosts
      WHERE user_id = v_user_id
        AND completed_date = v_yesterday
    ) INTO v_has_completed_yesterday;
    
    -- If user completed a boost yesterday, increment streak
    -- If not, reset streak to 1
    IF v_has_completed_yesterday THEN
      UPDATE users
      SET burn_streak = burn_streak + 1
      WHERE id = v_user_id;
    ELSE
      UPDATE users
      SET burn_streak = 1
      WHERE id = v_user_id;
    END IF;
    
    -- Log the streak update
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      1,
      jsonb_build_object(
        'operation', 'update_burn_streak',
        'user_id', v_user_id,
        'previous_streak', v_current_streak,
        'new_streak', CASE WHEN v_has_completed_yesterday THEN v_current_streak + 1 ELSE 1 END,
        'has_completed_yesterday', v_has_completed_yesterday,
        'timestamp', now()
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to update burn streak when a boost is completed
DROP TRIGGER IF EXISTS update_burn_streak_trigger ON public.completed_boosts;
CREATE TRIGGER update_burn_streak_trigger
  AFTER INSERT ON public.completed_boosts
  FOR EACH ROW
  EXECUTE FUNCTION update_burn_streak();

-- Create function to check and reset burn streaks
CREATE OR REPLACE FUNCTION check_and_reset_burn_streaks()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := current_date;
  v_yesterday date := current_date - interval '1 day';
  v_reset_count integer := 0;
  v_user record;
BEGIN
  -- Find users who have a streak but didn't complete a boost yesterday
  FOR v_user IN (
    SELECT u.id, u.burn_streak
    FROM users u
    WHERE u.burn_streak > 0
      AND NOT EXISTS (
        SELECT 1
        FROM completed_boosts cb
        WHERE cb.user_id = u.id
          AND cb.completed_date = v_yesterday
      )
  ) LOOP
    -- Reset streak to 0
    UPDATE users
    SET burn_streak = 0
    WHERE id = v_user.id;
    
    v_reset_count := v_reset_count + 1;
    
    -- Log the reset
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      0,
      jsonb_build_object(
        'operation', 'reset_burn_streak',
        'user_id', v_user.id,
        'previous_streak', v_user.burn_streak,
        'reason', 'No boost completed yesterday',
        'timestamp', now()
      )
    );
  END LOOP;
  
  RETURN v_reset_count;
END;
$$;

-- Create a cron job to check and reset burn streaks daily
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'pg_cron'
  ) THEN
    -- Use proper syntax for cron.schedule
    BEGIN
      PERFORM cron.schedule(
        'check-and-reset-burn-streaks',
        '0 0 * * *',  -- Run at midnight every day
        'SELECT check_and_reset_burn_streaks()'
      );
    EXCEPTION
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create cron job: %', SQLERRM;
    END;
  ELSE
    RAISE NOTICE 'pg_cron extension not available. Please set up an external cron job to call check_and_reset_burn_streaks() daily.';
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
    'operation', 'fix_burn_streak',
    'description', 'Fixed burn streak increment when completing boosts',
    'timestamp', now()
  )
);