/*
  # Fix Sleep Boost Completion

  1. Changes
    - Update the boost_fp_values table to ensure all sleep boosts have the correct category
    - Fix the get_boost_category function to properly handle case-insensitive comparisons
    - Update the complete_boost function to ensure it returns the correct category
    - Add missing sleep boost entries to the boost_fp_values table
    
  2. Security
    - Maintain existing RLS policies
    - Use security definer functions
*/

-- First, check if we have sleep boosts in the boost_fp_values table
DO $$
DECLARE
  v_sleep_boost_count integer;
BEGIN
  -- Count sleep boosts
  SELECT COUNT(*) INTO v_sleep_boost_count
  FROM boost_fp_values
  WHERE LOWER(category) = 'sleep';
  
  -- If no sleep boosts found, insert them
  IF v_sleep_boost_count = 0 THEN
    -- Insert tier 1 sleep boosts
    INSERT INTO boost_fp_values (boost_id, fp_value, category)
    VALUES 
      ('sleep-t1-1', 1, 'sleep'),
      ('sleep-t1-2', 2, 'sleep'),
      ('sleep-t1-3', 3, 'sleep'),
      ('sleep-t1-4', 4, 'sleep'),
      ('sleep-t1-5', 5, 'sleep'),
      ('sleep-t1-6', 6, 'sleep'),
      ('sleep-t2-1', 7, 'sleep'),
      ('sleep-t2-2', 8, 'sleep'),
      ('sleep-t2-3', 9, 'sleep');
    
    -- Log the insertion
    INSERT INTO boost_processing_logs (
      processed_at,
      boosts_processed,
      details
    ) VALUES (
      now(),
      9,
      jsonb_build_object(
        'operation', 'insert_sleep_boosts',
        'description', 'Added missing sleep boosts to boost_fp_values table',
        'timestamp', now()
      )
    );
  END IF;
END $$;

-- Update the get_boost_category function to handle case sensitivity properly
CREATE OR REPLACE FUNCTION get_boost_category(p_boost_id text)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category text;
  v_prefix text;
BEGIN
  -- First try to get from boost_fp_values
  SELECT category INTO v_category
  FROM boost_fp_values
  WHERE boost_id = p_boost_id;
  
  -- If not found, try to extract from boost_id (e.g., 'sleep-t1-1')
  IF v_category IS NULL THEN
    -- Extract category from boost_id format (e.g., 'sleep-t1-1' -> 'sleep')
    v_prefix := split_part(p_boost_id, '-', 1);
    
    -- Check for known categories (case-insensitive)
    IF LOWER(v_prefix) = 'sleep' THEN
      v_category := 'sleep';
    ELSIF LOWER(v_prefix) = 'mindset' THEN
      v_category := 'mindset';
    ELSIF LOWER(v_prefix) = 'exercise' THEN
      v_category := 'exercise';
    ELSIF LOWER(v_prefix) = 'nutrition' THEN
      v_category := 'nutrition';
    ELSIF LOWER(v_prefix) = 'biohacking' THEN
      v_category := 'biohacking';
    ELSE
      -- Default to 'general' if unknown
      v_category := 'general';
    END IF;
  END IF;
  
  RETURN LOWER(v_category);
END;
$$;

-- Update the complete_boost function to ensure it returns the correct category
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
  
  -- Log the boost completion with category
  INSERT INTO boost_processing_logs (
    processed_at,
    boosts_processed,
    details
  ) VALUES (
    now(),
    1,
    jsonb_build_object(
      'operation', 'complete_boost',
      'user_id', p_user_id,
      'boost_id', p_boost_id,
      'boost_category', v_boost_category,
      'fp_earned', v_fp_value,
      'timestamp', now()
    )
  );
  
  -- Return success with FP earned and category
  RETURN jsonb_build_object(
    'success', true,
    'completed_id', v_completed_id,
    'fp_earned', v_fp_value,
    'boost_category', v_boost_category
  );
END;
$$;

-- Grant execute permission to public
GRANT EXECUTE ON FUNCTION complete_boost(uuid, text) TO public;

-- Update the update_contest_boost_count trigger function to handle case-insensitive comparisons
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
  
  -- Log the boost category for debugging
  INSERT INTO boost_processing_logs (
    processed_at,
    boosts_processed,
    details
  ) VALUES (
    now(),
    1,
    jsonb_build_object(
      'operation', 'boost_category_check',
      'boost_id', NEW.boost_id,
      'detected_category', v_boost_category,
      'timestamp', now()
    )
  );
  
  -- Find all active contests for this user matching the boost category
  FOR v_active_contests IN (
    -- First check active_contests table
    SELECT 
      ac.id, 
      ac.challenge_id, 
      ac.boost_count, 
      ac.last_daily_boost_completed_date,
      LOWER(c.health_category) as contest_category
    FROM active_contests ac
    JOIN contests c ON ac.contest_id = c.id
    WHERE ac.user_id = NEW.user_id
      AND ac.status = 'active'
    
    UNION ALL
    
    -- Then check challenges table (legacy)
    SELECT 
      c.id, 
      c.challenge_id, 
      c.boost_count, 
      c.last_daily_boost_completed_date,
      LOWER(ct.health_category) as contest_category
    FROM challenges c
    JOIN contests ct ON c.challenge_id = ct.challenge_id
    WHERE c.user_id = NEW.user_id
      AND c.status = 'active'
      AND c.category = 'Contests'
  ) LOOP
    -- Check if the boost category matches the contest category
    IF LOWER(v_boost_category) = LOWER(v_active_contests.contest_category) THEN
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
            'contest_category', v_active_contests.contest_category,
            'contest_id', v_active_contests.challenge_id,
            'previous_count', v_active_contests.boost_count,
            'new_count', COALESCE(v_active_contests.boost_count, 0) + 1,
            'timestamp', now()
          )
        );
      END IF;
    END IF;
  END LOOP;
  
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

-- Log the migration
INSERT INTO public.boost_processing_logs (
  processed_at,
  boosts_processed,
  details
) VALUES (
  now(),
  0,
  jsonb_build_object(
    'operation', 'fix_sleep_boost_completion',
    'description', 'Fixed sleep boost completion and contest boost tracking',
    'timestamp', now()
  )
);