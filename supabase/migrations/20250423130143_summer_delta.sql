/*
  # Fix Contest Boost Count for Sleep Category

  1. Changes
    - Create a function to sync contest boost counts for sleep category boosts
    - Add trigger to update contest boost counts when a sleep boost is completed
    - Fix issue where sleep boosts don't update contest progress
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create function to sync contest boost counts for sleep category boosts
CREATE OR REPLACE FUNCTION sync_contest_boost_counts(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today date := current_date;
  v_sleep_boosts_today integer;
  v_active_contests record;
  v_updated_count integer := 0;
  v_result jsonb;
BEGIN
  -- Count sleep boosts completed today
  SELECT COUNT(*) INTO v_sleep_boosts_today
  FROM completed_boosts cb
  JOIN boost_fp_values bfp ON cb.boost_id = bfp.boost_id
  WHERE cb.user_id = p_user_id
    AND cb.completed_date = v_today
    AND bfp.category = 'sleep';
  
  -- If no sleep boosts completed today, return early
  IF v_sleep_boosts_today = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'message', 'No sleep boosts completed today',
      'updated_contests', 0
    );
  END IF;
  
  -- Find all active sleep contests for this user
  FOR v_active_contests IN (
    -- First check active_contests table
    SELECT ac.id, ac.challenge_id, ac.boost_count, ac.last_daily_boost_completed_date
    FROM active_contests ac
    JOIN contests c ON ac.contest_id = c.id
    WHERE ac.user_id = p_user_id
      AND ac.status = 'active'
      AND LOWER(c.health_category) = 'sleep'
    
    UNION ALL
    
    -- Then check challenges table (legacy)
    SELECT c.id, c.challenge_id, c.boost_count, c.last_daily_boost_completed_date
    FROM challenges c
    JOIN contests ct ON c.challenge_id = ct.challenge_id
    WHERE c.user_id = p_user_id
      AND c.status = 'active'
      AND c.category = 'Contests'
      AND LOWER(ct.health_category) = 'sleep'
  ) LOOP
    -- Check if boost already completed today for this contest
    IF v_active_contests.last_daily_boost_completed_date IS NULL OR 
       v_active_contests.last_daily_boost_completed_date < v_today THEN
      
      -- Try to update in active_contests first
      UPDATE active_contests
      SET 
        boost_count = COALESCE(boost_count, 0) + 1,
        last_daily_boost_completed_date = v_today
      WHERE id = v_active_contests.id
      RETURNING id;
      
      -- If no rows affected, try challenges table
      IF NOT FOUND THEN
        UPDATE challenges
        SET 
          boost_count = COALESCE(boost_count, 0) + 1,
          last_daily_boost_completed_date = v_today
        WHERE id = v_active_contests.id;
      END IF;
      
      v_updated_count := v_updated_count + 1;
      
      -- Log the update
      INSERT INTO boost_processing_logs (
        processed_at,
        boosts_processed,
        details
      ) VALUES (
        now(),
        1,
        jsonb_build_object(
          'operation', 'sync_contest_boost_counts',
          'user_id', p_user_id,
          'contest_id', v_active_contests.challenge_id,
          'previous_count', v_active_contests.boost_count,
          'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
          'timestamp', now()
        )
      );
    END IF;
  END LOOP;
  
  -- Return result
  v_result := jsonb_build_object(
    'success', true,
    'message', 'Contest boost counts synced successfully',
    'sleep_boosts_today', v_sleep_boosts_today,
    'updated_contests', v_updated_count
  );
  
  RETURN v_result;
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION sync_contest_boost_counts(uuid) TO public;

-- Create trigger function to update contest boost counts when a boost is completed
CREATE OR REPLACE FUNCTION update_contest_boost_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_boost_category text;
  v_active_contests record;
  v_today date := current_date;
BEGIN
  -- Get the category of the completed boost
  SELECT category INTO v_boost_category
  FROM boost_fp_values
  WHERE boost_id = NEW.boost_id;
  
  -- Only proceed if this is a sleep category boost
  IF LOWER(v_boost_category) = 'sleep' THEN
    -- Find all active sleep contests for this user
    FOR v_active_contests IN (
      -- First check active_contests table
      SELECT ac.id, ac.challenge_id, ac.boost_count, ac.last_daily_boost_completed_date
      FROM active_contests ac
      JOIN contests c ON ac.contest_id = c.id
      WHERE ac.user_id = NEW.user_id
        AND ac.status = 'active'
        AND LOWER(c.health_category) = 'sleep'
      
      UNION ALL
      
      -- Then check challenges table (legacy)
      SELECT c.id, c.challenge_id, c.boost_count, c.last_daily_boost_completed_date
      FROM challenges c
      JOIN contests ct ON c.challenge_id = ct.challenge_id
      WHERE c.user_id = NEW.user_id
        AND c.status = 'active'
        AND c.category = 'Contests'
        AND LOWER(ct.health_category) = 'sleep'
    ) LOOP
      -- Check if boost already completed today for this contest
      IF v_active_contests.last_daily_boost_completed_date IS NULL OR 
         v_active_contests.last_daily_boost_completed_date < v_today THEN
        
        -- Try to update in active_contests first
        UPDATE active_contests
        SET 
          boost_count = COALESCE(boost_count, 0) + 1,
          last_daily_boost_completed_date = v_today
        WHERE id = v_active_contests.id
        RETURNING id;
        
        -- If no rows affected, try challenges table
        IF NOT FOUND THEN
          UPDATE challenges
          SET 
            boost_count = COALESCE(boost_count, 0) + 1,
            last_daily_boost_completed_date = v_today
          WHERE id = v_active_contests.id;
        END IF;
        
        -- Log the update
        INSERT INTO boost_processing_logs (
          processed_at,
          boosts_processed,
          details
        ) VALUES (
          now(),
          1,
          jsonb_build_object(
            'operation', 'update_contest_boost_count',
            'user_id', NEW.user_id,
            'boost_id', NEW.boost_id,
            'contest_id', v_active_contests.challenge_id,
            'previous_count', v_active_contests.boost_count,
            'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
            'timestamp', now()
          )
        );
      END IF;
    END LOOP;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to update contest boost count when a boost is completed
DROP TRIGGER IF EXISTS update_contest_boost_count_trigger ON public.completed_boosts;
CREATE TRIGGER update_contest_boost_count_trigger
  AFTER INSERT ON public.completed_boosts
  FOR EACH ROW
  EXECUTE FUNCTION update_contest_boost_count();

-- Run the sync function for all users with active sleep contests
DO $$
DECLARE
  v_user record;
  v_result jsonb;
BEGIN
  -- Get all users with active sleep contests
  FOR v_user IN (
    -- From active_contests table
    SELECT DISTINCT ac.user_id
    FROM active_contests ac
    JOIN contests c ON ac.contest_id = c.id
    WHERE ac.status = 'active'
      AND LOWER(c.health_category) = 'sleep'
    
    UNION
    
    -- From challenges table (legacy)
    SELECT DISTINCT ch.user_id
    FROM challenges ch
    JOIN contests c ON ch.challenge_id = c.challenge_id
    WHERE ch.status = 'active'
      AND ch.category = 'Contests'
      AND LOWER(c.health_category) = 'sleep'
  ) LOOP
    -- Sync contest boost counts for this user
    SELECT sync_contest_boost_counts(v_user.user_id) INTO v_result;
    
    -- Log the result
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      0,
      jsonb_build_object(
        'operation', 'sync_contest_boost_counts_migration',
        'user_id', v_user.user_id,
        'result', v_result,
        'timestamp', now()
      )
    );
  END LOOP;
END $$;