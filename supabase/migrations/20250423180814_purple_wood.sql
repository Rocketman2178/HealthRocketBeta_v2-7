/*
  # Improve Contest Boost Tracking

  1. Changes
    - Create a function to get boost category from boost_id
    - Update the update_contest_boost_count trigger function to properly handle sleep boosts
    - Ensure boost count is updated for active contests when a sleep boost is completed
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- Create function to get boost category from boost_id
CREATE OR REPLACE FUNCTION get_boost_category(p_boost_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category text;
BEGIN
  -- Try to get category from boost_fp_values table
  SELECT category INTO v_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- If not found, try to determine from boost_id prefix
  IF v_category IS NULL THEN
    -- Extract category from boost_id (e.g., 'sleep-t1-1' -> 'sleep')
    v_category := split_part(p_boost_id, '-', 1);
  END IF;
  
  RETURN LOWER(v_category);
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION get_boost_category(text) TO public;

-- Create or replace the update_contest_boost_count trigger function
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
  v_updated_count integer := 0;
BEGIN
  -- Get the category of the completed boost
  SELECT get_boost_category(NEW.boost_id) INTO v_boost_category;
  
  -- Only proceed if this is a sleep category boost
  IF v_boost_category = 'sleep' THEN
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
            'operation', 'update_contest_boost_count',
            'user_id', NEW.user_id,
            'boost_id', NEW.boost_id,
            'boost_category', v_boost_category,
            'contest_id', v_active_contests.challenge_id,
            'previous_count', v_active_contests.boost_count,
            'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
            'timestamp', now()
          )
        );
      END IF;
    END LOOP;
    
    -- Dispatch event to update UI
    PERFORM pg_notify(
      'contest_boost_updated',
      jsonb_build_object(
        'user_id', NEW.user_id,
        'boost_category', v_boost_category,
        'updated_count', v_updated_count
      )::text
    );
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS update_contest_boost_count_trigger ON public.completed_boosts;

-- Create trigger to update contest boost count when a boost is completed
CREATE TRIGGER update_contest_boost_count_trigger
  AFTER INSERT ON public.completed_boosts
  FOR EACH ROW
  EXECUTE FUNCTION update_contest_boost_count();

-- Create function to manually sync contest boost counts
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
  WHERE cb.user_id = p_user_id
    AND cb.completed_date = v_today
    AND get_boost_category(cb.boost_id) = 'sleep';
  
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

-- Update the complete_boost function to trigger contest boost updates
CREATE OR REPLACE FUNCTION complete_boost(
  p_user_id uuid,
  p_boost_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fp_value integer;
  v_completed_id uuid;
  v_today date := current_date;
  v_boost_category text;
  v_result jsonb;
  v_contest_sync_result jsonb;
BEGIN
  -- Get FP value for the boost
  SELECT fp_value, category INTO v_fp_value, v_boost_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- Default to 1 FP if not found
  v_fp_value := COALESCE(v_fp_value, 1);
  
  -- If category not found, try to determine from boost_id
  IF v_boost_category IS NULL THEN
    v_boost_category := get_boost_category(p_boost_id);
  END IF;
  
  -- Check if already completed today
  IF EXISTS (
    SELECT 1
    FROM completed_boosts
    WHERE user_id = p_user_id
      AND boost_id = p_boost_id
      AND completed_date = v_today
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'Boost already completed today',
      'fp_earned', 0
    );
  END IF;
  
  -- Insert completed boost
  INSERT INTO completed_boosts (
    user_id,
    boost_id,
    completed_at,
    completed_date
  ) VALUES (
    p_user_id,
    p_boost_id,
    now(),
    v_today
  )
  RETURNING id INTO v_completed_id;
  
  -- Update daily FP
  PERFORM update_daily_fp(
    p_user_id,
    v_today,
    v_fp_value,
    1, -- boosts_completed
    0, -- challenges_completed
    0  -- quests_completed
  );
  
  -- For sleep boosts, sync contest boost counts
  IF LOWER(v_boost_category) = 'sleep' THEN
    SELECT sync_contest_boost_counts(p_user_id) INTO v_contest_sync_result;
  END IF;
  
  -- Return success with FP earned and category
  RETURN jsonb_build_object(
    'success', true,
    'completed_id', v_completed_id,
    'fp_earned', v_fp_value,
    'boost_category', v_boost_category,
    'contest_sync_result', v_contest_sync_result
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION complete_boost(uuid, text) TO public;

-- Create a function to check if a boost is in a specific category
CREATE OR REPLACE FUNCTION is_boost_in_category(
  p_boost_id text,
  p_category text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category text;
BEGIN
  -- Get boost category
  SELECT get_boost_category(p_boost_id) INTO v_category;
  
  -- Compare with requested category
  RETURN LOWER(v_category) = LOWER(p_category);
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION is_boost_in_category(text, text) TO public;

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'update_contest_boost_tracking',
    'description', 'Updated contest boost tracking to automatically update when sleep boosts are completed',
    'timestamp', now()
  )
);